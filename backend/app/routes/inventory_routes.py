from fastapi import APIRouter, HTTPException

from app.services.inventory_service import (
    get_all_inventory,
    get_inventory_by_id,
    get_inventory_by_store,
    get_inventory_by_product,
    update_inventory_stock
)

router = APIRouter(
    prefix="/inventory",
    tags=["Inventory"]
)


@router.get("/")
def all_inventory():
    inventory = get_all_inventory()

    return {
        "count": len(inventory),
        "inventory": inventory
    }

# --- Appended from backend2 ---
from app.services import inventory_service

@router.get("/collections")
def inventory_collections():
    """Lists all top-level collection names in the shared Firestore project."""
    return inventory_service.list_collections()


@router.get("/preview")
def inventory_preview(collection: str, limit: int = 5):
    """Read-only preview of a given collection's documents, to inspect real structure."""
    return inventory_service.preview_collection(collection, limit=limit)


@router.get("/overstock-suggestions")
def overstock_suggestions(category: str = None, limit: int = 10):
    """
    Returns overstocked products (read-only, from the inventory component's
    precomputed alert), optionally filtered by category.
    """
    return inventory_service.get_overstock_suggestions(category=category, limit=limit)


@router.get("/marketing-opportunities")
def marketing_opportunities(
    category: str = None,
    gender: str = None,
    store_id: str = None,
    year: int = None,
    month: int = None,
    limit: int = 20,
):
    """
    Returns inventory items flagged by the Inventory team as good candidates
    for a promotion (recommended_action = 'PROMOTE'), with optional filters
    by category, gender, store, and/or year/month. Read-only, sourced from
    the shared marketing_opportunities collection.
    """
    return inventory_service.get_marketing_opportunities(
        category=category, gender=gender, store_id=store_id, year=year, month=month, limit=limit
    )


@router.get("/marketing-opportunities/summary")
def marketing_opportunities_summary():
    """
    Returns aggregate stats (total items, total excess units, total value at
    risk) plus the real available filter values (categories, genders,
    stores, months) currently present in the data.
    """
    return inventory_service.get_marketing_opportunities_summary()


@router.get("/{inventory_id}")
def inventory_by_id(inventory_id: str):
    inventory = get_inventory_by_id(inventory_id)

    if inventory is None:
        raise HTTPException(
            status_code=404,
            detail="Inventory record not found"
        )

    return inventory


@router.get("/store/{store_id}")
def inventory_by_store(store_id: str):
    inventory = get_inventory_by_store(store_id)

    return {
        "store_id": store_id,
        "count": len(inventory),
        "inventory": inventory
    }


@router.get("/product/{product_id}")
def inventory_by_product(product_id: str):
    inventory = get_inventory_by_product(product_id)

    return {
        "product_id": product_id,
        "count": len(inventory),
        "inventory": inventory
    }


@router.put("/{inventory_id}/stock")
def update_stock(inventory_id: str, current_stock: int):
    result = update_inventory_stock(
        inventory_id,
        current_stock
    )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Inventory record not found"
        )

    return result
