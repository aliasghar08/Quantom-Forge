# Quantum Forge ⇄ Avogadro 2

This folder is a complete **Avogadro 2 plugin**. It lets you push the molecule
open in the desktop app straight into the Quantum Forge web workstation, in
either direction.

```
avogadro_plugin/
├── avogadro.toml            # plugin metadata (Avogadro 2.0+ reads this first)
├── pyproject.toml           # fallback metadata for tooling / older builds
├── quantom_forge_export.py  # the menu commands
├── install_plugin.py        # one-command installer for all platforms
└── README.md
```

## Install

**Automatic (recommended)**

```bash
python install_plugin.py
```

It copies the plugin to the correct per-platform location and tells you where.
Use `--dry-run` to preview and `--force` to replace an existing install.

**Manual**

Copy this whole folder to `…/OpenChemistry/Avogadro/plugins/python/quantom-forge`:

| Platform | Path |
| --- | --- |
| Windows | `%LOCALAPPDATA%\OpenChemistry\Avogadro\plugins\python\quantom-forge` |
| macOS | `~/Library/Application Support/OpenChemistry/Avogadro/plugins/python/quantom-forge` |
| Linux | `~/.local/share/OpenChemistry/Avogadro/plugins/python/quantom-forge` |

> The folder name matters. Avogadro only accepts plugin names made of letters,
> digits and hyphens — no underscores or spaces.

Restart Avogadro afterwards.

## Use

Open or build a molecule, then pick a command from **Extensions ▸ Quantum Forge**:

| Command | What it does |
| --- | --- |
| **Export to Quantum Forge Web** | Opens the web dashboard with this structure pre-loaded. |
| **Copy Quantum Forge Link** | Puts a shareable deep link on the clipboard. |
| **Check Quantum Forge Connection** | Shows which endpoint the plugin will open. |

The structure travels as **Chemical JSON** (Avogadro's native format), so bonds,
bond orders and per-atom properties survive the trip — the previous version used
bare XYZ and lost all connectivity information.

Quantum Forge accepts the structure two ways:

* **automatically** — the editor opens with the molecule loaded (default), or
* **on request** — a banner appears with an “Open in editor” button when
  *Settings ▸ Avogadro ▸ Auto-load on arrival* is off.

The import parameters are stripped from the address bar afterwards, so a page
refresh does not re-import (and re-run) the same structure.

## Pointing at a local build

By default the plugin opens <https://quantom-forge.web.app>. While developing the
web app, set:

```bash
# Linux / macOS
export QUANTUM_FORGE_URL=http://localhost:8080

# Windows (PowerShell)
$env:QUANTUM_FORGE_URL = "http://localhost:8080"
```

The same value can be set permanently in Quantum Forge under
*Settings ▸ Avogadro ▸ Bridge endpoint*, which is what the “Send to Avogadro”
button in the coordinate editor uses.

Set `QUANTUM_FORGE_NO_BROWSER=1` to print the link instead of opening a browser —
useful for scripting and for CI.

## Going the other way (web → Avogadro)

Avogadro 2 has no URL-open hook, so the trip back is file-based. In the Quantum
Forge **Editor**:

* **Export ▸ CJSON** — open the file directly in Avogadro (best fidelity).
* **Export ▸ XYZ / CML / SDF** — for other tools.
* **Export trajectory** on the dashboard — writes every NEB image as a multi-XYZ
  file that Avogadro animates image by image.
* **Export bundle (.zip)** — trajectory, final structure (XYZ + CJSON) and a
  manifest with the energies.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| No **Quantum Forge** menu | Plugin folder name has an underscore, or Avogadro was not restarted. |
| “No request JSON received” | Running the script by hand without piping a structure in. See the tests below. |
| “needs a … kB URL” | Structure too large for a URL. Export CJSON and open the file instead. |
| Dashboard opens but nothing loads | *Settings ▸ Avogadro ▸ Enable deep-link import* is off. |

## Verify without Avogadro

The script is a normal command-line program, so it can be exercised directly:

```bash
echo '{"cjson":{"chemicalJson":1,
  "atoms":{"coords":{"3d":[0,0,0.117,0,0.755,-0.471,0,-0.755,-0.471]},
           "elements":{"number":[8,1,1]}}}}' \
  | QUANTUM_FORGE_NO_BROWSER=1 python quantom_forge_export.py
```

It prints a `{"message": …}` JSON object and the deep link, without opening a
browser. Add `--status` to check the configured endpoint.
