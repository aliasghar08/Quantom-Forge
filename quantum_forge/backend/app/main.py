from fastapi import FastAPI, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from uuid import uuid4
from .models.reaction import ReactionRequest, ReactionStatusResponse
from .services.compute_worker import simulate_ts_search, get_reaction_status

app = FastAPI(title="ColabReaction Compute API", version="1.0.0")

# Enable CORS for local Flutter web/desktop development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/reactions/submit", response_model=ReactionStatusResponse)
async def submit_reaction_reaction(request: ReactionRequest, background_tasks: BackgroundTasks):
    reaction_id = str(uuid4())
    
    # In a production app, we would enqueue this to Celery/Redis
    # Here we use FastAPI's BackgroundTasks to simulate async worker execution
    background_tasks.add_task(
        simulate_ts_search, 
        reaction_id=reaction_id, 
        reactant_xyz=request.reactant_xyz, 
        product_xyz=request.product_xyz
    )
    
    # Return initial pending state immediately
    return get_reaction_status(reaction_id)

@app.get("/reactions/{reaction_id}", response_model=ReactionStatusResponse)
async def get_reaction(reaction_id: str):
    return get_reaction_status(reaction_id)

@app.get("/health")
def health_check():
    return {"status": "ok", "message": "ColabReaction Compute Node is active"}
