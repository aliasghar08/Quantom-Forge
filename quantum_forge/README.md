# Quantum Forge 🧪⚛️

**Quantum Forge** is a cutting-edge, AI-powered quantum chemistry optimization and visualization platform built **exclusively for the Web** using Flutter. Designed for researchers and students, it provides an intuitive, high-performance web dashboard for visualizing molecular structures, modeling transition states, and calculating complex thermodynamic properties entirely in the browser.

## 🌐 Web-First Platform

Quantum Forge is optimized specifically for web browsers. By leveraging WebGL and Flutter Web, it delivers a heavy-duty computational chemistry suite without requiring any desktop installations. Whether you are on Windows, macOS, or Linux, you can simply open your browser and access the full suite of tools.

## 🚀 Comprehensive Feature List

### 1. 3D Interactive Physics Engine & Molecular Builder
*   **Inverse Raycasting**: A highly advanced custom 3D drawing engine built from scratch. Click and drag in the 3D void to draw molecules!
*   **Covalent Distance Calculation**: Automatically calculates optimal bond lengths and standard geometries when placing new atoms.
*   **Element Selector**: Easily switch between common elements (H, C, N, O, F, P, S, Cl).
*   **Dynamic Orbiting & Panning**: Complete mouse and touch control over the 3D molecular canvas.

### 2. Deep File Format Parsing
*   **Multi-Format Support**: Natively parses `.mol`, `.sdf`, `.cml`, and `.xyz` files directly in the browser without any backend processing.
*   **Avogadro Compatibility**: Fully supports loading structure files exported directly from Avogadro.

### 3. Transition State (TS) Modeling & Animation
*   **Avogadro Player parity**: the panel is a faithful rebuild of Avogadro 2's Animation Tool (`playertool.cpp`) — `<` / `>` stepping, a 1-based `Frame: N/M` box, a frame slider, `Start:` / `End:` range controls, a `Dynamic bonding?` checkbox, a `Frame rate:` box in FPS (default 5, with 0 remapped to 5), `Play` / `Pause`, and Avogadro's keyboard map (Space, ← →, Shift for ten frames, ↑ Start, ↓ End).
*   **WebGL rendering through NGL** with its impostor spheres and cylinder bonds, at `radiusScale 0.5 / aspectRatio 2.0`, under an **orthographic camera** with 4x MSAA, antialiasing and a display-matched pixel ratio. Four display types: Ball and Stick, Licorice, Van der Waals, Wireframe.
*   **Two element palettes**, switchable from the header: Avogadro's own `element_color` table (carbon `#7F7F7F`) and the Jmol/CPK table NGL calls `element` (carbon `#909090`).
*   **Discrete frames, never interpolation**: each NEB image is a computed geometry, so images are shown exactly as calculated. Looping wraps within `[Start, End]`, matching Avogadro's `animate()`.
*   **Dynamic bonding**: re-perceives every bond per frame with Avogadro's rule (covalent radii + a 0.45 Å tolerance, H–H and the noble gases excluded), so bond breaking and forming is visible in the geometry.
*   Paths are handed to NGL as **multi-model SDF**, not XYZ — NGL has no XYZ parser. [`AVOGADRO_ANIMATION_PARITY.md`](AVOGADRO_ANIMATION_PARITY.md) documents that finding with evidence, every other measured API detail, and the known divergences from Avogadro.

### 4. Advanced Analytics & Reaction Dashboards
*   **Energy Profile Graphs**: Interactive 2D line charts plotting the reaction coordinate against relative energy (Activation Energy and Enthalpy).
*   **Arrhenius Kinetics Plots**: Interactive $ln(k)$ vs $1/T$ graphs for evaluating reaction rates.
*   **Vibrational Analysis Spectrums**: Simulated IR spectrum graphs to analyze the dominant vibrational modes of transition states.
*   **Thermodynamic Metrics**: Live-updating cards displaying Gibbs Free Energy, Enthalpy, Entropy, and calculated reaction rates.

### 5. Quantum Render Modes & Aesthetics
*   **Electron Clouds & VDW Surfaces**: High-performance gradient painters simulate electron density and Van der Waals surfaces.
*   **Visual Modes**: Toggle between Standard (Ball & Stick), Glassmorphism, and Metallic rendering styles.
*   **Dynamic Lighting**: Custom 3D shading, specular highlights, and ambient occlusion applied to 2D canvas drawing.

### 6. Cloud-Connected Reaction Library
*   **Firestore Database**: A sprawling, centralized database of pre-calculated textbook chemical reactions (Grignard Additions, Fischer Esterifications, Friedel-Crafts, Suzuki Couplings).
*   **Real-time Search & Filtering**: Instantly search reactions by IUPAC name, reaction type (Addition, Substitution, Elimination), or chemical tags.

### 7. Seamless Avogadro 2 Integration
*   Quantum Forge acts as the perfect companion to desktop Avogadro software. 
*   Includes a native Avogadro 2 Python Command Plugin to instantly pipe your active desktop molecules directly into the web dashboard.

### 8. User Management & Security
*   **Firebase Authentication**: Secure user login displaying real-time user profiles and emails in the application drawer.

## 🛠️ Tools & Platforms Used

This project leverages modern frameworks and cloud platforms to deliver a robust web experience:

*   **Frontend Framework**: Flutter (Web-Targeted)
*   **Language**: Dart (with `dart:html` for native web APIs)
*   **Backend as a Service (BaaS)**: Google Firebase
    *   **Firebase Authentication**: Secure user login and identity management.
    *   **Cloud Firestore**: Real-time NoSQL database for the centralized reaction library.
    *   **Firebase Hosting**: Global CDN deployment for the web application.
*   **State Management**: Custom Riverpod-style architecture utilizing Providers and `ValueNotifier`.
*   **UI/UX Libraries**: `flutter_staggered_animations` for dynamic transitions, Material 3 design system.
*   **Computational Chemistry Tools**: Avogadro 2 (via Python Command Plugin integration).

## ⚙️ How to Run

1.  Ensure you have the [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
2.  Clone the repository and install dependencies:
    ```bash
    git clone https://github.com/aliasgharinnocent/Quantum-forge.git
    cd Quantum_forge
    flutter pub get
    ```
3.  Run the application locally **on Chrome**:
    ```bash
    flutter run -d chrome
    ```

## 🌐 Deployment

Quantum Forge is currently deployed and live via Firebase Hosting:
[https://Quantum-forge.web.app](https://Quantum-forge.web.app)

## 👤 Author

Developed by **Ali Asghar**  
Contact: aliasgharinnocent@yahoo.com
