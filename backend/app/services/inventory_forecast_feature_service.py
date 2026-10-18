from typing import Optional

from app.constants.collections import (
    MONTHLY_FORECAST_PROFILES_COLLECTION,
    PRODUCTS_COLLECTION,
    INVENTORY_COLLECTION
)

from app.services.firebase_service import (
    get_document_by_id,
    get_all_documents
)

from app.services.store_service import (
    get_store_by_id
)


# ==========================================================
# SIMPLE MEMORY CACHE
# ==========================================================

_profile_cache: dict[str, dict] = {}

_products_cache: Optional[list[dict]] = None

_inventory_cache: Optional[list[dict]] = None


# ==========================================================
# GENERAL HELPERS
# ==========================================================

def _clean_document_part(
    value: str
) -> str:
    """
    Must match the document-ID format used by
    upload_monthly_forecast_profiles.py.
    """

    return (
        str(value)
        .strip()
        .replace("/", "-")
        .replace("\\", "-")
        .replace(" ", "_")
    )


def _build_profile_document_id(
    store_id: str,
    category: str,
    brand: str,
    gender: str,
    month: int
) -> str:

    return (
        f"{_clean_document_part(store_id)}_"
        f"{_clean_document_part(category)}_"
        f"{_clean_document_part(brand)}_"
        f"{_clean_document_part(gender)}_"
        f"M{int(month):02d}"
    )


def _to_float(
    value,
    default: float = 0.0
) -> float:

    try:
        return float(value)

    except (TypeError, ValueError):
        return default


def _to_int(
    value,
    default: int = 0
) -> int:

    try:
        return int(value)

    except (TypeError, ValueError):
        return default


# ==========================================================
# PROFILE LOOKUP
# ==========================================================

def get_monthly_forecast_profile(
    store_id: str,
    category: str,
    brand: str,
    gender: str,
    month: int
) -> Optional[dict]:
    """
    Retrieve one compact historical seasonal profile.

    First request:
        1 Firestore document read.

    Repeated requests:
        Served from memory cache.
    """

    document_id = (
        _build_profile_document_id(
            store_id=store_id,
            category=category,
            brand=brand,
            gender=gender,
            month=month
        )
    )

    if document_id in _profile_cache:

        return _profile_cache[
            document_id
        ].copy()

    profile = get_document_by_id(
        MONTHLY_FORECAST_PROFILES_COLLECTION,
        document_id
    )

    if profile is None:
        return None

    _profile_cache[
        document_id
    ] = profile.copy()

    return profile.copy()


# ==========================================================
# PRODUCT CACHE
# ==========================================================

def _get_products() -> list[dict]:
    """
    Products change infrequently, so load once
    and retain them in process memory.
    """

    global _products_cache

    if _products_cache is None:

        _products_cache = (
            get_all_documents(
                PRODUCTS_COLLECTION
            )
        )

    return _products_cache


# ==========================================================
# INVENTORY CACHE
# ==========================================================

def _get_inventory() -> list[dict]:
    """
    Current PP2 implementation uses an in-memory
    inventory cache.

    IMPORTANT:
    When stock is changed by an execution workflow,
    this cache should eventually be invalidated.

    For PP2 forecasting demonstrations this prevents
    repeated Firestore reads.
    """

    global _inventory_cache

    if _inventory_cache is None:

        _inventory_cache = (
            get_all_documents(
                INVENTORY_COLLECTION
            )
        )

    return _inventory_cache


def clear_forecast_inventory_cache():
    """
    Can later be called after inventory updates.
    """

    global _inventory_cache

    _inventory_cache = None


def clear_forecast_profile_cache():
    _profile_cache.clear()


# ==========================================================
# PRODUCT FILTER
# ==========================================================

def _get_matching_product_ids(
    category: str,
    brand: str,
    gender: str
) -> set[str]:

    products = _get_products()

    matching_ids = set()

    for product in products:

        if (
            str(
                product.get(
                    "category",
                    ""
                )
            ).strip().lower()
            != category.strip().lower()
        ):
            continue

        if (
            str(
                product.get(
                    "brand",
                    ""
                )
            ).strip().lower()
            != brand.strip().lower()
        ):
            continue

        if (
            str(
                product.get(
                    "gender",
                    ""
                )
            ).strip().lower()
            != gender.strip().lower()
        ):
            continue

        product_id = (
            product.get("product_id")
            or product.get("id")
        )

        if product_id:

            matching_ids.add(
                str(product_id)
            )

    return matching_ids


# ==========================================================
# CURRENT INVENTORY AGGREGATION
# ==========================================================

def build_current_inventory_features(
    store_id: str,
    category: str,
    brand: str,
    gender: str
) -> dict:
    """
    Calculate current operational inventory features.

    Historical inventory CSV data is NOT used.
    """

    product_ids = (
        _get_matching_product_ids(
            category=category,
            brand=brand,
            gender=gender
        )
    )

    if not product_ids:

        raise ValueError(
            "No products found for the selected "
            "category, brand and gender."
        )

    inventory = _get_inventory()

    matching_items = []

    for item in inventory:

        item_store_id = str(
            item.get(
                "store_id",
                ""
            )
        )

        product_id = str(
            item.get(
                "product_id",
                ""
            )
        )

        if (
            item_store_id == store_id
            and product_id in product_ids
        ):
            matching_items.append(
                item
            )

    if not matching_items:

        raise ValueError(
            "No current inventory records found "
            "for the selected forecast combination."
        )

    current_stock_values = [
        _to_float(
            item.get("current_stock")
        )
        for item in matching_items
    ]

    reorder_values = [
        _to_float(
            item.get("reorder_level")
        )
        for item in matching_items
    ]

    max_stock_values = [
        _to_float(
            item.get("max_stock")
        )
        for item in matching_items
    ]

    count = len(
        matching_items
    )

    return {
        "avg_current_stock": round(
            sum(current_stock_values)
            / count,
            2
        ),

        "min_current_stock": round(
            min(current_stock_values),
            2
        ),

        "max_current_stock": round(
            max(current_stock_values),
            2
        ),

        "total_current_stock": round(
            sum(current_stock_values),
            2
        ),

        "avg_reorder_level": round(
            sum(reorder_values)
            / count,
            2
        ),

        "total_reorder_level": round(
            sum(reorder_values),
            2
        ),

        "avg_max_stock": round(
            sum(max_stock_values)
            / count,
            2
        ),

        "inventory_item_count": count
    }


# ==========================================================
# MONTHLY MODEL PAYLOAD
# ==========================================================

def build_auto_monthly_payload(
    store_id: str,
    category: str,
    brand: str,
    gender: str,
    year: int,
    month: int,
    weather_profile: Optional[dict] = None
) -> dict:
    """
    Construct the complete payload expected by the
    existing monthly forecasting model.

    Sources:

    Historical demand/promotion/calendar:
        monthly_forecast_profiles

    Store metadata:
        stores

    Current stock:
        inventory_current

    Weather:
        existing Open-Meteo seasonal profile
    """

    profile = (
        get_monthly_forecast_profile(
            store_id=store_id,
            category=category,
            brand=brand,
            gender=gender,
            month=month
        )
    )

    if profile is None:

        raise ValueError(
            "Historical monthly forecast profile "
            "was not found for this selection."
        )

    store = get_store_by_id(
        store_id
    )

    if not store:

        raise ValueError(
            f"Store '{store_id}' was not found."
        )

    inventory_features = (
        build_current_inventory_features(
            store_id=store_id,
            category=category,
            brand=brand,
            gender=gender
        )
    )

    quarter = (
        (
            int(month) - 1
        )
        // 3
    ) + 1

    # ----------------------------------------------
    # WEATHER
    # ----------------------------------------------

    weather_profile = (
        weather_profile
        or {}
    )

    payload = {
        # ------------------------------------------
        # DIMENSIONS
        # ------------------------------------------

        "store_id": store_id,
        "category": category,
        "brand": brand,
        "gender": gender,

        # ------------------------------------------
        # STORE
        # ------------------------------------------

        "city": (
            store.get("city")
            or ""
        ),

        "region": (
            store.get("region")
            or ""
        ),

        "store_type": (
            store.get("store_type")
            or ""
        ),

        # ------------------------------------------
        # TARGET PERIOD
        # ------------------------------------------

        "year": int(year),
        "month": int(month),
        "quarter": int(quarter),

        # ------------------------------------------
        # HISTORICAL SALES BASELINE
        # ------------------------------------------

        "monthly_units_sold": _to_float(
            profile.get(
                "monthly_units_sold"
            )
        ),

        "avg_price_lkr": _to_float(
            profile.get(
                "avg_price_lkr"
            )
        ),

        "avg_promotion_percent": _to_float(
            profile.get(
                "avg_promotion_percent"
            )
        ),

        "total_revenue": _to_float(
            profile.get(
                "total_revenue"
            )
        ),

        "total_customer_count": _to_float(
            profile.get(
                "total_customer_count"
            )
        ),

        "unique_products_sold": _to_float(
            profile.get(
                "unique_products_sold"
            )
        ),

        # ------------------------------------------
        # WEATHER
        # ------------------------------------------

        "avg_temperature": _to_float(
            weather_profile.get(
                "avg_temperature"
            )
        ),

        "avg_humidity": _to_float(
            weather_profile.get(
                "avg_humidity"
            )
        ),

        "total_rainfall": _to_float(
            weather_profile.get(
                "total_rainfall"
            )
        ),

        "rainy_days": _to_int(
            weather_profile.get(
                "rainy_days"
            )
        ),

        "storm_days": _to_int(
            weather_profile.get(
                "storm_days"
            )
        ),

        "sunny_days": _to_int(
            weather_profile.get(
                "sunny_days"
            )
        ),

        # ------------------------------------------
        # EVENTS
        # ------------------------------------------

        "holiday_days": _to_int(
            profile.get(
                "holiday_days"
            )
        ),

        "festival_days": _to_int(
            profile.get(
                "festival_days"
            )
        ),

        "school_days": _to_int(
            profile.get(
                "school_days"
            )
        ),

        "weekend_days": _to_int(
            profile.get(
                "weekend_days"
            )
        ),

        # ------------------------------------------
        # PROMOTIONS
        # ------------------------------------------

        "promotion_days": _to_int(
            profile.get(
                "promotion_days"
            )
        ),

        "max_promotion_percent": _to_float(
            profile.get(
                "max_promotion_percent"
            )
        ),

        "avg_campaign_discount": _to_float(
            profile.get(
                "avg_campaign_discount"
            )
        ),

        # ------------------------------------------
        # CURRENT INVENTORY
        # ------------------------------------------

        "avg_current_stock": (
            inventory_features[
                "avg_current_stock"
            ]
        ),

        "min_current_stock": (
            inventory_features[
                "min_current_stock"
            ]
        ),

        "max_current_stock": (
            inventory_features[
                "max_current_stock"
            ]
        ),

        "total_current_stock": (
            inventory_features[
                "total_current_stock"
            ]
        ),

        "avg_reorder_level": (
            inventory_features[
                "avg_reorder_level"
            ]
        ),

        "total_reorder_level": (
            inventory_features[
                "total_reorder_level"
            ]
        ),

        "avg_max_stock": (
            inventory_features[
                "avg_max_stock"
            ]
        ),

        # ------------------------------------------
        # HISTORICAL DEMAND FEATURES
        # ------------------------------------------

        "previous_month_sales": _to_float(
            profile.get(
                "previous_month_sales"
            )
        ),

        "previous_2_month_avg": _to_float(
            profile.get(
                "previous_2_month_avg"
            )
        ),

        "previous_3_month_avg": _to_float(
            profile.get(
                "previous_3_month_avg"
            )
        ),

        "previous_6_month_avg": _to_float(
            profile.get(
                "previous_6_month_avg"
            )
        ),

        "same_month_last_year": _to_float(
            profile.get(
                "same_month_last_year"
            )
        ),

        "sales_growth_1m": _to_float(
            profile.get(
                "sales_growth_1m"
            )
        ),

        "sales_growth_3m": _to_float(
            profile.get(
                "sales_growth_3m"
            )
        ),
    }

    return payload