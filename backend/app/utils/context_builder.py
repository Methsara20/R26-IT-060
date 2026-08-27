from app.services.predictor import predict_demand
from app.services.decision_engine import make_decision


def build_context():
    payload = {
        "store_id": "S001",
        "product_id": "P006",
        "category": "Accessories",
        "price_lkr": 1800,
        "discount": 0.1,
        "temperature": 27,
        "rainfall": 18,
        "humidity": 88,
        "weather_condition": "Rainy",
        "month": 6,
        "day": 10,
        "day_of_week_num": 2,
        "lag_1": 20,
        "lag_7": 18,
        "rolling_mean_7": 19,
        "is_holiday": 0,
        "is_promotion": 0,
        "is_school": 0,
        "is_festival": 0
    }

    #  UPDATED (now returns 2 values)
    prediction, confidence = predict_demand(payload)

    decision = make_decision(
        store_id=payload["store_id"],
        product_id=payload["product_id"],
        predicted_demand=prediction
    )

    return payload, prediction, confidence, decision