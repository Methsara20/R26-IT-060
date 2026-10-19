from fastapi import APIRouter, Depends
from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.security.inventory_permissions import inventory_analysis_user, require_store_access

from app.schemas.recommendation_schema import RecommendationRequest
from app.services.recommendation_service import generate_recommendation

router = APIRouter(
    prefix="/recommendations",
    tags=["Recommendations"]
)


@router.post("/generate")
def generate_inventory_recommendation(data: RecommendationRequest, user: InventoryPrincipal = Depends(inventory_analysis_user())):
    require_store_access(user, data.store_id)
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
