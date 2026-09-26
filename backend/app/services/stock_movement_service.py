"""
Stock movement service.

Responsibilities:
1. Generate deterministic transfer recommendations.
2. Rank qualified source stores using business criteria.
3. Create and version stock-movement records.
4. Trigger one cached AI explanation for each new movement.
5. Manage approve, reject and cancel workflows.
6. Execute approved transfers.
7. Update source and target inventory.
8. Refresh analytics and optimization candidates.
9. Create inventory transaction records.
10. Generate one cached AI execution summary after execution.
"""

from datetime import datetime
from typing import Any, Optional

from app.constants.collections import (
    INVENTORY_COLLECTION,
    INVENTORY_TRANSACTIONS_COLLECTION,
    OPTIMIZATION_CANDIDATES_COLLECTION,
    STOCK_MOVEMENTS_COLLECTION
)

from app.services.analytics_summary_service import (
    refresh_summaries_after_inventory_update
)

from app.services.explanation_service import (
    generate_and_save_execution_summary,
    generate_and_save_recommendation_explanation
)

from app.services.firebase_service import (
    create_or_update_document,
    get_all_documents,
    get_collection,
    get_document_by_id,
    update_document
)

from app.services.inventory_service import (
    clear_inventory_cache
)

from app.services.optimization_candidate_service import (
    update_optimization_candidate
)

from app.services.store_distance_service import (
    get_route_information
)


# ==========================================================
# CONFIGURATION
# ==========================================================

RECOMMENDATION_ALGORITHM = (
    "transfer_ranking_v2.1_business_criteria_xai"
)


# ==========================================================
# GENERAL HELPERS
# ==========================================================

def now() -> str:
    return datetime.now().isoformat()


def to_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def to_float(
    value: Any,
    default: float = 0.0
) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def build_status_history_entry(
    status: str
) -> dict:
    return {
        "status": status,
        "time": now()
    }


def append_status_history(
    movement: dict,
    status: str
) -> list:
    history = list(
        movement.get("status_history") or []
    )

    history.append(
        build_status_history_entry(status)
    )

    return history


def generate_movement_id(
    candidate_id: str,
    version: int
) -> str:
    date_part = datetime.now().strftime(
        "%Y%m%d"
    )

    return (
        f"MOV-{date_part}-"
        f"{candidate_id}-V{version}"
    )


def generate_transaction_id(
    movement_id: str
) -> str:
    date_part = datetime.now().strftime(
        "%Y%m%d"
    )

    return (
        f"TXN-{date_part}-{movement_id}"
    )


# ==========================================================
# QUERY FUNCTIONS
# ==========================================================

def get_all_stock_movements() -> list:
    movements = get_all_documents(
        STOCK_MOVEMENTS_COLLECTION
    )

    return sorted(
        movements,
        key=lambda item: item.get(
            "created_at",
            ""
        ),
        reverse=True
    )


def get_stock_movement_by_id(
    movement_id: str
) -> Optional[dict]:
    return get_document_by_id(
        STOCK_MOVEMENTS_COLLECTION,
        movement_id
    )


def get_next_recommendation_version(
    candidate_id: str
) -> int:
    movements = get_all_documents(
        STOCK_MOVEMENTS_COLLECTION
    )

    versions = [
        to_int(
            movement.get(
                "recommendation_version"
            )
        )
        for movement in movements
        if movement.get("candidate_id")
        == candidate_id
    ]

    return max(versions, default=0) + 1


def get_inventory_by_store_and_product(
    store_id: str,
    product_id: str
) -> Optional[dict]:
    """
    Find the inventory document for one
    product in one store.
    """

    docs = (
        get_collection(INVENTORY_COLLECTION)
        .where(
            "store_id",
            "==",
            store_id
        )
        .where(
            "product_id",
            "==",
            product_id
        )
        .limit(1)
        .stream()
    )

    for doc in docs:
        item = doc.to_dict()
        item["id"] = doc.id
        return item

    return None


# ==========================================================
# RECOMMENDATION CONFIDENCE
# ==========================================================

def calculate_recommendation_confidence(
    source: dict
) -> int:
    """
    Confidence describes the strength of the
    selected recommendation.

    It does not select the source showroom.
    """

    confidence = 60

    coverage = to_float(
        source.get("coverage_percentage")
    )

    distance = to_float(
        source.get("distance_km"),
        999
    )

    remaining_buffer = to_int(
        source.get("remaining_buffer")
    )

    reorder_level = to_int(
        source.get("reorder_level")
    )

    estimated_cost = to_float(
        source.get("estimated_transfer_cost"),
        999999
    )

    risk = source.get(
        "risk_after_transfer"
    )

    if coverage >= 100:
        confidence += 15
    elif coverage >= 75:
        confidence += 10
    elif coverage > 0:
        confidence += 5

    if distance <= 5:
        confidence += 10
    elif distance <= 10:
        confidence += 8
    elif distance <= 20:
        confidence += 5

    if remaining_buffer >= reorder_level:
        confidence += 10
    elif remaining_buffer > 0:
        confidence += 5

    if estimated_cost <= 1000:
        confidence += 5
    elif estimated_cost <= 3000:
        confidence += 3

    if risk == "LOW":
        confidence += 3
    elif risk == "HIGH":
        confidence -= 10

    return max(
        0,
        min(confidence, 98)
    )


def get_confidence_label(
    confidence: int
) -> str:
    if confidence >= 90:
        return "VERY_HIGH"

    if confidence >= 80:
        return "HIGH"

    if confidence >= 70:
        return "MEDIUM"

    return "LOW"


# ==========================================================
# SOURCE STORE EVALUATION
# ==========================================================

def calculate_risk_after_transfer(
    remaining_buffer: int,
    reorder_level: int
) -> str:
    if remaining_buffer <= 0:
        return "HIGH"

    if (
        reorder_level > 0
        and remaining_buffer
        < reorder_level * 0.25
    ):
        return "MEDIUM"

    return "LOW"


def build_evaluated_sources(
    qualified_sources: list,
    shortage_qty: int,
    target_store_id: str
) -> list:
    """
    Apply hard business constraints and rank
    valid source showrooms.

    Ranking priority:
    1. Highest coverage
    2. Lowest estimated transport cost
    3. Lowest distance
    4. Lowest travel time
    5. Highest remaining buffer
    6. Highest available surplus
    """

    evaluated_sources = []

    for source in qualified_sources:
        source_store_id = source.get(
            "store_id"
        )

        if not source_store_id:
            continue

        current_stock = to_int(
            source.get("current_stock")
        )

        reorder_level = to_int(
            source.get("reorder_level")
        )

        surplus_qty = to_int(
            source.get("surplus_qty")
        )

        possible_transfer_qty = to_int(
            source.get(
                "possible_transfer_qty"
            )
        )

        stock_after_transfer = to_int(
            source.get(
                "stock_after_transfer"
            )
        )

        # Hard constraint 1:
        # Source must provide some stock.
        if possible_transfer_qty <= 0:
            continue

        # Hard constraint 2:
        # Source must remain above reorder level.
        if (
            stock_after_transfer
            < reorder_level
        ):
            continue

        route_info = get_route_information(
            source_store_id,
            target_store_id
        )

        # Missing route information should make
        # a source less attractive but should not
        # crash recommendation generation.
        if route_info is None:
            distance_km = 999.0
            estimated_time_minutes = 999
            estimated_transfer_cost = 999999.0
            route_available = False
        else:
            distance_km = to_float(
                route_info.get("distance_km"),
                999
            )

            estimated_time_minutes = to_int(
                route_info.get(
                    "estimated_time_minutes"
                ),
                999
            )

            estimated_transfer_cost = to_float(
                route_info.get(
                    "estimated_transfer_cost"
                ),
                999999
            )

            route_available = True

        coverage_percentage = 0.0

        if shortage_qty > 0:
            coverage_percentage = round(
                (
                    possible_transfer_qty
                    / shortage_qty
                )
                * 100,
                2
            )

        remaining_buffer = (
            stock_after_transfer
            - reorder_level
        )

        risk_after_transfer = (
            calculate_risk_after_transfer(
                remaining_buffer,
                reorder_level
            )
        )

        evaluated_sources.append({
            "store_id": source_store_id,

            "current_stock": current_stock,
            "reorder_level": reorder_level,
            "surplus_qty": surplus_qty,

            "possible_transfer_qty": (
                possible_transfer_qty
            ),

            "stock_after_transfer": (
                stock_after_transfer
            ),

            "remaining_buffer": (
                remaining_buffer
            ),

            "coverage_percentage": (
                coverage_percentage
            ),

            "risk_after_transfer": (
                risk_after_transfer
            ),

            "route_available": (
                route_available
            ),

            "distance_km": distance_km,

            "estimated_time_minutes": (
                estimated_time_minutes
            ),

            "estimated_transfer_cost": (
                estimated_transfer_cost
            )
        })

    evaluated_sources = sorted(
        evaluated_sources,
        key=lambda source: (
            -to_float(
                source.get(
                    "coverage_percentage"
                )
            ),

            to_float(
                source.get(
                    "estimated_transfer_cost"
                ),
                999999
            ),

            to_float(
                source.get("distance_km"),
                999
            ),

            to_int(
                source.get(
                    "estimated_time_minutes"
                ),
                999
            ),

            -to_int(
                source.get(
                    "remaining_buffer"
                )
            ),

            -to_int(
                source.get("surplus_qty")
            )
        )
    )

    ranked_sources = []

    for rank, source in enumerate(
        evaluated_sources,
        start=1
    ):
        ranked_sources.append({
            **source,
            "rank": rank
        })

    return ranked_sources


# ==========================================================
# TRANSFER PRIORITY
# ==========================================================

def calculate_transfer_priority(
    coverage_percentage: float,
    confidence: int,
    risk_after_transfer: str
) -> str:
    if (
        coverage_percentage >= 100
        and confidence >= 90
        and risk_after_transfer == "LOW"
    ):
        return "HIGH"

    if (
        coverage_percentage >= 75
        and confidence >= 80
        and risk_after_transfer
        in {"LOW", "MEDIUM"}
    ):
        return "MEDIUM"

    return "LOW"


# ==========================================================
# DETERMINISTIC RECOMMENDATION REASON
# ==========================================================

def build_recommendation_reason(
    best_source: dict,
    recommended_qty: int,
    target_store_id: str
) -> str:
    """
    Safe fallback explanation generated without AI.
    """

    return (
        f"{best_source.get('store_id')} is recommended "
        f"to transfer {recommended_qty} units to "
        f"{target_store_id}. The source can cover "
        f"{best_source.get('coverage_percentage')}% "
        f"of the shortage and remain "
        f"{best_source.get('remaining_buffer')} units "
        f"above its reorder level. The route is "
        f"{best_source.get('distance_km')} km with an "
        f"estimated transfer cost of LKR "
        f"{best_source.get('estimated_transfer_cost')}."
    )


# ==========================================================
# AI SAFE-CALL HELPERS
# ==========================================================

def try_generate_recommendation_explanation(
    movement_id: str
) -> Optional[dict]:
    """
    AI failure must not prevent recommendation creation.
    """

    try:
        result = (
            generate_and_save_recommendation_explanation(
                movement_id=movement_id
            )
        )

        if isinstance(result, dict):
            return result

    except Exception as exc:
        update_document(
            STOCK_MOVEMENTS_COLLECTION,
            movement_id,
            {
                "ai_explanation_generated": False,
                "ai_explanation_error": str(exc),
                "ai_explanation_updated_at": now(),
                "updated_at": now()
            }
        )

    return None


def try_generate_execution_summary(
    movement_id: str
) -> Optional[dict]:
    """
    AI failure must not reverse a completed transfer.
    """

    try:
        result = (
            generate_and_save_execution_summary(
                movement_id=movement_id
            )
        )

        if (
            isinstance(result, dict)
            and "error" not in result
        ):
            return result

    except Exception as exc:
        update_document(
            STOCK_MOVEMENTS_COLLECTION,
            movement_id,
            {
                "ai_execution_summary_generated": (
                    False
                ),
                "ai_execution_summary_error": (
                    str(exc)
                ),
                "ai_execution_summary_updated_at": (
                    now()
                ),
                "updated_at": now()
            }
        )

    return None


# ==========================================================
# RECOMMEND TRANSFER
# ==========================================================

def recommend_transfer(
    candidate_id: str
):
    candidate = get_document_by_id(
        OPTIMIZATION_CANDIDATES_COLLECTION,
        candidate_id
    )

    if candidate is None:
        return None

    if (
        candidate.get("recommended_action")
        != "TRANSFER"
    ):
        return {
            "error": (
                "Candidate is not recommended "
                "for transfer"
            ),
            "recommended_action": (
                candidate.get(
                    "recommended_action"
                )
            )
        }

    if not candidate.get("transfer_ready"):
        return {
            "error": (
                "Transfer is not ready for "
                "this candidate"
            ),
            "transfer_feasibility": (
                candidate.get(
                    "transfer_feasibility"
                )
            )
        }

    qualified_sources = (
        candidate.get(
            "qualified_source_details",
            []
        )
        or []
    )

    if not qualified_sources:
        return {
            "error": (
                "No qualified source stores found"
            )
        }

    shortage_qty = to_int(
        candidate.get("shortage_qty")
    )

    target_stock_before = to_int(
        candidate.get("current_stock")
    )

    target_reorder_level = to_int(
        candidate.get("reorder_level")
    )

    target_store_id = candidate.get(
        "store_id"
    )

    if shortage_qty <= 0:
        return {
            "error": (
                "Candidate does not have a valid "
                "shortage quantity"
            ),
            "shortage_qty": shortage_qty
        }

    if not target_store_id:
        return {
            "error": (
                "Candidate target store is missing"
            )
        }

    evaluated_sources = (
        build_evaluated_sources(
            qualified_sources=qualified_sources,
            shortage_qty=shortage_qty,
            target_store_id=target_store_id
        )
    )

    if not evaluated_sources:
        return {
            "error": (
                "No valid evaluated source stores found"
            )
        }

    best_source = evaluated_sources[0]

    recommended_qty = min(
        shortage_qty,
        to_int(
            best_source.get(
                "possible_transfer_qty"
            )
        )
    )

    if recommended_qty <= 0:
        return {
            "error": (
                "Unable to calculate a valid "
                "transfer quantity"
            )
        }

    source_stock_before = to_int(
        best_source.get("current_stock")
    )

    source_reorder_level = to_int(
        best_source.get("reorder_level")
    )

    source_stock_after = (
        source_stock_before
        - recommended_qty
    )

    target_stock_after = (
        target_stock_before
        + recommended_qty
    )

    coverage_percentage = round(
        (
            recommended_qty
            / shortage_qty
        )
        * 100,
        2
    )

    remaining_buffer = (
        source_stock_after
        - source_reorder_level
    )

    simulation_status = "SAFE"

    if (
        source_stock_after
        < source_reorder_level
    ):
        simulation_status = "UNSAFE"

    elif (
        target_stock_after
        < target_reorder_level
    ):
        simulation_status = "PARTIAL"

    recommendation_confidence = (
        calculate_recommendation_confidence(
            best_source
        )
    )

    recommendation_confidence_label = (
        get_confidence_label(
            recommendation_confidence
        )
    )

    transfer_priority = (
        calculate_transfer_priority(
            coverage_percentage=(
                coverage_percentage
            ),
            confidence=(
                recommendation_confidence
            ),
            risk_after_transfer=(
                best_source.get(
                    "risk_after_transfer"
                )
            )
        )
    )

    version = get_next_recommendation_version(
        candidate_id
    )

    movement_id = generate_movement_id(
        candidate_id,
        version
    )

    alternative_sources = [
        source.get("store_id")
        for source in evaluated_sources[1:4]
    ]

    recommendation_reason = (
        build_recommendation_reason(
            best_source=best_source,
            recommended_qty=recommended_qty,
            target_store_id=target_store_id
        )
    )

    movement_timestamp = now()

    movement = {
        # Identity
        "movement_id": movement_id,
        "candidate_id": candidate_id,
        "recommendation_version": version,

        # Workflow
        "movement_type": "TRANSFER",
        "movement_status": "RECOMMENDED",
        "previous_status": None,

        "status_history": [
            {
                "status": "RECOMMENDED",
                "time": movement_timestamp
            }
        ],

        # Workflow flags
        "is_approved": False,
        "is_rejected": False,
        "is_cancelled": False,
        "is_executed": False,

        # Recommendation metadata
        "is_ai_generated": True,
        "is_ai_explanation_enabled": True,

        "recommendation_algorithm": (
            RECOMMENDATION_ALGORITHM
        ),

        "recommendation_rank": 1,

        # AI recommendation explanation cache
        "ai_explanation": None,
        "ai_explanation_context": None,

        "ai_explanation_generated": False,
        "ai_explanation_source": None,
        "ai_explanation_model": None,
        "ai_explanation_version": None,

        "ai_explanation_generated_at": None,
        "ai_explanation_updated_at": None,
        "ai_explanation_error": None,

        # AI execution summary cache
        "ai_execution_summary": None,
        "ai_execution_context": None,

        "ai_execution_summary_generated": False,
        "ai_execution_summary_source": None,
        "ai_execution_summary_model": None,
        "ai_execution_summary_version": None,

        "ai_execution_summary_generated_at": None,
        "ai_execution_summary_updated_at": None,
        "ai_execution_summary_error": None,

        # Product
        "product_id": candidate.get(
            "product_id"
        ),

        "product_name": candidate.get(
            "product_name"
        ),

        "category": candidate.get(
            "category"
        ),

        "subcategory": candidate.get(
            "subcategory"
        ),

        "brand": candidate.get("brand"),
        "gender": candidate.get("gender"),

        # Transfer
        "from_store": best_source.get(
            "store_id"
        ),

        "to_store": target_store_id,

        "recommended_qty": (
            recommended_qty
        ),

        # Simulated stock
        "source_stock_before": (
            source_stock_before
        ),

        "source_stock_after": (
            source_stock_after
        ),

        "target_stock_before": (
            target_stock_before
        ),

        "target_stock_after": (
            target_stock_after
        ),

        "source_reorder_level": (
            source_reorder_level
        ),

        "target_reorder_level": (
            target_reorder_level
        ),

        # Decision metrics
        "coverage_percentage": (
            coverage_percentage
        ),

        "remaining_buffer": (
            remaining_buffer
        ),

        "risk_after_transfer": (
            best_source.get(
                "risk_after_transfer"
            )
        ),

        "simulation_status": (
            simulation_status
        ),

        # Logistics
        "route_available": (
            best_source.get(
                "route_available"
            )
        ),

        "distance_km": best_source.get(
            "distance_km"
        ),

        "estimated_time_minutes": (
            best_source.get(
                "estimated_time_minutes"
            )
        ),

        "estimated_transfer_cost": (
            best_source.get(
                "estimated_transfer_cost"
            )
        ),

        # Confidence and priority
        "recommendation_confidence": (
            recommendation_confidence
        ),

        "recommendation_confidence_label": (
            recommendation_confidence_label
        ),

        "transfer_priority": (
            transfer_priority
        ),

        # Alternatives and impact
        "alternative_sources": (
            alternative_sources
        ),

        "estimated_stock_improvement": {
            "before": target_stock_before,
            "after": target_stock_after,
            "improvement": recommended_qty
        },

        "evaluated_sources": (
            evaluated_sources
        ),

        "decision_confidence": (
            candidate.get(
                "decision_confidence"
            )
        ),

        "recommendation_reason": (
            recommendation_reason
        ),

        # Approval
        "approved_by": None,
        "approved_at": None,

        # Rejection
        "rejected_by": None,
        "rejected_at": None,
        "rejection_reason": None,

        # Cancellation
        "cancelled_by": None,
        "cancelled_at": None,
        "cancel_reason": None,

        # Execution
        "executed_by": None,
        "executed_at": None,
        "execution_error": None,

        "transaction_id": None,

        # Timestamps
        "created_at": movement_timestamp,
        "updated_at": movement_timestamp
    }

    create_or_update_document(
        STOCK_MOVEMENTS_COLLECTION,
        movement_id,
        movement,
        merge=False
    )

    update_document(
        OPTIMIZATION_CANDIDATES_COLLECTION,
        candidate_id,
        {
            "status": "RECOMMENDED",
            "latest_movement_id": movement_id,
            "latest_recommendation_version": (
                version
            ),
            "last_updated": now()
        }
    )

    # Generate once and save into this exact
    # movement version. Failure does not prevent
    # recommendation creation.
    updated_movement = (
        try_generate_recommendation_explanation(
            movement_id
        )
    )

    if updated_movement is not None:
        return updated_movement

    return get_stock_movement_by_id(
        movement_id
    )


# ==========================================================
# APPROVE MOVEMENT
# ==========================================================

def approve_movement(
    movement_id: str
):
    movement = get_stock_movement_by_id(
        movement_id
    )

    if movement is None:
        return None

    current_status = movement.get(
        "movement_status"
    )

    if current_status != "RECOMMENDED":
        return {
            "error": (
                "Only recommended movements "
                "can be approved"
            ),
            "current_status": current_status
        }

    update_timestamp = now()

    update_document(
        STOCK_MOVEMENTS_COLLECTION,
        movement_id,
        {
            "movement_status": "APPROVED",
            "previous_status": current_status,

            "is_approved": True,
            "is_rejected": False,
            "is_cancelled": False,
            "is_executed": False,

            "approved_by": None,
            "approved_at": update_timestamp,

            "status_history": (
                append_status_history(
                    movement,
                    "APPROVED"
                )
            ),

            "updated_at": update_timestamp
        }
    )

    return get_stock_movement_by_id(
        movement_id
    )


# ==========================================================
# REJECT MOVEMENT
# ==========================================================

def reject_movement(
    movement_id: str,
    rejection_reason: Optional[str] = None
):
    movement = get_stock_movement_by_id(
        movement_id
    )

    if movement is None:
        return None

    current_status = movement.get(
        "movement_status"
    )

    if current_status != "RECOMMENDED":
        return {
            "error": (
                "Only recommended movements "
                "can be rejected"
            ),
            "current_status": current_status
        }

    update_timestamp = now()

    update_document(
        STOCK_MOVEMENTS_COLLECTION,
        movement_id,
        {
            "movement_status": "REJECTED",
            "previous_status": current_status,

            "is_approved": False,
            "is_rejected": True,
            "is_cancelled": False,
            "is_executed": False,

            "rejected_by": None,
            "rejected_at": update_timestamp,
            "rejection_reason": (
                rejection_reason
            ),

            "status_history": (
                append_status_history(
                    movement,
                    "REJECTED"
                )
            ),

            "updated_at": update_timestamp
        }
    )

    return get_stock_movement_by_id(
        movement_id
    )


# ==========================================================
# CANCEL MOVEMENT
# ==========================================================

def cancel_movement(
    movement_id: str,
    cancel_reason: Optional[str] = None
):
    movement = get_stock_movement_by_id(
        movement_id
    )

    if movement is None:
        return None

    current_status = movement.get(
        "movement_status"
    )

    if current_status not in {
        "RECOMMENDED",
        "APPROVED"
    }:
        return {
            "error": (
                "Only recommended or approved "
                "movements can be cancelled"
            ),
            "current_status": current_status
        }

    update_timestamp = now()

    update_data = {
        "movement_status": "CANCELLED",
        "previous_status": current_status,

        "is_cancelled": True,
        "is_executed": False,

        "cancelled_by": None,
        "cancelled_at": update_timestamp,
        "cancel_reason": cancel_reason,

        "status_history": (
            append_status_history(
                movement,
                "CANCELLED"
            )
        ),

        "updated_at": update_timestamp
    }

    # Preserve historical approval if the
    # movement was approved before cancellation.
    if current_status == "RECOMMENDED":
        update_data["is_approved"] = False

    update_document(
        STOCK_MOVEMENTS_COLLECTION,
        movement_id,
        update_data
    )

    return get_stock_movement_by_id(
        movement_id
    )


# ==========================================================
# EXECUTION VALIDATION
# ==========================================================

def validate_execution_state(
    movement: dict
) -> Optional[dict]:
    if movement.get("is_executed") is True:
        return {
            "error": "Movement already executed",
            "current_status": movement.get(
                "movement_status"
            ),
            "transaction_id": movement.get(
                "transaction_id"
            )
        }

    if (
        movement.get("movement_status")
        != "APPROVED"
    ):
        return {
            "error": (
                "Only approved movements can "
                "be executed"
            ),
            "current_status": movement.get(
                "movement_status"
            )
        }

    if (
        movement.get("movement_type")
        != "TRANSFER"
    ):
        return {
            "error": (
                "Only transfer movements can "
                "be executed"
            ),
            "movement_type": movement.get(
                "movement_type"
            )
        }

    return None


# ==========================================================
# EXECUTE MOVEMENT
# ==========================================================

def execute_movement(
    movement_id: str
):
    movement = get_stock_movement_by_id(
        movement_id
    )

    if movement is None:
        return None

    state_error = validate_execution_state(
        movement
    )

    if state_error:
        return state_error

    product_id = movement.get(
        "product_id"
    )

    from_store = movement.get(
        "from_store"
    )

    to_store = movement.get(
        "to_store"
    )

    quantity = to_int(
        movement.get("recommended_qty")
    )

    if not product_id:
        return {
            "error": (
                "Movement product ID is missing"
            )
        }

    if not from_store or not to_store:
        return {
            "error": (
                "Movement source or target "
                "store is missing"
            )
        }

    if from_store == to_store:
        return {
            "error": (
                "Source and target stores "
                "cannot be the same"
            )
        }

    if quantity <= 0:
        return {
            "error": (
                "Invalid transfer quantity"
            ),
            "recommended_qty": quantity
        }

    source_inventory = (
        get_inventory_by_store_and_product(
            from_store,
            product_id
        )
    )

    target_inventory = (
        get_inventory_by_store_and_product(
            to_store,
            product_id
        )
    )

    if source_inventory is None:
        return {
            "error": (
                "Source inventory record "
                "not found"
            ),
            "store_id": from_store,
            "product_id": product_id
        }

    if target_inventory is None:
        return {
            "error": (
                "Target inventory record "
                "not found"
            ),
            "store_id": to_store,
            "product_id": product_id
        }

    source_current_stock = to_int(
        source_inventory.get("current_stock")
    )

    target_current_stock = to_int(
        target_inventory.get("current_stock")
    )

    source_reorder_level = to_int(
        source_inventory.get(
            "reorder_level"
        )
    )

    source_new_stock = (
        source_current_stock
        - quantity
    )

    target_new_stock = (
        target_current_stock
        + quantity
    )

    if source_current_stock < quantity:
        return {
            "error": (
                "Source store does not have "
                "enough stock"
            ),
            "source_current_stock": (
                source_current_stock
            ),
            "required_qty": quantity
        }

    if (
        source_new_stock
        < source_reorder_level
    ):
        return {
            "error": (
                "Execution would drop source "
                "below its reorder level"
            ),
            "source_stock_after": (
                source_new_stock
            ),
            "source_reorder_level": (
                source_reorder_level
            )
        }

    in_progress_history = (
        append_status_history(
            movement,
            "IN_PROGRESS"
        )
    )

    in_progress_timestamp = now()

    update_document(
        STOCK_MOVEMENTS_COLLECTION,
        movement_id,
        {
            "movement_status": "IN_PROGRESS",
            "previous_status": "APPROVED",

            "status_history": (
                in_progress_history
            ),

            "execution_started_at": (
                in_progress_timestamp
            ),

            "execution_error": None,
            "updated_at": (
                in_progress_timestamp
            )
        }
    )

    try:
        old_source_inventory = (
            source_inventory.copy()
        )

        old_target_inventory = (
            target_inventory.copy()
        )

        new_source_inventory = (
            source_inventory.copy()
        )

        new_target_inventory = (
            target_inventory.copy()
        )

        new_source_inventory[
            "current_stock"
        ] = source_new_stock

        new_target_inventory[
            "current_stock"
        ] = target_new_stock

        # Update source inventory.
        source_update_result = update_document(
            INVENTORY_COLLECTION,
            source_inventory["id"],
            {
                "current_stock": (
                    source_new_stock
                )
            }
        )

        if source_update_result is None:
            raise RuntimeError(
                "Source inventory update failed"
            )

        # Update target inventory.
        target_update_result = update_document(
            INVENTORY_COLLECTION,
            target_inventory["id"],
            {
                "current_stock": (
                    target_new_stock
                )
            }
        )

        if target_update_result is None:
            raise RuntimeError(
                "Target inventory update failed"
            )

        # Refresh analytics incrementally.
        refresh_summaries_after_inventory_update(
            old_inventory=(
                old_source_inventory
            ),
            new_inventory=(
                new_source_inventory
            )
        )

        refresh_summaries_after_inventory_update(
            old_inventory=(
                old_target_inventory
            ),
            new_inventory=(
                new_target_inventory
            )
        )

        # Re-evaluate optimization candidates
        # for both affected inventory records.
        update_optimization_candidate(
            new_source_inventory
        )

        update_optimization_candidate(
            new_target_inventory
        )

        clear_inventory_cache()

        transaction_id = (
            generate_transaction_id(
                movement_id
            )
        )

        transaction_timestamp = now()

        transaction = {
            "transaction_id": (
                transaction_id
            ),

            "movement_id": movement_id,
            "candidate_id": movement.get(
                "candidate_id"
            ),

            "transaction_type": "TRANSFER",
            "transaction_status": "COMPLETED",

            "product_id": product_id,

            "product_name": movement.get(
                "product_name"
            ),

            "from_store": from_store,
            "to_store": to_store,

            "quantity": quantity,

            "source_inventory_id": (
                source_inventory.get("id")
            ),

            "target_inventory_id": (
                target_inventory.get("id")
            ),

            "source_stock_before": (
                source_current_stock
            ),

            "source_stock_after": (
                source_new_stock
            ),

            "target_stock_before": (
                target_current_stock
            ),

            "target_stock_after": (
                target_new_stock
            ),

            "executed_by": None,
            "created_at": (
                transaction_timestamp
            ),
            "updated_at": (
                transaction_timestamp
            )
        }

        create_or_update_document(
            INVENTORY_TRANSACTIONS_COLLECTION,
            transaction_id,
            transaction,
            merge=False
        )

        executed_history = list(
            in_progress_history
        )

        executed_timestamp = now()

        executed_history.append({
            "status": "EXECUTED",
            "time": executed_timestamp
        })

        update_document(
            STOCK_MOVEMENTS_COLLECTION,
            movement_id,
            {
                "movement_status": "EXECUTED",
                "previous_status": (
                    "IN_PROGRESS"
                ),

                "is_executed": True,

                # Approval remains true because
                # execution followed approval.
                "is_approved": True,

                "executed_by": None,
                "executed_at": (
                    executed_timestamp
                ),

                "actual_source_stock_before": (
                    source_current_stock
                ),

                "actual_source_stock_after": (
                    source_new_stock
                ),

                "actual_target_stock_before": (
                    target_current_stock
                ),

                "actual_target_stock_after": (
                    target_new_stock
                ),

                "transaction_id": (
                    transaction_id
                ),

                "execution_error": None,

                "status_history": (
                    executed_history
                ),

                "updated_at": (
                    executed_timestamp
                )
            }
        )

        # Generate the execution summary once.
        # Failure here must not undo inventory changes.
        updated_movement = (
            try_generate_execution_summary(
                movement_id
            )
        )

        if updated_movement is not None:
            return updated_movement

        return get_stock_movement_by_id(
            movement_id
        )

    except Exception as exc:
        failed_timestamp = now()

        failed_history = list(
            in_progress_history
        )

        failed_history.append({
            "status": "FAILED",
            "time": failed_timestamp
        })

        update_document(
            STOCK_MOVEMENTS_COLLECTION,
            movement_id,
            {
                "movement_status": "FAILED",
                "previous_status": (
                    "IN_PROGRESS"
                ),

                "is_executed": False,

                "execution_error": str(exc),

                "status_history": (
                    failed_history
                ),

                "updated_at": (
                    failed_timestamp
                )
            }
        )

        return {
            "error": "Execution failed",
            "details": str(exc),
            "movement_id": movement_id
        }