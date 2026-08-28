def calculate_days_on_hand(current_stock: int, forecast_demand: int, forecast_days: int = 30):
    if forecast_demand <= 0:
        return 999

    avg_daily_demand = forecast_demand / forecast_days
    return round(current_stock / avg_daily_demand, 2)


def calculate_stock_health(current_stock: int, forecast_demand: int, max_stock: int):
    if current_stock <= 0:
        return "Stockout"

    if current_stock < forecast_demand * 0.5:
        return "Critical"

    if current_stock < forecast_demand:
        return "Low Stock"

    if current_stock > max_stock:
        return "Overstock"

    if current_stock > forecast_demand * 2:
        return "Excess"

    return "Healthy"


def calculate_stockout_risk(current_stock: int, forecast_demand: int):
    if forecast_demand <= 0:
        return "Low"

    ratio = current_stock / forecast_demand

    if ratio < 0.5:
        return "High"

    if ratio < 1:
        return "Medium"

    return "Low"


def calculate_overstock_risk(current_stock: int, forecast_demand: int, max_stock: int):
    if current_stock > max_stock:
        return "High"

    if forecast_demand > 0 and current_stock > forecast_demand * 2:
        return "Medium"

    return "Low"