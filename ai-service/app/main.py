from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.services.firebase_service import initialize_firebase
from app.routes import product_routes
from app.routes import inventory_routes
from app.routes import store_routes
from app.routes import forecast_routes
from app.routes import intelligence_routes
from app.routes import recommendation_routes
from app.routes import analytics_routes

app = FastAPI(
    title="Smart Inventory AI Service",
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup_event():
    initialize_firebase()


app.include_router(product_routes.router)
app.include_router(inventory_routes.router)
app.include_router(store_routes.router)
app.include_router(forecast_routes.router)
app.include_router(intelligence_routes.router)
app.include_router(recommendation_routes.router)
app.include_router(analytics_routes.router)

@app.get("/")
def home():
    return {
        "message": "Smart Inventory AI Service Running",
        "version": "2.0.0"
    }


@app.get("/health")
def health_check():
    return {
        "status": "OK",
        "firebase": "Connected"
    }