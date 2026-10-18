from app.services.intelligence_service import generate_inventory_intelligence


def calculate_priority(stock_health: str, stockout_risk: str, overstock_risk: str):
    if stock_health in ["Stockout", "Critical"] or stockout_risk == "High":
        return "HIGH"

    if stock_health == "Low Stock" or stockout_risk == "Medium":
        return "MEDIUM"

    if stock_health in ["Overstock", "Excess"] or overstock_risk in ["High", "Medium"]:
        return "MEDIUM"

    return "LOW"


def calculate_risk_score(current_stock: int, forecast_demand: int, max_stock: int):
    if forecast_demand <= 0:
        return 20

    if current_stock < forecast_demand:
        shortage_ratio = (forecast_demand - current_stock) / forecast_demand
        return min(100, int(shortage_ratio * 100))

    if current_stock > max_stock:
        overstock_ratio = (current_stock - max_stock) / max_stock
        return min(100, int(overstock_ratio * 100))

    return 20


def generate_recommendation(
    product_id: str,
    store_id: str,
    current_stock: int,
    reorder_level: int,
    max_stock: int,
    forecast_demand: int,
    cost_price: float = 0,
    selling_price: float = 0
):
    intelligence = generate_inventory_intelligence(
        current_stock=current_stock,
        reorder_level=reorder_level,
        max_stock=max_stock,
        forecast_demand=forecast_demand,
        cost_price=cost_price,
        selling_price=selling_price
    )

    priority = calculate_priority(
        intelligence["stock_health"],
        intelligence["stockout_risk"],
        intelligence["overstock_risk"]
    )

    risk_score = calculate_risk_score(
        current_stock=current_stock,
        forecast_demand=forecast_demand,
        max_stock=max_stock
    )

    urgency_score = risk_score

    return {
        "product_id": product_id,
        "store_id": store_id,

        "forecast_demand": forecast_demand,
        "current_stock": current_stock,

        "stock_health": intelligence["stock_health"],
        "days_on_hand": intelligence["days_on_hand"],
        "stockout_risk": intelligence["stockout_risk"],
        "overstock_risk": intelligence["overstock_risk"],

        "recommended_action": intelligence["recommended_action"],
        "recommended_quantity": intelligence["recommended_quantity"],
        "suggested_discount": intelligence["suggested_discount"],

        "priority": priority,
        "urgency_score": urgency_score,
        "inventory_risk_score": risk_score,

        "inventory_value": intelligence["inventory_value"],
        "potential_revenue": intelligence["potential_revenue"],
        "potential_profit": intelligence["potential_profit"],

        "recommendation_reason": intelligence["recommendation_reason"]
    }