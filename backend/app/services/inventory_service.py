# from app.services.firebase_service import (
#     get_all_documents,
#     get_document_by_id,
#     get_collection,
#     update_document
# )
# from app.constants.collections import INVENTORY_COLLECTION
#
#
# def get_all_inventory():
#     return get_all_documents(INVENTORY_COLLECTION)
#
#
# def get_inventory_by_id(inventory_id: str):
#     return get_document_by_id(
#         INVENTORY_COLLECTION,
#         inventory_id
#     )
#
#
# def get_inventory_by_store(store_id: str):
#     docs = get_collection(INVENTORY_COLLECTION).where(
#         "store_id",
#         "==",
#         store_id
#     ).stream()
#
#     data = []
#
#     for doc in docs:
#         item = doc.to_dict()
#         item["id"] = doc.id
#         data.append(item)
#
#     return data
#
#
# def get_inventory_by_product(product_id: str):
#     docs = get_collection(INVENTORY_COLLECTION).where(
#         "product_id",
#         "==",
#         product_id
#     ).stream()
#
#     data = []
#
#     for doc in docs:
#         item = doc.to_dict()
#         item["id"] = doc.id
#         data.append(item)
#
#     return data
#
#
# def update_inventory_stock(inventory_id: str, current_stock: int):
#     return update_document(
#         INVENTORY_COLLECTION,
#         inventory_id,
#         {
#             "current_stock": current_stock
#         }
#     )

from app.services.firebase_service import (
    get_all_documents,
    get_document_by_id,
    update_document
)

from app.constants.collections import INVENTORY_COLLECTION

from app.services.analytics_summary_service import (
    refresh_summaries_after_inventory_update
)

from app.services.optimization_candidate_service import (
    update_optimization_candidate
)


_inventory_cache = None


def get_all_inventory(force_refresh: bool = False):
    global _inventory_cache

    if _inventory_cache is None or force_refresh:
        print("Loading inventory from Firestore...")
        _inventory_cache = get_all_documents(INVENTORY_COLLECTION)

    return _inventory_cache


def get_inventory_by_id(inventory_id: str):
    inventory = get_all_inventory()

    for item in inventory:
        if item.get("inventory_id") == inventory_id or item.get("id") == inventory_id:
            return item

    return get_document_by_id(
        INVENTORY_COLLECTION,
        inventory_id
    )


def get_inventory_by_store(store_id: str):
    inventory = get_all_inventory()

    return [
        item for item in inventory
        if item.get("store_id") == store_id
    ]


def get_inventory_by_product(product_id: str):
    inventory = get_all_inventory()

    return [
        item for item in inventory
        if item.get("product_id") == product_id
    ]


def update_inventory_stock(inventory_id: str, current_stock: int):
    old_inventory = get_document_by_id(
        INVENTORY_COLLECTION,
        inventory_id
    )

    if old_inventory is None:
        return None

    new_inventory = old_inventory.copy()
    new_inventory["current_stock"] = current_stock

    result = update_document(
        INVENTORY_COLLECTION,
        inventory_id,
        {
            "current_stock": current_stock
        }
    )

    if result is None:
        return None

    analytics_updated = False
    candidate_result = {
        "candidate_updated": False,
        "candidate_status": "NOT_PROCESSED"
    }

    try:
        refresh_summaries_after_inventory_update(
            old_inventory=old_inventory,
            new_inventory=new_inventory
        )
        analytics_updated = True

    except Exception as e:
        print(f"Analytics summary update failed: {e}")

    try:
        candidate_result = update_optimization_candidate(
            new_inventory
        )

    except Exception as e:
        print(f"Optimization candidate update failed: {e}")

        candidate_result = {
            "candidate_updated": False,
            "candidate_status": "FAILED",
            "error": str(e)
        }

    clear_inventory_cache()

    return {
        **result,
        "old_stock": old_inventory.get("current_stock"),
        "new_stock": current_stock,
        "analytics_updated": analytics_updated,
        "optimization_candidate": candidate_result
    }


def clear_inventory_cache():
    global _inventory_cache
    _inventory_cache = None