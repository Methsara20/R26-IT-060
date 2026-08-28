from fastapi import APIRouter, HTTPException

from app.services.analytics_service import (
    get_dashboard_summary,
    get_showroom_performance,
    get_best_showroom,
    get_inventory_summary_by_category,
    get_brand_summary,
    get_gender_summary,
    get_low_stock_items,
    get_overstock_items,
    get_high_value_inventory
)

router = APIRouter(
    prefix="/analytics",
    tags=["Analytics"]
)


@router.get("/dashboard")
def dashboard_summary():
    return get_dashboard_summary()


@router.get("/showroom-performance")
def showroom_performance():
    result = get_showroom_performance()

    return {
        "count": len(result),
        "showrooms": result
    }


@router.get("/best-showroom")
def best_showroom():
    result = get_best_showroom()

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="No showroom data found"
        )

    return result


@router.get("/inventory/category-summary")
def category_inventory_summary():
    result = get_inventory_summary_by_category()

    return {
        "count": len(result),
        "categories": result
    }

@router.get("/brands")
def brands():
    return get_brand_summary()


@router.get("/genders")
def genders():
    return get_gender_summary()


@router.get("/low-stock-items")
def low_stock_items():
    return get_low_stock_items()


@router.get("/overstock-items")
def overstock_items():
    return get_overstock_items()


@router.get("/high-value-inventory")
def high_value_inventory():
    return get_high_value_inventory()