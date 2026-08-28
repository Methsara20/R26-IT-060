from app.services.firebase_service import (
    get_all_documents,
    get_document_by_id
)

from app.constants.collections import (
    ANALYTICS_SUMMARY_COLLECTION,
    SHOWROOM_ANALYTICS_COLLECTION,
    CATEGORY_ANALYTICS_COLLECTION,
    BRAND_ANALYTICS_COLLECTION,
    GENDER_ANALYTICS_COLLECTION,
    ALERT_ITEMS_COLLECTION
)


def sort_by_profit(items):
    return sorted(
        items,
        key=lambda x: x.get("potential_profit", 0),
        reverse=True
    )


def get_dashboard_summary():
    result = get_document_by_id(
        ANALYTICS_SUMMARY_COLLECTION,
        "dashboard"
    )

    if result is None:
        return {
            "error": "Dashboard summary not found. Run analytics summary generator first."
        }

    return result


def get_showroom_performance():
    result = get_all_documents(
        SHOWROOM_ANALYTICS_COLLECTION
    )

    return sort_by_profit(result)


def get_best_showroom():
    performance = get_showroom_performance()

    if not performance:
        return None

    return performance[0]


def get_inventory_summary_by_category():
    result = get_all_documents(
        CATEGORY_ANALYTICS_COLLECTION
    )

    return sort_by_profit(result)


def get_brand_summary():
    result = get_all_documents(
        BRAND_ANALYTICS_COLLECTION
    )

    return sort_by_profit(result)


def get_gender_summary():
    result = get_all_documents(
        GENDER_ANALYTICS_COLLECTION
    )

    return sort_by_profit(result)


def get_low_stock_items():
    result = get_document_by_id(
        ALERT_ITEMS_COLLECTION,
        "low_stock"
    )

    if result is None:
        return {
            "count": 0,
            "items": []
        }

    return result


def get_overstock_items():
    result = get_document_by_id(
        ALERT_ITEMS_COLLECTION,
        "overstock"
    )

    if result is None:
        return {
            "count": 0,
            "items": []
        }

    return result


def get_high_value_inventory():
    result = get_document_by_id(
        ALERT_ITEMS_COLLECTION,
        "high_value_inventory"
    )

    if result is None:
        return {
            "count": 0,
            "items": []
        }

    return result