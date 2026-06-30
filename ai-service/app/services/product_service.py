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


_products_cache = None


def get_all_products(force_refresh: bool = False):
    global _products_cache

    if _products_cache is None or force_refresh:
        print("Loading products from Firestore...")
        _products_cache = get_all_documents(PRODUCTS_COLLECTION)

    return _products_cache


def get_product_by_id(product_id: str):
    products = get_all_products()

    for product in products:
        if product.get("product_id") == product_id or product.get("id") == product_id:
            return product

    return get_document_by_id(PRODUCTS_COLLECTION, product_id)


def clear_products_cache():
    global _products_cache
    _products_cache = None