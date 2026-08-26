from fastapi import APIRouter, HTTPException, Query

from app.services.product_service import (
    get_all_products,
    get_product_by_id,
    get_products_by_category
)

router = APIRouter(
    prefix="/products",
    tags=["Products"]
)


@router.get("")
def list_products(
    category: str | None = Query(default=None),
    refresh: bool = Query(default=False),
):
    if refresh:
        products = get_all_products(force_refresh=True)
    elif category:
        products = get_products_by_category(category)
    else:
        products = get_all_products()

    return {
        "count": len(products),
        "products": products,
    }


@router.get("/{product_id}")
def product_by_id(product_id: str):
    product = get_product_by_id(product_id)

    if product is None:
        raise HTTPException(
            status_code=404,
            detail="Product not found"
        )

    return product