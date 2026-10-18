from fastapi import APIRouter, HTTPException, Query

from app.services.product_service import (
    get_products_paginated,
    get_product_by_id,
    get_products_by_category,
    get_all_products
)

router = APIRouter(
    prefix="/products",
    tags=["Products"]
)

@router.get("")
def list_products(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=50, ge=1, le=100),
    category: str | None = Query(default=None),
    all_products: bool = Query(default=False)
):
    if all_products:
        # Dashboard expects all products or filtered by category without pagination
        if category:
            products = get_products_by_category(category)
        else:
            products = get_all_products()
        return {
            "count": len(products),
            "products": products,
        }
    else:
        # Mobile app expects paginated products with stock injection
        products = get_products_paginated(page=page, limit=limit, category=category)
        return {
            "count": len(products),
            "page": page,
            "limit": limit,
            "products": products,
        }

@router.get("/{product_id}")
def product_by_id(product_id: str):
    product = get_product_by_id(product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    return product
