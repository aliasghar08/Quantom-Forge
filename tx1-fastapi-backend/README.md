# Transition1x GNN energy service

A FastAPI wrapper around a graph neural network that predicts a single total
energy (eV) for one molecular geometry. This is the service behind
`kDefaultGnnBackendUrl` in the Flutter app.

## API

| Method | Path | Body / response |
| --- | --- | --- |
| `GET` | `/health` | `{"status": "ok" \| "degraded", "message": ..., "model_loaded": bool}` |
| `POST` | `/predict` | `{"atomic_numbers": [...], "positions": [[x,y,z], ...]}` → `{"status": "success", "energy_ev": float}` |
| `GET` | `/` | service description |
| `GET` | `/docs` | FastAPI's generated OpenAPI UI |

Both shapes are **load-bearing**: the Flutter client reads `status`/`energy_ev`
in `predictEnergy()`, and `healthCheck()` accepts only a 200 whose body decodes to
JSON carrying `"status": "ok"`. A bare 200 is deliberately rejected by the client,
because a misrouted deployment answering 200 with an HTML page once looked
healthy. Do not change either shape without changing
`quantum_forge/lib/core/services/backend_compute_service.dart`.

`status` is `"degraded"` — with HTTP 200, so the body can be read — when the
checkpoint did not load, and `/predict` then answers **503** (not 500: the service
is up and the request is fine, the model is simply unavailable).

## Running locally

```bash
cd tx1-fastapi-backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

```bash
curl http://127.0.0.1:8000/health
curl -X POST http://127.0.0.1:8000/predict \
  -H 'Content-Type: application/json' \
  -d '{"atomic_numbers":[6,1,1,1,1],"positions":[[0,0,0],[0.63,0.63,0.63],[-0.63,-0.63,0.63],[-0.63,0.63,-0.63],[0.63,-0.63,-0.63]]}'
```

## Tests

```bash
python test_main.py     # standalone, no test runner required
pytest test_main.py     # if you have pytest
```

Neither `pytest` nor `httpx` is in `requirements.txt`: the image does not need
them, and the tests run standalone so they work wherever Python does. The tests
pin the CORS preflight (the thing that decides whether a *browser* client can
call this at all), both response shapes, checkpoint loading, and request
validation.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `T1X_CHECKPOINT` | the `t1x_model_checkpoint.pt` next to `main.py` | Checkpoint location |
| `T1X_ALLOWED_ORIGINS` | `*` | Comma-separated browser origins, or `*` |
| `PORT` | `8000` | Port uvicorn binds |

## Deploying

`Dockerfile` builds a self-contained image with the checkpoint baked in.
`render.yaml` at the repository root is a Render blueprint for it.

**The service name in the blueprint determines the URL, and it does not match the
URL the app currently defaults to.** `render.yaml` declares
`quantom-forge-gnn` (→ `https://quantom-forge-gnn.onrender.com`), while
`kDefaultGnnBackendUrl` is `https://quantom-forge-1.onrender.com`. Either rename
the service in the blueprint to `quantom-forge-1`, or update that constant and
the value in Settings ▸ Compute. Left as-is rather than guessed at, because a
mismatch produces a service that deploys cleanly and is never called.

Two things to know about the free plan: it **spins down when idle**, so the first
request after a quiet period pays a cold start plus the model load; and the image
is large, because the CPU-only PyTorch wheel is a few hundred MB.

## Status in the app

**This service is callable but not surfaced.** The Flutter app has a complete
client for it — `predictEnergy()` in `backend_compute_service.dart`, plus a
persisted `gnnBackendUrl` setting and a `hasGnnBackend` flag — but `predictEnergy`
has **no call sites** and `hasGnnBackend` is unused in the UI. Nothing in the app
invokes the model today; the reaction animation's energies come from the UMA/DMF
backend. Wiring it in is a separate decision, and it should be labelled clearly if
it is: this GNN and UMA are different models with independent absolute-energy
references, so only their *relative* profiles are comparable.

## What was fixed

The first version of `main.py` had four problems, all of which fail silently from
the app's point of view:

1. **No CORS middleware.** The app is a browser app; without it the preflight is
   rejected before the request is made, and `predictEnergy()` returns null —
   indistinguishable from the model being down. This is almost certainly why the
   integration never came together.
2. **The checkpoint was loaded from a bare relative path.** `torch.load(
   "t1x_model_checkpoint.pt")` only works when the process starts in this
   directory, which no container or buildpack guarantees. It is resolved against
   `__file__` now, with `T1X_CHECKPOINT` as an override.
3. **`@app.on_event("startup")` is deprecated** and removed in recent FastAPI
   releases (0.141 is installed here). Replaced with a `lifespan` context manager.
4. **A failed model load was invisible.** The exception was printed and `/predict`
   answered 500 with no way to learn why. The reason is captured and reported via
   `/health`.

Also added: `/health`, without which the app's health check 404s; explicit
request validation, so a mismatched atom/position count is a 422 naming the
mismatch rather than a broadcasting error from inside the distance matrix; and a
test suite.
