from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import (
    kpi_routes,
    recommend_routes,
    poster_routes,
    calendar_routes,
    customer_routes,
    upload_routes,
    inventory_routes,
    report_routes,
)

app = FastAPI(
    title="SkyHigh Marketing Intelligence API",
    description="Backend API for customer segmentation, promotion recommendation, and campaign KPIs.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health_check():
    return {"status": "ok"}

app.include_router(kpi_routes.router)
app.include_router(recommend_routes.router)
app.include_router(poster_routes.router)
app.include_router(calendar_routes.router)
app.include_router(customer_routes.router)
app.include_router(upload_routes.router)
app.include_router(inventory_routes.router)
app.include_router(report_routes.router)
