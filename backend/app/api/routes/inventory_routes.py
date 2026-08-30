from fastapi import APIRouter
from app.services import inventory_service

router = APIRouter(prefix="/inventory", tags=["Inventory"])


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