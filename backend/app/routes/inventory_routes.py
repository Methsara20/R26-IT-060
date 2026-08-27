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