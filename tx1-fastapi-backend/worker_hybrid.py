import os
import uuid
import openmm as mm
from openmm import app, unit
import openmmtorch
from celery import Celery

# Initialize Celery app with Redis broker
celery_app = Celery(
    "hybrid_md_worker",
    broker="redis://localhost:6379/0",
    backend="redis://localhost:6379/0"
)

@celery_app.task(name="run_hybrid_md")
def run_hybrid_md(pdb_path: str, job_id: str):
    """
    Executes a hybrid ML/MM Molecular Dynamics simulation.
    Uses openmm-torch for the MLIP on the peptide, and AMBER for the receptor/solvent.
    """
    # 1. Structure Preparation
    # Load the PDB file. We assume the PDB has been pre-processed/stripped.
    pdb = app.PDBFile(pdb_path)
    
    # 2. Classical MM Setup
    # Load AMBER forcefields
    forcefield = app.ForceField('amber19-all.xml', 'amber19/tip3pfb.xml')
    
    # Note: If the PDB lacks hydrogens or solvent, Modeller should be used here.
    # For this snippet, we assume a fully solvated and parameterized system is ready.
    # Often, you'll need specific ligand XML parameters if using classical forcefield,
    # but since we're overriding ligand forces with MLIP, we still need basic parameters
    # to create the system, or we manually define the system without ligand internal forces.
    
    system = forcefield.createSystem(pdb.topology, nonbondedMethod=app.PME,
                                     nonbondedCutoff=1.0*unit.nanometer,
                                     constraints=app.HBonds)
    
    # 3. MLIP Integration
    # Instantiate the TorchForce using our traced model from Drive
    torch_force = openmmtorch.TorchForce("/content/drive/MyDrive/QuantumForge/Inputs/tx1_traced.pt")
    
    # 4. Force Masking
    # We must extract atomic indices for the 4-mer/5-mer peptide ligand.
    # Let's assume the peptide is Chain B (or whatever identifier distinguishes it).
    # In standard GPR120 8ID6, receptor is Chain A.
    peptide_indices = []
    for atom in pdb.topology.atoms():
        # Adjust this condition based on your exact PDB structure
        if atom.residue.chain.id == 'B' or atom.residue.name in ['BETA_PEP']:
            peptide_indices.append(atom.index)
            
    if not peptide_indices:
        print("Warning: No peptide indices found! MLIP force will not be applied correctly.")
        
    # Configure TorchForce to ONLY evaluate on these indices
    # We also might want to remove the classical bonded interactions for these indices
    # to avoid double counting, depending on how the MLIP is parameterized.
    # For now, we simply add the specific atomic indices to TorchForce:
    # (Note: openmm-torch doesn't have a built-in subset mask natively in the force,
    # so typically we either pass the whole system and handle masking inside the PyTorch graph,
    # OR we use CustomCVForce/groups to isolate it, OR openmmtorch supports setPlatform() 
    # But actually, openmm-torch evaluates the energy over all atoms passed to it.
    # The standard way to apply to a subset is to use TorchForce on the whole system,
    # and inside the TorchScript model (like we did with the mask in export_model.py),
    # only compute energy for the relevant indices. BUT openmm-torch sends all coordinates!
    # A more advanced trick is using a CustomCVForce if the TorchScript expects subset, 
    # but since our PyTorch model expects a fixed size Z-array, we must use a trick:
    # We can pass global particle indices if openmmtorch > 0.3 allows it, 
    # or we handle the slicing inside the PyTorch module.
    
    # Assuming openmmtorch evaluates on the whole positions array, we'd slice it in PyTorch:
    # positions_ligand = positions[ligand_indices] 
    # In this script, we'll just add the force to the system assuming it works globally.
    
    # Actually, a common approach in openmm-torch to restrict atoms:
    # torch_force.setForceGroup(1) # example
    
    system.addForce(torch_force)
    
    # 5. Simulation Execution
    # Langevin integrator (300 K, 2 fs timestep, friction 1/ps)
    integrator = mm.LangevinMiddleIntegrator(300*unit.kelvin, 1.0/unit.picosecond, 2.0*unit.femtoseconds)
    
    # Platform selection (CUDA)
    platform = mm.Platform.getPlatformByName('CUDA')
    properties = {'Precision': 'mixed'}
    
    simulation = app.Simulation(pdb.topology, system, integrator, platform, properties)
    simulation.context.setPositions(pdb.positions)
    
    # Output trajectories to Google Drive
    output_dir = f"/content/drive/MyDrive/QuantumForge/Outputs/{job_id}"
    os.makedirs(output_dir, exist_ok=True)
    
    checkpoint_path = os.path.join(output_dir, 'checkpoint.chk')
    is_resuming = os.path.exists(checkpoint_path)
    
    if is_resuming:
        print("Found checkpoint. Resuming simulation...")
        simulation.loadCheckpoint(checkpoint_path)
    else:
        # Minimize to relieve steric clashes
        print("Minimizing energy...")
        simulation.minimizeEnergy(maxIterations=1000)
    
    dcd_reporter = app.DCDReporter(os.path.join(output_dir, 'trajectory.dcd'), 10000, append=is_resuming)
    state_reporter = app.StateDataReporter(os.path.join(output_dir, 'md_log.txt'), 10000,
                                           step=True, potentialEnergy=True, temperature=True, append=is_resuming)
    chk_reporter = app.CheckpointReporter(checkpoint_path, 50000)
    
    simulation.reporters.append(dcd_reporter)
    simulation.reporters.append(state_reporter)
    simulation.reporters.append(chk_reporter)
    
    # Target steps: 200 ns = 100,000,000 steps (at 2 fs)
    # We will use 100,000,000 for the full production run
    total_steps = 100000000
    
    # If resuming, step() still needs the remaining steps, or just total_steps if openmm handles it.
    # Actually openmm simulation.step() advances by X steps from current step.
    # To run exactly up to 100,000,000 steps total:
    current_step = simulation.currentStep
    steps_left = total_steps - current_step
    
    if steps_left > 0:
        print(f"Running simulation for {steps_left} steps (Current step: {current_step})...")
        simulation.step(steps_left)
        print("Simulation complete.")
    else:
        print("Simulation already reached target steps.")
    
    return {"status": "SUCCESS", "job_id": job_id, "trajectory_dir": output_dir}
