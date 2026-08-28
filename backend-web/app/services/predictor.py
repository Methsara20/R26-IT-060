import pickle
import json
import pandas as pd

# Load model & columns
model = pickle.load(open("app/models/model.pkl", "rb"))
columns = json.load(open("app/models/columns.json", "r"))


#  NEW — Confidence Function
# def calculate_confidence(prediction, rolling_mean_7):
#     diff = abs(prediction - rolling_mean_7)
#
#     if diff < 2:
#         return "HIGH"
#     elif diff < 5:
#         return "MEDIUM"
#     else:
#         return "LOW"

def calculate_confidence(prediction, rolling_mean_7):
    diff = abs(prediction - rolling_mean_7)

    if rolling_mean_7 == 0:
        return 75

    diff_percentage = diff / rolling_mean_7

    confidence = 100 - (diff_percentage * 100)

    confidence = max(60, min(95, confidence))

    return int(round(confidence))

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
    raw_prediction = float(model.predict(df)[0])

    # Convert demand to whole number
    prediction = int(round(raw_prediction))

    # Confidence as percentage
    confidence = calculate_confidence(
        prediction,
        payload.get("rolling_mean_7", prediction)
    )

    return prediction, confidence