# Quantom Forge

**Quantom Forge** is a cutting-edge, AI-powered quantum chemistry optimization and visualization web platform built with Flutter. Designed for researchers and students, it provides an intuitive, high-performance interface for visualizing molecular structures, modeling transition states, and calculating complex thermodynamic properties.

## 🚀 Key Features

*   **Interactive 3D Molecular Visualization**: Fully custom 3D rendering engine built in Flutter. Supports orbiting, zooming, and dynamic styling (bond cylinders, electron clouds, and structural modes).
*   **Transition State (TS) Animations**: Interpolates and animates chemical reactions from reactants to products through the transition state with smooth kinetic transitions.
*   **AI-Powered Optimization**: Integrates deeply with MACE and Quantum ESPRESSO capabilities (via backend) to compute energy profiles, reaction pathways, and vibrational modes.
*   **Advanced Analytics Dashboard**: 
    *   Dynamic Reaction Energy Profiles (Gibbs, Enthalpy)
    *   Arrhenius Kinetics plots
    *   Interactive Vibrational Frequency spectrums
    *   Thermodynamic properties tables
*   **Reaction Library**: A comprehensive, animated database of pre-calculated chemical reactions, transition states, and textbook examples.
*   **Cross-Platform Export**: Export active molecular frames to standard `.xyz` format for interoperability.
*   **Seamless Avogadro 2 Integration**: Includes a native Avogadro 2 Python Command Plugin to instantly pipe molecules from your desktop directly into the web dashboard.

## 🛠️ Avogadro Integration

Quantom Forge fully supports deep-linking from desktop molecular editors. We provide an official Avogadro 2 extension to automatically export your active molecule straight to the web app.

See the [Avogadro Plugin Directory](avogadro_plugin/) for installation and usage instructions.

## 💻 Tech Stack

*   **Frontend**: Flutter (Web), Dart
*   **Architecture**: Riverpod-style State Management (Custom ProviderScope)
*   **Backend / Auth**: Firebase (Authentication, Firestore, Hosting)
*   **UI/UX**: Custom Glassmorphism, Staggered Animations (`flutter_staggered_animations`), Material 3.

## ⚙️ How to Run

1.  Ensure you have the [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
2.  Clone the repository and install dependencies:
    ```bash
    git clone https://github.com/yourusername/quantom-forge.git
    cd quantom_forge
    flutter pub get
    ```
3.  Run the application locally on Chrome/Web:
    ```bash
    flutter run -d chrome
    ```

## 🌐 Deployment

Quantom Forge is currently deployed and live via Firebase Hosting:
[https://quantom-forge.web.app](https://quantom-forge.web.app)

## 👤 Author

Developed by **Ali Asghar**  
Contact: aliasgharinnocent@yahoo.com
