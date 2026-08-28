import json
import pickle
import pandas as pd

from pathlib import Path

from app.services.weather_service import (
    get_monthly_weather_profile
)


BASE_DIR = Path(__file__).resolve().parent.parent

MODEL_PATH = (
    BASE_DIR
    / "models"
    / "inventory_intelligence_model.pkl"
)

COLUMNS_PATH = (
    BASE_DIR
    / "models"
    / "inventory_intelligence_columns.json"
)


# --------------------------------------------------
# Load model
# --------------------------------------------------

with open(MODEL_PATH, "rb") as f:
    inventory_model = pickle.load(f)


with open(COLUMNS_PATH, "r") as f:
    inventory_columns = json.load(f)


# --------------------------------------------------
# Prepare model input
# --------------------------------------------------

def prepare_inventory_input(payload: dict):

    df = pd.DataFrame([payload])

    df = pd.get_dummies(df)

    for col in inventory_columns:

        if col not in df.columns:
            df[col] = 0

    df = df[inventory_columns]

    return df


# --------------------------------------------------
# Confidence
# --------------------------------------------------

def calculate_inventory_confidence(
    prediction,
    previous_3_month_avg
):

    if previous_3_month_avg == 0:
        return 75

    diff = abs(
        prediction
        - previous_3_month_avg
    )

    diff_percentage = (
        diff
        / previous_3_month_avg
    )

    confidence = (
        100
        - (diff_percentage * 100)
    )

    confidence = max(
        60,
        min(95, confidence)
    )

    return int(round(confidence))


# --------------------------------------------------
# Apply seasonal weather
# --------------------------------------------------

def apply_monthly_weather_profile(
    payload: dict
) -> tuple[dict, dict]:
    """
    Replace manually supplied monthly weather features
    with the historical seasonal weather profile for
    the requested store and month.

    Does NOT modify the original payload.
    """

    working_payload = payload.copy()

    store_id = working_payload["store_id"]
    month = int(working_payload["month"])

    weather_profile = (
        get_monthly_weather_profile(
            store_id=store_id,
            month=month
        )
    )

    working_payload["avg_temperature"] = (
        weather_profile["avg_temperature"]
    )

    working_payload["avg_humidity"] = (
        weather_profile["avg_humidity"]
    )

    working_payload["total_rainfall"] = (
        weather_profile["total_rainfall"]
    )

    working_payload["rainy_days"] = (
        weather_profile["rainy_days"]
    )

    working_payload["storm_days"] = (
        weather_profile["storm_days"]
    )

    working_payload["sunny_days"] = (
        weather_profile["sunny_days"]
    )

    return (
        working_payload,
        weather_profile
    )


# --------------------------------------------------
# Internal model prediction
# --------------------------------------------------

def _predict_monthly_from_payload(
    payload: dict
) -> dict:
    """
    Run the existing XGBoost model using an already
    prepared payload.

    Weather must already be present in the payload.
    """

    input_df = prepare_inventory_input(
        payload
    )

    raw_prediction = float(
        inventory_model.predict(
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
        calculate_inventory_confidence(
            predicted_demand,
            payload.get(
                "previous_3_month_avg",
                predicted_demand
            )
        )
    )

    return {
        "predicted_monthly_demand":
            predicted_demand,

        "confidence_percentage":
            confidence,

        "confidence":
            f"{confidence}%"
    }


# --------------------------------------------------
# Monthly forecast
# --------------------------------------------------

def predict_monthly_inventory_demand(
    payload: dict
):

    weather_payload, weather_profile = (
        apply_monthly_weather_profile(
            payload
        )
    )

    result = (
        _predict_monthly_from_payload(
            weather_payload
        )
    )

    return {
        **result,

        "weather_source":
            "Open-Meteo",

        "weather_mode":
            "HISTORICAL_SEASONAL_PROFILE",

        "weather_profile": {
            "month":
                weather_profile["month"],

            "month_name":
                weather_profile.get(
                    "month_name"
                ),

            "historical_years":
                weather_profile.get(
                    "historical_years",
                    []
                ),

            "years_used":
                weather_profile.get(
                    "years_used"
                ),

            "avg_temperature":
                weather_profile[
                    "avg_temperature"
                ],

            "avg_humidity":
                weather_profile[
                    "avg_humidity"
                ],

            "total_rainfall":
                weather_profile[
                    "total_rainfall"
                ],

            "rainy_days":
                weather_profile[
                    "rainy_days"
                ],

            "storm_days":
                weather_profile[
                    "storm_days"
                ],

            "sunny_days":
                weather_profile[
                    "sunny_days"
                ]
        }
    }


# --------------------------------------------------
# Quarterly forecast
# --------------------------------------------------

def predict_quarterly_inventory_demand(
    payload: dict
):

    monthly_forecasts = []

    working_payload = payload.copy()

    total_demand = 0

    for month_number in range(1, 4):

        # ------------------------------------------
        # Get correct seasonal weather for
        # THIS month
        # ------------------------------------------

        weather_payload, weather_profile = (
            apply_monthly_weather_profile(
                working_payload
            )
        )

        # ------------------------------------------
        # Run existing model
        # ------------------------------------------

        result = (
            _predict_monthly_from_payload(
                weather_payload
            )
        )

        predicted = (
            result[
                "predicted_monthly_demand"
            ]
        )

        total_demand += predicted

        monthly_forecasts.append({

            "month_number":
                month_number,

            "year":
                working_payload["year"],

            "month":
                working_payload["month"],

            "month_name":
                weather_profile.get(
                    "month_name"
                ),

            "predicted_demand":
                predicted,

            "confidence_percentage":
                result[
                    "confidence_percentage"
                ],

            "confidence":
                result["confidence"],

            "weather": {

                "avg_temperature":
                    weather_profile[
                        "avg_temperature"
                    ],

                "avg_humidity":
                    weather_profile[
                        "avg_humidity"
                    ],

                "total_rainfall":
                    weather_profile[
                        "total_rainfall"
                    ],

                "rainy_days":
                    weather_profile[
                        "rainy_days"
                    ],

                "storm_days":
                    weather_profile[
                        "storm_days"
                    ],

                "sunny_days":
                    weather_profile[
                        "sunny_days"
                    ]
            }
        })

        # ------------------------------------------
        # Preserve old values BEFORE changing them
        # ------------------------------------------

        old_previous_month = (
            working_payload[
                "previous_month_sales"
            ]
        )

        old_previous_2_avg = (
            working_payload[
                "previous_2_month_avg"
            ]
        )

        old_previous_3_avg = (
            working_payload[
                "previous_3_month_avg"
            ]
        )

        # ------------------------------------------
        # Update rolling sales history
        # ------------------------------------------

        working_payload[
            "previous_month_sales"
        ] = predicted

        working_payload[
            "previous_2_month_avg"
        ] = (
            predicted
            + old_previous_month
        ) / 2

        working_payload[
            "previous_3_month_avg"
        ] = (
            predicted
            + old_previous_month
            + old_previous_2_avg
        ) / 3

        working_payload[
            "previous_6_month_avg"
        ] = (
            predicted
            + (
                working_payload[
                    "previous_6_month_avg"
                ] * 5
            )
        ) / 6

        working_payload[
            "monthly_units_sold"
        ] = predicted

        # ------------------------------------------
        # Move to next month
        # ------------------------------------------

        working_payload["month"] += 1

        if working_payload["month"] > 12:

            working_payload["month"] = 1

            working_payload["year"] += 1

        working_payload["quarter"] = (
            (
                working_payload["month"]
                - 1
            )
            // 3
        ) + 1


    # --------------------------------------------------
    # Overall confidence
    # --------------------------------------------------

    avg_confidence = int(
        round(
            sum(
                item[
                    "confidence_percentage"
                ]
                for item
                in monthly_forecasts
            )
            / len(monthly_forecasts)
        )
    )


    return {

        "forecast_months":
            3,

        "predicted_quarterly_demand":
            total_demand,

        "average_confidence_percentage":
            avg_confidence,

        "confidence":
            f"{avg_confidence}%",

        "weather_source":
            "Open-Meteo",

        "weather_mode":
            "HISTORICAL_SEASONAL_PROFILE",

        "monthly_forecasts":
            monthly_forecasts
    }