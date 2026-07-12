from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.routes import zone
from app.routes import profile
from app.routes import tryon
from app.routes import inventory
from app.routes import monitoring

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(zone.router, prefix="/zone", tags=["Zone"])
app.include_router(profile.router, prefix="/profile", tags=["Profile"])
app.include_router(tryon.router, prefix="/tryon", tags=["Try On"])
app.include_router(inventory.router, prefix="/inventory", tags=["Inventory"])
app.include_router(monitoring.router, prefix="/monitoring", tags=["Monitoring"])

app.mount("/generated", StaticFiles(directory="generated"), name="generated")
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

@app.get("/")
def root():
    return {"message": "Backend is running successfully"}