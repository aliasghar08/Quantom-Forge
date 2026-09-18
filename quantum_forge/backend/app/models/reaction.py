from pydantic import BaseModel, Field
from typing import List, Optional
from enum import Enum

class ReactionState(str, Enum):
    IDLE = "idle"
    PENDING = "pending"
    OPTIMIZING = "optimizing"
    COMPLETED = "completed"
    ERROR = "error"

class ReactionRequest(BaseModel):
    reactant_xyz: str = Field(..., description="Raw XYZ string of the reactant")
    product_xyz: str = Field(..., description="Raw XYZ string of the product")
    charge: int = Field(0, description="Total system charge")
    spin_multiplicity: int = Field(1, description="Spin multiplicity")

class ReactionStatusResponse(BaseModel):
    reaction_id: str
    state: ReactionState
    progress: float
    message: Optional[str] = None
    energy_profile: Optional[List[float]] = None
    trajectory_frames: Optional[List[str]] = None
