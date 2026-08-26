from app.services.firebase_service import (
    get_all_documents,
    get_document_by_id
)

from app.constants.collections import PRODUCTS_COLLECTION
from app.config.settings import PRODUCT_IMAGE_BASE_URL
from app.firebase_config import db

FALLBACK_PRODUCTS = [
    {
        "product_id": "P001",
        "product_name": "Classic Denim Jacket",
        "brand": "NexaRetail",
        "category": "Outerwear",
        "price_lkr": 4500.0,
        "current_stock": 15,
        "description": "Versatile classic blue denim jacket with front metal buttons and twin flap pockets.",
        "image_key": "denim_jacket"
    },
    {
        "product_id": "P002",
        "product_name": "Slim Fit Cotton T-Shirt",
        "brand": "NexaRetail",
        "category": "Tops",
        "price_lkr": 2200.0,
        "current_stock": 25,
        "description": "Breathable 100% organic cotton t-shirt with modern slim silhouette.",
        "image_key": "cotton_tshirt"
    },
    {
        "product_id": "P003",
        "product_name": "Tailored Chino Pants",
        "brand": "NexaRetail",
        "category": "Bottoms",
        "price_lkr": 3800.0,
        "current_stock": 20,
        "description": "Smart casual stretch chino pants with tapered fit and slant pockets.",
        "image_key": "chino_pants"
    },
    {
        "product_id": "P004",
        "product_name": "Summer Floral Dress",
        "brand": "NexaRetail",
        "category": "Dresses",
        "price_lkr": 5200.0,
        "current_stock": 12,
        "description": "Lightweight breezy floral print dress with soft waist cinching.",
        "image_key": "floral_dress"
    }
]


def add_product_image_url(product: dict) -> dict:
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
    products = []
    try:
        products = get_all_documents(PRODUCTS_COLLECTION)
    except Exception as e:
        print(f"[ProductService] Stream error: {e}")

    if not products and db is not None:
        try:
            print("Stream returned 0 products. Falling back to direct db.collection().get()...")
            docs = db.collection(PRODUCTS_COLLECTION).get()
            products = []
            for doc in docs:
                p = doc.to_dict()
                p["id"] = doc.id
                products.append(p)
        except Exception as e:
            print(f"[ProductService] Error executing direct .get(): {e}")

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
        while not products and retry_count < 2:
            import time
            retry_count += 1
            print(f"Retrying product fetch (attempt {retry_count})...")
            time.sleep(0.5)
            products = fetch_raw_products_from_firestore()

        if not products:
            print("[ProductService] Firestore empty or quota reached. Using default product catalog.")
            products = FALLBACK_PRODUCTS.copy()

        # Load current stock map
        stock_map = {}
        if db is not None:
            try:
                inventory_docs = db.collection("inventory_current").get()
                for doc in inventory_docs:
                    data = doc.to_dict()
                    pid = data.get("product_id")
                    if pid:
                        stock_map[pid] = stock_map.get(pid, 0) + int(data.get("current_stock", 0))
            except Exception as e:
                print(f"[ProductService] Error loading inventory: {e}")

        enriched_products = []
        for product in products:
            enriched = add_product_image_url(product)
            pid = enriched.get("product_id") or enriched.get("id") or "P00"
            
            enriched["product_id"] = pid
            enriched["product_name"] = enriched.get("product_name") or enriched.get("name") or "Product Item"
            enriched["brand"] = enriched.get("brand") or "NexaRetail"
            enriched["category"] = enriched.get("category") or "General"
            enriched["current_stock"] = stock_map.get(pid, enriched.get("current_stock", 10))
            
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

    return cached_products or FALLBACK_PRODUCTS


def get_product_by_id(product_id: str):
    products = get_all_products()

    for product in products:
        if (
            product.get("product_id") == product_id
            or product.get("id") == product_id
        ):
            return product

    try:
        product = get_document_by_id(
            PRODUCTS_COLLECTION,
            product_id
        )
        if product:
            return add_product_image_url(product)
    except Exception as e:
        print(f"[ProductService] get_product_by_id error: {e}")

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