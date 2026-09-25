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
    # 1. Load the original model
    model = MolecularGraphNetwork()
    ckpt = checkpoint_path()
    if ckpt.exists():
        model.load_state_dict(torch.load(ckpt, map_location="cpu"))
        print(f"Loaded weights from {ckpt}")
    else:
        print(f"Warning: Checkpoint {ckpt} not found. Using untrained weights.")
    
    model.eval()

    # NOTE: To use openmm-torch, the model needs to know the atomic numbers of the atoms
    # being passed to it. In the hybrid simulation, we apply TorchForce ONLY to the peptide ligand.
    # Therefore, we need to know the exact atomic sequence of the peptide ligand.
    # For this tracing script, we will use a placeholder Z array.
    # In practice, you must replace `placeholder_z` with the actual atomic numbers (z) of your peptide.
    
    # Placeholder: A 4-mer beta-peptide typically has around 40-50 atoms.
    # We will just trace with a dummy sequence. 
    # YOU MUST UPDATE THIS Z-ARRAY TO MATCH YOUR EXTRACTED LIGAND EXACTLY.
    num_atoms_in_ligand = 50
    placeholder_z = [6] * num_atoms_in_ligand  # e.g., Carbon atoms
    
    wrapped_model = OpenMMTorchWrapper(model, placeholder_z)
    
    # 2. Trace the model
    # Dummy input positions (N, 3)
    dummy_positions = torch.randn((num_atoms_in_ligand, 3), dtype=torch.float32)
    
    traced_model = torch.jit.trace(wrapped_model, (dummy_positions,))
    
    # 3. Save the TorchScript module
    output_path = "tx1_traced.pt"
    traced_model.save(output_path)
    print(f"Successfully exported TorchScript model to {output_path}")

if __name__ == "__main__":
    export_model()
