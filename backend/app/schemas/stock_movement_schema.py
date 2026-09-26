from pydantic import BaseModel
from typing import Optional


class ApproveMovementRequest(BaseModel):
    is_approved: bool = True


class RejectMovementRequest(BaseModel):
    is_rejected: bool = True
    rejection_reason: Optional[str] = None


class CancelMovementRequest(BaseModel):
    is_cancelled: bool = True
    cancel_reason: Optional[str] = None


class ExecuteMovementRequest(BaseModel):
    is_executed: bool = True