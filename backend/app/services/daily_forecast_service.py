import json
import pickle

from datetime import timedelta, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import pandas as pd

from app.services.weather_service import (
    get_forecast_weather,
    get_weather_for_date
)

# ==========================================================
# CONFIGURATION
# ==========================================================
BASE_DIR = Path(__file__).resolve().parent.parent

MODEL_PATH = (BASE_DIR/ "models"/ "daily_forecast_model.pkl")

COLUMNS_PATH = (BASE_DIR/ "models"/ "daily_columns.json")

SRI_LANKA_TIMEZONE = ZoneInfo("Asia/Colombo")


# ==========================================================
# LOAD MODEL
# ==========================================================

with open(MODEL_PATH, "rb") as f:
    model = pickle.load(f)

with open(COLUMNS_PATH, "r") as f:
    columns = json.load(f)


# ==========================================================
# CONFIDENCE
# ==========================================================

def calculate_confidence(
    prediction,
    rolling_mean_7
):
    """
    Calculate forecast confidence using the existing
    project logic.

    This logic is intentionally unchanged.
    """

    if rolling_mean_7 == 0:
        return 75

    diff = abs(
        prediction - rolling_mean_7
    )

    diff_percentage = (
        diff / rolling_mean_7
    )

    confidence = (
        100
        - (diff_percentage * 100)
    )

    confidence = max(
        60,
        min(
            95,
            confidence
        )
    )

    return int(
        round(confidence)
    )


# ==========================================================
# MODEL INPUT
# ==========================================================

def prepare_input(
    payload: dict
):
    """
    Prepare the existing XGBoost feature payload.

    Existing model-column alignment logic is preserved.
    """

    df = pd.DataFrame(
        [payload]
    )

    df = pd.get_dummies(
        df
    )

    for col in columns:

        if col not in df.columns:
            df[col] = 0

    df = df[columns]

    return df


# ==========================================================
# PURE MODEL PREDICTION
# ==========================================================

def _predict_from_payload(
    payload: dict
) -> dict:
    """
    Run the XGBoost model using an already prepared
    business/weather payload.

    IMPORTANT:
    This function does NOT call the weather API.

    It preserves the original prediction logic.
    """

    input_df = prepare_input(
        payload
    )

    raw_prediction = float(
        model.predict(
            input_df
        )[0]
    )

    predicted_demand = int(
        round(raw_prediction)
    )

    predicted_demand = max(
        0,
        predicted_demand
    )

    confidence = (
        calculate_confidence(
            predicted_demand,
            payload.get(
                "rolling_mean_7",
                predicted_demand
            )
        )
    )

    return {
        "predicted_demand":
            predicted_demand,

        "confidence_percentage":
            confidence,

        "confidence":
            f"{confidence}%"
    }


# ==========================================================
# WEATHER + DATE INJECTION
# ==========================================================

def _apply_weather_and_date(
    payload: dict,
    weather: dict
) -> dict:
    """
    Create a copy of the payload and override only
    the date/weather fields required by the trained
    daily model.

    Existing business, lag, promotion and event
    features remain unchanged.
    """

    updated_payload = (
        payload.copy()
    )

    forecast_date_string = (
        weather.get("date")
    )

    if not forecast_date_string:
        raise ValueError(
            "Weather data does not contain "
            "a forecast date."
        )

    forecast_date = (
        pd.Timestamp(
            forecast_date_string
        )
    )

    # ------------------------------------------------------
    # WEATHER
    # ------------------------------------------------------

    temperature = weather.get(
        "temperature"
    )

    humidity = weather.get(
        "humidity"
    )

    rainfall = weather.get(
        "rainfall"
    )

    if temperature is None:
        raise ValueError(
            "Temperature is unavailable "
            "for the forecast date."
        )

    if humidity is None:
        raise ValueError(
            "Humidity is unavailable "
            "for the forecast date."
        )

    updated_payload["temperature"] = float(temperature)

    updated_payload["humidity"] = float(humidity)

    updated_payload["rainfall"] = float(rainfall or 0)

    updated_payload["weather_condition"] = weather.get("weather_condition","Unknown")

    # ------------------------------------------------------
    # FORECAST DATE
    # ------------------------------------------------------

    updated_payload["month"] = int(forecast_date.month)

    updated_payload["day"] = int(forecast_date.day)

    updated_payload["day_of_week_num"] = int(forecast_date.dayofweek)

    updated_payload["is_weekend"
    ] = (
        1
        if forecast_date.dayofweek
        in [5, 6]
        else 0
    )

    return updated_payload


# ==========================================================
# NEXT-DAY FORECAST
# ==========================================================

def predict_next_day(
    payload: dict
):
    """
    Predict demand for TOMORROW.

    Flow:

    store_id
        ↓
    tomorrow's real forecast weather
        ↓
    inject weather + date
        ↓
    existing XGBoost model
    """

    store_id = payload.get(
        "store_id"
    )

    if not store_id:
        raise ValueError(
            "store_id is required "
            "for weather-aware forecasting."
        )

    # Sri Lanka local date.
    today = pd.Timestamp.now(
        tz=SRI_LANKA_TIMEZONE
    ).date()

    target_date = (
        today
        + timedelta(days=1)
    )

    target_date_string = (
        target_date.isoformat()
    )

    # Fetch tomorrow's weather.
    weather = get_weather_for_date(
        store_id=store_id,
        target_date=target_date_string
    )

    forecast_payload = (
        _apply_weather_and_date(
            payload=payload,
            weather=weather
        )
    )

    prediction_result = (
        _predict_from_payload(
            forecast_payload
        )
    )

    return {
        "forecast_date":
            target_date_string,

        "weather": {
            "temperature":
                weather.get(
                    "temperature"
                ),

            "humidity":
                weather.get(
                    "humidity"
                ),

            "rainfall":
                weather.get(
                    "rainfall"
                ),

            "weather_condition":
                weather.get(
                    "weather_condition"
                )
        },

        **prediction_result
    }


# ==========================================================
# 7-DAY FORECAST
# ==========================================================

def generate_7_day_forecast(
    payload: dict
):
    """
    Generate a seven-day demand forecast.

    Forecast period:
    Tomorrow → next seven days.

    Only ONE weather API request is used.

    Existing lag and confidence logic is preserved.
    """

    store_id = payload.get(
        "store_id"
    )

    if not store_id:
        raise ValueError(
            "store_id is required "
            "for weather-aware forecasting."
        )

    # ------------------------------------------------------
    # GET 8 WEATHER DAYS
    # ------------------------------------------------------
    #
    # Open-Meteo starts from today.
    #
    # We need:
    # tomorrow + next 6 days
    #
    # Therefore request 8 days:
    #
    # index 0 = today
    # index 1 = tomorrow
    # ...
    # index 7 = day 7
    # ------------------------------------------------------

    weather_result = (
        get_forecast_weather(
            store_id=store_id,
            days=8
        )
    )

    all_weather = (
        weather_result.get(
            "weather",
            []
        )
    )

    if len(all_weather) < 8:
        raise ValueError(
            "Seven-day weather forecast "
            "is currently unavailable."
        )

    # Exclude today's weather.
    forecast_weather = (
        all_weather[1:8]
    )

    forecast = []

    base_payload = (
        payload.copy()
    )

    # ------------------------------------------------------
    # EXISTING LAG LOGIC
    # ------------------------------------------------------

    lag_1 = base_payload.get(
        "lag_1",
        0
    )

    lag_7 = base_payload.get(
        "lag_7",
        0
    )

    rolling_mean_7 = (
        base_payload.get(
            "rolling_mean_7",
            0
        )
    )

    # ------------------------------------------------------
    # GENERATE EACH DAY
    # ------------------------------------------------------

    for day_number, weather in enumerate(
        forecast_weather,
        start=1
    ):

        # Inject this specific day's
        # weather and calendar values.
        day_payload = (
            _apply_weather_and_date(
                payload=base_payload,
                weather=weather
            )
        )

        prediction_result = (
            _predict_from_payload(
                day_payload
            )
        )

        predicted_demand = (
            prediction_result[
                "predicted_demand"
            ]
        )
        forecast.append({
            "day":
                day_number,
            "date":
                weather.get(
                    "date"
                ),
            "predicted_demand":
                predicted_demand,

            "confidence_percentage":
                prediction_result[
                    "confidence_percentage"
                ],
            "confidence":
                prediction_result[
                    "confidence"
                ],
            "weather": {
                "temperature":
                    weather.get(
                        "temperature"
                    ),
                "humidity":
                    weather.get(
                        "humidity"
                    ),
                "rainfall":
                    weather.get(
                        "rainfall"
                    ),
                "weather_condition":
                    weather.get(
                        "weather_condition"
                    )
            }
        })

        # --------------------------------------------------
        # EXISTING ROLLING FORECAST LOGIC
        # --------------------------------------------------
        #
        # We intentionally preserve this exactly as
        # your existing implementation behaves.
        # --------------------------------------------------

        lag_7 = lag_1

        lag_1 = (
            predicted_demand
        )

        rolling_mean_7 = (
            (
                (
                    rolling_mean_7 * 6
                )
                + predicted_demand
            )
            / 7
            if rolling_mean_7
            else predicted_demand
        )

        base_payload[
            "lag_1"
        ] = lag_1

        base_payload[
            "lag_7"
        ] = lag_7

        base_payload[
            "rolling_mean_7"
        ] = rolling_mean_7

    # ------------------------------------------------------
    # TOTALS
    # ------------------------------------------------------

    total_forecast = sum(
        item[
            "predicted_demand"
        ]
        for item in forecast
    )

    avg_confidence = int(
        round(
            sum(
                item[
                    "confidence_percentage"
                ]
                for item in forecast
            )
            / len(forecast)
        )
    )

    return {
        "forecast_days": 7,
        "start_date":forecast[0]["date"],
        "end_date":forecast[-1]["date"],
        "weather_source":"Open-Meteo",
        "weather_mode":"SHORT_RANGE_FORECAST",
        "total_predicted_demand": total_forecast,
        "average_confidence_percentage":avg_confidence,
        "confidence":f"{avg_confidence}%",
        "forecast":forecast
    }

def generate_custom_forecast(
    payload: dict,
    start_date,
    end_date
):
    """
    Generate a custom demand forecast from 1 to 14 days.

    Uses:
    - Date-specific Open-Meteo weather
    - Existing XGBoost model
    - Existing confidence logic
    - Existing recursive lag logic
    """

    store_id = payload.get("store_id")

    if not store_id:
        raise ValueError(
            "store_id is required."
        )

    if isinstance(start_date, str):
        start_date = datetime.strptime(
            start_date,
            "%Y-%m-%d"
        ).date()

    if isinstance(end_date, str):
        end_date = datetime.strptime(
            end_date,
            "%Y-%m-%d"
        ).date()

    if end_date < start_date:
        raise ValueError(
            "end_date cannot be before start_date."
        )

    forecast_days = (
        end_date - start_date
    ).days + 1

    if forecast_days < 1 or forecast_days > 14:
        raise ValueError(
            "Custom forecast range must be between "
            "1 and 14 days."
        )

    today = datetime.now().date()

    if start_date <= today:
        raise ValueError(
            "Custom forecast must start from tomorrow "
            "or a future date."
        )

    days_from_today_to_end = (
        end_date - today
    ).days

    if days_from_today_to_end > 14:
        raise ValueError(
            "The selected end date is outside the "
            "supported 14-day weather forecast window."
        )

    # --------------------------------------------------
    # ONE WEATHER REQUEST
    # --------------------------------------------------

    weather_result = get_forecast_weather(
        store_id=store_id,
        days=days_from_today_to_end + 1
    )

    weather_items = (
        weather_result.get("weather", [])
    )

    weather_by_date = {
        item["date"]: item
        for item in weather_items
    }

    # --------------------------------------------------
    # EXISTING PAYLOAD + LAG VALUES
    # --------------------------------------------------

    base_payload = payload.copy()

    lag_1 = base_payload.get(
        "lag_1",
        0
    )

    lag_7 = base_payload.get(
        "lag_7",
        0
    )

    rolling_mean_7 = base_payload.get(
        "rolling_mean_7",
        0
    )

    forecast = []

    current_date = start_date

    day_number = 1

    while current_date <= end_date:

        date_string = (
            current_date.isoformat()
        )

        weather = weather_by_date.get(
            date_string
        )

        if weather is None:
            raise ValueError(
                f"Weather data is unavailable for "
                f"{date_string}."
            )

        day_payload = (
            _apply_weather_and_date(
                payload=base_payload,
                weather=weather
            )
        )

        prediction_result = (
            _predict_from_payload(
                day_payload
            )
        )

        predicted_demand = (
            prediction_result[
                "predicted_demand"
            ]
        )

        forecast.append({
            "day": day_number,

            "date": date_string,

            "predicted_demand":
                predicted_demand,

            "confidence_percentage":
                prediction_result[
                    "confidence_percentage"
                ],

            "confidence":
                prediction_result[
                    "confidence"
                ],

            "weather": {
                "temperature":
                    weather.get(
                        "temperature"
                    ),

                "humidity":
                    weather.get(
                        "humidity"
                    ),

                "rainfall":
                    weather.get(
                        "rainfall"
                    ),

                "weather_condition":
                    weather.get(
                        "weather_condition"
                    )
            }
        })

        # Preserve current recursive forecasting logic

        lag_7 = lag_1

        lag_1 = predicted_demand

        rolling_mean_7 = (
            (
                (
                    rolling_mean_7 * 6
                )
                + predicted_demand
            )
            / 7
            if rolling_mean_7
            else predicted_demand
        )

        base_payload["lag_1"] = (
            lag_1
        )

        base_payload["lag_7"] = (
            lag_7
        )

        base_payload[
            "rolling_mean_7"
        ] = rolling_mean_7

        current_date += timedelta(
            days=1
        )

        day_number += 1

    total_forecast = sum(
        item["predicted_demand"]
        for item in forecast
    )

    avg_confidence = int(
        round(
            sum(
                item[
                    "confidence_percentage"
                ]
                for item in forecast
            )
            / len(forecast)
        )
    )

    return {
        "forecast_days":
            len(forecast),

        "start_date":
            start_date.isoformat(),

        "end_date":
            end_date.isoformat(),

        "weather_source":
            "Open-Meteo",

        "weather_mode":
            "SHORT_RANGE_FORECAST",

        "total_predicted_demand":
            total_forecast,

        "average_confidence_percentage":
            avg_confidence,

        "confidence":
            f"{avg_confidence}%",

        "forecast":
            forecast
    }