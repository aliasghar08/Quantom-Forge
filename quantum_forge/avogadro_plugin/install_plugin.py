#!/usr/bin/env python3
# ============================================================================
# Quantum Forge — Avogadro plugin installer
# ----------------------------------------------------------------------------
# Copies this folder into Avogadro 2's user plugin directory:
#
#     <USERDATA>/OpenChemistry/Avogadro/plugins/python/quantom-forge
#
# The old README told users to drop a single .py file into `commands/`, which
# stopped working when Avogadro 1.103 required every plugin to be a folder with
# its own metadata. This script does the correct thing for every platform and
# refuses to clobber an existing installation unless asked.
#
# Usage:
#     python install_plugin.py            # install
#     python install_plugin.py --dry-run  # show what would happen
#     python install_plugin.py --force    # overwrite an existing install
#     python install_plugin.py --uninstall
# ============================================================================

from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path

PLUGIN_NAME = "quantom-forge"
SOURCE_DIR = Path(__file__).resolve().parent
#: Files that make up the installed plugin (metadata + scripts + notes).
PAYLOAD = ("avogadro.toml", "pyproject.toml", "quantom_forge_export.py", "README.md")


def user_data_dir() -> Path:
    """Platform-specific `<USERDATA>` root used by Avogadro."""
    if sys.platform.startswith("win"):
        base = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~\\AppData\\Local")
        return Path(base)
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support"
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))


def target_dir() -> Path:
    return user_data_dir() / "OpenChemistry" / "Avogadro" / "plugins" / "python" / PLUGIN_NAME


def main() -> int:
    parser = argparse.ArgumentParser(description="Install the Quantum Forge Avogadro 2 plugin.")
    parser.add_argument("--dry-run", action="store_true", help="report actions without writing")
    parser.add_argument("--force", action="store_true", help="overwrite an existing installation")
    parser.add_argument("--uninstall", action="store_true", help="remove the installed plugin")
    args = parser.parse_args()

    destination = target_dir()
    print(f"Plugin source : {SOURCE_DIR}")
    print(f"Plugin target : {destination}")

    if args.uninstall:
        if not destination.exists():
            print("Nothing to uninstall.")
            return 0
        if args.dry_run:
            print("Would remove the plugin directory.")
            return 0
        shutil.rmtree(destination)
        print("Removed. Restart Avogadro to apply.")
        return 0

    missing = [name for name in PAYLOAD if not (SOURCE_DIR / name).exists()]
    if missing:
        print(f"error: plugin folder is incomplete, missing: {', '.join(missing)}")
        print("Run this script from inside the repository's avogadro_plugin/ folder.")
        return 1

    if destination.exists() and not args.force:
        print("error: the plugin is already installed. Re-run with --force to replace it.")
        return 1

    if args.dry_run:
        print("Would create the target directory and copy:")
        for name in PAYLOAD:
            print(f"  - {name}")
        return 0

    destination.mkdir(parents=True, exist_ok=True)
    for name in PAYLOAD:
        shutil.copy2(SOURCE_DIR / name, destination / name)

    print(f"Installed {len(PAYLOAD)} files.")
    print("Restart Avogadro, then use: Extensions ▸ Quantum Forge ▸ Export to Quantum Forge Web")
    print()
    print("Optional: point the plugin at a local build with")
    print("  QUANTUM_FORGE_URL=http://localhost:8080")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
