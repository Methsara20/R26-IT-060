from typing import Optional
from pydantic import BaseModel, EmailStr


class ProfileCreateRequest(BaseModel):
    email: EmailStr
    password: str
    height: float
    weight: float
    gender: str


class ProfileUpdateRequest(BaseModel):
    height: Optional[float] = None
    weight: Optional[float] = None
    gender: Optional[str] = None
    password: Optional[str] = None