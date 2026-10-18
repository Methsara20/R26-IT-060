from fastapi import APIRouter, HTTPException

from app.schemas.forecast_schema import DailyForecastRequest
from app.schemas.forecast_schema import CustomForecastRequest
from app.services.daily_forecast_service import (
    predict_next_day,
    generate_7_day_forecast,
    generate_custom_forecast
)
from app.schemas.forecast_schema import InventoryForecastRequest

from app.schemas.forecast_schema import (
    AutoMonthlyForecastRequest,
    AutoQuarterlyForecastRequest
)

from app.services.inventory_forecast_service import (
    predict_monthly_inventory_demand,
    predict_quarterly_inventory_demand
)

from app.services.inventory_forecast_feature_service import (
    build_auto_monthly_payload
)

from app.services.weather_service import (
    get_monthly_weather_profile
)

router = APIRouter(
    prefix="/forecast",
    tags=["Forecast"]
)


@router.post("/daily")
def daily_forecast(data: DailyForecastRequest):
    payload = data.dict()

    result = predict_next_day(payload)

    return {
        "forecast_type": "daily",
        "store_id": data.store_id,
        "product_id": data.product_id,
        **result
    }


@router.post("/7-day")
def seven_day_forecast(data: DailyForecastRequest):
    payload = data.dict()

    result = generate_7_day_forecast(payload)

    return {
        "forecast_type": "7-day",
        "store_id": data.store_id,
        "product_id": data.product_id,
        **result
    }

@router.post("/inventory/monthly")
def monthly_inventory_forecast(data: InventoryForecastRequest):
    payload = data.dict()

    result = predict_monthly_inventory_demand(payload)

    return {
        "forecast_type": "inventory_monthly",
        "store_id": data.store_id,
        "category": data.category,
        "brand": data.brand,
        "gender": data.gender,
        **result
    }


@router.post("/inventory/quarterly")
def quarterly_inventory_forecast(data: InventoryForecastRequest):
    payload = data.dict()

    result = predict_quarterly_inventory_demand(payload)

    return {
        "forecast_type": "inventory_quarterly",
        "store_id": data.store_id,
        "category": data.category,
        "brand": data.brand,
        "gender": data.gender,
        **result
    }

@router.post("/custom")
def custom_forecast(
    data: CustomForecastRequest
):
    payload = data.model_dump(
        exclude={
            "start_date",
            "end_date"
        }
    )

    result = generate_custom_forecast(
        payload=payload,
        start_date=data.start_date,
        end_date=data.end_date
    )

    return {
        "forecast_type":
            "custom",

        "store_id":
            data.store_id,

        "product_id":
            data.product_id,

        **result
    }

@router.post(
    "/inventory/monthly/auto"
)
def automatic_monthly_inventory_forecast(
    data: AutoMonthlyForecastRequest
):
    """
    Manager-facing monthly forecast.

    The manager supplies only business selection
    fields. All internal ML features are prepared
    by the backend.
    """

    try:

        weather_profile = (
            get_monthly_weather_profile(
                store_id=data.store_id,
                month=data.month
            )
        )

        payload = (
            build_auto_monthly_payload(
                store_id=data.store_id,
                category=data.category,
                brand=data.brand,
                gender=data.gender,
                year=data.year,
                month=data.month,
                weather_profile=weather_profile
            )
        )

        result = (
            predict_monthly_inventory_demand(
                payload
            )
        )

        return {
            "forecast_type":
                "inventory_monthly_auto",

            "forecast_mode":
                "SYSTEM_PREPARED",

            "store_id":
                data.store_id,

            "category":
                data.category,

            "brand":
                data.brand,

            "gender":
                data.gender,

            "year":
                data.year,

            "month":
                data.month,

            **result
        }

    except ValueError as exc:

        raise HTTPException(
            status_code=400,
            detail=str(exc)
        )

    except Exception as exc:

        print(
            "Automatic monthly "
            f"forecast error: {exc}"
        )

        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to generate "
                "automatic monthly forecast."
            )
        )

def _quarter_months(
    year: int,
    quarter: int
) -> list[tuple[int, int]]:

    first_month = (
        (quarter - 1)
        * 3
        + 1
    )

    return [
        (
            year,
            first_month
        ),
        (
            year,
            first_month + 1
        ),
        (
            year,
            first_month + 2
        ),
    ]

@router.post(
    "/inventory/quarterly/auto"
)
def automatic_quarterly_inventory_forecast(
    data: AutoQuarterlyForecastRequest
):
    """
    Generate three independently prepared monthly
    forecasts and combine them into one quarterly
    forecast.

    Every month receives its own:
    - historical seasonal profile
    - seasonal weather profile
    - current inventory context
    """

    try:

        monthly_forecasts = []

        total_demand = 0

        confidence_values = []

        months = _quarter_months(
            year=data.year,
            quarter=data.quarter
        )

        for (
            forecast_year,
            forecast_month
        ) in months:

            weather_profile = (
                get_monthly_weather_profile(
                    store_id=(
                        data.store_id
                    ),
                    month=(
                        forecast_month
                    )
                )
            )

            payload = (
                build_auto_monthly_payload(
                    store_id=(
                        data.store_id
                    ),
                    category=(
                        data.category
                    ),
                    brand=data.brand,
                    gender=data.gender,
                    year=forecast_year,
                    month=forecast_month,
                    weather_profile=(
                        weather_profile
                    )
                )
            )

            result = (
                predict_monthly_inventory_demand(
                    payload
                )
            )

            predicted = int(
                result[
                    "predicted_monthly_demand"
                ]
            )

            confidence = int(
                result[
                    "confidence_percentage"
                ]
            )

            total_demand += predicted

            confidence_values.append(
                confidence
            )

            monthly_forecasts.append({
                "year":
                    forecast_year,

                "month":
                    forecast_month,

                "predicted_demand":
                    predicted,

                "confidence_percentage":
                    confidence,

                "confidence":
                    result["confidence"],

                "weather": {
                    "avg_temperature":
                        weather_profile.get(
                            "avg_temperature"
                        ),

                    "avg_humidity":
                        weather_profile.get(
                            "avg_humidity"
                        ),

                    "total_rainfall":
                        weather_profile.get(
                            "total_rainfall"
                        ),

                    "rainy_days":
                        weather_profile.get(
                            "rainy_days"
                        ),

                    "storm_days":
                        weather_profile.get(
                            "storm_days"
                        ),

                    "sunny_days":
                        weather_profile.get(
                            "sunny_days"
                        )
                }
            })

        average_confidence = int(
            round(
                sum(
                    confidence_values
                )
                / len(
                    confidence_values
                )
            )
        )

        return {
            "forecast_type":
                "inventory_quarterly_auto",

            "forecast_mode":
                "SYSTEM_PREPARED",

            "store_id":
                data.store_id,

            "category":
                data.category,

            "brand":
                data.brand,

            "gender":
                data.gender,

            "year":
                data.year,

            "quarter":
                data.quarter,

            "forecast_months": 3,

            "predicted_quarterly_demand":
                total_demand,

            "average_confidence_percentage":
                average_confidence,

            "confidence":
                f"{average_confidence}%",

            "weather_source":
                "Open-Meteo",

            "weather_mode":
                "HISTORICAL_SEASONAL_PROFILE",

            "monthly_forecasts":
                monthly_forecasts
        }

    except ValueError as exc:

        raise HTTPException(
            status_code=400,
            detail=str(exc)
        )

    except Exception as exc:

        print(
            "Automatic quarterly "
            f"forecast error: {exc}"
        )

        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to generate "
                "automatic quarterly forecast."
            )
        )