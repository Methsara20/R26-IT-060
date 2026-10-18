from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class GoogleLoginRequest(BaseModel):
    id_token: str


class LoginResponse(BaseModel):
    message: str
    access_token: str
    token_type: str
    profile_id: str
    email: EmailStr