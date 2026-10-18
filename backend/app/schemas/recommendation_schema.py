from pydantic import BaseModel


class RecommendationRequest(BaseModel):
    product_id: str
    store_id: str

    current_stock: int
    reorder_level: int
    max_stock: int

    forecast_demand: int

    cost_price: float = 0
    selling_price: float = 0