from pydantic import BaseModel, Field
from datetime import date


class DailyForecastRequest(BaseModel):
    store_id: str
    product_id: str
    price_lkr: float
    promotion_percent: float = 0

    temperature: float = 30
    humidity: float = 75
    rainfall: float = 0

    is_holiday: int = 0
    is_festival: int = 0
    is_school: int = 0
    is_weekend: int = 0

    month: int
    day: int
    day_of_week_num: int

    lag_1: float = 0
    lag_7: float = 0
    rolling_mean_7: float = 0

class InventoryForecastRequest(BaseModel):
    store_id: str
    category: str
    brand: str
    gender: str

    city: str
    region: str
    store_type: str

    year: int
    month: int
    quarter: int

    monthly_units_sold: float
    avg_price_lkr: float
    avg_promotion_percent: float
    total_revenue: float
    total_customer_count: float
    unique_products_sold: float

    avg_temperature: float
    avg_humidity: float
    total_rainfall: float
    rainy_days: int
    storm_days: int
    sunny_days: int

    holiday_days: int
    festival_days: int
    school_days: int
    weekend_days: int

    promotion_days: int
    max_promotion_percent: float
    avg_campaign_discount: float

    avg_current_stock: float
    min_current_stock: float
    max_current_stock: float
    total_current_stock: float
    avg_reorder_level: float
    total_reorder_level: float
    avg_max_stock: float

    previous_month_sales: float
    previous_2_month_avg: float
    previous_3_month_avg: float
    previous_6_month_avg: float
    same_month_last_year: float

    sales_growth_1m: float
    sales_growth_3m: float


class CustomForecastRequest(BaseModel):
    store_id: str
    product_id: str

    price_lkr: float
    promotion_percent: float = 0

    start_date: date
    end_date: date

    is_holiday: int = 0
    is_festival: int = 0
    is_school: int = 0

    lag_1: float = 0
    lag_7: float = 0
    rolling_mean_7: float = 0

class AutoMonthlyForecastRequest(BaseModel):
    """
    Manager-facing monthly forecast request.

    Internal ML features are prepared automatically
    by the backend.
    """

    store_id: str
    category: str
    brand: str
    gender: str

    year: int = Field(
        ge=2021,
        le=2100
    )

    month: int = Field(
        ge=1,
        le=12
    )


class AutoQuarterlyForecastRequest(BaseModel):
    """
    Manager-facing quarterly forecast request.

    The backend automatically derives the three
    months belonging to the selected quarter.
    """

    store_id: str
    category: str
    brand: str
    gender: str

    year: int = Field(
        ge=2021,
        le=2100
    )

    quarter: int = Field(
        ge=1,
        le=4
    )