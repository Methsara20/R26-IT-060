# from app.services.firebase_service import (
#     get_all_documents,
#     get_document_by_id
# )
# from app.constants.collections import PRODUCTS_COLLECTION
#
#
# def get_all_products():
#     return get_all_documents(PRODUCTS_COLLECTION)
#
#
# def get_product_by_id(product_id: str):
#     return get_document_by_id(PRODUCTS_COLLECTION, product_id)
#

from app.services.firebase_service import (
    get_all_documents,
    get_document_by_id
)

from app.constants.collections import PRODUCTS_COLLECTION
from app.config.settings import PRODUCT_IMAGE_BASE_URL


_products_cache = None


def add_product_image_url(product: dict) -> dict:
    """
    Adds a public GitHub Pages image URL.

    Firestore stores:
        image_key

    API returns:
        image_url
    """

    result = product.copy()

    image_key = result.get("image_key")

    if image_key:
        result["image_url"] = (
            f"{PRODUCT_IMAGE_BASE_URL.rstrip('/')}/{image_key}.jpg"
        )
    else:
        result["image_url"] = None

    return result


from app.firebase_config import db
from app.services.firebase_service import get_paginated_documents

def get_products_paginated(page: int = 1, limit: int = 50, category: str = None):
    offset = (page - 1) * limit
    
    filters = []
    if category and category.lower() != "all":
        # Note: Firestore is case-sensitive, so we use the exact category passed from the frontend
        filters.append({"field": "category", "op": "==", "value": category})
        
    products = get_paginated_documents(PRODUCTS_COLLECTION, limit, offset, filters)
    
    if not products:
        return []

    # Get inventory only for the products on this page
    product_ids = [p.get("product_id") or p.get("id") for p in products]
    product_ids = [pid for pid in product_ids if pid]
    
    stock_map = {}
    try:
        if product_ids:
            # Firestore allows 'in' queries with a maximum of 30 items
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
        
        # Alias price
        enriched["price_lkr"] = enriched.get("selling_price", 0.0)
        enriched_products.append(enriched)

    return enriched_products


def get_all_products():
    """
    WARNING: This fetches all products and bypasses pagination. 
    It should ONLY be used by the RAG service for database ingestion 
    and never for user-facing API routes.
    """
    from app.services.firebase_service import get_all_documents
    products = get_all_documents(PRODUCTS_COLLECTION)
    
    enriched_products = []
    for product in products:
        enriched = add_product_image_url(product)
        # RAG expects price_lkr
        enriched["price_lkr"] = enriched.get("selling_price", 0.0)
        enriched_products.append(enriched)
        
    return enriched_products

def get_product_by_id(product_id: str):
    product = get_document_by_id(
        PRODUCTS_COLLECTION,
        product_id
    )

    if product:
        return add_product_image_url(product)

    return None