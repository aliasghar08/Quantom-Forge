from fastapi import FastAPI, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from uuid import uuid4

from .models.reaction import ReactionRequest, ReactionStatusResponse, ReactionState
from .services.dmf_worker import run_dmf, compute_imaginary_frequencies

app = FastAPI(title="ColabReaction Compute API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── In-memory job store ──────────────────────────────────────────────────────
# A real deployment would use Celery/Redis or the Firestore worker; this keeps
# the FastAPI service self-contained for local use.
_JOBS: dict = {}


def _run_job(reaction_id: str, request: ReactionRequest) -> None:
    job = _JOBS[reaction_id]
    job["state"] = ReactionState.OPTIMIZING
    job["progress"] = 0.05
    job["message"] = "Interpolating initial path (FB-ENM)…"

    try:
        result = run_dmf(
            reactant_xyz=request.reactant_xyz,
            product_xyz=request.product_xyz,
            charge=request.charge,
            spin_multiplicity=request.spin_multiplicity,
            nmove=request.nmove,
            update_teval=request.update_teval,
            convergence=request.convergence,
            mlip_model=request.mlip_model,
            hf_token=request.hf_token,
        )
        job.update(
            state=ReactionState.COMPLETED,
            progress=1.0,
            message="DMF/UMA optimisation converged.",
            energy_profile=result["energy_profile"],
            energy_profile_ev=result["energy_profile_ev"],
            trajectory_frames=result["trajectory_frames"],
            max_energy_index=result["max_energy_index"],
        )

        # Imaginary frequencies at the highest-energy image (transition state).
        ts_frame = result["trajectory_frames"][result["max_energy_index"]]
        modes = compute_imaginary_frequencies(
            ts_frame,
            charge=request.charge,
            spin_multiplicity=request.spin_multiplicity,
            mlip_model=request.mlip_model,
            hf_token=request.hf_token,
        )
        job["vibrational_modes"] = [
            {"frequency": m["frequency"], "vectors": m["vectors"]} for m in modes
        ]
    except Exception as e:  # pragma: no cover - runtime/dependency failures
        job.update(
            state=ReactionState.ERROR,
            progress=1.0,
            message="DMF/UMA optimisation failed.",
            error=str(e),
        )


@app.post("/reactions/submit", response_model=ReactionStatusResponse)
async def submit_reaction(request: ReactionRequest, background_tasks: BackgroundTasks):
    reaction_id = str(uuid4())
    _JOBS[reaction_id] = {
        "reaction_id": reaction_id,
        "state": ReactionState.PENDING,
        "progress": 0.0,
        "message": "Queued…",
    }
    background_tasks.add_task(_run_job, reaction_id, request)
    return _status(reaction_id)


@app.get("/reactions/{reaction_id}", response_model=ReactionStatusResponse)
async def get_reaction(reaction_id: str):
    return _status(reaction_id)


def _status(reaction_id: str) -> ReactionStatusResponse:
    job = _JOBS.get(reaction_id, {
        "reaction_id": reaction_id,
        "state": ReactionState.ERROR,
        "progress": 0.0,
        "message": "Unknown reaction id",
    })
    return ReactionStatusResponse(**job)


@app.get("/health")
def health_check():
    return {"status": "ok", "message": "ColabReaction Compute Node is active"}
