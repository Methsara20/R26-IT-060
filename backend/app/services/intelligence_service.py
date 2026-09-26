from app.utils.inventory_utils import (
    calculate_days_on_hand,
    calculate_stock_health,
    calculate_stockout_risk,
    calculate_overstock_risk
)


def generate_inventory_intelligence(
    current_stock: int,
    reorder_level: int,
    max_stock: int,
    forecast_demand: int,
    cost_price: float = 0,
    selling_price: float = 0
):
    days_on_hand = calculate_days_on_hand(
        current_stock=current_stock,
        forecast_demand=forecast_demand
    )

    stock_health = calculate_stock_health(
        current_stock=current_stock,
        forecast_demand=forecast_demand,
        max_stock=max_stock
    )

    stockout_risk = calculate_stockout_risk(
        current_stock=current_stock,
        forecast_demand=forecast_demand
    )

    overstock_risk = calculate_overstock_risk(
        current_stock=current_stock,
        forecast_demand=forecast_demand,
        max_stock=max_stock
    )

    shortage_qty = max(0, forecast_demand - current_stock)
    excess_qty = max(0, current_stock - forecast_demand)

    inventory_value = round(current_stock * cost_price, 2)
    potential_revenue = round(current_stock * selling_price, 2)
    potential_profit = round(current_stock * (selling_price - cost_price), 2)

    recommended_action = "MONITOR"
    recommended_quantity = 0
    suggested_discount = 0

    if stock_health in ["Stockout", "Critical"]:
        recommended_action = "REORDER"
        recommended_quantity = max(shortage_qty, reorder_level)

    elif stock_health == "Low Stock":
        recommended_action = "REPLENISH"
        recommended_quantity = shortage_qty

    elif stock_health in ["Overstock", "Excess"]:
        recommended_action = "PROMOTE"
        suggested_discount = 15

        if current_stock > forecast_demand * 3:
            suggested_discount = 25
        elif current_stock > forecast_demand * 2:
            suggested_discount = 20

    elif stock_health == "Healthy":
        recommended_action = "NO_ACTION"

    recommendation_reason = build_recommendation_reason(
        stock_health,
        current_stock,
        forecast_demand,
        recommended_action
    )

    return {
        "forecast_demand": forecast_demand,
        "current_stock": current_stock,
        "stock_health": stock_health,
        "days_on_hand": days_on_hand,
        "stockout_risk": stockout_risk,
        "overstock_risk": overstock_risk,
        "shortage_qty": shortage_qty,
        "excess_qty": excess_qty,
        "recommended_action": recommended_action,
        "recommended_quantity": recommended_quantity,
        "suggested_discount": suggested_discount,
        "recommendation_reason": recommendation_reason,
        "inventory_value": inventory_value,
        "potential_revenue": potential_revenue,
        "potential_profit": potential_profit
    }


def build_recommendation_reason(
    stock_health: str,
    current_stock: int,
    forecast_demand: int,
    recommended_action: str
):
    if recommended_action == "REORDER":
        return (
            f"Current stock is {current_stock}, while forecast demand is "
            f"{forecast_demand}. Reorder is recommended to avoid stockout."
        )

    if recommended_action == "REPLENISH":
        return (
            f"Forecast demand exceeds current stock. Additional stock is "
            f"recommended to maintain availability."
        )

    if recommended_action == "PROMOTE":
        return (
            f"Current stock is significantly higher than forecast demand. "
            f"A promotion is recommended to reduce excess inventory."
        )

    return (
        f"Current stock is sufficient compared to forecast demand. "
        f"No immediate inventory action is required."
    )