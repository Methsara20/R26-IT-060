"""
backend/model_service.py
Loads the trained XGBoost redemption-probability model and provides a
rank_offers() function — exactly the same logic used in the Streamlit
Recommender tab, just exposed here for the FastAPI backend to call.
"""

import pickle
import json
import os
import numpy as np

MODEL_PATH = "app/ml/model.pkl"
META_PATH = "app/ml/columns.json"

_model = None
_meta = None


def load_model():
    global _model, _meta
    if _model is not None:
        return _model, _meta

    if not os.path.exists(MODEL_PATH) or not os.path.exists(META_PATH):
        raise FileNotFoundError(
            f"Model files not found. Expected {MODEL_PATH} and {META_PATH}. "
            "Run train_model.py first."
        )

    with open(MODEL_PATH, "rb") as f:
        _model = pickle.load(f)
    with open(META_PATH, "r") as f:
        _meta = json.load(f)

    return _model, _meta


def _encode_row(input_dict, meta):
    encoders = meta["encoders"]
    categorical_features = meta["categorical_features"]
    numeric_features = meta["numeric_features"]

    row = []
    for feat in categorical_features:
        val = str(input_dict[feat])
        classes = encoders[feat]
        if val not in classes:
            raise ValueError(f"'{val}' is not a recognized value for '{feat}'. Valid options: {classes}")
        row.append(classes.index(val))

    for feat in numeric_features:
        row.append(float(input_dict[feat]))

    return np.array([row])


def rank_offers(customer_profile: dict, discount_pct: float = 20.0):
    """
    customer_profile should contain: age_group, gender, loyalty_tier, channel,
    preferred_category, visit_frequency, total_spend_lkr, avg_basket_value_lkr,
    days_since_last_purchase, customer_past_redemption_rate.

    Returns a list of {offer_type, probability} sorted by probability descending,
    by scoring every possible offer_type for this customer and comparing.
    """
    model, meta = load_model()
    offer_types = meta["encoders"]["offer_type"]

    results = []
    for offer_type in offer_types:
        row_input = dict(customer_profile)
        row_input["offer_type"] = offer_type
        row_input["discount_pct"] = discount_pct

        X = _encode_row(row_input, meta)
        proba = model.predict_proba(X)[0][1]  # probability of redeemed=1
        results.append({"offer_type": offer_type, "probability": round(float(proba), 4)})

    results.sort(key=lambda r: r["probability"], reverse=True)
    return results


def get_model_info():
    _, meta = load_model()
    return {
        "model_type": meta.get("model_type", "unknown"),
        "accuracy": meta.get("accuracy"),
        "roc_auc": meta.get("roc_auc"),
        "baseline_redemption_rate": meta.get("baseline_redemption_rate"),
        "feature_importance": meta.get("feature_importance"),
        "training_rows": meta.get("training_rows"),
    }
