# from datetime import datetime
#
# from app.services.firebase_service import (
#     get_document_by_id,
#     create_or_update_document,
#     delete_document
# )
#
# from app.constants.collections import (
#     PRODUCTS_COLLECTION,
#     OPTIMIZATION_CANDIDATES_COLLECTION
# )
#
#
# def to_int(value, default=0):
#     try:
#         return int(value)
#     except (TypeError, ValueError):
#         return default
#
#
# def calculate_priority(current_stock: int, reorder_level: int, max_stock: int):
#     if current_stock <= 0:
#         return "HIGH"
#
#     if current_stock <= reorder_level:
#         return "HIGH"
#
#     if max_stock > 0 and current_stock >= max_stock * 0.85:
#         return "MEDIUM"
#
#     return "LOW"
#
#
# def get_candidate_type(current_stock: int, reorder_level: int, max_stock: int):
#     if current_stock <= reorder_level:
#         return "LOW_STOCK"
#
#     if max_stock > 0 and current_stock >= max_stock * 0.85:
#         return "OVERSTOCK"
#
#     return None
#
#
# def build_candidate_id(product_id: str, store_id: str):
#     return f"{product_id}_{store_id}"
#
#
# def update_optimization_candidate(inventory_item: dict):
#     product_id = inventory_item.get("product_id")
#     store_id = inventory_item.get("store_id")
#
#     if not product_id or not store_id:
#         return None
#
#     product = get_document_by_id(
#         PRODUCTS_COLLECTION,
#         product_id
#     )
#
#     if product is None:
#         return None
#
#     current_stock = to_int(inventory_item.get("current_stock"))
#     reorder_level = to_int(inventory_item.get("reorder_level"))
#     max_stock = to_int(inventory_item.get("max_stock"))
#
#     candidate_type = get_candidate_type(
#         current_stock,
#         reorder_level,
#         max_stock
#     )
#
#     candidate_id = build_candidate_id(
#         product_id,
#         store_id
#     )
#
#     # If item is now healthy, remove it from optimization candidates
#     if candidate_type is None:
#         delete_document(
#             OPTIMIZATION_CANDIDATES_COLLECTION,
#             candidate_id
#         )
#
#         return {
#             "candidate_updated": True,
#             "candidate_status": "REMOVED",
#             "candidate_id": candidate_id
#         }
#
#     priority = calculate_priority(
#         current_stock,
#         reorder_level,
#         max_stock
#     )
#
#     candidate = {
#         "candidate_id": candidate_id,
#         "product_id": product_id,
#         "store_id": store_id,
#
#         "product_name": product.get("product_name", ""),
#         "category": product.get("category", ""),
#         "subcategory": product.get("subcategory", ""),
#         "brand": product.get("brand", ""),
#         "gender": product.get("gender", ""),
#
#         "current_stock": current_stock,
#         "reorder_level": reorder_level,
#         "max_stock": max_stock,
#
#         "candidate_type": candidate_type,
#         "priority": priority,
#         "status": "PENDING",
#
#         "last_updated": datetime.now().isoformat()
#     }
#
#     create_or_update_document(
#         OPTIMIZATION_CANDIDATES_COLLECTION,
#         candidate_id,
#         candidate,
#         merge=False
#     )
#
#     return {
#         "candidate_updated": True,
#         "candidate_status": "CREATED_OR_UPDATED",
#         "candidate_id": candidate_id
#     }

from datetime import datetime

from app.services.firebase_service import (
    get_all_documents,
    get_document_by_id,
    create_or_update_document,
    delete_document
)

from app.constants.collections import (
    PRODUCTS_COLLECTION,
    OPTIMIZATION_CANDIDATES_COLLECTION
)


OVERSTOCK_THRESHOLD = 0.85


def to_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def get_now():
    return datetime.now().isoformat()


def calculate_shortage_qty(current_stock: int, reorder_level: int):
    return max(0, reorder_level - current_stock)


def calculate_surplus_qty(current_stock: int, max_stock: int):
    if max_stock <= 0:
        return 0

    overstock_point = int(max_stock * OVERSTOCK_THRESHOLD)
    return max(0, current_stock - overstock_point)


def calculate_stock_health(current_stock: int, reorder_level: int, max_stock: int):
    if current_stock <= 0:
        return "Stockout"

    if current_stock <= reorder_level * 0.5:
        return "Critical"

    if current_stock < reorder_level:
        return "Low Stock"

    if max_stock > 0 and current_stock >= max_stock:
        return "Overstock"

    if max_stock > 0 and current_stock >= max_stock * OVERSTOCK_THRESHOLD:
        return "Excess"

    return "Healthy"


def calculate_priority(current_stock: int, reorder_level: int, max_stock: int):
    stock_health = calculate_stock_health(
        current_stock,
        reorder_level,
        max_stock
    )

    if stock_health in ["Stockout", "Critical"]:
        return "HIGH"

    if stock_health == "Low Stock":
        return "HIGH"

    if stock_health in ["Overstock", "Excess"]:
        return "MEDIUM"

    return "LOW"


def get_candidate_type(current_stock: int, reorder_level: int, max_stock: int):
    if current_stock < reorder_level:
        return "LOW_STOCK"

    if max_stock > 0 and current_stock >= max_stock * OVERSTOCK_THRESHOLD:
        return "OVERSTOCK"

    return None


def build_candidate_id(product_id: str, store_id: str):
    return f"{product_id}_{store_id}"


def update_optimization_candidate(inventory_item: dict):
    product_id = inventory_item.get("product_id")
    store_id = inventory_item.get("store_id")

    if not product_id or not store_id:
        return None

    product = get_document_by_id(
        PRODUCTS_COLLECTION,
        product_id
    )

    if product is None:
        return None

    current_stock = to_int(inventory_item.get("current_stock"))
    reorder_level = to_int(inventory_item.get("reorder_level"))
    max_stock = to_int(inventory_item.get("max_stock"))

    candidate_type = get_candidate_type(
        current_stock,
        reorder_level,
        max_stock
    )

    candidate_id = build_candidate_id(
        product_id,
        store_id
    )

    if candidate_type is None:
        delete_document(
            OPTIMIZATION_CANDIDATES_COLLECTION,
            candidate_id
        )

        return {
            "candidate_updated": True,
            "candidate_status": "REMOVED",
            "candidate_id": candidate_id
        }

    existing_candidate = get_document_by_id(
        OPTIMIZATION_CANDIDATES_COLLECTION,
        candidate_id
    )

    now = get_now()

    created_at = now

    if existing_candidate is not None:
        created_at = existing_candidate.get("created_at", now)

    shortage_qty = calculate_shortage_qty(
        current_stock,
        reorder_level
    )

    surplus_qty = calculate_surplus_qty(
        current_stock,
        max_stock
    )

    stock_health = calculate_stock_health(
        current_stock,
        reorder_level,
        max_stock
    )

    priority = calculate_priority(
        current_stock,
        reorder_level,
        max_stock
    )

    candidate = {
        "candidate_id": candidate_id,

        "product_id": product_id,
        "product_name": product.get("product_name", ""),

        "store_id": store_id,

        "category": product.get("category", ""),
        "subcategory": product.get("subcategory", ""),
        "brand": product.get("brand", ""),
        "gender": product.get("gender", ""),

        "current_stock": current_stock,
        "reorder_level": reorder_level,
        "max_stock": max_stock,

        "shortage_qty": shortage_qty,
        "surplus_qty": surplus_qty,

        "stock_health": stock_health,

        "candidate_type": candidate_type,
        "priority": priority,

        "recommended_action": "PENDING",
        "decision_reason": "",

        "status": "PENDING",

        "created_at": created_at,
        "last_updated": now
    }

    create_or_update_document(
        OPTIMIZATION_CANDIDATES_COLLECTION,
        candidate_id,
        candidate,
        merge=False
    )

    return {
        "candidate_updated": True,
        "candidate_status": "CREATED_OR_UPDATED",
        "candidate_id": candidate_id
    }


def get_all_candidates():
    candidates = get_all_documents(
        OPTIMIZATION_CANDIDATES_COLLECTION
    )

    priority_order = {
        "HIGH": 1,
        "MEDIUM": 2,
        "LOW": 3
    }

    return sorted(
        candidates,
        key=lambda x: priority_order.get(
            x.get("priority", "LOW"),
            3
        )
    )


def get_candidate_by_id(candidate_id: str):
    return get_document_by_id(
        OPTIMIZATION_CANDIDATES_COLLECTION,
        candidate_id
    )


def get_candidates_by_store(store_id: str):
    candidates = get_all_candidates()

    return [
        item for item in candidates
        if item.get("store_id") == store_id
    ]


def get_candidates_by_priority(priority: str):
    candidates = get_all_candidates()
    priority = priority.upper()

    return [
        item for item in candidates
        if item.get("priority") == priority
    ]


def get_candidates_by_type(candidate_type: str):
    candidates = get_all_candidates()
    candidate_type = candidate_type.upper()

    return [
        item for item in candidates
        if item.get("candidate_type") == candidate_type
    ]


def get_candidates_by_status(status: str):
    candidates = get_all_candidates()
    status = status.upper()

    return [
        item for item in candidates
        if item.get("status") == status
    ]


def get_candidate_summary():
    candidates = get_all_candidates()

    summary = {
        "total_candidates": len(candidates),
        "high_priority": 0,
        "medium_priority": 0,
        "low_priority": 0,
        "low_stock": 0,
        "overstock": 0,
        "pending": 0,
        "analyzing": 0,
        "recommended": 0,
        "approved": 0,
        "completed": 0,
        "last_generated": get_now()
    }

    for item in candidates:
        priority = item.get("priority")
        candidate_type = item.get("candidate_type")
        status = item.get("status")

        if priority == "HIGH":
            summary["high_priority"] += 1
        elif priority == "MEDIUM":
            summary["medium_priority"] += 1
        elif priority == "LOW":
            summary["low_priority"] += 1

        if candidate_type == "LOW_STOCK":
            summary["low_stock"] += 1
        elif candidate_type == "OVERSTOCK":
            summary["overstock"] += 1

        if status == "PENDING":
            summary["pending"] += 1
        elif status == "ANALYZING":
            summary["analyzing"] += 1
        elif status == "RECOMMENDED":
            summary["recommended"] += 1
        elif status == "APPROVED":
            summary["approved"] += 1
        elif status == "COMPLETED":
            summary["completed"] += 1

    return summary