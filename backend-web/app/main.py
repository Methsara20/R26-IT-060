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
from app.routes import optimization_candidate_routes
from app.routes import decision_engine_routes
from app.routes import stock_movement_routes
from app.routes.chat_routes import router as chat_router
from app.routes import weather_routes
from app.routes import decision_workflow_routes
from app.routes.marketing_opportunity_routes import router as marketing_opportunity_router


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
app.include_router(optimization_candidate_routes.router)
app.include_router(decision_engine_routes.router)
app.include_router(stock_movement_routes.router)
app.include_router(chat_router)
app.include_router(weather_routes.router)
app.include_router(decision_workflow_routes.router)
app.include_router(marketing_opportunity_router)

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
