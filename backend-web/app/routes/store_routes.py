from fastapi import APIRouter, HTTPException

from app.services.store_service import (
    get_all_stores,
    get_store_by_id
)

router = APIRouter(
    prefix="/stores",
    tags=["Stores"]
)


@router.get("/")
def all_stores():
    stores = get_all_stores()

    return {
        "count": len(stores),
        "stores": stores
    }


@router.get("/{store_id}")
def store_by_id(store_id: str):
    store = get_store_by_id(store_id)

    if store is None:
        raise HTTPException(
            status_code=404,
            detail="Store not found"
        )

    return store