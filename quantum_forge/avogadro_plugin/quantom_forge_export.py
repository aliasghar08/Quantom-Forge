#!/usr/bin/env python3
# ============================================================================
# Quantum Forge — Avogadro 2 menu command
# ----------------------------------------------------------------------------
# Sends the molecule currently open in Avogadro to the Quantum Forge web app.
#
# Why this file was rewritten
# ---------------------------
# The first version targeted the *pre-2.0* Avogadro script API, which had three
# problems:
#
#   1. It shipped without plugin metadata. Since Avogadro 1.103 a bare script is
#      no longer installable — a plugin is a folder plus `pyproject.toml` /
#      `avogadro.toml`. Without it the menu entry never appeared.
#   2. It read the input JSON from stdin only and required `--run-command`,
#      an argument the 2.0 API deprecated. In 2.0 the JSON is passed as the
#      main argument.
#   3. It hard-coded `https://Quantum-forge.web.app` (wrong capitalisation, and
#      a typo'd host) and stripped the base64 padding, which produced an
#      undecodable payload roughly one time in three.
#
# It now speaks the current API, emits Chemical JSON (Avogadro's native format,
# so bonds survive the trip), accepts a plain XYZ fallback, and lets the target
# instance be configured for local development.
# ============================================================================

from __future__ import annotations

import base64
import json
import os
import sys
import urllib.parse
import webbrowser

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DEFAULT_BASE_URL = "https://quantom-forge.web.app"

#: Environment overrides so a researcher can point the plugin at a local build
#: without editing the file:  QUANTUM_FORGE_URL=http://localhost:8080
ENV_BASE_URL = "QUANTUM_FORGE_URL"
ENV_NO_BROWSER = "QUANTUM_FORGE_NO_BROWSER"

#: Browsers and servers disagree about how long a URL may be. 64 kB of URL is
#: already generous; past that we refuse and tell the user to export a file.
MAX_URL_LENGTH = 60_000

#: Guard against pathological structures coming from a mis-behaving caller.
MAX_ATOMS = 20_000

CHEMICAL_JSON_VERSION = 1


def base_url() -> str:
    """Target Quantum Forge instance, honouring the environment override."""
    url = os.environ.get(ENV_BASE_URL, DEFAULT_BASE_URL).strip()
    if not url:
        url = DEFAULT_BASE_URL
    return url.rstrip("/")


# ---------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------

def read_request() -> dict:
    """Reads the Avogadro request JSON.

    Avogadro 2 passes the JSON object as the first non-flag argument. Older
    builds (and `pixi run python ... | plugin`) pipe it on stdin instead, so
    both are supported.
    """
    for arg in sys.argv[1:]:
        if arg.startswith("-"):
            continue
        candidate = arg.strip()
        if candidate.startswith("{"):
            try:
                return json.loads(candidate)
            except ValueError:
                break

    if sys.stdin is not None and not sys.stdin.isatty():
        raw = sys.stdin.read().strip()
        if raw:
            try:
                return json.loads(raw)
            except ValueError as exc:
                raise SystemExit(f"Could not parse the request JSON: {exc}")

    raise SystemExit("No request JSON received from Avogadro.")


def molecule_from(request: dict) -> tuple[dict, str]:
    """Extracts a CJSON document and a human-readable title."""
    cjson = request.get("cjson")
    if isinstance(cjson, dict):
        title = cjson.get("name") or "Avogadro molecule"
        return cjson, str(title)

    # Some Avogadro versions honour the requested plain format instead.
    for key in ("xyz", "cml", "sdf", "mol"):
        payload = request.get(key)
        if isinstance(payload, str) and payload.strip():
            title = payload.strip().splitlines()[0][:80] or "Avogadro molecule"
            return {"chemicalJson": CHEMICAL_JSON_VERSION,
                    "name": title,
                    "format": key,
                    "data": payload}, title

    raise SystemExit(
        "This Avogadro build sent neither CJSON nor a supported text structure."
    )


def atom_count(cjson: dict) -> int:
    atoms = cjson.get("atoms") or {}
    elements = atoms.get("elements") or {}
    numbers = elements.get("number") or []
    return len(numbers) if isinstance(numbers, list) else 0


# ---------------------------------------------------------------------------
# Transport
# ---------------------------------------------------------------------------

def encode_cjson(cjson: dict) -> str:
    """URL-safe base64 of the UTF-8 CJSON document.

    Padding is *kept*: stripping it (as the old plugin did) yields a payload the
    receiving base64 decoder rejects whenever the byte length is not a multiple
    of three. `urllib.parse.quote` keeps `=` intact in a query value, and the
    web app restores padding defensively anyway.
    """
    raw = json.dumps(cjson, separators=(",", ":")).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii")


def build_url(cjson: dict, title: str) -> str:
    payload = encode_cjson(cjson)
    query = urllib.parse.urlencode(
        {
            "import_struct": payload,
            "fmt": "cjson",
            "source": "avogadro",
            "name": title,
        }
    )
    return f"{base_url()}/?{query}"


# ---------------------------------------------------------------------------
# Command implementation
# ---------------------------------------------------------------------------

def copy_to_clipboard(text: str) -> bool:
    """Best-effort clipboard write with no third-party dependencies."""
    import shutil
    import subprocess

    try:
        if sys.platform == "darwin":
            subprocess.run(["pbcopy"], input=text.encode("utf-8"), check=True)
            return True
        if sys.platform.startswith("win"):
            subprocess.run(
                ["clip"], input=text.encode("utf-16-le"), check=True, shell=True
            )
            return True
        for tool, args in (
            ("wl-copy", ["wl-copy"]),
            ("xclip", ["xclip", "-selection", "clipboard"]),
            ("xsel", ["xsel", "--clipboard", "--input"]),
        ):
            if shutil.which(tool):
                subprocess.run(args, input=text.encode("utf-8"), check=True)
                return True
    except Exception:  # noqa: BLE001 - clipboard is never load-bearing
        return False
    return False


def status() -> dict:
    """Reports the endpoint so a user can confirm the bridge configuration."""
    return {
        "message": (
            f"Quantum Forge endpoint: {base_url()}\n"
            f"Override it with the {ENV_BASE_URL} environment variable, e.g.\n"
            f"  {ENV_BASE_URL}=http://localhost:8080"
        )
    }


def run(copy_only: bool = False) -> dict:
    request = read_request()
    cjson, title = molecule_from(request)

    count = atom_count(cjson)
    if count > MAX_ATOMS:
        raise SystemExit(
            f"Structure has {count} atoms; Quantum Forge accepts up to {MAX_ATOMS}."
        )

    url = build_url(cjson, title)
    if len(url) > MAX_URL_LENGTH:
        raise SystemExit(
            f"This structure needs a {(len(url) / 1024):.0f} kB URL, which browsers "
            "will truncate.\nIn Quantum Forge use Editor > Export > .cjson, then open "
            "the file in Avogadro instead."
        )

    if copy_only:
        if copy_to_clipboard(url):
            return {
                "message": (
                    f"Copied a Quantum Forge link for '{title}' "
                    f"({count} atoms) to the clipboard."
                )
            }
        # No clipboard available: fall back to printing so the user can copy it.
        print(url)
        return {
            "message": (
                "No clipboard tool available — the Quantum Forge link was written "
                "to the terminal instead."
            )
        }

    if os.environ.get(ENV_NO_BROWSER):
        print(url)
    else:
        webbrowser.open(url)

    where = base_url()
    if count:
        message = f"Opened Quantum Forge ({where}) with {count} atoms."
    else:
        message = f"Opened Quantum Forge ({where})."
    return {"message": message}


def main() -> None:
    # Flags that every Avogadro feature must tolerate. `--print-options` is only
    # answered when the metadata declares dynamic options, which this plugin
    # does not, but replying politely costs nothing.
    if "--print-options" in sys.argv:
        print(json.dumps({"userOptions": {}}))
        return
    if "--debug" in sys.argv:
        sys.stderr.write(
            f"quantum-forge: base_url={base_url()} "
            f"argv={sys.argv[1:]!r} env={ENV_BASE_URL!r}\n"
        )

    try:
        if "--status" in sys.argv or "--check" in sys.argv:
            result = status()
        else:
            result = run(copy_only="--copy" in sys.argv)
        print(json.dumps(result))
    except SystemExit as exc:
        # Avogadro renders `error` as a dialog, which is far more visible than a
        # crashed process.
        message = str(exc) or "Quantum Forge export failed."
        print(json.dumps({"error": message}))
        sys.exit(0)
    except Exception as exc:  # noqa: BLE001 - never crash inside Avogadro
        print(json.dumps({"error": f"Quantum Forge bridge failed: {exc}"}))
        sys.exit(0)


if __name__ == "__main__":
    main()
