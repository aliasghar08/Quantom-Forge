# Quantom Forge 🧪⚛️

**Quantom Forge** is a cutting-edge, AI-powered quantum chemistry optimization and visualization platform built **exclusively for the Web** using Flutter. Designed for researchers and students, it provides an intuitive, high-performance web dashboard for visualizing molecular structures, modeling transition states, and calculating complex thermodynamic properties entirely in the browser.

## 🌐 Web-First Platform

Quantom Forge is optimized specifically for web browsers. By leveraging WebGL and Flutter Web, it delivers a heavy-duty computational chemistry suite without requiring any desktop installations. Whether you are on Windows, macOS, or Linux, you can simply open your browser and access the full suite of tools.

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
*   **Reaction Path Interpolation**: Smoothly animates chemical reactions, transitioning atoms from their Reactant state through the Transition State (TS), and finally into the Product state.
*   **Play/Pause Controls**: Detailed timeline scrubber to pause animations exactly at the transition state to study bond-breaking and bond-forming geometries.

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
*   Quantom Forge acts as the perfect companion to desktop Avogadro software. 
*   Includes a native Avogadro 2 Python Command Plugin to instantly pipe your active desktop molecules directly into the web dashboard.

### 8. User Management & Security
*   **Firebase Authentication**: Secure user login displaying real-time user profiles and emails in the application drawer.

## 💻 Tech Stack

*   **Frontend**: Flutter (Web-Targeted), Dart, `dart:html`
*   **State Management**: Custom Riverpod-style architecture utilizing Providers and `ValueNotifier`.
*   **Backend / Auth**: Firebase (Authentication, Firestore, Hosting)
*   **UI/UX**: Custom Glassmorphism, Responsive `Wrap` layouts, Material 3 design, `flutter_staggered_animations`.

## ⚙️ How to Run

1.  Ensure you have the [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
2.  Clone the repository and install dependencies:
    ```bash
    git clone https://github.com/aliasgharinnocent/quantom-forge.git
    cd quantom_forge
    flutter pub get
    ```
3.  Run the application locally **on Chrome**:
    ```bash
    flutter run -d chrome
    ```

## 🌐 Deployment

Quantom Forge is currently deployed and live via Firebase Hosting:
[https://quantom-forge.web.app](https://quantom-forge.web.app)

## 👤 Author

Developed by **Ali Asghar**  
Contact: aliasgharinnocent@yahoo.com
