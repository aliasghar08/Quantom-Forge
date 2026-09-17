# 🌌 Quantum Forge

**Quantum Forge** is a state-of-the-art, offline-first computational chemistry workstation built entirely in pure Dart and Flutter. Designed for Ph.D.-level researchers, it provides a high-performance desktop interface for transition state optimization, geometry visualization, and advanced quantum chemical parameter tuning.

---

## ✨ Features

- 🖥️ **Zero-Dependency 3D Viewer**: A completely custom, mathematically rigorous 3D molecule renderer written purely in Dart (`CustomPainter`), eliminating the need for slow WebView wrappers or external JavaScript engines like 3Dmol.js.
- 🔬 **Electron Cloud Rendering**: Advanced volumetric rendering techniques to simulate orbital glow and electron density around atoms in real-time at 60 FPS.
- 🤖 **AI-Assisted TS Guesser**: A Linear Synchronous Transit (LST) tool to automatically guess saddle points and intermediate geometries directly in the editor.
- ⚛️ **Automated Conformational Search**: Toggleable pre-optimization MMFF94 sweeps.
- 📊 **Advanced Analytics & Kinetics**: Multi-path kinetic energy profile comparisons, alongside fast-glance thermodynamic parameters (ΔH‡, ΔS‡, ΔG‡).
- 💾 **Local Job Repository**: Complete offline persistence of all calculation jobs in your native OS `LOCALAPPDATA` directory for maximum privacy and speed.
- 🚀 **Native Desktop Integration**: Uses Windows Win32 APIs via FFI for ultra-fast, zero-dependency native file picking.

---

## 🛠️ Architecture

Quantum Forge is built strictly with performance and reliability in mind:
- **State Management**: Zero third-party dependencies. A custom, lightweight dependency injection (`ProviderScope`) and reactive state engine (`ValueNotifier`) is used throughout.
- **Rendering Optimization**: Strict widget tree `const` enforcement and targeted `RepaintBoundary` wrappers guarantee flawless 60 FPS even when rendering thousands of atoms.
- **Compile Target**: Compiles down to a highly optimized native Windows executable (`.exe`).

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/) (Channel stable, v3.24+)
- Windows OS for native desktop compilation

### Build & Run
```bash
# 1. Fetch the minimal dependencies
flutter pub get

# 2. Run in debug mode
flutter run -d windows

# 3. Build the highly-optimized native executable
flutter build windows
```
