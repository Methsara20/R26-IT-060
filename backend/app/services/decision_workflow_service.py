import hashlib
import math
from datetime import datetime, timedelta
from typing import Any

from google.api_core.exceptions import (
    AlreadyExists,
    ResourceExhausted,
)
from google.cloud.firestore_v1.base_query import FieldFilter

from app.constants.collections import (
    DECISION_WORKFLOWS_COLLECTION,
    OPTIMIZATION_CANDIDATES_COLLECTION,
    INVENTORY_COLLECTION,
)

from app.schemas.decision_workflow_schema import (
    DecisionWorkflowForecastType,
    DecisionWorkflowRequest,
)

from app.services.daily_forecast_service import (
    generate_7_day_forecast,
    generate_custom_forecast,
    predict_next_day,
)

from app.services.decision_engine_service import (
    analyze_candidate,
)

from app.services.firebase_service import (
    create_or_update_document,
    get_collection,
    get_document_by_id,
)

from app.services.intelligence_service import (
    generate_inventory_intelligence,
)

from app.services.product_service import (
    get_product_by_id,
)

from app.services.stock_movement_service import (
    get_stock_movement_by_id,
    recommend_transfer,
)

from app.services.store_service import (
    get_store_by_id,
)


# ==========================================================
# WORKFLOW STATUS → NEXT ACTION
# ==========================================================

NEXT_ACTION_BY_STATUS = {
    "PROCESSING": "WAIT_FOR_COMPLETION",
    "FORECAST_READY": "WAIT_FOR_COMPLETION",
    "INTELLIGENCE_READY": "WAIT_FOR_COMPLETION",
    "OPTIMIZATION_REQUIRED": "WAIT_FOR_COMPLETION",
    "NO_ACTION_REQUIRED": "NONE",
    "CANDIDATE_ANALYZED": "REVIEW_OPTIMIZATION",
    "MOVEMENT_RECOMMENDED": "MANAGER_REVIEW",
    "REORDER_RECOMMENDED": "REVIEW_REORDER",
    "FAILED": "RETRY_OR_REVIEW",
}


# ==========================================================
# SAFE FAILURE MESSAGES
# ==========================================================

FAILURE_MESSAGES = {
    "CATALOG_LOOKUP":
        "Unable to load the requested product or store.",

    "INVENTORY_LOOKUP":
        "Unable to load inventory for the requested item.",

    "FORECAST":
        "Unable to generate forecast.",

    "INTELLIGENCE":
        "Unable to analyze inventory intelligence.",

    "CANDIDATE_CREATION":
        "Unable to create the optimization candidate.",

    "DECISION_ANALYSIS":
        "Unable to analyze the optimization candidate.",

    "MOVEMENT_RECOMMENDATION":
        "Unable to create a stock movement recommendation.",
}


# ==========================================================
# CUSTOM EXCEPTIONS
# ==========================================================

class DecisionWorkflowValidationError(ValueError):
    pass


class DecisionWorkflowNotFoundError(LookupError):
    pass


class DecisionWorkflowQuotaError(RuntimeError):
    pass


class DecisionWorkflowExecutionError(RuntimeError):
    pass


# ==========================================================
# GENERAL HELPERS
# ==========================================================

def _now() -> str:
    return datetime.now().isoformat()


def _workflow_id(
    idempotency_key: str,
) -> str:

    digest = hashlib.sha256(
        idempotency_key.encode("utf-8")
    ).hexdigest()[:20]

    return f"WF-{digest.upper()}"


def _candidate_id(
    workflow_id: str,
) -> str:

    return f"FW-{workflow_id}"


def _number(
    value: Any,
    default: float = 0,
) -> float:

    try:
        return float(value)

    except (TypeError, ValueError):
        return default


# ==========================================================
# REQUEST VALIDATION
# ==========================================================

def _validate_business_request(
    request: DecisionWorkflowRequest,
) -> None:

    if (
        request.forecast_type
        == DecisionWorkflowForecastType.CUSTOM
    ):

        if (
            request.start_date is None
            or request.end_date is None
        ):
            raise DecisionWorkflowValidationError(
                "start_date and end_date are required "
                "for CUSTOM forecasts."
            )

        if request.end_date < request.start_date:
            raise DecisionWorkflowValidationError(
                "end_date cannot be before start_date."
            )

        inclusive_days = (
            request.end_date
            - request.start_date
        ).days + 1

        if inclusive_days > 14:
            raise DecisionWorkflowValidationError(
                "CUSTOM forecast date range cannot "
                "exceed 14 inclusive days."
            )

    elif (
        request.start_date is not None
        or request.end_date is not None
    ):
        raise DecisionWorkflowValidationError(
            "start_date and end_date are supported "
            "only for CUSTOM forecasts."
        )


# ==========================================================
# IDEMPOTENCY
# ==========================================================

def _request_identity(
    request: DecisionWorkflowRequest,
) -> dict:

    return {
        "forecast_type":
            request.forecast_type.value,

        "store_id":
            request.store_id,

        "product_id":
            request.product_id,

        "selling_price":
            request.selling_price,

        "promotion_percent":
            request.promotion_percent,

        "start_date":
            (
                request.start_date.isoformat()
                if request.start_date
                else None
            ),

        "end_date":
            (
                request.end_date.isoformat()
                if request.end_date
                else None
            ),
    }


def _assert_same_idempotent_request(
    existing: dict,
    request: DecisionWorkflowRequest,
) -> None:

    requested = _request_identity(
        request
    )

    if any(
        existing.get(field) != value
        for field, value
        in requested.items()
    ):
        raise DecisionWorkflowValidationError(
            "This idempotency key has already "
            "been used with different request data."
        )


def _with_next_action(
    workflow: dict,
) -> dict:

    result = workflow.copy()

    result["next_action"] = (
        NEXT_ACTION_BY_STATUS.get(
            result.get("workflow_status"),
            "REVIEW_OPTIMIZATION",
        )
    )

    return result


def _claim_workflow(
    request: DecisionWorkflowRequest,
) -> tuple[dict, bool]:

    workflow_id = _workflow_id(
        request.idempotency_key
    )

    existing = get_document_by_id(
        DECISION_WORKFLOWS_COLLECTION,
        workflow_id,
    )

    if existing is not None:

        _assert_same_idempotent_request(
            existing,
            request,
        )

        return (
            _with_next_action(existing),
            False,
        )

    timestamp = _now()

    workflow = {
        "workflow_id":
            workflow_id,

        "idempotency_key":
            request.idempotency_key,

        "workflow_status":
            "PROCESSING",

        "next_action":
            "WAIT_FOR_COMPLETION",

        "forecast_type":
            request.forecast_type.value,

        "store_id":
            request.store_id,

        "product_id":
            request.product_id,

        "selling_price":
            request.selling_price,

        "promotion_percent":
            request.promotion_percent,

        "start_date":
            (
                request.start_date.isoformat()
                if request.start_date
                else None
            ),

        "end_date":
            (
                request.end_date.isoformat()
                if request.end_date
                else None
            ),

        "candidate_id":
            None,

        "movement_id":
            None,

        "failure_stage":
            None,

        "error_message":
            None,

        "created_at":
            timestamp,

        "updated_at":
            timestamp,
    }

    try:

        (
            get_collection(
                DECISION_WORKFLOWS_COLLECTION
            )
            .document(workflow_id)
            .create(workflow)
        )

        workflow["id"] = workflow_id

        return workflow, True

    except AlreadyExists:

        concurrent = get_document_by_id(
            DECISION_WORKFLOWS_COLLECTION,
            workflow_id,
        )

        if concurrent is None:
            raise DecisionWorkflowExecutionError(
                "Unable to load the existing "
                "idempotent workflow."
            )

        _assert_same_idempotent_request(
            concurrent,
            request,
        )

        return (
            _with_next_action(concurrent),
            False,
        )


# ==========================================================
# TARGET INVENTORY LOOKUP
# ==========================================================
#
# IMPORTANT:
#
# Previous implementation:
#
#   get_inventory_by_product(product_id)
#
# eventually called:
#
#   get_all_inventory()
#       ↓
#   get_all_documents("inventory_current")
#
# which loaded the entire inventory collection.
#
# This implementation queries only the required
# store + product inventory record.
# ==========================================================

def _find_inventory(
    store_id: str,
    product_id: str,
) -> dict | None:

    docs = (
        get_collection(
            INVENTORY_COLLECTION
        )
        .where(
            filter=FieldFilter(
                "store_id",
                "==",
                store_id,
            )
        )
        .where(
            filter=FieldFilter(
                "product_id",
                "==",
                product_id,
            )
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
# FORECAST PAYLOAD
# ==========================================================

def _forecast_payload(
    request: DecisionWorkflowRequest,
) -> dict:

    payload = {
        "store_id":
            request.store_id,

        "product_id":
            request.product_id,

        "price_lkr":
            request.selling_price,

        "promotion_percent":
            request.promotion_percent,

        "lag_1":
            0,

        "lag_7":
            0,

        "rolling_mean_7":
            0,

        "is_holiday":
            0,

        "is_festival":
            0,

        "is_school":
            0,
    }

    if (
        request.forecast_type
        != DecisionWorkflowForecastType.CUSTOM
    ):

        tomorrow = (
            datetime.now()
            + timedelta(days=1)
        )

        payload.update(
            {
                "temperature":
                    30,

                "humidity":
                    75,

                "rainfall":
                    0,

                "is_weekend":
                    0,

                "month":
                    tomorrow.month,

                "day":
                    tomorrow.day,

                "day_of_week_num":
                    tomorrow.weekday(),
            }
        )

    return payload


# ==========================================================
# FORECAST EXECUTION
# ==========================================================

def _run_forecast(
    request: DecisionWorkflowRequest,
    payload: dict,
) -> dict:

    # ------------------------------------------------------
    # DAILY
    # ------------------------------------------------------

    if (
        request.forecast_type
        == DecisionWorkflowForecastType.DAILY
    ):

        raw = predict_next_day(
            payload
        )

        details = {
            **raw,
            "weather_source":
                "Open-Meteo",

            "weather_mode":
                "SHORT_RANGE_FORECAST",
        }

        return {
            "forecast_horizon_days":
                1,

            "forecast_total_demand":
                _number(
                    raw.get(
                        "predicted_demand"
                    )
                ),

            "forecast_average_confidence":
                _number(
                    raw.get(
                        "confidence_percentage"
                    )
                ),

            "forecast_start_date":
                raw.get(
                    "forecast_date"
                ),

            "forecast_end_date":
                raw.get(
                    "forecast_date"
                ),

            "forecast_details":
                details,
        }

    # ------------------------------------------------------
    # SEVEN DAY
    # ------------------------------------------------------

    if (
        request.forecast_type
        == DecisionWorkflowForecastType.SEVEN_DAY
    ):

        raw = generate_7_day_forecast(
            payload
        )

    # ------------------------------------------------------
    # CUSTOM
    # ------------------------------------------------------

    else:

        raw = generate_custom_forecast(
            payload=payload,
            start_date=request.start_date,
            end_date=request.end_date,
        )

    forecast_items = (
        raw.get("forecast")
        or []
    )

    total = raw.get(
        "total_predicted_demand"
    )

    if total is None:

        total = sum(
            _number(
                item.get(
                    "predicted_demand"
                )
            )
            for item
            in forecast_items
        )

    confidence = raw.get(
        "average_confidence_percentage"
    )

    if (
        confidence is None
        and forecast_items
    ):

        confidence = (
            sum(
                _number(
                    item.get(
                        "confidence_percentage"
                    )
                )
                for item
                in forecast_items
            )
            / len(forecast_items)
        )

    return {
        "forecast_horizon_days":
            int(
                raw.get(
                    "forecast_days"
                )
                or len(
                    forecast_items
                )
            ),

        "forecast_total_demand":
            _number(total),

        "forecast_average_confidence":
            round(
                _number(confidence),
                2,
            ),

        "forecast_start_date":
            raw.get(
                "start_date"
            ),

        "forecast_end_date":
            raw.get(
                "end_date"
            ),

        "forecast_details":
            raw,
    }


# ==========================================================
# FORECAST PRIORITY
# ==========================================================

def _forecast_priority(
    shortage_qty: int,
    required_stock: float,
) -> tuple[str, float]:

    if required_stock <= 0:
        return "LOW", 0

    shortage_percentage = round(
        (
            shortage_qty
            / required_stock
        )
        * 100,
        2,
    )

    if shortage_percentage >= 60:
        return (
            "HIGH",
            shortage_percentage,
        )

    if shortage_percentage >= 30:
        return (
            "MEDIUM",
            shortage_percentage,
        )

    return (
        "LOW",
        shortage_percentage,
    )


# ==========================================================
# WORKFLOW-LEVEL INVENTORY INTERPRETATION
# ==========================================================
#
# Standalone inventory intelligence evaluates stock
# mainly against forecast demand.
#
# The Connected Decision Workflow must additionally
# protect the reorder buffer.
#
# This prevents the UI from presenting:
#
#   PROMOTE
#
# while the workflow simultaneously requires:
#
#   TRANSFER
#
# because forecast demand + reorder buffer is not covered.
# ==========================================================

def _build_workflow_intelligence(
    intelligence: dict,
    current_stock: int,
    forecast_total: float,
    reorder_level: int,
    shortage_qty: int,
) -> dict:

    result = intelligence.copy()

    projected_stock = (
        current_stock
        - forecast_total
    )

    if shortage_qty > 0:

        result.update(
            {
                "operational_status":
                    "BELOW_REORDER_BUFFER",

                "operational_action":
                    "TRANSFER_OR_REPLENISH",

                "operational_shortage_qty":
                    shortage_qty,

                "projected_stock_after_demand":
                    projected_stock,

                "required_reorder_buffer":
                    reorder_level,

                "operational_reason":
                    (
                        "Current stock may cover forecast "
                        "demand, but it does not fully cover "
                        "forecast demand plus the reorder "
                        f"buffer. {shortage_qty} additional "
                        "units are required to maintain the "
                        "configured inventory safety level."
                    ),
            }
        )

    else:

        result.update(
            {
                "operational_status":
                    "BUFFER_COVERED",

                "operational_action":
                    intelligence.get(
                        "recommended_action",
                        "NO_ACTION",
                    ),

                "operational_shortage_qty":
                    0,

                "projected_stock_after_demand":
                    projected_stock,

                "required_reorder_buffer":
                    reorder_level,

                "operational_reason":
                    (
                        "Current stock covers forecast "
                        "demand and the reorder buffer."
                    ),
            }
        )

    return result


# ==========================================================
# FORECAST WORKFLOW CANDIDATE
# ==========================================================

def _build_candidate(
    workflow_id: str,
    product: dict,
    inventory: dict,
    intelligence: dict,
    forecast_result: dict,
    shortage_qty: int,
    required_stock: float,
) -> dict:

    timestamp = _now()

    candidate_id = _candidate_id(
        workflow_id
    )

    (
        priority,
        shortage_percentage,
    ) = _forecast_priority(
        shortage_qty,
        required_stock,
    )

    return {
        "candidate_id":
            candidate_id,

        "candidate_origin":
            "FORECAST_WORKFLOW",

        "workflow_id":
            workflow_id,

        "product_id":
            inventory.get(
                "product_id"
            ),

        "product_name":
            product.get(
                "product_name",
                "",
            ),

        "store_id":
            inventory.get(
                "store_id"
            ),

        "category":
            product.get(
                "category",
                "",
            ),

        "subcategory":
            product.get(
                "subcategory",
                "",
            ),

        "brand":
            product.get(
                "brand",
                "",
            ),

        "gender":
            product.get(
                "gender",
                "",
            ),

        "current_stock":
            int(
                _number(
                    inventory.get(
                        "current_stock"
                    )
                )
            ),

        "reorder_level":
            int(
                _number(
                    inventory.get(
                        "reorder_level"
                    )
                )
            ),

        "max_stock":
            int(
                _number(
                    inventory.get(
                        "max_stock"
                    )
                )
            ),

        "shortage_qty":
            shortage_qty,

        "surplus_qty":
            0,

        "stock_health":
            intelligence.get(
                "stock_health"
            ),

        "candidate_type":
            "LOW_STOCK",

        "priority":
            priority,

        "forecast_shortage_percentage":
            shortage_percentage,

        "forecast_horizon_days":
            forecast_result[
                "forecast_horizon_days"
            ],

        "forecast_total_demand":
            forecast_result[
                "forecast_total_demand"
            ],

        "forecast_average_confidence":
            forecast_result[
                "forecast_average_confidence"
            ],

        "recommended_action":
            "PENDING",

        "decision_reason":
            "",

        "status":
            "PENDING",

        "created_at":
            timestamp,

        "last_updated":
            timestamp,
    }


# ==========================================================
# SAVE WORKFLOW
# ==========================================================

def _save_workflow(
    workflow_id: str,
    workflow: dict,
) -> dict:

    workflow["next_action"] = (
        NEXT_ACTION_BY_STATUS.get(
            workflow.get(
                "workflow_status"
            ),
            "REVIEW_OPTIMIZATION",
        )
    )

    workflow["updated_at"] = (
        _now()
    )

    create_or_update_document(
        DECISION_WORKFLOWS_COLLECTION,
        workflow_id,
        workflow,
        merge=False,
    )

    result = workflow.copy()

    result["id"] = workflow_id

    return result


# ==========================================================
# HYDRATE WORKFLOW
# ==========================================================

def _hydrate_workflow(
    workflow: dict,
) -> dict:

    result = _with_next_action(
        workflow
    )

    candidate_id = result.get(
        "candidate_id"
    )

    movement_id = result.get(
        "movement_id"
    )

    if candidate_id:

        result["candidate"] = (
            get_document_by_id(
                OPTIMIZATION_CANDIDATES_COLLECTION,
                candidate_id,
            )
        )

    if movement_id:

        result["movement"] = (
            get_stock_movement_by_id(
                movement_id
            )
        )

    return result


# ==========================================================
# MAIN CONNECTED DECISION WORKFLOW
# ==========================================================

def analyze_decision_workflow(
    request: DecisionWorkflowRequest,
) -> dict:

    _validate_business_request(
        request
    )

    failure_stage = (
        "CATALOG_LOOKUP"
    )

    workflow_id = _workflow_id(
        request.idempotency_key
    )

    workflow_claimed = False

    try:

        # --------------------------------------------------
        # IDEMPOTENCY
        # --------------------------------------------------

        (
            workflow,
            workflow_claimed,
        ) = _claim_workflow(
            request
        )

        if not workflow_claimed:

            return _hydrate_workflow(
                workflow
            )

        # --------------------------------------------------
        # PRODUCT + STORE
        # --------------------------------------------------

        store = get_store_by_id(
            request.store_id
        )

        product = get_product_by_id(
            request.product_id
        )

        if store is None:

            raise DecisionWorkflowValidationError(
                f"Store '{request.store_id}' "
                "was not found."
            )

        if product is None:

            raise DecisionWorkflowValidationError(
                f"Product '{request.product_id}' "
                "was not found."
            )

        # --------------------------------------------------
        # INVENTORY
        # --------------------------------------------------

        failure_stage = (
            "INVENTORY_LOOKUP"
        )

        inventory = _find_inventory(
            request.store_id,
            request.product_id,
        )

        if inventory is None:

            raise DecisionWorkflowValidationError(
                "Inventory was not found for "
                "the requested store and product."
            )

        current_stock = int(
            _number(
                inventory.get(
                    "current_stock"
                )
            )
        )

        reorder_level = int(
            _number(
                inventory.get(
                    "reorder_level"
                )
            )
        )

        max_stock = int(
            _number(
                inventory.get(
                    "max_stock"
                )
            )
        )

        # --------------------------------------------------
        # FORECAST
        # --------------------------------------------------

        failure_stage = (
            "FORECAST"
        )

        forecast_result = (
            _run_forecast(
                request,
                _forecast_payload(
                    request
                ),
            )
        )

        forecast_total = (
            forecast_result[
                "forecast_total_demand"
            ]
        )

        projected_stock = (
            current_stock
            - forecast_total
        )

        required_stock = (
            forecast_total
            + reorder_level
        )

        shortage_qty = max(
            0,
            math.ceil(
                required_stock
                - current_stock
            ),
        )

        # --------------------------------------------------
        # INVENTORY INTELLIGENCE
        # --------------------------------------------------

        failure_stage = (
            "INTELLIGENCE"
        )

        raw_intelligence = (
            generate_inventory_intelligence(
                current_stock=current_stock,
                reorder_level=reorder_level,
                max_stock=max_stock,
                forecast_demand=math.ceil(
                    forecast_total
                ),
                cost_price=_number(
                    product.get(
                        "cost_price"
                    )
                ),
                selling_price=(
                    request.selling_price
                ),
            )
        )

        # Connected workflow interpretation.
        intelligence = (
            _build_workflow_intelligence(
                intelligence=raw_intelligence,
                current_stock=current_stock,
                forecast_total=forecast_total,
                reorder_level=reorder_level,
                shortage_qty=shortage_qty,
            )
        )

        # --------------------------------------------------
        # INVENTORY SNAPSHOT
        # --------------------------------------------------

        inventory_snapshot = {
            "inventory_id":
                (
                    inventory.get(
                        "inventory_id"
                    )
                    or inventory.get(
                        "id"
                    )
                ),

            "current_stock":
                current_stock,

            "reorder_level":
                reorder_level,

            "max_stock":
                max_stock,

            "projected_stock_after_demand":
                projected_stock,

            "required_stock_before_demand":
                required_stock,

            "forecast_shortage_qty":
                shortage_qty,
        }

        workflow.update(
            {
                "forecast_result":
                    forecast_result,

                "inventory_snapshot":
                    inventory_snapshot,

                "inventory_intelligence":
                    intelligence,

                "failure_stage":
                    None,

                "error_message":
                    None,
            }
        )

        # --------------------------------------------------
        # NO SHORTAGE
        # --------------------------------------------------

        if shortage_qty <= 0:

            workflow.update(
                {
                    "workflow_status":
                        "NO_ACTION_REQUIRED",

                    "status_reason":
                        (
                            "Current stock covers "
                            "forecast demand and the "
                            "reorder buffer."
                        ),
                }
            )

            return _save_workflow(
                workflow_id,
                workflow,
            )

        # --------------------------------------------------
        # CREATE FORECAST CANDIDATE
        # --------------------------------------------------

        failure_stage = (
            "CANDIDATE_CREATION"
        )

        candidate = _build_candidate(
            workflow_id,
            product,
            inventory,
            intelligence,
            forecast_result,
            shortage_qty,
            required_stock,
        )

        candidate_id = (
            candidate[
                "candidate_id"
            ]
        )

        create_or_update_document(
            OPTIMIZATION_CANDIDATES_COLLECTION,
            candidate_id,
            candidate,
            merge=False,
        )

        workflow["candidate_id"] = (
            candidate_id
        )

        # --------------------------------------------------
        # DECISION ENGINE
        # --------------------------------------------------

        failure_stage = (
            "DECISION_ANALYSIS"
        )

        analysis = analyze_candidate(
            candidate_id
        )

        if (
            analysis is None
            or analysis.get(
                "candidate"
            ) is None
        ):

            raise DecisionWorkflowExecutionError(
                "The Decision Engine did not "
                "return an analyzed candidate."
            )

        analyzed_candidate = (
            analysis["candidate"]
        )

        workflow["decision_result"] = (
            analysis.get(
                "decision"
            )
        )

        workflow["workflow_status"] = (
            "CANDIDATE_ANALYZED"
        )

        # --------------------------------------------------
        # REORDER
        # --------------------------------------------------

        if (
            analyzed_candidate.get(
                "recommended_action"
            )
            == "REORDER"
        ):

            workflow["workflow_status"] = (
                "REORDER_RECOMMENDED"
            )

        # --------------------------------------------------
        # TRANSFER
        # --------------------------------------------------

        elif (
            analyzed_candidate.get(
                "recommended_action"
            )
            == "TRANSFER"

            and analyzed_candidate.get(
                "transfer_ready"
            )
            is True
        ):

            failure_stage = (
                "MOVEMENT_RECOMMENDATION"
            )

            # Extra protection against duplicate movement.
            if workflow.get(
                "movement_id"
            ):

                return _hydrate_workflow(
                    workflow
                )

            movement = recommend_transfer(
                candidate_id
            )

            if (
                movement is None
                or movement.get(
                    "error"
                )
            ):

                raise DecisionWorkflowExecutionError(
                    "The transfer recommendation "
                    "service could not create "
                    "a movement."
                )

            workflow["movement_id"] = (
                movement.get(
                    "movement_id"
                )
                or movement.get(
                    "id"
                )
            )

            workflow["workflow_status"] = (
                "MOVEMENT_RECOMMENDED"
            )

        # --------------------------------------------------
        # SAVE FINAL WORKFLOW STATE
        # --------------------------------------------------

        saved = _save_workflow(
            workflow_id,
            workflow,
        )

        saved["candidate"] = (
            analyzed_candidate
        )

        if workflow.get(
            "movement_id"
        ):

            saved["movement"] = (
                movement
            )

        return saved

    # ======================================================
    # FIRESTORE QUOTA
    # ======================================================

    except ResourceExhausted as exc:

        raise DecisionWorkflowQuotaError(
            "Firestore quota is currently "
            "exhausted. Please retry later."
        ) from exc

    # ======================================================
    # VALIDATION ERROR
    # ======================================================

    except DecisionWorkflowValidationError:

        if workflow_claimed:

            failure = workflow.copy()

            failure.update(
                {
                    "workflow_status":
                        "FAILED",

                    "failure_stage":
                        failure_stage,

                    "error_message":
                        FAILURE_MESSAGES.get(
                            failure_stage,
                            "Unable to process "
                            "the workflow.",
                        ),
                }
            )

            _save_workflow(
                workflow_id,
                failure,
            )

        raise

    # ======================================================
    # UNEXPECTED ERROR
    # ======================================================

    except Exception as exc:

        if workflow_claimed:

            failure = workflow.copy()

            failure.update(
                {
                    "workflow_status":
                        "FAILED",

                    "failure_stage":
                        failure_stage,

                    "error_message":
                        FAILURE_MESSAGES.get(
                            failure_stage,
                            "Unable to process "
                            "the workflow.",
                        ),
                }
            )

            try:

                _save_workflow(
                    workflow_id,
                    failure,
                )

            except ResourceExhausted as quota_exc:

                raise DecisionWorkflowQuotaError(
                    "Firestore quota is currently "
                    "exhausted. Please retry later."
                ) from quota_exc

        raise DecisionWorkflowExecutionError(
            FAILURE_MESSAGES.get(
                failure_stage,
                "Unable to process the workflow.",
            )
        ) from exc


# ==========================================================
# GET ONE WORKFLOW
# ==========================================================

def get_decision_workflow(
    workflow_id: str,
) -> dict:

    try:

        workflow = get_document_by_id(
            DECISION_WORKFLOWS_COLLECTION,
            workflow_id,
        )

        if workflow is None:

            raise DecisionWorkflowNotFoundError(
                f"Decision workflow "
                f"'{workflow_id}' was not found."
            )

        return _hydrate_workflow(
            workflow
        )

    except ResourceExhausted as exc:

        raise DecisionWorkflowQuotaError(
            "Firestore quota is currently "
            "exhausted. Please retry later."
        ) from exc


# ==========================================================
# WORKFLOW HISTORY
# ==========================================================

def list_decision_workflows(
    limit: int = 20,
) -> list[dict]:

    try:

        docs = (
            get_collection(
                DECISION_WORKFLOWS_COLLECTION
            )
            .order_by(
                "created_at",
                direction="DESCENDING",
            )
            .limit(limit)
            .stream()
        )

        workflows = []

        for doc in docs:

            item = doc.to_dict()

            item["id"] = doc.id

            workflows.append(
                _with_next_action(
                    item
                )
            )

        return workflows

    except ResourceExhausted as exc:

        raise DecisionWorkflowQuotaError(
            "Firestore quota is currently "
            "exhausted. Please retry later."
        ) from exc