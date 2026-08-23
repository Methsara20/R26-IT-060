import os
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.routes import zone
from app.routes import profile
from app.routes import tryon
from app.routes import monitoring
from app.routes import product_routes
from app.routes import smart_inventory
from app.routes import stylist

app = FastAPI()

from fastapi import Request
from fastapi.responses import JSONResponse
import traceback

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error", "traceback": traceback.format_exc()},
    )
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
app.include_router(monitoring.router, prefix="/monitoring", tags=["Monitoring"])
app.include_router(product_routes.router)
app.include_router(smart_inventory.router)
app.include_router(stylist.router, prefix="/stylist", tags=["Stylist"])
app.mount("/generated", StaticFiles(directory="generated"), name="generated")

@app.get("/test-crash")
def test_crash():
    from app.services.auth_service import hash_password
    try:
        h = hash_password("test")
        return {"status": "ok", "hash": h}
    except Exception as e:
        import traceback
        return {"status": "error", "traceback": traceback.format_exc()}

@app.get("/test-ml-crash")
def test_ml_crash():
    from app.services.body_measurement_service import predict_body_measurements
    try:
        res = predict_body_measurements(170.0, 56.0, "MALE")
        return {"status": "ok", "result": res}
    except Exception as e:
        import traceback
        return {"status": "error", "traceback": traceback.format_exc()}
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

@app.get("/")
def root():
    return {"message": "Backend is running successfully"}