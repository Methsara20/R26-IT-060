# from app.services.firebase_service import (
#     get_all_documents,
#     get_document_by_id
# )
# from app.constants.collections import STORES_COLLECTION
#
#
# def get_all_stores():
#     return get_all_documents(STORES_COLLECTION)
#
#
# def get_store_by_id(store_id: str):
#     return get_document_by_id(
#         STORES_COLLECTION,
#         store_id
#     )

from app.services.firebase_service import (
    get_all_documents,
    get_document_by_id
)
from app.constants.collections import STORES_COLLECTION


_stores_cache = None


def get_all_stores(force_refresh: bool = False):
    global _stores_cache

    if _stores_cache is None or force_refresh:
        print("Loading stores from Firestore...")
        stores = get_all_documents(STORES_COLLECTION)
        _stores_cache = sorted(stores, key=lambda x: x.get("store_id", x.get("id", "")))

    return _stores_cache


def get_store_by_id(store_id: str):
    stores = get_all_stores()

    for store in stores:
        if store.get("store_id") == store_id or store.get("id") == store_id:
            return store

    return get_document_by_id(STORES_COLLECTION, store_id)


def clear_stores_cache():
    global _stores_cache
    _stores_cache = None