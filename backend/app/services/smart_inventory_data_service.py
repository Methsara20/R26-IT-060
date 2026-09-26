import pandas as pd
from datetime import datetime

#  Load datasets once
inventory_df = pd.read_csv("app/data/inventory_2026.csv")
sales_df = pd.read_csv("app/data/sl_retail_sales_2024.csv")
weather_df = pd.read_csv("app/data/weather_2024.csv")
events_df = pd.read_csv("app/data/events_2024.csv")


def get_sales_value(sales, current_stock):
    if sales is None:
        return current_stock

    for col in ["units_sold", "unit_sold", "sales_qty", "sales", "quantity"]:
        if col in sales:
            return float(sales[col])

    return current_stock


# MAIN PAYLOAD
def build_payload(store_id, product_id, current_stock, price_lkr, promotion_percent):
    from app.services.product_service import get_product_by_id
    prod = get_product_by_id(product_id)
    if not prod:
        raise ValueError("Product not found")

    sales = sales_df[
        (sales_df["store_id"] == store_id) &
        (sales_df["product_id"] == product_id)
    ]

    if not sales.empty:
        sales = sales.sort_values("date").iloc[-1]
    else:
        sales = None

    weather = weather_df.iloc[-1]
    today = datetime.now()

    event_today = events_df[
        events_df["date"] == today.strftime("%Y-%m-%d")
    ]

    if not event_today.empty:
        event_today = event_today.iloc[0]
    else:
        event_today = {}

    promotion_percent = float(promotion_percent or 0)

    payload = {}

    #  BASE
    payload["store_id"] = store_id
    payload["product_id"] = product_id
    payload["category"] = prod.get("category", "")
    payload["brand"] = prod.get("brand", "")
    payload["gender"] = prod.get("gender", "")
    payload["subcategory"] = prod.get("subcategory", "")

    #  USER INPUT
    payload["price_lkr"] = float(price_lkr)
    payload["discount"] = promotion_percent / 100

    #  WEATHER
    payload["temperature"] = float(weather["temperature"])
    payload["rainfall"] = float(weather["rainfall"])
    payload["humidity"] = float(weather["humidity"])
    payload["weather_condition"] = weather.get("weather_condition", "Unknown")

    #  TIME
    payload["month"] = today.month
    payload["day"] = today.day
    payload["day_of_week_num"] = today.weekday()

    #  LAG
    lag = get_sales_value(sales, current_stock)

    payload["lag_1"] = lag
    payload["lag_7"] = lag
    payload["rolling_mean_7"] = lag

    #  EVENTS
    payload["is_holiday"] = int(event_today.get("is_holiday", 0))
    payload["is_promotion"] = 1 if promotion_percent > 0 else 0
    payload["is_school"] = int(event_today.get("is_school", 0))
    payload["is_festival"] = int(event_today.get("is_festival", 0))

    return payload


def detect_trend(payload):
    lag_1 = payload.get("lag_1", 0)
    lag_7 = payload.get("lag_7", 0)

    if lag_1 > lag_7:
        return "UP"
    elif lag_1 < lag_7:
        return "DOWN"
    else:
        return "STABLE"


def trend_based_forecast(prediction, payload):
    trend = detect_trend(payload)

    forecast = []

    day_factors = [1.00, 1.01, 0.99, 1.02, 0.98, 1.01, 1.00]

    for i in range(7):
        if trend == "UP":
            trend_factor = 1 + (0.01 * (i + 1))
        elif trend == "DOWN":
            trend_factor = 1 - (0.01 * (i + 1))
        else:
            trend_factor = 1.0

        day_value = prediction * trend_factor * day_factors[i]
        forecast.append(round(day_value, 2))

    total = round(sum(forecast), 2)

    return forecast, total, trend


def enrich_with_forecast(prediction, payload):
    forecast_list, forecast_total, trend = trend_based_forecast(prediction, payload)

    return {
        "forecast_7_days": forecast_total,
        "forecast_7_days_list": forecast_list,
        "trend": trend
    }


def get_product_store_info(store_id=None, product_id=None):
    from app.services.product_service import get_all_products, get_product_by_id
    from app.services.store_service import get_all_stores, get_store_by_id

    # DROPDOWN DATA MODE
    if store_id is None and product_id is None:
        products = get_all_products()
        stores = get_all_stores()
        
        dropdown_products = []
        for p in products:
            dropdown_products.append({
                "product_id": p.get("product_id") or p.get("id"),
                "product_name": p.get("product_name") or p.get("name"),
                "brand": p.get("brand"),
                "gender": p.get("gender"),
                "subcategory": p.get("subcategory")
            })
            
        dropdown_stores = []
        for s in stores:
            dropdown_stores.append({
                "store_id": s.get("store_id") or s.get("id"),
                "store_name": s.get("store_name") or s.get("name")
            })

        return {
            "products": dropdown_products,
            "stores": dropdown_stores
        }

    #  PRODUCT DETAILS MODE
    prod = get_product_by_id(product_id)
    if not prod:
        raise ValueError("Product not found")

    store = get_store_by_id(store_id)
    if not store:
        raise ValueError("Store not found")

    sales = sales_df[
        (sales_df["store_id"] == store_id) &
        (sales_df["product_id"] == product_id)
    ]

    if not sales.empty:
        sales = sales.sort_values("date")

        latest_sales = float(sales.iloc[-1]["units_sold"])
        latest_price = float(sales.iloc[-1]["price_lkr"])

        if len(sales) >= 7:
            recent_avg = sales.tail(3)["units_sold"].mean()
            older_avg = sales.head(3)["units_sold"].mean()

            if recent_avg > older_avg:
                trend = "UP"
            elif recent_avg < older_avg:
                trend = "DOWN"
            else:
                trend = "STABLE"
        else:
            trend = "STABLE"

    else:
        latest_sales = 0
        latest_price = float(prod.get("selling_price") or prod.get("price_lkr") or 0.0)
        trend = "STABLE"

    return {
        "product_id": product_id,
        "product_name": prod.get("product_name") or prod.get("name"),
        "brand": prod.get("brand"),
        "gender": prod.get("gender"),
        "subcategory": prod.get("subcategory"),
        "store_id": store_id,
        "store_name": store.get("store_name") or store.get("name"),
        "category": prod.get("category"),
        "current_stock": int(prod.get("current_stock") or 0),
        "price_lkr": latest_price,
        "recent_sales": latest_sales,
        "trend": trend
    }