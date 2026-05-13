from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.routes import profile
from app.routes import tryon

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(profile.router, prefix="/profile", tags=["Profile"])
app.include_router(tryon.router, prefix="/tryon", tags=["Try On"])

app.mount("/generated", StaticFiles(directory="generated"), name="generated")

@app.get("/")
def root():
    return {"message": "Backend is running successfully"}