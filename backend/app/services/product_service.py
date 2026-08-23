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

def get_all_products(force_refresh: bool = False):
    global _products_cache

    if _products_cache is None or force_refresh:
        print("Loading products from Firestore...")

        products = get_all_documents(PRODUCTS_COLLECTION)
        
        # Workaround for Firestore gRPC cold start silent drop bug
        if not products:
            import time
            time.sleep(1)
            print("Retrying products fetch due to empty stream (gRPC cold start)...")
            products = get_all_documents(PRODUCTS_COLLECTION)

        try:
            inventory_docs = db.collection("inventory_current").stream()
            stock_map = {}
            for doc in inventory_docs:
                data = doc.to_dict()
                pid = data.get("product_id")
                if pid:
                    stock_map[pid] = stock_map.get(pid, 0) + int(data.get("current_stock", 0))
        except Exception as e:
            print(f"Error loading inventory: {e}")
            stock_map = {}

        enriched_products = []
        for product in products:
            enriched = add_product_image_url(product)
            pid = enriched.get("product_id")
            enriched["current_stock"] = stock_map.get(pid, 0)
            
            # Alias price
            enriched["price_lkr"] = enriched.get("selling_price", 0.0)
            enriched_products.append(enriched)

        if enriched_products:
            _products_cache = enriched_products

    return _products_cache or []


def get_product_by_id(product_id: str):
    products = get_all_products()

    for product in products:
        if (
            product.get("product_id") == product_id
            or product.get("id") == product_id
        ):
            return product

    product = get_document_by_id(
        PRODUCTS_COLLECTION,
        product_id
    )

    if product:
        return add_product_image_url(product)

    return None

def get_products_by_category(
    category: str,
) -> list[dict]:
    normalized_category = category.strip().lower()

    return [
        product
        for product in get_all_products()
        if str(
            product.get("category", "")
        ).strip().lower() == normalized_category
    ]


def clear_products_cache():
    global _products_cache
    _products_cache = None