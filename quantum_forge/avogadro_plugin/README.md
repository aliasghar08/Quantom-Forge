# Quantom Forge Avogadro Integration

This directory contains the official plugin to bridge **Avogadro 2** with the **Quantom Forge** web application.

## Installation Instructions

1. Open **Avogadro 2**.
2. Go to `Extensions` > `Scripts` > `Manage Scripts...` (or `Plugin Downloader` depending on your version).
3. Alternatively, manually copy the `quantom_forge_export.py` file into your local Avogadro `commands` scripts directory.
   - **Windows:** `C:\\Users\\<YourUser>\\AppData\\Local\\OpenChemistry\\Avogadro\\commands`
   - **Mac:** `~/Library/Application Support/OpenChemistry/Avogadro/commands`
   - **Linux:** `~/.local/share/OpenChemistry/Avogadro/commands`
4. Restart Avogadro.

## How to use

1. Open or build any molecule in Avogadro.
2. In the top menu, go to **Extensions** > **Quantom Forge** > **Export to Quantom Forge Web**.
3. Avogadro will automatically extract your molecule data, encode it securely, and open your default web browser to your Quantom Forge dashboard, pre-loaded and ready for quantum optimization!
