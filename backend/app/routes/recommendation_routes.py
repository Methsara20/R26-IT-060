from fastapi import APIRouter

from app.schemas.recommendation_schema import RecommendationRequest
from app.services.recommendation_service import generate_recommendation

router = APIRouter(
    prefix="/recommendations",
    tags=["Recommendations"]
)


@router.post("/generate")
def generate_inventory_recommendation(data: RecommendationRequest):
    return generate_recommendation(
        product_id=data.product_id,
        store_id=data.store_id,
        current_stock=data.current_stock,
        reorder_level=data.reorder_level,
        max_stock=data.max_stock,
        forecast_demand=data.forecast_demand,
        cost_price=data.cost_price,
        selling_price=data.selling_price
    )