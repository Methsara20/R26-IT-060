from fastapi import APIRouter, HTTPException

from app.services.product_service import (
    get_all_products,
    get_product_by_id
)

router = APIRouter(
    prefix="/products",
    tags=["Products"]
)


@router.get("/")
def all_products():
    return {
        "count": len(get_all_products()),
        "products": get_all_products()
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