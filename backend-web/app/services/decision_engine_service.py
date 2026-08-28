from datetime import datetime
from firebase_admin import firestore

from app.services.firebase_service import (
    get_document_by_id,
    get_collection,
    update_document
)

from app.constants.collections import (
    INVENTORY_COLLECTION,
    OPTIMIZATION_CANDIDATES_COLLECTION
)


def to_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def get_now():
    return datetime.now().isoformat()


def get_product_inventory(product_id: str):
    docs = get_collection(INVENTORY_COLLECTION).where(
        "product_id",
        "==",
        product_id
    ).stream()

    inventory = []

    for doc in docs:
        item = doc.to_dict()
        item["id"] = doc.id
        inventory.append(item)

    return inventory


def calculate_surplus(item):
    current_stock = to_int(item.get("current_stock"))
    reorder_level = to_int(item.get("reorder_level"))

    return max(0, current_stock - reorder_level)


def calculate_shortage_percentage(shortage_qty: int, reorder_level: int):
    if reorder_level <= 0:
        return 0

    return round((shortage_qty / reorder_level) * 100, 2)


def calculate_shortage_severity(shortage_percentage: float):
    if shortage_percentage <= 0:
        return "NONE"
    if shortage_percentage <= 30:
        return "LOW"
    if shortage_percentage <= 60:
        return "MEDIUM"
    if shortage_percentage <= 85:
        return "HIGH"

    return "CRITICAL"


def calculate_transfer_feasibility(total_surplus: int, shortage_qty: int):
    if shortage_qty <= 0:
        return "NOT_REQUIRED"

    if total_surplus <= 0:
        return "IMPOSSIBLE"

    coverage_ratio = total_surplus / shortage_qty

    if coverage_ratio >= 1.5:
        return "HIGH"
    if coverage_ratio >= 1:
        return "MEDIUM"

    return "LOW"


def calculate_decision_confidence(
    shortage_qty: int,
    total_surplus: int,
    qualified_store_count: int,
    shortage_percentage: float
):
    if shortage_qty <= 0:
        return 90

    if total_surplus <= 0:
        return 60

    coverage_ratio = total_surplus / shortage_qty

    confidence = 55

    if coverage_ratio >= 1.5:
        confidence += 25
    elif coverage_ratio >= 1:
        confidence += 20
    elif coverage_ratio >= 0.5:
        confidence += 10
    else:
        confidence += 5

    if qualified_store_count >= 3:
        confidence += 10
    elif qualified_store_count == 2:
        confidence += 5

    if shortage_percentage >= 85:
        confidence += 5

    return min(confidence, 95)


def decide_low_stock(candidate: dict):
    product_id = candidate.get("product_id")
    target_store_id = candidate.get("store_id")

    shortage_qty = to_int(candidate.get("shortage_qty"))
    reorder_level = to_int(candidate.get("reorder_level"))
    
    if shortage_qty <= 0:
        return {
            "recommended_action": "NO_ACTION",
            "decision_confidence": 95,
            "decision_reason": (
                "Current stock meets the reorder level, so no stock "
                "transfer or reorder is required."
            ),
            "available_source_stores": 0,
            "qualified_source_stores": [],
            "qualified_source_details": [],
            "total_available_surplus": 0,
            "coverage_ratio": 0,
            "transfer_feasibility": "NOT_REQUIRED",
            "shortage_qty": 0,
            "shortage_percentage": 0,
            "shortage_severity": "NONE",
            "transfer_ready": False,
        }

    inventory_rows = get_product_inventory(product_id)

    qualified_source_stores = []

    for item in inventory_rows:
        store_id = item.get("store_id")

        if store_id == target_store_id:
            continue

        current_stock = to_int(item.get("current_stock"))
        source_reorder_level = to_int(item.get("reorder_level"))
        source_surplus = max(0, current_stock - source_reorder_level)

        if source_surplus <= 0:
            continue

        possible_transfer_qty = min(shortage_qty, source_surplus)
        source_stock_after_transfer = current_stock - possible_transfer_qty

        if source_stock_after_transfer >= source_reorder_level:
            qualified_source_stores.append({
                "store_id": store_id,
                "current_stock": current_stock,
                "reorder_level": source_reorder_level,
                "surplus_qty": source_surplus,
                "possible_transfer_qty": possible_transfer_qty,
                "stock_after_transfer": source_stock_after_transfer
            })

    qualified_source_stores = sorted(
        qualified_source_stores,
        key=lambda x: x["surplus_qty"],
        reverse=True
    )

    qualified_source_store_ids = [
        item["store_id"]
        for item in qualified_source_stores
    ]

    total_available_surplus = sum(
        item["surplus_qty"]
        for item in qualified_source_stores
    )

    available_source_stores = len(qualified_source_stores)

    coverage_ratio = 0
    if shortage_qty > 0:
        coverage_ratio = round(
            total_available_surplus / shortage_qty,
            2
        )

    shortage_percentage = calculate_shortage_percentage(
        shortage_qty,
        reorder_level
    )

    shortage_severity = calculate_shortage_severity(
        shortage_percentage
    )

    transfer_feasibility = calculate_transfer_feasibility(
        total_available_surplus,
        shortage_qty
    )

    confidence = calculate_decision_confidence(
        shortage_qty=shortage_qty,
        total_surplus=total_available_surplus,
        qualified_store_count=available_source_stores,
        shortage_percentage=shortage_percentage
    )

    if total_available_surplus > 0:
        return {
            "recommended_action": "TRANSFER",
            "decision_confidence": confidence,
            "decision_reason": (
                f"{available_source_stores} qualified showroom(s) can safely transfer stock. "
                f"Total qualified surplus is {total_available_surplus} units for shortage of {shortage_qty} units."
            ),
            "available_source_stores": available_source_stores,
            "qualified_source_stores": qualified_source_store_ids,
            "qualified_source_details": qualified_source_stores,
            "total_available_surplus": total_available_surplus,
            "coverage_ratio": coverage_ratio,
            "transfer_feasibility": transfer_feasibility,
            "shortage_qty": shortage_qty,
            "shortage_percentage": shortage_percentage,
            "shortage_severity": shortage_severity,
            "transfer_ready": transfer_feasibility in ["HIGH", "MEDIUM"]
        }

    return {
        "recommended_action": "REORDER",
        "decision_confidence": confidence,
        "decision_reason": (
            "No qualified showroom can safely transfer this product without dropping below its reorder level. "
            "Reorder is recommended."
        ),
        "available_source_stores": 0,
        "qualified_source_stores": [],
        "qualified_source_details": [],
        "total_available_surplus": 0,
        "coverage_ratio": 0,
        "transfer_feasibility": "IMPOSSIBLE",
        "shortage_qty": shortage_qty,
        "shortage_percentage": shortage_percentage,
        "shortage_severity": shortage_severity,
        "transfer_ready": False
    }


def decide_overstock(candidate: dict):
    surplus_qty = to_int(candidate.get("surplus_qty"))

    confidence = 80

    if surplus_qty > 100:
        confidence = 90
    elif surplus_qty > 50:
        confidence = 85

    return {
        "recommended_action": "PROMOTION",
        "decision_confidence": confidence,
        "decision_reason": (
            f"This product has {surplus_qty} surplus units above the healthy stock threshold. "
            "Promotion is recommended to reduce excess inventory."
        ),
        "available_source_stores": 0,
        "qualified_source_stores": [],
        "qualified_source_details": [],
        "total_available_surplus": surplus_qty,
        "coverage_ratio": 0,
        "transfer_feasibility": "NOT_REQUIRED",
        "shortage_qty": 0,
        "shortage_percentage": 0,
        "shortage_severity": "NONE",
        "transfer_ready": False
    }


def analyze_candidate(candidate_id: str):
    candidate = get_document_by_id(
        OPTIMIZATION_CANDIDATES_COLLECTION,
        candidate_id
    )

    if candidate is None:
        return None

    update_document(
        OPTIMIZATION_CANDIDATES_COLLECTION,
        candidate_id,
        {
            "status": "ANALYZING",
            "last_updated": get_now()
        }
    )

    candidate_type = candidate.get("candidate_type")
    

    if candidate_type == "LOW_STOCK":
        decision = decide_low_stock(candidate)
    elif candidate_type == "OVERSTOCK":
        decision = decide_overstock(candidate)
    else:
        decision = {
            "recommended_action": "NO_ACTION",
            "decision_confidence": 70,
            "decision_reason": "Candidate does not require stock optimization action.",
            "available_source_stores": 0,
            "qualified_source_stores": [],
            "qualified_source_details": [],
            "total_available_surplus": 0,
            "coverage_ratio": 0,
            "transfer_feasibility": "NOT_REQUIRED",
            "shortage_qty": 0,
            "shortage_percentage": 0,
            "shortage_severity": "NONE",
            "transfer_ready": False
        }

    # update_data = {
    #     **decision,
    #     "status": "RECOMMENDED",
    #     "decision_time": get_now(),
    #     "last_updated": get_now()
    # }

    update_data = {
        **decision,
        "status": "RECOMMENDED",
        "decision_time": get_now(),
        "last_updated": get_now(),

        # remove old field from previous Decision Engine version
        "eligible_source_stores": firestore.DELETE_FIELD
    }

    update_document(
        OPTIMIZATION_CANDIDATES_COLLECTION,
        candidate_id,
        update_data
    )

    updated_candidate = get_document_by_id(
        OPTIMIZATION_CANDIDATES_COLLECTION,
        candidate_id
    )

    return {
        "candidate_id": candidate_id,
        "decision": decision,
        "candidate": updated_candidate
    }