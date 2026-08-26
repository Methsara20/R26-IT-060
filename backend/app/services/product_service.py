from app.services.firebase_service import (
    get_all_documents,
    get_document_by_id
)

from app.constants.collections import PRODUCTS_COLLECTION
from app.config.settings import PRODUCT_IMAGE_BASE_URL
from app.firebase_config import db


def add_product_image_url(product: dict) -> dict:
    """
    Adds a public image URL to product dict.
    Supports image_key (GitHub Pages) or direct image_url.
    """
    result = product.copy()
    image_key = result.get("image_key")

    if image_key:
        result["image_url"] = (
            f"{PRODUCT_IMAGE_BASE_URL.rstrip('/')}/{image_key}.jpg"
        )
    else:
        result["image_url"] = result.get("image_url") or None

    return result


def fetch_raw_products_from_firestore():
    """
    Fetches raw products from Firestore using stream first,
    falling back to direct .get() to bypass gRPC silent stream drops.
    """
    products = get_all_documents(PRODUCTS_COLLECTION)

    if not products:
        print("Stream returned 0 products. Falling back to direct db.collection().get()...")
        try:
            docs = db.collection(PRODUCTS_COLLECTION).get()
            products = []
            for doc in docs:
                p = doc.to_dict()
                p["id"] = doc.id
                products.append(p)
        except Exception as e:
            print(f"Error executing direct .get() on products collection: {e}")

    return products


def get_all_products(force_refresh: bool = False):
    from app.services.cache_service import products_cache

    if force_refresh:
        products_cache.clear()

    cached_products = products_cache.get("all_products")

    if not cached_products or force_refresh:
        print("Loading products from Firestore...")

        products = fetch_raw_products_from_firestore()

        # Retry loop for Firestore cold start
        retry_count = 0
        while not products and retry_count < 3:
            import time
            retry_count += 1
            sleep_time = retry_count * 1.0
            print(f"Retrying product fetch (attempt {retry_count})...")
            time.sleep(sleep_time)
            products = fetch_raw_products_from_firestore()

        # Load current stock map
        stock_map = {}
        try:
            inventory_docs = db.collection("inventory_current").get()
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
            
            # Normalize product_id
            enriched["product_id"] = pid
            
            # Normalize product_name / name
            enriched["product_name"] = enriched.get("product_name") or enriched.get("name") or "Product Item"
            
            # Normalize brand
            enriched["brand"] = enriched.get("brand") or "Brand"
            
            # Normalize category
            enriched["category"] = enriched.get("category") or "General"
            
            # Normalize stock
            enriched["current_stock"] = stock_map.get(pid, enriched.get("current_stock", 10))
            
            # Normalize price
            price_val = (
                enriched.get("price_lkr") or 
                enriched.get("selling_price") or 
                enriched.get("price") or 
                0.0
            )
            try:
                enriched["price_lkr"] = float(price_val)
            except (ValueError, TypeError):
                enriched["price_lkr"] = 0.0

            enriched_products.append(enriched)

        if enriched_products:
            products_cache.set("all_products", enriched_products)
            cached_products = enriched_products
        else:
            products_cache.clear()

    return cached_products or []


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


def get_products_by_category(category: str) -> list[dict]:
    normalized_category = category.strip().lower()

    return [
        product
        for product in get_all_products()
        if str(product.get("category", "")).strip().lower() == normalized_category
    ]


def clear_products_cache():
    from app.services.cache_service import products_cache
    products_cache.clear()