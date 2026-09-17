# 🌌 Quantum Forge

**Quantum Forge** is a state-of-the-art, offline-first computational chemistry workstation built entirely in pure Dart and Flutter. Designed for Ph.D.-level researchers, it provides a high-performance desktop interface for transition state optimization, geometry visualization, and advanced quantum chemical parameter tuning.

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows" />
</p>

---

## ✨ Comprehensive Features

- **🖥️ Zero-Dependency 3D Viewer**: A custom, mathematically rigorous 3D molecule renderer written purely in Dart (`CustomPainter`), eliminating the need for slow WebView wrappers or external engines. Includes interactive molecular editing and a dedicated coordinate editor screen.
- **🔬 Electron Cloud Rendering**: Advanced volumetric rendering techniques simulate orbital glow and electron density around atoms in real-time at 60 FPS.
- **🤖 AI-Assisted TS Guesser**: A Linear Synchronous Transit (LST) tool automatically guesses saddle points and intermediate geometries directly in the editor.
- **⚛️ Automated Conformational Search**: Toggleable pre-optimization MMFF94 sweeps to explore potential energy surfaces.
- **📊 Advanced Analytics & Kinetics**: Multi-path kinetic energy profile comparisons, alongside fast-glance thermodynamic parameters (ΔH‡, ΔS‡, ΔG‡). Features interactive kinetic chart widgets.
- **💾 Local Job Repository**: Complete offline persistence of all calculation jobs in your native OS `LOCALAPPDATA` directory for maximum privacy and speed. Tracked via comprehensive Dashboard and History screens.
- **🚀 Native Desktop Integration**: Uses Windows Win32 APIs via FFI for ultra-fast, zero-dependency native file picking.
- **📝 Native XYZ Parsing**: Custom parser to handle standard chemical coordinate `.xyz` files efficiently.
- **🔐 Secure Authentication Services**: Integrated authentication layer (Local & Generic) to manage sessions and privacy.
- **🧪 Reaction Library**: Integrated library of pre-built reaction templates to bootstrap calculations rapidly.

---

## 🛠️ Project Structure

The codebase is strictly organized using a feature-first architecture, ensuring separation of concerns and high scalability.

```text
lib/
├── core/                       # Foundation and shared logic
│   ├── services/               # Core services (Auth, Job Repository, Win32 File Picker, Local Storage)
│   ├── state/                  # Dependency injection and base provider setup
│   └── utils/                  # Utilities (XYZ Parser, UUIDs, Local Prefs)
│
├── features/                   # Feature-driven modules
│   ├── job_runner/             # Main computational and analytics module
│   │   ├── data/               # Job state models
│   │   ├── presentation/       # Screens (Dashboard, Analytics, History, Coordinate Editor)
│   │   │   └── widgets/        # Specialized Widgets (Molecular Viewer, Kinetic Chart, Controls Panel)
│   │   └── providers/          # Reactive state management for computational jobs and settings
│   │
│   └── reaction_library/       # Templates and pre-defined chemical reactions
│       ├── data/               # Reaction templates and molecular data
│       └── presentation/       # Library screens and Reaction Card widgets
│
└── main.dart                   # Application entry point
```

### Architectural Highlights

- **State Management**: Zero third-party dependencies. We use a custom, lightweight dependency injection (`ProviderScope`) and reactive state engine (`ValueNotifier`).
- **Rendering Optimization**: Strict widget tree `const` enforcement and targeted `RepaintBoundary` wrappers guarantee flawless 60 FPS even when rendering thousands of atoms.
- **Platform Specifics**: Designed with desktop in mind, compiling down to a highly optimized native Windows executable (`.exe`).
