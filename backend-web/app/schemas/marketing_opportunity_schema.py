from typing import Optional

from pydantic import BaseModel, Field


class MarketingOpportunityRequest(BaseModel):
    workflow_id: str = Field(..., min_length=1)

    product_id: str = Field(..., min_length=1)
    product_name: str = Field(..., min_length=1)

    store_id: str = Field(..., min_length=1)

    category: Optional[str] = None
    subcategory: Optional[str] = None
    brand: Optional[str] = None
    gender: Optional[str] = None

    current_stock: int = Field(..., ge=0)
    forecast_demand: int = Field(..., ge=0)
    required_stock: int = Field(..., ge=0)
    excess_quantity: int = Field(..., ge=0)

    selling_price: Optional[float] = Field(
        default=None,
        ge=0,
    )
    promotion_percent: Optional[float] = Field(
        default=None,
        ge=0,
        le=100,
    )

    stock_health: str = Field(..., min_length=1)
    recommended_action: str = Field(..., min_length=1)


class MarketingOpportunityResponse(BaseModel):
    opportunity_id: str
    workflow_id: str
    status: str
    message: str