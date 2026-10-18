from pydantic import BaseModel
from typing import Optional

class CustomerProfile(BaseModel):
    age_group: str
    gender: str
    loyalty_tier: str
    channel: str
    preferred_category: str
    visit_frequency: float
    total_spend_lkr: float
    avg_basket_value_lkr: float
    days_since_last_purchase: float
    customer_past_redemption_rate: float = 0.0
    discount_pct: Optional[float] = 20.0
    is_seasonal_window: int = 0
    is_salary_cycle: int = 0
    is_school_holiday: int = 0
