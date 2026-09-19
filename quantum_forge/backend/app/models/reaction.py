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
    """Inputs for the Direct MaxFlux / UMA reaction-path search.

    Mirrors ColabReaction's input arguments: reactant/product XYZ plus the
    DMF settings (charge, multiplicity, nmove, update_teval, convergence) and
    the Hugging Face token / MLIP model used to load the UMA potential.
    """
    reactant_xyz: str = Field(..., description="Raw XYZ string of the reactant")
    product_xyz: str = Field(..., description="Raw XYZ string of the product")

    charge: int = Field(0, description="Total system charge")
    spin_multiplicity: int = Field(1, description="Spin multiplicity (2S+1)")

    nmove: int = Field(20, description="Number of movable DMF evaluation points")
    update_teval: bool = Field(False, description="Concentrate points around the barrier")
    convergence: str = Field("tight", description="DMF convergence: tight | middle | loose")

    mlip_model: str = Field("UMA-SM", description="fairchem model: UMA-SM | UMA-Medium")
    hf_token: Optional[str] = Field(None, description="Hugging Face token for UMA weights")


class VibrationalMode(BaseModel):
    frequency: float
    vectors: List[List[float]] = []


class ReactionStatusResponse(BaseModel):
    reaction_id: str
    state: ReactionState
    progress: float
    message: Optional[str] = None
    energy_profile: Optional[List[float]] = None          # ΔE vs reactant, kcal/mol
    energy_profile_ev: Optional[List[float]] = None
    trajectory_frames: Optional[List[str]] = None
    vibrational_modes: Optional[List[VibrationalMode]] = None
    max_energy_index: Optional[int] = None
    error: Optional[str] = None
