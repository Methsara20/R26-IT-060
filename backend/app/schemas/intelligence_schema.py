from pydantic import BaseModel


class InventoryIntelligenceRequest(BaseModel):
    current_stock: int
    reorder_level: int
    max_stock: int
    forecast_demand: int
    cost_price: float = 0
    selling_price: float = 0