from app.services.firebase_service import (
    get_all_documents,
    get_document_by_id,
    get_paginated_documents
)
from app.constants.collections import PRODUCTS_COLLECTION
from app.config.settings import PRODUCT_IMAGE_BASE_URL
from app.firebase_config import db

_products_cache = None

def add_product_image_url(product: dict) -> dict:
    """Adds a public GitHub Pages image URL."""
    result = product.copy()
    image_key = result.get("image_key")
    if image_key:
        result["image_url"] = f"{PRODUCT_IMAGE_BASE_URL.rstrip('/')}/{image_key}.jpg"
    else:
        result["image_url"] = None
    return result

def get_products_paginated(page: int = 1, limit: int = 50, category: str = None):
    offset = (page - 1) * limit
    filters = []
    if category and category.lower() != "all":
        filters.append({"field": "category", "op": "==", "value": category})
        
    products = get_paginated_documents(PRODUCTS_COLLECTION, limit, offset, filters)
    if not products:
        return []

    product_ids = [p.get("product_id") or p.get("id") for p in products]
    product_ids = [pid for pid in product_ids if pid]
    
    stock_map = {}
    try:
        if product_ids:
            for i in range(0, len(product_ids), 30):
                chunk = product_ids[i:i+30]
                inventory_docs = db.collection("inventory_current").where("product_id", "in", chunk).stream()
                for doc in inventory_docs:
                    data = doc.to_dict()
                    pid = data.get("product_id")
                    if pid:
                        stock_map[pid] = stock_map.get(pid, 0) + int(data.get("current_stock", 0))
    except Exception as e:
        print(f"Error loading inventory: {e}")

    enriched_products = []
    for product in products:
        enriched = add_product_image_url(product)
        pid = enriched.get("product_id") or enriched.get("id")
        enriched["current_stock"] = stock_map.get(pid, 0)
        enriched["price_lkr"] = enriched.get("selling_price", 0.0)
        enriched_products.append(enriched)
    return enriched_products

def get_all_products(force_refresh: bool = False):
    global _products_cache
    if _products_cache is None or force_refresh:
        print("Loading products from DB (Cached)...")
        products = get_all_documents(PRODUCTS_COLLECTION)
        enriched = []
        for product in products:
            p = add_product_image_url(product)
            p["price_lkr"] = p.get("selling_price", 0.0)
            enriched.append(p)
        _products_cache = enriched
    return _products_cache

def get_product_by_id(product_id: str):
    products = get_all_products()
    for product in products:
        if product.get("product_id") == product_id or product.get("id") == product_id:
            return product
    product = get_document_by_id(PRODUCTS_COLLECTION, product_id)
    if product:
        p = add_product_image_url(product)
        p["price_lkr"] = p.get("selling_price", 0.0)
        return p
    return None

def get_products_by_category(category: str) -> list[dict]:
    normalized_category = category.strip().lower()
    return [
        product for product in get_all_products()
        if str(product.get("category", "")).strip().lower() == normalized_category
    ]

def clear_products_cache():
    global _products_cache
    _products_cache = None
