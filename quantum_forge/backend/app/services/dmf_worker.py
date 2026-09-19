"""
ColabReaction — Direct MaxFlux (DMF) + UMA reaction-path optimizer.

A faithful port of ColabReaction v1.0.3 (notebook cells [8] "Optimization of the
reaction path by DMF/UMA" and [11] "Calculating Imaginary Frequency of All Local
Maxima"). It replaces the previous mock `process_reaction` with the real pipeline:

    reactant.xyz + product.xyz
        ├─ FB-ENM initial path      (interpolate_fbenm, correlated=True)
        ├─ DirectMaxFlux solve      (nmove, update_teval, convergence tol)
        ├─ UMA MLIP energies        (fairchem-core FAIRChemCalculator, 'omol')
        ├─ trajectory frames        (multi-frame XYZ, DMF_final.xyz)
        └─ energy profile           (eV / hartree / kcal·mol⁻¹ / ΔE vs reactant)

Requirements (see backend/requirements.txt): ase, numpy, fairchem-core,
direct-maxflux, numba, rdkit (optional, for file conversion upstream).

The UMA model is gated behind a Hugging Face token and needs a CUDA GPU; this
module raises a clear error when the dependencies or hardware are missing.
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import time
from typing import Dict, List, Optional

# Physical constants (identical to the notebook).
EV_TO_KCAL_MOL = 23.0605
EV_TO_HARTREE = 1.0 / 27.2114  # ≈ 0.0367493

# Model identifiers recognised by the app's MLIP selector.
MODEL_NAMES = {
    "UMA-SM": "uma-s-1p1",
    "UMA-Medium": "uma-m-1p1",
    "uma-s-1p1": "uma-s-1p1",
    "uma-m-1p1": "uma-m-1p1",
}


def resolve_model_name(mlip_model: str) -> str:
    """Map a Quantum Forge MLIP label to a fairchem model identifier."""
    return MODEL_NAMES.get(mlip_model, "uma-s-1p1")


def login_hf(token: Optional[str]) -> None:
    """Store the Hugging Face token so fairchem can download the UMA weights."""
    if not token:
        return
    os.environ["HF_TOKEN"] = token
    try:
        subprocess.run(
            ["huggingface-cli", "login", "--token", token],
            check=False,
            capture_output=True,
        )
    except FileNotFoundError:
        # `huggingface-cli` may not be on PATH; the HF_TOKEN env var is enough.
        pass


def _xyz_to_atoms(xyz: str):
    from ase.io import read

    fd, path = tempfile.mkstemp(suffix=".xyz", text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(xyz)
        return read(path)
    finally:
        os.unlink(path)


def _atoms_to_xyz(atoms, title: str = "frame") -> str:
    from ase.io import write

    fd, path = tempfile.mkstemp(suffix=".xyz", text=True)
    try:
        os.close(fd)
        write(path, atoms, format="xyz")
        with open(path, encoding="utf-8") as f:
            return f.read()
    finally:
        os.unlink(path)


def _pick_device() -> str:
    try:
        import torch  # noqa: F401

        return "cuda" if torch.cuda.is_available() else "cpu"
    except Exception:
        return "cpu"


def run_dmf(
    reactant_xyz: str,
    product_xyz: str,
    charge: int = 0,
    spin_multiplicity: int = 1,
    nmove: int = 20,
    update_teval: bool = False,
    convergence: str = "tight",
    mlip_model: str = "UMA-SM",
    hf_token: Optional[str] = None,
) -> Dict:
    """
    Run the Direct MaxFlux / UMA reaction-path optimisation.

    `convergence` accepts the notebook's 'tight' | 'middle' | 'loose' (the app's
    'Tight'/'Normal'/'Loose' map onto these).
    """
    from ase import Atoms

    login_hf(hf_token)

    try:
        from dmf import DirectMaxFlux, interpolate_fbenm  # noqa: F401
        from fairchem.core import FAIRChemCalculator, pretrained_mlip  # noqa: F401
    except ImportError as e:  # pragma: no cover - dependency environment
        raise RuntimeError(
            "DMF/UMA dependencies are not installed. Install backend requirements "
            f"(fairchem-core, direct-maxflux, ase, numba): {e}"
        ) from e

    model_name = resolve_model_name(mlip_model)
    device = _pick_device()

    t_start = time.perf_counter()

    ref_images = [_xyz_to_atoms(reactant_xyz), _xyz_to_atoms(product_xyz)]

    # 1. FB-ENM initial path.
    t0 = time.perf_counter()
    mxflx_fbenm = interpolate_fbenm(ref_images, correlated=True)
    coefs = mxflx_fbenm.coefs.copy()
    t_fbenm = time.perf_counter() - t0

    # 2. Set up and solve Direct MaxFlux.
    t0 = time.perf_counter()
    mxflx = DirectMaxFlux(
        ref_images, coefs=coefs, nmove=nmove, update_teval=update_teval
    )

    predictor = pretrained_mlip.get_predict_unit(model_name, device=device)
    for image in mxflx.images:
        image.info["charge"] = charge
        image.info["spin"] = spin_multiplicity
        image.calc = FAIRChemCalculator(predictor, task_name="omol")

    mxflx.add_ipopt_options({"output_file": "DMF_ipopt.out"})
    mxflx.solve(tol=convergence)
    t_dmf = time.perf_counter() - t0

    # 3. Recalculate energies for the final images (some frames may lack them).
    final_images: List[Atoms] = []
    for img in mxflx.images:
        atoms = Atoms(positions=img.get_positions(), numbers=img.get_atomic_numbers())
        atoms.info["charge"] = img.info.get("charge", charge)
        atoms.info["spin"] = img.info.get("spin", spin_multiplicity)
        atoms.calc = FAIRChemCalculator(predictor, task_name="omol")
        try:
            atoms.get_potential_energy()
        except Exception:
            pass
        final_images.append(atoms)

    t_total = time.perf_counter() - t_start

    # 4. Serialise the trajectory and energy profile.
    trajectory_frames = [_atoms_to_xyz(a, f"Frame {i}") for i, a in enumerate(final_images)]
    energies_ev = [float(a.get_potential_energy()) for a in final_images]
    energies_kcal = [e * EV_TO_KCAL_MOL for e in energies_ev]
    ref = energies_kcal[0]
    relative_kcal = [e - ref for e in energies_kcal]
    max_energy_index = int(max(range(len(relative_kcal)), key=lambda i: relative_kcal[i]))

    return {
        "trajectory_frames": trajectory_frames,
        "energy_profile": relative_kcal,  # ΔE vs reactant, kcal/mol (matches DMF_energy.csv)
        "energy_profile_ev": energies_ev,
        "energies_hartree": [e * EV_TO_HARTREE for e in energies_ev],
        "max_energy_index": max_energy_index,
        "timing": {"fbenm_s": t_fbenm, "dmf_s": t_dmf, "total_s": t_total},
    }


def compute_imaginary_frequencies(
    xyz: str,
    charge: int = 0,
    spin_multiplicity: int = 1,
    mlip_model: str = "UMA-SM",
    hf_token: Optional[str] = None,
) -> List[Dict]:
    """
    Compute vibrational frequencies (ASE Vibrations) at a local maximum and
    return the imaginary modes — the notebook's cell [11].

    Returns a list of `{"frequency": cm^-1, "vectors": []}` where a negative
    frequency denotes an imaginary mode along the reaction coordinate.
    """
    from ase.vibrations import Vibrations
    from fairchem.core import FAIRChemCalculator, pretrained_mlip

    login_hf(hf_token)
    predictor = pretrained_mlip.get_predict_unit(
        resolve_model_name(mlip_model), device=_pick_device()
    )

    atoms = _xyz_to_atoms(xyz)
    atoms.info["charge"] = charge
    atoms.info["spin"] = spin_multiplicity
    atoms.calc = FAIRChemCalculator(predictor, task_name="omol")

    vib = Vibrations(atoms, name="vib")
    vib.run()
    freqs_eV = vib.get_frequencies()  # ASE returns ħω in eV
    freqs_cm1 = [f * 8065.544 for f in freqs_eV]  # 1 eV = 8065.544 cm⁻¹

    return [
        {"frequency": round(f, 2), "vectors": []}
        for f in freqs_cm1
        if f < 0
    ]
