"""Transition1x GNN energy service.

A small FastAPI wrapper around a graph neural network that predicts a single
total energy (eV) for one molecular geometry. The Flutter app talks to it as:

    POST /predict  {"atomic_numbers": [...], "positions": [[x, y, z], ...]}
                -> {"status": "success", "energy_ev": <float>}

    GET  /health  -> {"status": "ok" | "degraded", "message": ...}

Both shapes are relied on by `backend_compute_service.dart` in the Flutter app —
`predictEnergy()` reads `status`/`energy_ev`, and `healthCheck()` only accepts a
200 whose body decodes to JSON carrying `"status": "ok"` (a bare 200 is
deliberately not treated as healthy, because a misrouted deployment answering 200
with an HTML page once looked "healthy"). Do not change either shape without
changing the client.

Four things here were wrong in the first version, and all four are the kind that
fail silently from the app's side:

1. **No CORS.** The app is a *browser* app. Without `CORSMiddleware` the
   preflight `OPTIONS` is rejected before the request is ever made, and
   `predictEnergy()` just returns null — indistinguishable from the model being
   down.
2. **The checkpoint was loaded from a bare relative path.** `torch.load(
   "t1x_model_checkpoint.pt")` only works when the process happens to start in
   this directory, which is not something a container or a platform buildpack
   guarantees. It is resolved against `__file__` now, with an env override.
3. **`@app.on_event("startup")` is deprecated** and removed in recent FastAPI
   releases. It is a `lifespan` context manager now.
4. **A failed model load was invisible.** The exception was printed and then
   `/predict` answered 500 "Model failed to load on startup" with no way to find
   out *why*. The reason is captured and reported by `/health`.
"""

from __future__ import annotations

import os
from contextlib import asynccontextmanager
from pathlib import Path

import torch
import torch.nn as nn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ==========================================
# 1. MODEL ARCHITECTURE (Graph Neural Network)
# ==========================================
# Unchanged from the version the checkpoint was trained against. Every default
# here (hidden_dim, num_interactions, max_Z) is part of the state dict's shape,
# so editing any of them makes load_state_dict fail rather than silently
# degrade — which is the good failure, but it is still a failure.
class MolecularGraphNetwork(nn.Module):
    def __init__(self, hidden_dim=128, num_interactions=3, max_Z=100):
        super().__init__()
        self.embedding = nn.Embedding(max_Z, hidden_dim)

        self.distance_expansion = nn.Sequential(
            nn.Linear(1, hidden_dim),
            nn.SiLU(),
            nn.Linear(hidden_dim, hidden_dim)
        )

        self.interaction_layers = nn.ModuleList([
            nn.Sequential(
                nn.Linear(hidden_dim * 2, hidden_dim),
                nn.SiLU(),
                nn.Linear(hidden_dim, hidden_dim)
            ) for _ in range(num_interactions)
        ])

        self.energy_readout = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.SiLU(),
            nn.Linear(hidden_dim // 2, 1)
        )

    def forward(self, z, pos, mask=None):
        node_features = self.embedding(z)

        pos_expanded_1 = pos.unsqueeze(2)  # [batch, N, 1, 3]
        pos_expanded_2 = pos.unsqueeze(1)  # [batch, 1, N, 3]
        dist_matrix = torch.norm(pos_expanded_1 - pos_expanded_2, dim=-1)

        dist_features = self.distance_expansion(dist_matrix.unsqueeze(-1))

        for layer in self.interaction_layers:
            expanded_nodes = node_features.unsqueeze(2).expand(-1, -1, pos.size(1), -1)
            combined = torch.cat([expanded_nodes, dist_features], dim=-1)
            messages = layer(combined).sum(dim=2)
            node_features = node_features + messages

        per_atom_energy = self.energy_readout(node_features).squeeze(-1)
        if mask is not None:
            per_atom_energy = per_atom_energy * mask

        total_energy = per_atom_energy.sum(dim=-1)
        return total_energy


# ==========================================
# 2. CHECKPOINT RESOLUTION
# ==========================================
BASE_DIR = Path(__file__).resolve().parent
DEFAULT_CHECKPOINT = BASE_DIR / "t1x_model_checkpoint.pt"


def checkpoint_path() -> Path:
    """Where the checkpoint lives.

    Defaults to the copy sitting next to this file, which is how the image and
    the repository are laid out. `T1X_CHECKPOINT` overrides it, so a model built
    elsewhere (a Render disk, an S3 download) does not need a code change.
    """
    override = os.environ.get("T1X_CHECKPOINT", "").strip()
    return Path(override).expanduser() if override else DEFAULT_CHECKPOINT


# ==========================================
# 3. APPLICATION AND LIFESPAN
# ==========================================
model: MolecularGraphNetwork | None = None
model_error: str | None = None


def load_model() -> None:
    """Loads the checkpoint, recording any failure instead of raising.

    Deliberately non-fatal. A process that dies on a bad checkpoint crash-loops
    on a platform like Render and the reason is only visible in the build log;
    one that stays up can be asked why through `/health`.
    """
    global model, model_error

    path = checkpoint_path()
    try:
        if not path.is_file():
            raise FileNotFoundError(
                f"checkpoint not found at {path}. Set T1X_CHECKPOINT to override."
            )

        network = MolecularGraphNetwork()
        checkpoint = torch.load(str(path), map_location=torch.device("cpu"))

        if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
            state = checkpoint["model_state_dict"]
        else:
            state = checkpoint

        network.load_state_dict(state)
        network.eval()

        model = network
        model_error = None
        print(f"Model loaded from {path}")
    except Exception as exc:  # noqa: BLE001 - reported, not swallowed
        model = None
        model_error = f"{type(exc).__name__}: {exc}"
        print(f"Error loading model: {model_error}")


@asynccontextmanager
async def lifespan(_: FastAPI):
    load_model()
    yield


def allowed_origins() -> list[str]:
    """Browser origins permitted to call this service.

    `*` by default. This is a stateless energy calculator with no credentials and
    no user data, so a permissive default is the pragmatic choice and it is what
    makes a local `flutter run -d chrome` work without configuration — the
    dev-server port changes every run. Narrow it in production by setting
    `T1X_ALLOWED_ORIGINS` to a comma-separated list.
    """
    raw = os.environ.get("T1X_ALLOWED_ORIGINS", "*").strip()
    if raw in ("", "*"):
        return ["*"]
    return [origin.strip() for origin in raw.split(",") if origin.strip()]


app = FastAPI(title="Transition1x GNN API", version="1.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins(),
    # Must stay False while allow_origins is "*": the CORS spec forbids the
    # wildcard with credentials, and browsers reject the combination outright.
    # The client sends no cookies or auth headers, so nothing is lost.
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


# ==========================================
# 4. API
# ==========================================
class MoleculeRequest(BaseModel):
    atomic_numbers: list[int]
    positions: list[list[float]]


@app.get("/")
def root() -> dict:
    """Human-readable landing payload, for anyone who opens the URL."""
    return {
        "service": "Transition1x GNN API",
        "endpoints": {
            "health": "GET /health",
            "predict": "POST /predict {atomic_numbers, positions}",
        },
        "docs": "/docs",
    }


@app.get("/health")
def health() -> dict:
    """Liveness *and* readiness, in the shape the app's health check requires.

    `status` is `"degraded"` rather than `"ok"` when the checkpoint did not
    load, and the HTTP status stays 200 so the body can be read. That is the
    point: the app treats anything other than `{"status": "ok"}` as unhealthy
    and shows the `message`, so a service whose model is missing reports why
    instead of looking fine or timing out.
    """
    if model is None:
        return {
            "status": "degraded",
            "message": f"Model unavailable — {model_error}",
            "model_loaded": False,
        }
    return {
        "status": "ok",
        "message": "Transition1x GNN ready.",
        "model_loaded": True,
    }


@app.post("/predict")
def predict_energy(molecule: MoleculeRequest):
    if model is None:
        # 503, not 500: the service is up and the request is fine, the model is
        # simply not available. 500 would suggest a bug in the request path.
        raise HTTPException(
            status_code=503,
            detail=f"Model unavailable — {model_error}",
        )

    atomic_numbers = molecule.atomic_numbers
    positions = molecule.positions

    # Checked here rather than left to torch, so a malformed request gets a
    # message naming the mismatch instead of a broadcasting error from inside
    # the distance matrix.
    if len(atomic_numbers) != len(positions):
        raise HTTPException(
            status_code=422,
            detail=(
                f"atomic_numbers has {len(atomic_numbers)} entries but positions "
                f"has {len(positions)}; they must describe the same atoms."
            ),
        )
    if not atomic_numbers:
        raise HTTPException(status_code=422, detail="No atoms supplied.")
    for index, position in enumerate(positions):
        if len(position) != 3:
            raise HTTPException(
                status_code=422,
                detail=f"positions[{index}] has {len(position)} values; expected 3 (x, y, z).",
            )

    try:
        # Convert lists to tensors and add batch dimension [1, N]
        z = torch.tensor(atomic_numbers, dtype=torch.long).unsqueeze(0)
        pos = torch.tensor(positions, dtype=torch.float32).unsqueeze(0)

        # Create mask to match the training pipeline logic
        mask = (z != 0).float()

        with torch.no_grad():
            energy = model(z, pos, mask)

        return {
            "status": "success",
            "energy_ev": energy.item(),
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"{type(exc).__name__}: {exc}")
