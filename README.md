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
quantum_forge/
├── lib/
│   ├── core/
│   │   ├── services/
│   │   │   ├── auth_service.dart
│   │   │   ├── file_picker_service.dart
│   │   │   ├── job_repository.dart
│   │   │   ├── local_auth_service.dart
│   │   │   ├── local_job_repository.dart
│   │   │   ├── local_storage_service.dart
│   │   │   └── storage_service.dart
│   │   ├── state/
│   │   │   └── provider.dart
│   │   └── utils/
│   │       ├── local_prefs.dart
│   │       ├── uuid_util.dart
│   │       ├── win32_file_picker.dart
│   │       └── xyz_parser.dart
│   ├── features/
│   │   ├── job_runner/
│   │   │   ├── data/
│   │   │   │   └── models/
│   │   │   │       └── job_models.dart
│   │   │   ├── presentation/
│   │   │   │   ├── screens/
│   │   │   │   │   ├── analytics_screen.dart
│   │   │   │   │   ├── coordinate_editor_screen.dart
│   │   │   │   │   ├── dashboard_screen.dart
│   │   │   │   │   └── history_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── kinetic_chart_widget.dart
│   │   │   │       ├── molecular_viewer_widget.dart
│   │   │   │       └── quantum_controls_panel.dart
│   │   │   └── providers/
│   │   │       ├── job_provider.dart
│   │   │       └── settings_provider.dart
│   │   └── reaction_library/
│   │       ├── data/
│   │       │   └── reaction_templates.dart
│   │       └── presentation/
│   │           ├── screens/
│   │           │   └── library_screen.dart
│   │           └── widgets/
│   │               └── reaction_card_widget.dart
│   └── main.dart
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
├── windows/
├── macos/
├── linux/
├── ios/
├── android/
└── web/
```

### Architectural Highlights

- **State Management**: Zero third-party dependencies. We use a custom, lightweight dependency injection (`ProviderScope`) and reactive state engine (`ValueNotifier`).
- **Rendering Optimization**: Strict widget tree `const` enforcement and targeted `RepaintBoundary` wrappers guarantee flawless 60 FPS even when rendering thousands of atoms.
- **Platform Specifics**: Designed with desktop in mind, compiling down to a highly optimized native Windows executable (`.exe`).
