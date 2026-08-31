from datetime import datetime, timedelta
from typing import Optional
from statistics import mean
import calendar

import requests

from app.services.store_service import (
    get_store_by_id
)


# ==========================================================
# API CONFIGURATION
# ==========================================================

OPEN_METEO_URL = (
    "https://api.open-meteo.com/v1/forecast"
)

OPEN_METEO_HISTORICAL_URL = (
    "https://archive-api.open-meteo.com/v1/archive"
)

MAX_FORECAST_DAYS = 14

REQUEST_TIMEOUT = 15


# ==========================================================
# SHORT-RANGE WEATHER CACHE
# ==========================================================

_weather_cache = {}

CACHE_MINUTES = 30


# ==========================================================
# HISTORICAL WEATHER CONFIGURATION
# ==========================================================

DEFAULT_HISTORICAL_YEARS = [
    2021,
    2022,
    2023,
    2024,
    2025
]

# A day is considered rainy if rainfall
# is greater than this threshold.
RAINY_DAY_THRESHOLD_MM = 0.1

_historical_weather_cache = {}

HISTORICAL_CACHE_HOURS = 24


# ==========================================================
# WEATHER CONDITION HELPERS
# ==========================================================

def _weather_condition_from_code(
    code: Optional[int]
) -> str:
    """
    Convert WMO weather code into a simple
    weather condition.
    """

    if code is None:
        return "Unknown"

    try:
        code = int(code)

    except (TypeError, ValueError):
        return "Unknown"

    if code == 0:
        return "Clear"

    if code in [1, 2, 3]:
        return "Cloudy"

    if code in [45, 48]:
        return "Fog"

    if code in [
        51,
        53,
        55,
        56,
        57
    ]:
        return "Drizzle"

    if code in [
        61,
        63,
        65,
        66,
        67,
        80,
        81,
        82
    ]:
        return "Rain"

    if code in [
        71,
        73,
        75,
        77,
        85,
        86
    ]:
        return "Snow"

    if code in [
        95,
        96,
        99
    ]:
        return "Storm"

    return "Unknown"


def _is_sunny_weather_code(
    code
) -> bool:
    """
    Determine whether a day can be classified
    as sunny / mostly clear.
    """

    if code is None:
        return False

    try:
        code = int(code)

    except (TypeError, ValueError):
        return False

    return code in [
        0,
        1
    ]


def _is_storm_weather_code(
    code
) -> bool:
    """
    WMO thunderstorm codes.
    """

    if code is None:
        return False

    try:
        code = int(code)

    except (TypeError, ValueError):
        return False

    return code in [
        95,
        96,
        99
    ]


# ==========================================================
# STORE COORDINATES
# ==========================================================

def _get_store_coordinates(
    store_id: str
) -> tuple[float, float]:
    """
    Read latitude and longitude from Firestore.
    """

    store = get_store_by_id(
        store_id
    )

    if not store:
        raise ValueError(
            f"Store '{store_id}' was not found."
        )

    latitude = store.get(
        "latitude"
    )

    longitude = store.get(
        "longitude"
    )

    if (
        latitude is None
        or longitude is None
    ):
        raise ValueError(
            f"Coordinates are not configured "
            f"for store '{store_id}'."
        )

    return (
        float(latitude),
        float(longitude)
    )


# ==========================================================
# SHORT-RANGE WEATHER CACHE
# ==========================================================

def _get_cached_weather(
    store_id: str,
    days: int
):
    cache_key = (
        f"{store_id}:{days}"
    )

    cached = _weather_cache.get(
        cache_key
    )

    if not cached:
        return None

    if (
        datetime.now()
        >= cached["expires_at"]
    ):
        del _weather_cache[
            cache_key
        ]

        return None

    return cached["data"]


def _save_weather_cache(
    store_id: str,
    days: int,
    data: dict
):
    cache_key = (
        f"{store_id}:{days}"
    )

    _weather_cache[
        cache_key
    ] = {
        "expires_at": (
            datetime.now()
            + timedelta(
                minutes=CACHE_MINUTES
            )
        ),
        "data": data
    }


# ==========================================================
# SHORT-RANGE WEATHER
# ==========================================================

def get_forecast_weather(
    store_id: str,
    days: int = 7,
    force_refresh: bool = False
) -> dict:
    """
    Get short-range forecast weather.

    Used by:
    - Daily Forecast
    - 7-Day Forecast
    - Custom Forecast <= 14 days
    """

    if (
        days < 1
        or days > MAX_FORECAST_DAYS
    ):
        raise ValueError(
            f"Forecast days must be between "
            f"1 and {MAX_FORECAST_DAYS}."
        )

    if not force_refresh:

        cached = (
            _get_cached_weather(
                store_id,
                days
            )
        )

        if cached:
            return cached

    latitude, longitude = (
        _get_store_coordinates(
            store_id
        )
    )

    params = {
        "latitude":
            latitude,

        "longitude":
            longitude,

        "daily": ",".join([
            "temperature_2m_mean",
            "precipitation_sum",
            "rain_sum",
            "weather_code"
        ]),

        "hourly":
            "relative_humidity_2m",

        "timezone":
            "Asia/Colombo",

        "forecast_days":
            days
    }

    try:

        response = requests.get(
            OPEN_METEO_URL,
            params=params,
            timeout=REQUEST_TIMEOUT
        )

        response.raise_for_status()

        api_data = (
            response.json()
        )

    except requests.RequestException as exc:

        raise RuntimeError(
            "Unable to retrieve weather "
            f"data: {exc}"
        ) from exc

    daily = api_data.get(
        "daily",
        {}
    )

    hourly = api_data.get(
        "hourly",
        {}
    )

    dates = daily.get(
        "time",
        []
    )

    temperatures = daily.get(
        "temperature_2m_mean",
        []
    )

    precipitation = daily.get(
        "precipitation_sum",
        []
    )

    rain = daily.get(
        "rain_sum",
        []
    )

    weather_codes = daily.get(
        "weather_code",
        []
    )

    hourly_times = hourly.get(
        "time",
        []
    )

    hourly_humidity = hourly.get(
        "relative_humidity_2m",
        []
    )

    # ------------------------------------------------------
    # DAILY AVERAGE HUMIDITY
    # ------------------------------------------------------

    humidity_by_date = {}

    for (
        time_value,
        humidity_value
    ) in zip(
        hourly_times,
        hourly_humidity
    ):

        date_value = (
            time_value[:10]
        )

        if humidity_value is None:
            continue

        humidity_by_date.setdefault(
            date_value,
            []
        ).append(
            float(humidity_value)
        )

    forecast = []

    for (
        index,
        date_value
    ) in enumerate(dates):

        humidity_values = (
            humidity_by_date.get(
                date_value,
                []
            )
        )

        average_humidity = (
            round(
                sum(humidity_values)
                / len(humidity_values),
                2
            )
            if humidity_values
            else None
        )

        temperature = (
            temperatures[index]
            if index
            < len(temperatures)
            else None
        )

        precipitation_value = (
            precipitation[index]
            if index
            < len(precipitation)
            else None
        )

        rain_value = (
            rain[index]
            if index
            < len(rain)
            else None
        )

        weather_code = (
            weather_codes[index]
            if index
            < len(weather_codes)
            else None
        )

        forecast.append({
            "date":
                date_value,

            "temperature":
                (
                    round(
                        float(
                            temperature
                        ),
                        2
                    )
                    if temperature
                    is not None
                    else None
                ),

            "humidity":
                average_humidity,

            "rainfall":
                (
                    round(
                        float(
                            rain_value
                        ),
                        2
                    )
                    if rain_value
                    is not None
                    else 0.0
                ),

            "precipitation":
                (
                    round(
                        float(
                            precipitation_value
                        ),
                        2
                    )
                    if precipitation_value
                    is not None
                    else 0.0
                ),

            "weather_code":
                weather_code,

            "weather_condition":
                _weather_condition_from_code(
                    weather_code
                )
        })

    result = {
        "store_id":
            store_id,

        "latitude":
            latitude,

        "longitude":
            longitude,

        "timezone":
            "Asia/Colombo",

        "forecast_days":
            len(forecast),

        "weather":
            forecast
    }

    _save_weather_cache(
        store_id,
        days,
        result
    )

    return result


# ==========================================================
# WEATHER FOR ONE DATE
# ==========================================================

def get_weather_for_date(
    store_id: str,
    target_date: str
) -> dict:
    """
    Return weather for a specific date
    inside the supported 14-day window.
    """

    try:

        requested_date = (
            datetime.strptime(
                target_date,
                "%Y-%m-%d"
            ).date()
        )

    except ValueError as exc:

        raise ValueError(
            "target_date must use "
            "YYYY-MM-DD format."
        ) from exc

    today = (
        datetime.now().date()
    )

    days_ahead = (
        requested_date
        - today
    ).days

    if days_ahead < 0:

        raise ValueError(
            "Historical dates are not "
            "supported by the short-range "
            "weather service."
        )

    if (
        days_ahead
        >= MAX_FORECAST_DAYS
    ):

        raise ValueError(
            "Target date is outside "
            "the supported 14-day "
            "forecast range."
        )

    weather_data = (
        get_forecast_weather(
            store_id=store_id,
            days=min(days_ahead + 3, MAX_FORECAST_DAYS)
        )
    )

    for item in (
        weather_data["weather"]
    ):

        if (
            item["date"]
            == target_date
        ):
            return item

    raise ValueError(
        f"Weather data is unavailable "
        f"for {target_date}."
    )


# ==========================================================
# HISTORICAL MONTH HELPERS
# ==========================================================

def _get_month_date_range(
    year: int,
    month: int
) -> tuple[str, str]:

    if (
        month < 1
        or month > 12
    ):
        raise ValueError(
            "Month must be between "
            "1 and 12."
        )

    last_day = (
        calendar.monthrange(
            year,
            month
        )[1]
    )

    start_date = (
        f"{year:04d}-"
        f"{month:02d}-01"
    )

    end_date = (
        f"{year:04d}-"
        f"{month:02d}-"
        f"{last_day:02d}"
    )

    return (
        start_date,
        end_date
    )


# ==========================================================
# HISTORICAL WEATHER CACHE
# ==========================================================

def _historical_cache_key(
    store_id: str,
    month: int,
    years: list[int]
) -> str:

    years_part = "-".join(
        str(year)
        for year
        in sorted(years)
    )

    return (
        f"{store_id}:"
        f"{month}:"
        f"{years_part}"
    )


def _get_cached_historical_profile(
    store_id: str,
    month: int,
    years: list[int]
):

    key = (
        _historical_cache_key(
            store_id,
            month,
            years
        )
    )

    cached = (
        _historical_weather_cache
        .get(key)
    )

    if not cached:
        return None

    if (
        datetime.now()
        >= cached["expires_at"]
    ):

        del (
            _historical_weather_cache[
                key
            ]
        )

        return None

    return cached["data"]


def _save_historical_profile_cache(
    store_id: str,
    month: int,
    years: list[int],
    data: dict
):

    key = (
        _historical_cache_key(
            store_id,
            month,
            years
        )
    )

    _historical_weather_cache[
        key
    ] = {
        "expires_at": (
            datetime.now()
            + timedelta(
                hours=(
                    HISTORICAL_CACHE_HOURS
                )
            )
        ),

        "data":
            data
    }


# ==========================================================
# HISTORICAL WEATHER FOR ONE MONTH
# ==========================================================

def _get_historical_month_weather(
    latitude: float,
    longitude: float,
    year: int,
    month: int
) -> dict:
    """
    Retrieve historical weather for one
    month of one year.
    """

    start_date, end_date = (
        _get_month_date_range(
            year,
            month
        )
    )

    params = {
        "latitude":
            latitude,

        "longitude":
            longitude,

        "start_date":
            start_date,

        "end_date":
            end_date,

        "daily": ",".join([
            "temperature_2m_mean",
            "rain_sum",
            "precipitation_sum",
            "weather_code"
        ]),

        "hourly":
            "relative_humidity_2m",

        "timezone":
            "Asia/Colombo"
    }

    try:

        response = requests.get(
            OPEN_METEO_HISTORICAL_URL,
            params=params,
            timeout=REQUEST_TIMEOUT
        )

        response.raise_for_status()

        api_data = (
            response.json()
        )

    except requests.RequestException as exc:

        raise RuntimeError(
            "Unable to retrieve historical "
            f"weather for "
            f"{year}-{month:02d}: "
            f"{exc}"
        ) from exc

    daily = api_data.get(
        "daily",
        {}
    )

    hourly = api_data.get(
        "hourly",
        {}
    )

    temperatures = [
        float(value)
        for value in (
            daily.get(
                "temperature_2m_mean",
                []
            )
        )
        if value is not None
    ]

    rainfall_values = [
        float(
            value or 0
        )
        for value in (
            daily.get(
                "rain_sum",
                []
            )
        )
    ]

    weather_codes = (
        daily.get(
            "weather_code",
            []
        )
        or []
    )

    humidity_values = [
        float(value)
        for value in (
            hourly.get(
                "relative_humidity_2m",
                []
            )
        )
        if value is not None
    ]

    if not temperatures:

        raise ValueError(
            "Historical temperature "
            f"data is unavailable for "
            f"{year}-{month:02d}."
        )

    avg_temperature = round(
        mean(
            temperatures
        ),
        2
    )

    avg_humidity = (
        round(
            mean(
                humidity_values
            ),
            2
        )
        if humidity_values
        else None
    )

    total_rainfall = round(
        sum(
            rainfall_values
        ),
        2
    )

    rainy_days = sum(
        1
        for rainfall
        in rainfall_values
        if rainfall
        > RAINY_DAY_THRESHOLD_MM
    )

    storm_days = sum(
        1
        for code
        in weather_codes
        if _is_storm_weather_code(
            code
        )
    )

    sunny_days = sum(
        1
        for code
        in weather_codes
        if _is_sunny_weather_code(
            code
        )
    )

    return {
        "year":
            year,

        "month":
            month,

        "avg_temperature":
            avg_temperature,

        "avg_humidity":
            avg_humidity,

        "total_rainfall":
            total_rainfall,

        "rainy_days":
            rainy_days,

        "storm_days":
            storm_days,

        "sunny_days":
            sunny_days,

        "days_in_month":
            len(
                daily.get(
                    "time",
                    []
                )
            )
    }


# ==========================================================
# MONTHLY SEASONAL WEATHER PROFILE
# ==========================================================

def get_monthly_weather_profile(
    store_id: str,
    month: int,
    years: Optional[
        list[int]
    ] = None,
    force_refresh: bool = False
) -> dict:
    """
    Build a historical seasonal profile
    for a store and calendar month.

    Example:

    CP006 + September

    uses:

    September 2021
    September 2022
    September 2023
    September 2024
    September 2025
    """

    if (
        month < 1
        or month > 12
    ):
        raise ValueError(
            "Month must be between "
            "1 and 12."
        )

    selected_years = (
        years
        if years
        else DEFAULT_HISTORICAL_YEARS
    )

    if not selected_years:

        raise ValueError(
            "At least one historical "
            "year is required."
        )

    if not force_refresh:

        cached = (
            _get_cached_historical_profile(
                store_id,
                month,
                selected_years
            )
        )

        if cached:
            return cached

    latitude, longitude = (
        _get_store_coordinates(
            store_id
        )
    )

    yearly_profiles = []

    for year in selected_years:

        yearly_profile = (
            _get_historical_month_weather(
                latitude=latitude,
                longitude=longitude,
                year=year,
                month=month
            )
        )

        yearly_profiles.append(
            yearly_profile
        )

    avg_temperature = round(
        mean(
            profile[
                "avg_temperature"
            ]
            for profile
            in yearly_profiles
        ),
        2
    )

    valid_humidity = [
        profile[
            "avg_humidity"
        ]
        for profile
        in yearly_profiles
        if profile[
            "avg_humidity"
        ] is not None
    ]

    avg_humidity = (
        round(
            mean(
                valid_humidity
            ),
            2
        )
        if valid_humidity
        else None
    )

    # Average typical monthly rainfall,
    # not total across all five years.
    avg_total_rainfall = round(
        mean(
            profile[
                "total_rainfall"
            ]
            for profile
            in yearly_profiles
        ),
        2
    )

    avg_rainy_days = int(
        round(
            mean(
                profile[
                    "rainy_days"
                ]
                for profile
                in yearly_profiles
            )
        )
    )

    avg_storm_days = int(
        round(
            mean(
                profile[
                    "storm_days"
                ]
                for profile
                in yearly_profiles
            )
        )
    )

    avg_sunny_days = int(
        round(
            mean(
                profile[
                    "sunny_days"
                ]
                for profile
                in yearly_profiles
            )
        )
    )

    result = {
        "store_id":
            store_id,

        "latitude":
            latitude,

        "longitude":
            longitude,

        "month":
            month,

        "month_name":
            calendar.month_name[
                month
            ],

        "historical_years":
            selected_years,

        "years_used":
            len(
                yearly_profiles
            ),

        "weather_mode":
            "HISTORICAL_SEASONAL_PROFILE",

        "avg_temperature":
            avg_temperature,

        "avg_humidity":
            avg_humidity,

        "total_rainfall":
            avg_total_rainfall,

        "rainy_days":
            avg_rainy_days,

        "storm_days":
            avg_storm_days,

        "sunny_days":
            avg_sunny_days,

        # Useful during testing/research.
        "yearly_profiles":
            yearly_profiles
    }

    _save_historical_profile_cache(
        store_id=store_id,
        month=month,
        years=selected_years,
        data=result
    )

    return result


# ==========================================================
# QUARTERLY WEATHER PROFILES
# ==========================================================

def get_quarterly_weather_profiles(
    store_id: str,
    quarter: int,
    years: Optional[
        list[int]
    ] = None
) -> dict:
    """
    Return the three seasonal monthly weather
    profiles belonging to a quarter.

    Q1 = Jan, Feb, Mar
    Q2 = Apr, May, Jun
    Q3 = Jul, Aug, Sep
    Q4 = Oct, Nov, Dec
    """

    if (
        quarter < 1
        or quarter > 4
    ):
        raise ValueError(
            "Quarter must be between "
            "1 and 4."
        )

    start_month = (
        (quarter - 1)
        * 3
        + 1
    )

    months = [
        start_month,
        start_month + 1,
        start_month + 2
    ]

    profiles = []

    for month in months:

        profile = (
            get_monthly_weather_profile(
                store_id=store_id,
                month=month,
                years=years
            )
        )

        profiles.append(
            profile
        )

    return {
        "store_id":
            store_id,

        "quarter":
            quarter,

        "weather_mode":
            "HISTORICAL_SEASONAL_PROFILE",

        "months":
            profiles
    }


# ==========================================================
# CACHE CLEARING
# ==========================================================

def clear_weather_cache():
    """
    Clear short-range and historical
    in-memory weather caches.
    """

    _weather_cache.clear()

    _historical_weather_cache.clear()