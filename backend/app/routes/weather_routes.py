from fastapi import APIRouter, HTTPException, Query

from app.services.weather_service import (
    get_forecast_weather,
    get_weather_for_date,
    get_monthly_weather_profile
)




router = APIRouter(
    prefix="/weather",
    tags=["Weather"]
)


@router.get("/store/{store_id}/forecast")
def store_weather_forecast(
    store_id: str,
    days: int = Query(
        default=7,
        ge=1,
        le=14
    )
):
    """
    Return short-range weather forecast
    for one store.
    """

    try:
        return get_forecast_weather(
            store_id=store_id,
            days=days
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc)
        )

    except RuntimeError as exc:
        raise HTTPException(
            status_code=502,
            detail=str(exc)
        )

    except Exception as exc:
        print(
            f"Weather forecast error: {exc}"
        )

        raise HTTPException(
            status_code=500,
            detail="Unable to load weather forecast."
        )


@router.get("/store/{store_id}/date/{target_date}")
def store_weather_by_date(
    store_id: str,
    target_date: str
):
    """
    Return weather for one specific date.

    Date format:
    YYYY-MM-DD
    """

    try:
        weather = get_weather_for_date(
            store_id=store_id,
            target_date=target_date
        )

        return {
            "store_id": store_id,
            "date": target_date,
            "weather": weather
        }

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc)
        )

    except RuntimeError as exc:
        raise HTTPException(
            status_code=502,
            detail=str(exc)
        )

    except Exception as exc:
        print(
            f"Weather date error: {exc}"
        )

        raise HTTPException(
            status_code=500,
            detail="Unable to load weather data."
        )

@router.get(
    "/store/{store_id}/monthly-profile/{month}"
)
def store_monthly_weather_profile(
    store_id: str,
    month: int
):
    """
    Return the historical seasonal weather profile
    for one store/month.

    Example:
    CP006 + month 9
    = typical September weather.
    """

    try:

        if month < 1 or month > 12:
            raise ValueError(
                "Month must be between 1 and 12."
            )

        return get_monthly_weather_profile(
            store_id=store_id,
            month=month
        )

    except ValueError as exc:

        raise HTTPException(
            status_code=400,
            detail=str(exc)
        )

    except RuntimeError as exc:

        raise HTTPException(
            status_code=502,
            detail=str(exc)
        )

    except Exception as exc:

        print(
            "Monthly weather profile "
            f"error: {exc}"
        )

        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to generate monthly "
                "weather profile."
            )
        )