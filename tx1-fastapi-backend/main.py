from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
import torch.nn as nn

# 1. PASTE YOUR EXACT MODEL ARCHITECTURE FROM COLAB HERE
# It must contain the 'embedding', 'distance_expansion', 'interaction_layers', 
# and 'energy_readout' modules defined in your checkpoint.
class Transition1xGNN(nn.Module):
    def __init__(self):
        super().__init__()
        # Paste your layer definitions here...
        pass
        
    def forward(self, z, pos, batch=None):
        # Paste your forward pass logic here...
        pass

# 2. Initialize FastAPI and the Model
app = FastAPI(title="Transition1x GNN API")
model = None

@app.on_event("startup")
def load_model():
    global model
    try:
        # Initialize your architecture
        model = Transition1xGNN() 
        
        # Load the 2MB checkpoint. map_location='cpu' is critical 
        # to prevent Render from crashing due to GPU memory constraints.
        checkpoint = torch.load("t1x_model_checkpoint.pt", map_location=torch.device('cpu'))
        
        # Unpack the state_dict depending on how your Colab script saved it
        if 'model_state_dict' in checkpoint:
            model.load_state_dict(checkpoint['model_state_dict'])
        else:
            model.load_state_dict(checkpoint)
            
        model.eval()
        print("Model loaded successfully!")
    except Exception as e:
        print(f"Error loading model: {e}")

# 3. Define the incoming JSON structure from Flutter
class MoleculeRequest(BaseModel):
    atomic_numbers: list[int]
    positions: list[list[float]] # 3D XYZ coordinates

# 4. Create the prediction endpoint
@app.post("/predict")
def predict_energy(molecule: MoleculeRequest):
    if model is None:
        raise HTTPException(status_code=500, detail="Model failed to load on startup")
    
    try:
        # Convert Flutter JSON lists to PyTorch CPU tensors
        z = torch.tensor(molecule.atomic_numbers, dtype=torch.long)
        pos = torch.tensor(molecule.positions, dtype=torch.float32)
        
        # Run inference (disable gradients to save memory and speed up processing)
        with torch.no_grad():
            energy = model(z, pos)
            
        return {
            "status": "success",
            "energy_ev": energy.item()
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))