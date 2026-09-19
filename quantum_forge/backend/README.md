# Quantum Forge compute backend — DMF/UMA reaction paths

This service runs the **real** reaction-path optimisation that the Flutter app
previously faked. It is a faithful port of
[ColabReaction](https://github.com/BILAB/ColabReaction) v1.0.3:

```
reactant.xyz + product.xyz
   ├─ FB-ENM initial path      (interpolate_fbenm, correlated=True)
   ├─ Direct MaxFlux solve     (nmove, update_teval, convergence)
   ├─ UMA MLIP energies        (fairchem-core FAIRChemCalculator, task 'omol')
   ├─ multi-frame trajectory   (DMF_final.xyz)
   └─ energy profile           (eV / hartree / kcal·mol⁻¹ / ΔE vs reactant)
   plus ASE vibrational analysis → imaginary frequencies at the TS
```

## Requirements

* **A CUDA GPU** — the UMA potential is far too slow on CPU for practical use.
* **A Hugging Face token** with access to the UMA weights (`uma-s-1p1` /
  `uma-m-1p1`). Pass it per request as `hf_token` or export `HF_TOKEN`.
* Python 3.10+.

## Install & run

```bash
cd quantum_forge/backend
python -m venv .venv && . .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# API (FastAPI)
uvicorn app.main:app --host 0.0.0.0 --port 8000

# Optional: Firestore queue worker (watches queues/ts_searches)
python -m app.services.compute_worker
```

> `requirements.txt` pins `direct-maxflux` to the same commit ColabReaction uses
> (the project was renamed to `pydmf` in Dec 2025). `fairchem-core` pulls large
> model weights on first use, so the first run is slow.

## API

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/reactions/submit` | Start a DMF/UMA run; returns a `reaction_id` immediately. |
| `GET` | `/reactions/{id}` | Poll status; `state` is `pending → optimizing → completed \| error`. |
| `GET` | `/health` | Liveness probe. |

Request body (`backend/app/models/reaction.py`):

```json
{
  "reactant_xyz": "3\nreactant\nO 0 0 0\nH 0 0.76 0.58\nH 0 -0.76 0.58",
  "product_xyz":  "3\nproduct\n...",
  "charge": 0,
  "spin_multiplicity": 1,
  "nmove": 20,
  "update_teval": false,
  "convergence": "tight",
  "mlip_model": "UMA-SM",
  "hf_token": "hf_..."
}
```

Completed responses carry `energy_profile` (ΔE vs reactant, kcal·mol⁻¹),
`trajectory_frames` (list of XYZ strings), `max_energy_index` (the TS image) and
`vibrational_modes` (imaginary frequencies in cm⁻¹).

## Connecting the Flutter app

Open **Settings ▸ Compute ▸ DMF/UMA compute backend** and enter the service base
URL (e.g. `https://your-dmf-backend.example.com`). The app then dispatches every
reaction to `POST <url>/reactions/submit` and polls for the result; the status,
trajectory and energy profile flow into the existing dashboard, animation and
analytics unchanged.

Leave the field **empty** to keep the self-contained illustrative simulation —
the app stays fully functional without a GPU backend.

## Notes on fidelity

* The energy profile, trajectory and imaginary frequencies are produced by the
  same calls the notebook makes, so results are directly comparable with a
  ColabReaction run for the same inputs and settings.
* The app's `charge`, `spinMultiplicity`, `nmove`, `updateTeval`, `convergence`
  and `mlipModel` settings map 1:1 onto the notebook's inputs
  (`Tight → tight`, `Normal → middle`, `Loose → loose`).
