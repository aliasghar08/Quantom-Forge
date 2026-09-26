import torch
import torch.nn as nn
from main import MolecularGraphNetwork, checkpoint_path
import os

class OpenMMTorchWrapper(nn.Module):
    """
    Wraps the MolecularGraphNetwork to be compatible with openmm-torch.
    OpenMM passes positions as a tensor of shape (N, 3) in nanometers.
    The model needs atomic numbers (z) and mask.
    Since openmm-torch only passes positions (and optionally box vectors),
    we must embed the atomic numbers inside the module or pass them via a trick.
    Typically, for a specific ligand, we can hardcode the z array into the model instance.
    """
    def __init__(self, model, z_array):
        super().__init__()
        self.model = model
        # Register z as a buffer so it becomes part of the TorchScript module
        self.register_buffer('z', torch.tensor(z_array, dtype=torch.long).unsqueeze(0))
        # Mask is all 1s for the ligand
        self.register_buffer('mask', torch.ones((1, len(z_array)), dtype=torch.float32))

    def forward(self, positions):
        # positions from OpenMM are in shape (N, 3) in nanometers.
        # We may need to convert them to Angstroms if TX1 expects Angstroms (typically 1 nm = 10 A)
        pos_A = positions * 10.0
        pos_A = pos_A.unsqueeze(0).float() # shape (1, N, 3)
        
        # Calculate energy (in eV)
        energy_ev = self.model(self.z, pos_A, self.mask)
        
        # OpenMM expects energy in kJ/mol.
        # 1 eV = 96.485 kJ/mol
        energy_kjmol = energy_ev * 96.485
        
        return energy_kjmol

def export_model():
    # 1. Load the original model from Drive
    model = MolecularGraphNetwork()
    ckpt = os.environ.get("QUANTUM_FORGE_MODEL_CHECKPOINT", "./t1x_model_checkpoint.pt")
    if os.path.exists(ckpt):
        state = torch.load(ckpt, map_location="cpu")
        if isinstance(state, dict) and "model_state_dict" in state:
            state = state["model_state_dict"]
            
        if "embedding.weight" in state:
            old_emb = state["embedding.weight"]
            if old_emb.shape[0] < model.embedding.weight.shape[0]:
                new_emb = torch.zeros_like(model.embedding.weight)
                new_emb[:old_emb.shape[0]] = old_emb
                state["embedding.weight"] = new_emb

        model.load_state_dict(state)
        print(f"Loaded weights from {ckpt}")
    else:
        print(f"Warning: Checkpoint {ckpt} not found. Using untrained weights.")
    
    model.eval()

    import sys
    import ase.io
    
    # NOTE: The exact atomic numbers of the custom 4-mer and 5-mer beta-peptides
    # must be extracted from a reference PDB to ensure tensor shapes match perfectly.
    # Pass the isolated peptide PDB path as a command-line argument.
    peptide_pdb_path = sys.argv[1] if len(sys.argv) > 1 else "peptide.pdb"
    
    if not os.path.exists(peptide_pdb_path):
        print(f"Error: Could not find {peptide_pdb_path}.")
        print("Usage: python export_model.py <path_to_isolated_peptide.pdb>")
        return
        
    print(f"Extracting atomic numbers from {peptide_pdb_path}...")
    atoms = ase.io.read(peptide_pdb_path)
    extracted_z = atoms.get_atomic_numbers().tolist()
    num_atoms_in_ligand = len(extracted_z)
    
    print(f"Extracted {num_atoms_in_ligand} atoms. Z-array: {extracted_z}")
    
    wrapped_model = OpenMMTorchWrapper(model, extracted_z)
    
    # 2. Trace the model
    # Dummy input positions (N, 3)
    dummy_positions = torch.randn((num_atoms_in_ligand, 3), dtype=torch.float32)
    
    traced_model = torch.jit.trace(wrapped_model, (dummy_positions,))
    
    # 3. Save the TorchScript module to Drive
    output_path = os.environ.get("QUANTUM_FORGE_MODEL_PATH", "./inputs/tx1_traced.pt")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    traced_model.save(output_path)
    print(f"Successfully exported TorchScript model to {output_path}")

if __name__ == "__main__":
    export_model()
