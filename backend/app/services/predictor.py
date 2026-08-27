import pickle
import json
import pandas as pd

# Load model & columns
model = pickle.load(open("app/models/model.pkl", "rb"))
columns = json.load(open("app/models/columns.json", "r"))


#  NEW — Confidence Function
def calculate_confidence(prediction, rolling_mean_7):
    diff = abs(prediction - rolling_mean_7)

    if diff < 2:
        return "HIGH"
    elif diff < 5:
        return "MEDIUM"
    else:
        return "LOW"


#  MAIN FUNCTION
def predict_demand(payload: dict):
    df = pd.DataFrame([payload])

    # One-hot encoding (same as training)
    df = pd.get_dummies(df)

    # Ensure all columns exist
    for col in columns:
        if col not in df.columns:
            df[col] = 0

    df = df[columns]

    # Prediction
    prediction = float(model.predict(df)[0])

    #  Confidence
    confidence = calculate_confidence(
        prediction,
        payload.get("rolling_mean_7", prediction)  # safe fallback
    )

    return prediction, confidence