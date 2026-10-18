import os
import joblib
import pandas as pd

MODEL_PATH = os.path.join("app", "ml_model", "body_measurement_model.pkl")

model = joblib.load(MODEL_PATH)


def predict_body_measurements(height: float, weight: float, gender: str):
    # Convert string gender to numerical feature (1.0 for male, 2.0 for female) to prevent ML crashes
    gender_val = 1.0 if gender.lower() == "male" else 2.0
    
    # Feature Engineering: Calculate BMI to feed into the advanced model
    bmi = ((weight / 0.453592) * 703) / (height ** 2)
    
    input_data = pd.DataFrame([{
        "gender": gender_val,
        "height": height,
        "weight": weight,
        "bmi": bmi
    }])

    prediction = model.predict(input_data)[0]

    return {
        "predicted_shoulder_width": round(float(prediction[0]), 2),
        "predicted_waist": round(float(prediction[1]), 2),
        "predicted_leg_length": round(float(prediction[2]), 2),
    }