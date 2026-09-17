from fastapi import FastAPI, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from uuid import uuid4
from .models.job import ReactionRequest, JobStatusResponse
from .services.compute_worker import simulate_ts_search, get_job_status

app = FastAPI(title="ColabReaction Compute API", version="1.0.0")

# Enable CORS for local Flutter web/desktop development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/jobs/submit", response_model=JobStatusResponse)
async def submit_reaction_job(request: ReactionRequest, background_tasks: BackgroundTasks):
    job_id = str(uuid4())
    
    # In a production app, we would enqueue this to Celery/Redis
    # Here we use FastAPI's BackgroundTasks to simulate async worker execution
    background_tasks.add_task(
        simulate_ts_search, 
        job_id=job_id, 
        reactant_xyz=request.reactant_xyz, 
        product_xyz=request.product_xyz
    )
    
    # Return initial pending state immediately
    return get_job_status(job_id)

@app.get("/jobs/{job_id}", response_model=JobStatusResponse)
async def get_job(job_id: str):
    return get_job_status(job_id)

@app.get("/health")
def health_check():
    return {"status": "ok", "message": "ColabReaction Compute Node is active"}
