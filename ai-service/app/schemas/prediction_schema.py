from pydantic import BaseModel

class SimplePredictionRequest(BaseModel):
    product_id: str
    store_id: str
    current_stock: float
    price_lkr: float
    promotion_percent: float

class PredictionRequest(BaseModel):
    store_id: str
    product_id: str
    category: str

    price_lkr: float
    discount: float

    temperature: float
    rainfall: float
    humidity: float
    weather_condition: str

    month: int
    day: int
    day_of_week_num: int

    lag_1: float
    lag_7: float
    rolling_mean_7: float

    is_holiday: int
    is_promotion: int
    is_school: int
    is_festival: int