from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
import torch.nn as nn

# ==========================================
# 1. MODEL ARCHITECTURE (Graph Neural Network)
# ==========================================
class MolecularGraphNetwork(nn.Module):
    def __init__(self, hidden_dim=128, num_interactions=3, max_Z=100):
        super().__init__()
        self.embedding = nn.Embedding(max_Z, hidden_dim)

        self.distance_expansion = nn.Sequential(
            nn.Linear(1, hidden_dim),
            nn.SiLU(),
            nn.Linear(hidden_dim, hidden_dim)
        )

        self.interaction_layers = nn.ModuleList([
            nn.Sequential(
                nn.Linear(hidden_dim * 2, hidden_dim),
                nn.SiLU(),
                nn.Linear(hidden_dim, hidden_dim)
            ) for _ in range(num_interactions)
        ])

        self.energy_readout = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.SiLU(),
            nn.Linear(hidden_dim // 2, 1)
        )

    def forward(self, z, pos, mask=None):
        node_features = self.embedding(z)

        pos_expanded_1 = pos.unsqueeze(2)  # [batch, N, 1, 3]
        pos_expanded_2 = pos.unsqueeze(1)  # [batch, 1, N, 3]
        dist_matrix = torch.norm(pos_expanded_1 - pos_expanded_2, dim=-1)

        dist_features = self.distance_expansion(dist_matrix.unsqueeze(-1))

        for layer in self.interaction_layers:
            expanded_nodes = node_features.unsqueeze(2).expand(-1, -1, pos.size(1), -1)
            combined = torch.cat([expanded_nodes, dist_features], dim=-1)
            messages = layer(combined).sum(dim=2)
            node_features = node_features + messages

        per_atom_energy = self.energy_readout(node_features).squeeze(-1)
        if mask is not None:
            per_atom_energy = per_atom_energy * mask

        total_energy = per_atom_energy.sum(dim=-1)
        return total_energy

# ==========================================
# 2. INITIALIZE FASTAPI AND LOAD CHECKPOINT
# ==========================================
app = FastAPI(title="Transition1x GNN API")
model = None

@app.on_event("startup")
def load_model():
    global model
    try:
        model = MolecularGraphNetwork() 
        checkpoint = torch.load("t1x_model_checkpoint.pt", map_location=torch.device('cpu'))
        
        if 'model_state_dict' in checkpoint:
            model.load_state_dict(checkpoint['model_state_dict'])
        else:
            model.load_state_dict(checkpoint)
            
        model.eval()
        print("Model loaded successfully!")
    except Exception as e:
        print(f"Error loading model: {e}")

# ==========================================
# 3. API ENDPOINT
# ==========================================
class MoleculeRequest(BaseModel):
    atomic_numbers: list[int]
    positions: list[list[float]]

@app.post("/predict")
def predict_energy(molecule: MoleculeRequest):
    if model is None:
        raise HTTPException(status_code=500, detail="Model failed to load on startup")
    
    try:
        # Convert lists to tensors and add batch dimension [1, N]
        z = torch.tensor(molecule.atomic_numbers, dtype=torch.long).unsqueeze(0)
        pos = torch.tensor(molecule.positions, dtype=torch.float32).unsqueeze(0)
        
        # Create mask to match the training pipeline logic
        mask = (z != 0).float()
        
        with torch.no_grad():
            energy = model(z, pos, mask)
            
        return {
            "status": "success",
            "energy_ev": energy.item()
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))