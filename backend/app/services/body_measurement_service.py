import os
import joblib
import pandas as pd

MODEL_PATH = os.path.join("app", "ml_model", "body_measurement_model.pkl")

model = joblib.load(MODEL_PATH)


def predict_body_measurements(height: float, gender: str):
    input_data = pd.DataFrame([{
        "height": height,
        "gender": gender.lower()
    }])

    prediction = model.predict(input_data)[0]

    return {
        "predicted_shoulder_width": round(float(prediction[0]), 2),
        "predicted_waist": round(float(prediction[1]), 2),
        "predicted_leg_length": round(float(prediction[2]), 2),
    }