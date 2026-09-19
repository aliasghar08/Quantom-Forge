# Quantom Forge 🧪⚛️

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Web-4285F4?style=for-the-badge&logo=googlechrome&logoColor=white" alt="Web" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase" />
</p>

**Quantom Forge** is an AI-assisted quantum chemistry optimisation and visualisation
workstation built **for the web** with Flutter. It gives researchers and students a
single browser dashboard for building molecules, modelling transition states, and
inspecting thermodynamic and kinetic results — with a two-way bridge to desktop
**Avogadro 2**.

## 🌐 Web-first platform

Quantom Forge targets the browser. WebGL and Flutter Web deliver the whole
computational-chemistry surface without a desktop install, on Windows, macOS or
Linux.

## 🚀 Features

### 1. 3D interactive builder
* **Inverse raycasting** — click into the 3D void to place atoms; drag from an atom
  to grow a bond at the ideal covalent distance.
* **Element picker** over the full periodic table with CPK colours and covalent /
  van-der-Waals radii.
* **Force-field relaxation** while you draw (toggleable), plus orbit/zoom camera
  controls and three atom representations (ball & stick, space filling, wireframe).

### 2. Structure I/O — Avogadro 2 native
* **Reads** CJSON (Avogadro's native Chemical JSON), CML, XYZ, SDF and MOL.
* **Writes** CJSON, CML, SDF (V2000 connection table) and XYZ, with configurable
  coordinate precision and title lines.
* **Perceives bonds** from covalent radii with a valence-aware order refinement, so
  exported connection tables are chemically sensible rather than a flat atom list.
* **Multi-XYZ trajectories** — the whole NEB path exports as one file Avogadro
  animates image by image.

### 3. Transition-state modelling & animation
* Interpolates reactants → transition state → products with a timeline scrubber that
  can be parked exactly on the saddle point.
* Energy-profile, Arrhenius and IR-spectrum plots drawn with the active theme's
  colour palette.

### 4. Reaction dashboards
* Energy profile (ΔE‡, ΔH‡), Arrhenius kinetics, simulated IR sticks.
* Live thermodynamic cards: Gibbs energy, enthalpy, entropy, rate constant, ZPE,
  dipole, HOMO–LUMO gap, polarisability, RMS gradient.

### 5. Cloud reaction library
* Firestore-backed library of textbook reactions (Grignard, Fischer esterification,
  Friedel–Crafts, Suzuki) with real-time search and filtering.

### 6. Scientific theming
Seven presets, each grounded in a real convention rather than a colour preference.
A theme is not just a `ColorScheme` — it also supplies the palette used by the
hand-written 2D/3D painters and the chart series colours.

| Preset | Family | Idea |
| --- | --- | --- |
| Dark Matter | Deep field | Low-glare default for long optimisation runs |
| Quantum Blue | Orbital | Cherenkov blue, metallic renderer |
| Neon Synth | Spectroscopy | Laser pink + cyan on violet, translucent atoms |
| Electron Cloud | Density | Teal isosurface palette, high VDW opacity |
| Spectroscopy | Spectroscopy | Low-glare slate with warm IR / violet UV-Vis accents |
| Scientific Light | Publication | Print-quality light theme for figures and projectors |
| Journal Mono | Publication | Greyscale-first, Okabe–Ito colour-blind-safe plots |

Themes persist across sessions; <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd> cycles
them.

### 7. Settings that actually apply
*Settings* is a real screen (drawer gear icon, or the app-bar gear) with five tabs —
Appearance, Editor, Export, Avogadro, Compute. Every control writes through to
storage immediately and takes effect without a restart:

* **Appearance** — theme presets, compact mode, reduce motion, tooltips.
* **Editor** — default element, auto-optimise, atom representation, bond drawing,
  hydrogen visibility, bond-perception tolerance, auto-save interval.
* **Export** — default format, coordinate precision, title line, plus a live preview
  of what those settings actually produce.
* **Avogadro** — bridge endpoint (hosted / localhost / custom), deep-link import
  toggles, and the per-platform plugin install path.
* **Compute** — temperature, step count, NEB images, convergence, and the analysis
  switches, mirroring the Quantum Controls panel.

### 8. Avogadro 2 bridge
Two directions, because Avogadro 2 has no URL-open hook:

* **Avogadro → web.** The bundled plugin (`avogadro_plugin/`) sends the open molecule
  as CJSON through a deep link; the editor opens with it pre-loaded (or a banner
  offers to, if auto-load is off). The payload is stripped from the address bar
  afterwards so a refresh does not re-import it.
* **Web → Avogadro.** *Export* writes CJSON/CML/SDF/XYZ files, *Export trajectory*
  writes the multi-XYZ path, and *Export bundle (.zip)* packages trajectory, final
  structure (XYZ + CJSON) and an energy manifest. See
  [`avogadro_plugin/README.md`](quantum_forge/avogadro_plugin/README.md).

### 9. Accounts
Firebase Authentication with profile and email shown in the drawer.

## 🛠️ Stack

* **Frontend**: Flutter (web) · Dart · `dart:js_interop` for browser APIs
* **State**: `provider` (`ChangeNotifier` + `ValueNotifier`)
* **Backend as a service**: Firebase Auth · Cloud Firestore · Firebase Hosting
* **Chemistry**: custom format writers/parsers; Avogadro 2 via a Python plugin
* **UI**: Material 3, `flutter_staggered_animations`, hand-written `CustomPainter` charts

## ⚙️ Running it

```bash
git clone https://github.com/aliasghar08/Quantum-Forge.git
cd Quantum-Forge/quantum_forge
flutter pub get
flutter run -d chrome
```

Quality gates:

```bash
flutter analyze   # must be clean
flutter test      # 93 tests
```

### Pointing the plugin at a local build

```bash
export QUANTUM_FORGE_URL=http://localhost:8080   # or $env: on PowerShell
```

The same value can be set in *Settings ▸ Avogadro ▸ Bridge endpoint*.

## 🌐 Deployment

Hosted via Firebase Hosting: [quantom-forge.web.app](https://quantom-forge.web.app)

## 📁 Layout

```
quantum_forge/
├── lib/
│   ├── core/
│   │   ├── settings/     # AppSettings (workspace prefs) + persistence
│   │   ├── theme/        # scientific theme presets
│   │   ├── services/     # auth, storage, Firestore, file picking
│   │   └── utils/        # Avogadro interchange, codec, deep links, parsers, ZIP
│   ├── features/
│   │   ├── auth/ reaction_library/ reaction_runner/ settings/
│   └── main.dart
├── avogadro_plugin/      # Avogadro 2 plugin + installer
└── test/                 # interchange, codec, settings, theme, parser, ZIP
```

## 👤 Author

Developed by **Ali Asghar**
