from fastapi import APIRouter, Depends
from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.security.inventory_permissions import inventory_analysis_user

from app.schemas.intelligence_schema import InventoryIntelligenceRequest
from app.services.intelligence_service import generate_inventory_intelligence

router = APIRouter(
    prefix="/intelligence",
    tags=["Inventory Intelligence"]
)


@router.post("/analyze")
def analyze_inventory(data: InventoryIntelligenceRequest, user: InventoryPrincipal = Depends(inventory_analysis_user())):
    result = generate_inventory_intelligence(
        current_stock=data.current_stock,
        reorder_level=data.reorder_level,
        max_stock=data.max_stock,
        forecast_demand=data.forecast_demand,
        cost_price=data.cost_price,
        selling_price=data.selling_price
    )

    return result
