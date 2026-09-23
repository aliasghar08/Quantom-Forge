"""Smoke tests for the Transition1x GNN service.

Runs either way:

    python test_main.py          # no test runner needed
    pytest test_main.py          # if you have pytest

`pytest` is not in `requirements.txt` on purpose — the service image does not
need it, and these tests run standalone so they work in an environment where
installing anything is inconvenient.

What is actually being pinned here, in order of how easily it breaks silently:

1. **CORS preflight succeeds.** Without this the Flutter *web* client cannot call
   the service at all, and `predictEnergy()` returns null — which looks exactly
   like the model being down. This is the test that would have caught the
   original bug.
2. **`/health` answers in the shape the app's health check accepts**, i.e. JSON
   with `"status"`. The app rejects a bare 200 deliberately.
3. **`/predict` returns `{"status": "success", "energy_ev": <float>}`**, the
   precise contract `predictEnergy()` reads.
4. **The checkpoint loads against the hard-coded architecture**, which is the
   failure that is invisible until a request arrives.
5. **Malformed requests are rejected with 422 naming the mismatch**, rather than
   a broadcasting error from inside the model.
"""

from __future__ import annotations

import sys

from fastapi.testclient import TestClient

from main import app

_client: TestClient | None = None


def client() -> TestClient:
    """A client whose lifespan has actually run.

    `TestClient(app)` does **not** run the startup lifespan unless it is used as
    a context manager. A module-level `client = TestClient(app)` therefore leaves
    the model unloaded, and every `/predict` test then fails with "Model
    unavailable" for a reason that has nothing to do with the service — which is
    exactly what happened the first time this file was run.

    Entered once and reused, so the 2.2 MB checkpoint is loaded a single time per
    run rather than once per test.
    """
    global _client
    if _client is None:
        _client = TestClient(app)
        _client.__enter__()  # runs the lifespan
    return _client


# ── /health ──────────────────────────────────────────────────────────────────

def test_health_reports_a_status_field():
    response = client().get("/health")
    assert response.status_code == 200, response.text

    body = response.json()
    # The app's healthCheck() requires this exact key; without it a perfectly
    # healthy service is reported as "Unexpected /health payload".
    assert "status" in body, body
    assert body["status"] in ("ok", "degraded"), body
    assert isinstance(body.get("message"), str) and body["message"], body


def test_health_reports_the_model_as_loaded():
    """Fails loudly if the checkpoint and the architecture disagree."""
    body = client().get("/health").json()
    assert body.get("model_loaded") is True, (
        "the model did not load; /health should be carrying the reason — got: "
        f"{body.get('message')}"
    )
    assert body["status"] == "ok", body


# ── CORS ─────────────────────────────────────────────────────────────────────

def test_cors_preflight_allows_a_browser_post():
    """The check that proves a Flutter web build can reach this service."""
    response = client().options(
        "/predict",
        headers={
            "Origin": "https://quantom-forge.web.app",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "content-type",
        },
    )
    assert response.status_code in (200, 204), response.text

    allow_origin = response.headers.get("access-control-allow-origin")
    assert allow_origin in ("*", "https://quantom-forge.web.app"), (
        "no usable CORS preflight response; the request would never be made"
    )


def test_cors_headers_present_on_the_actual_response():
    response = client().post(
        "/predict",
        json={"atomic_numbers": [6], "positions": [[0.0, 0.0, 0.0]]},
        headers={"Origin": "https://quantom-forge.web.app"},
    )
    assert "access-control-allow-origin" in {
        key.lower() for key in response.headers
    }, dict(response.headers)


# ── /predict ─────────────────────────────────────────────────────────────────

def test_predict_returns_the_documented_contract():
    # A single carbon atom: the smallest input the model accepts.
    response = client().post(
        "/predict",
        json={"atomic_numbers": [6], "positions": [[0.0, 0.0, 0.0]]},
    )
    assert response.status_code == 200, response.text

    body = response.json()
    assert body["status"] == "success", body
    assert isinstance(body["energy_ev"], (int, float)), body


def test_predict_is_deterministic_for_a_fixed_geometry():
    """Same input, same number — a service that drifts cannot be compared."""
    payload = {
        "atomic_numbers": [6, 1, 1, 1, 1],
        "positions": [
            [0.0, 0.0, 0.0],
            [0.63, 0.63, 0.63],
            [-0.63, -0.63, 0.63],
            [-0.63, 0.63, -0.63],
            [0.63, -0.63, -0.63],
        ],
    }
    first = client().post("/predict", json=payload).json()["energy_ev"]
    second = client().post("/predict", json=payload).json()["energy_ev"]
    assert first == second


def test_predict_changes_with_geometry():
    """A model that ignored its input would pass every other test here."""
    near = client().post(
        "/predict",
        json={"atomic_numbers": [6, 1], "positions": [[0.0, 0.0, 0.0], [1.09, 0.0, 0.0]]},
    ).json()["energy_ev"]
    far = client().post(
        "/predict",
        json={"atomic_numbers": [6, 1], "positions": [[0.0, 0.0, 0.0], [2.50, 0.0, 0.0]]},
    ).json()["energy_ev"]
    assert near != far, "the predicted energy did not respond to a changed geometry"


def test_predict_rejects_mismatched_atom_and_position_counts():
    response = client().post(
        "/predict",
        json={"atomic_numbers": [6, 1], "positions": [[0.0, 0.0, 0.0]]},
    )
    assert response.status_code == 422, response.text
    assert "same atoms" in response.json()["detail"]


def test_predict_rejects_a_position_that_is_not_three_dimensional():
    response = client().post(
        "/predict",
        json={"atomic_numbers": [6], "positions": [[0.0, 0.0]]},
    )
    assert response.status_code == 422, response.text
    assert "expected 3" in response.json()["detail"]


def test_predict_rejects_an_empty_molecule():
    response = client().post("/predict", json={"atomic_numbers": [], "positions": []})
    assert response.status_code == 422, response.text
    assert "No atoms" in response.json()["detail"]


# ── Standalone runner ────────────────────────────────────────────────────────

def _run_standalone() -> int:
    tests = [
        (name, value)
        for name, value in sorted(globals().items())
        if name.startswith("test_") and callable(value)
    ]
    failures = 0
    for name, test in tests:
        try:
            test()
            print(f"PASS  {name}")
        except AssertionError as exc:
            failures += 1
            print(f"FAIL  {name}: {exc}")
        except Exception as exc:  # noqa: BLE001 - reported, not hidden
            failures += 1
            print(f"ERROR {name}: {type(exc).__name__}: {exc}")

    print(f"\n{len(tests) - failures}/{len(tests)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(_run_standalone())
