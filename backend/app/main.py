from dotenv import load_dotenv
load_dotenv()

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

# Web dashboard routes
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

# Merged backend2 routes
from app.routes import kpi_routes
from app.routes import recommend_routes
from app.routes import poster_routes
from app.routes import calendar_routes
from app.routes import customer_routes
from app.routes import upload_routes
from app.routes import report_routes

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

# Web dashboard routers
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

# Merged backend2 routers
app.include_router(kpi_routes.router)
app.include_router(recommend_routes.router)
app.include_router(poster_routes.router)
app.include_router(calendar_routes.router)
app.include_router(customer_routes.router)
app.include_router(upload_routes.router)
app.include_router(report_routes.router)

app.mount("/generated", StaticFiles(directory="generated"), name="generated")


app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

@app.get("/")
def root():
    return {"message": "Backend is running successfully"}