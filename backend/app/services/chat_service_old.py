"""
Movement-aware Manager Assistant.

Responsibilities:
1. Load stock movement data directly from Firestore.
2. Answer factual questions locally without Gemini.
3. Use saved Explainable AI context for reasoning questions.
4. Use Gemini only for open-ended managerial questions.
5. Never recalculate or change the original recommendation.
6. Return a local fallback answer when Gemini is unavailable.
"""

import re
from typing import Any, Optional

from app.constants.collections import (
    STOCK_MOVEMENTS_COLLECTION
)

from app.services.explanation_service import (
    call_explanation_model,
    simplify_ai_error
)

from app.services.firebase_service import (
    get_document_by_id
)


# ==========================================================
# GENERAL HELPERS
# ==========================================================

def to_float(
    value: Any,
    default: float = 0.0
) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def to_int(
    value: Any,
    default: int = 0
) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def format_number(value: Any) -> str:
    number = to_float(value)

    if number.is_integer():
        return f"{int(number):,}"

    return f"{number:,.2f}"


def format_currency(value: Any) -> str:
    try:
        return f"LKR {float(value):,.2f}"
    except (TypeError, ValueError):
        return "Unavailable"


def normalize_message(message: str) -> str:
    return " ".join(
        message.lower().strip().split()
    )


def contains_any(
    message: str,
    phrases: list[str]
) -> bool:
    return any(
        phrase in message
        for phrase in phrases
    )


def build_chat_response(
    movement: dict,
    answer: str,
    answer_source: str,
    ai_model: Optional[str] = None,
    error_code: Optional[str] = None
) -> dict:
    return {
        "movement_id": movement.get(
            "movement_id"
        ),
        "movement_status": movement.get(
            "movement_status"
        ),
        "answer": answer,
        "answer_source": answer_source,
        "ai_model": ai_model,
        "error_code": error_code
    }


# ==========================================================
# MOVEMENT DATA
# ==========================================================

def get_movement(
    movement_id: str
) -> Optional[dict]:
    return get_document_by_id(
        STOCK_MOVEMENTS_COLLECTION,
        movement_id
    )


def get_alternative_by_store(
    movement: dict,
    store_id: str
) -> Optional[dict]:
    context = (
        movement.get(
            "ai_explanation_context"
        )
        or {}
    )

    alternatives = (
        context.get(
            "alternative_analysis"
        )
        or []
    )

    for source in alternatives:
        if (
            str(source.get("store_id")).upper()
            == store_id.upper()
        ):
            return source

    # Fallback to evaluated_sources if the
    # explanation context is unavailable.
    evaluated_sources = (
        movement.get(
            "evaluated_sources"
        )
        or []
    )

    for source in evaluated_sources:
        if (
            str(source.get("store_id")).upper()
            == store_id.upper()
        ):
            return source

    return None


def extract_store_id(
    message: str
) -> Optional[str]:
    match = re.search(
        r"\bCP\d{3}\b",
        message.upper()
    )

    if match:
        return match.group(0)

    return None


# ==========================================================
# LOCAL FACTUAL HANDLERS
# ==========================================================

def answer_status_question(
    movement: dict
) -> str:
    status = movement.get(
        "movement_status",
        "UNKNOWN"
    )

    if status == "RECOMMENDED":
        return (
            "This transfer is currently recommended "
            "and is waiting for a manager decision."
        )

    if status == "APPROVED":
        return (
            "This transfer has been approved but has "
            "not yet been executed."
        )

    if status == "REJECTED":
        reason = movement.get(
            "rejection_reason"
        )

        if reason:
            return (
                f"This recommendation was rejected. "
                f"The recorded reason is: {reason}."
            )

        return (
            "This recommendation was rejected."
        )

    if status == "CANCELLED":
        reason = movement.get(
            "cancel_reason"
        )

        if reason:
            return (
                f"This movement was cancelled. "
                f"The recorded reason is: {reason}."
            )

        return (
            "This movement was cancelled."
        )

    if status == "IN_PROGRESS":
        return (
            "This stock transfer is currently "
            "being processed."
        )

    if status == "EXECUTED":
        return (
            "This transfer was executed successfully "
            f"on {movement.get('executed_at')}."
        )

    if status == "FAILED":
        return (
            "The transfer execution failed. "
            f"Recorded error: "
            f"{movement.get('execution_error', 'Unavailable')}."
        )

    return (
        f"The current movement status is {status}."
    )


def answer_transfer_details(
    movement: dict
) -> str:
    return (
        f"The recommendation is to transfer "
        f"{format_number(movement.get('recommended_qty'))} "
        f"units of {movement.get('product_name')} from "
        f"{movement.get('from_store')} to "
        f"{movement.get('to_store')}."
    )


def answer_source_question(
    movement: dict
) -> str:
    return (
        f"The selected source showroom is "
        f"{movement.get('from_store')}."
    )


def answer_target_question(
    movement: dict
) -> str:
    return (
        f"The destination showroom is "
        f"{movement.get('to_store')}."
    )


def answer_quantity_question(
    movement: dict
) -> str:
    return (
        f"The recommended transfer quantity is "
        f"{format_number(movement.get('recommended_qty'))} "
        f"units."
    )


def answer_distance_question(
    movement: dict
) -> str:
    return (
        f"The estimated transfer distance is "
        f"{format_number(movement.get('distance_km'))} km, "
        f"with an estimated travel time of "
        f"{format_number(movement.get('estimated_time_minutes'))} "
        f"minutes."
    )


def answer_cost_question(
    movement: dict
) -> str:
    return (
        f"The estimated transfer cost is "
        f"{format_currency(movement.get('estimated_transfer_cost'))}."
    )


def answer_risk_question(
    movement: dict
) -> str:
    return (
        f"The inventory risk after the transfer is "
        f"{movement.get('risk_after_transfer', 'UNKNOWN')}. "
        f"The simulation status is "
        f"{movement.get('simulation_status', 'UNKNOWN')}, "
        f"and the source is expected to retain "
        f"{format_number(movement.get('remaining_buffer'))} "
        f"units above its reorder level."
    )


def answer_confidence_question(
    movement: dict
) -> str:
    context = (
        movement.get(
            "ai_explanation_context"
        )
        or {}
    )

    confidence_context = (
        context.get(
            "confidence_analysis"
        )
        or {}
    )

    factors = (
        confidence_context.get(
            "supporting_factors"
        )
        or []
    )

    base_answer = (
        f"The recommendation confidence is "
        f"{format_number(movement.get('recommendation_confidence'))}% "
        f"and is classified as "
        f"{movement.get('recommendation_confidence_label')}."
    )

    if factors:
        return (
            f"{base_answer} This is supported by: "
            f"{'; '.join(factors)}."
        )

    return base_answer


def answer_inventory_impact_question(
    movement: dict
) -> str:
    if (
        movement.get("movement_status")
        == "EXECUTED"
    ):
        return (
            f"After execution, source stock changed from "
            f"{format_number(movement.get('actual_source_stock_before'))} "
            f"to "
            f"{format_number(movement.get('actual_source_stock_after'))}, "
            f"while target stock changed from "
            f"{format_number(movement.get('actual_target_stock_before'))} "
            f"to "
            f"{format_number(movement.get('actual_target_stock_after'))}."
        )

    return (
        f"If approved and executed, source stock is expected "
        f"to change from "
        f"{format_number(movement.get('source_stock_before'))} "
        f"to {format_number(movement.get('source_stock_after'))}, "
        f"while target stock is expected to change from "
        f"{format_number(movement.get('target_stock_before'))} "
        f"to {format_number(movement.get('target_stock_after'))}."
    )


def answer_transaction_question(
    movement: dict
) -> str:
    transaction_id = movement.get(
        "transaction_id"
    )

    if transaction_id:
        return (
            f"The transfer transaction was recorded under "
            f"ID {transaction_id}."
        )

    return (
        "No transaction has been recorded because this "
        "movement has not yet been executed."
    )


def answer_alternatives_question(
    movement: dict
) -> str:
    alternatives = (
        movement.get(
            "alternative_sources"
        )
        or []
    )

    if not alternatives:
        return (
            "No alternative source showrooms were "
            "recorded for this recommendation."
        )

    return (
        f"The main alternative source showrooms were "
        f"{', '.join(alternatives)}."
    )


def answer_execution_summary(
    movement: dict
) -> str:
    saved_summary = movement.get(
        "ai_execution_summary"
    )

    if saved_summary:
        return saved_summary

    if (
        movement.get("movement_status")
        != "EXECUTED"
    ):
        return (
            "An execution summary is not available because "
            "this movement has not been executed."
        )

    return answer_inventory_impact_question(
        movement
    )


def answer_saved_explanation(
    movement: dict
) -> str:
    explanation = movement.get(
        "ai_explanation"
    )

    if explanation:
        return explanation

    return movement.get(
        "recommendation_reason",
        "A saved recommendation explanation is unavailable."
    )


# ==========================================================
# STORE COMPARISON
# ==========================================================

def build_store_comparison_answer(
    movement: dict,
    compare_store_id: str
) -> str:
    selected_store = movement.get(
        "from_store"
    )

    if compare_store_id == selected_store:
        return answer_saved_explanation(
            movement
        )

    selected = get_alternative_by_store(
        movement,
        selected_store
    )

    alternative = get_alternative_by_store(
        movement,
        compare_store_id
    )

    if alternative is None:
        return (
            f"{compare_store_id} was not found among the "
            f"evaluated source showrooms for this movement."
        )

    selected_distance = (
        selected.get("distance_km")
        if selected
        else movement.get("distance_km")
    )

    selected_cost = (
        selected.get("estimated_transfer_cost")
        if selected
        else movement.get(
            "estimated_transfer_cost"
        )
    )

    selected_buffer = (
        selected.get("remaining_buffer")
        if selected
        else movement.get(
            "remaining_buffer"
        )
    )

    alternative_coverage = to_float(
        alternative.get(
            "coverage_percentage"
        )
    )

    alternative_risk = alternative.get(
        "risk_after_transfer",
        "UNKNOWN"
    )

    answer = (
        f"{selected_store} was selected instead of "
        f"{compare_store_id} because it provided the "
        f"stronger overall business balance. "
    )

    if alternative_coverage < 100:
        answer += (
            f"{compare_store_id} could cover only "
            f"{format_number(alternative_coverage)}% "
            f"of the required quantity. "
        )

    answer += (
        f"{selected_store} is "
        f"{format_number(selected_distance)} km away with an "
        f"estimated cost of "
        f"{format_currency(selected_cost)}, and it retains "
        f"{format_number(selected_buffer)} units above its "
        f"reorder level. "
    )

    answer += (
        f"{compare_store_id} is "
        f"{format_number(alternative.get('distance_km'))} km away, "
        f"has an estimated cost of "
        f"{format_currency(alternative.get('estimated_transfer_cost'))}, "
        f"and has a {alternative_risk} risk after transfer."
    )

    return answer


# ==========================================================
# LOCAL QUESTION ROUTER
# ==========================================================

def handle_local_question(
    message: str,
    movement: dict
) -> Optional[str]:
    normalized = normalize_message(message)

    compare_store = extract_store_id(
        normalized
    )

    if (
        compare_store
        and compare_store
        != movement.get("from_store")
        and contains_any(
            normalized,
            [
                "why not",
                "instead of",
                "compare",
                "selected over",
                "choose over",
                "chosen over"
            ]
        )
    ):
        return build_store_comparison_answer(
            movement,
            compare_store
        )

    if contains_any(
        normalized,
        [
            "what is the status",
            "current status",
            "movement status",
            "was it approved",
            "was it rejected",
            "was it cancelled",
            "was it executed",
            "has it been executed"
        ]
    ):
        return answer_status_question(
            movement
        )

    if contains_any(
        normalized,
        [
            "which source",
            "source store",
            "source showroom",
            "where is it coming from",
            "transfer from"
        ]
    ):
        return answer_source_question(
            movement
        )

    if contains_any(
        normalized,
        [
            "which target",
            "target store",
            "target showroom",
            "destination",
            "transfer to"
        ]
    ):
        return answer_target_question(
            movement
        )

    if contains_any(
        normalized,
        [
            "how many units",
            "what quantity",
            "transfer quantity",
            "recommended quantity"
        ]
    ):
        return answer_quantity_question(
            movement
        )

    if contains_any(
        normalized,
        [
            "how far",
            "distance",
            "travel time",
            "how long"
        ]
    ):
        return answer_distance_question(
            movement
        )

    if contains_any(
        normalized,
        [
            "how much",
            "transfer cost",
            "transport cost",
            "estimated cost",
            "logistics cost"
        ]
    ):
        return answer_cost_question(
            movement
        )

    if contains_any(
        normalized,
        [
            "what is the risk",
            "risk after transfer",
            "is it safe",
            "inventory risk",
            "remaining buffer"
        ]
    ):
        return answer_risk_question(
            movement
        )

    if contains_any(
        normalized,
        [
            "confidence",
            "how confident",
            "why very high",
            "why high confidence"
        ]
    ):
        return answer_confidence_question(
            movement
        )

    if contains_any(
        normalized,
        [
            "inventory impact",
            "stock impact",
            "stock before",
            "stock after",
            "what changed",
            "business impact"
        ]
    ):
        return answer_inventory_impact_question(
            movement
        )

    if contains_any(
        normalized,
        [
            "transaction id",
            "transaction record",
            "transaction"
        ]
    ):
        return answer_transaction_question(
            movement
        )

    if contains_any(
        normalized,
        [
            "alternative stores",
            "alternative sources",
            "other stores",
            "other showrooms",
            "which alternatives"
        ]
    ):
        return answer_alternatives_question(
            movement
        )

    if contains_any(
        normalized,
        [
            "execution summary",
            "summarize execution",
            "what happened after execution"
        ]
    ):
        return answer_execution_summary(
            movement
        )

    if contains_any(
        normalized,
        [
            "why was this recommended",
            "explain recommendation",
            "why selected",
            "recommendation reason",
            "why this store"
        ]
    ):
        return answer_saved_explanation(
            movement
        )

    if contains_any(
        normalized,
        [
            "transfer details",
            "what is recommended",
            "summarize recommendation"
        ]
    ):
        return answer_transfer_details(
            movement
        )

    return None


# ==========================================================
# COMPACT MANAGER CHAT CONTEXT
# ==========================================================

def build_manager_chat_prompt(
    message: str,
    movement: dict
) -> str:
    context = (
        movement.get(
            "ai_explanation_context"
        )
        or {}
    )

    decision = context.get(
        "decision",
        {}
    )

    inventory = context.get(
        "inventory_analysis",
        {}
    )

    logistics = context.get(
        "logistics_analysis",
        {}
    )

    risk = context.get(
        "risk_analysis",
        {}
    )

    confidence = context.get(
        "confidence_analysis",
        {}
    )

    selected_source = context.get(
        "selected_source_analysis",
        {}
    )

    tradeoff = context.get(
        "tradeoff_analysis",
        movement.get(
            "recommendation_reason"
        )
    )

    business_impact = "; ".join(
        context.get(
            "expected_business_impact",
            []
        )
    )

    confidence_factors = "; ".join(
        confidence.get(
            "supporting_factors",
            []
        )
    )

    return f"""
You are a retail inventory manager assistant.

The inventory recommendation was already calculated by a
deterministic business engine.

Your role is only to explain the stored decision and its
business implications.

STRICT RULES:
- Use only the supplied movement facts.
- Never change the selected store, destination or quantity.
- Never invent stock values, costs, distances or risks.
- Do not expose internal code or ranking formulas.
- Do not claim that you executed, approved or rejected anything.
- If the required fact is unavailable, clearly say it is unavailable.
- Keep the answer concise and manager-friendly.
- Use no more than five sentences.

MOVEMENT:
ID: {movement.get('movement_id')}
Status: {movement.get('movement_status')}
Product: {movement.get('product_name')}

DECISION:
Selected source: {decision.get('selected_store', movement.get('from_store'))}
Target store: {decision.get('target_store', movement.get('to_store'))}
Quantity: {decision.get('recommended_qty', movement.get('recommended_qty'))}
Coverage: {decision.get('coverage_percentage', movement.get('coverage_percentage'))}%

INVENTORY:
Source before: {inventory.get('source_stock_before', movement.get('source_stock_before'))}
Source after: {inventory.get('source_stock_after', movement.get('source_stock_after'))}
Source reorder level: {inventory.get('source_reorder_level', movement.get('source_reorder_level'))}
Remaining buffer: {inventory.get('remaining_buffer', movement.get('remaining_buffer'))}
Target before: {inventory.get('target_stock_before', movement.get('target_stock_before'))}
Target after: {inventory.get('target_stock_after', movement.get('target_stock_after'))}

LOGISTICS:
Distance: {logistics.get('distance_km', movement.get('distance_km'))} km
Estimated travel time: {logistics.get('estimated_time_minutes', movement.get('estimated_time_minutes'))} minutes
Estimated cost: {format_currency(logistics.get('estimated_transfer_cost', movement.get('estimated_transfer_cost')))}

RISK:
Risk after transfer: {risk.get('risk_after_transfer', movement.get('risk_after_transfer'))}
Simulation: {risk.get('simulation_status', movement.get('simulation_status'))}

SELECTED SOURCE ANALYSIS:
{selected_source}

TRADE-OFF:
{tradeoff}

CONFIDENCE:
Level: {confidence.get('confidence_label', movement.get('recommendation_confidence_label'))}
Supporting factors: {confidence_factors}

EXPECTED BUSINESS IMPACT:
{business_impact}

SAVED EXPLANATION:
{movement.get('ai_explanation')}

EXECUTION SUMMARY:
{movement.get('ai_execution_summary')}

MANAGER QUESTION:
{message}

Answer the manager using only the supplied facts.
""".strip()


# ==========================================================
# MAIN CHAT HANDLER
# ==========================================================

def handle_chat(
    message: str,
    movement_id: str
) -> dict:
    try:
        movement = get_movement(
            movement_id
        )

        if movement is None:
            return {
                "movement_id": movement_id,
                "movement_status": None,
                "answer": (
                    "The requested stock movement "
                    "could not be found."
                ),
                "answer_source": "SYSTEM",
                "ai_model": None,
                "error_code": "MOVEMENT_NOT_FOUND"
            }

        local_answer = handle_local_question(
            message,
            movement
        )

        if local_answer:
            return build_chat_response(
                movement=movement,
                answer=local_answer,
                answer_source="LOCAL_RULES"
            )

        prompt = build_manager_chat_prompt(
            message=message,
            movement=movement
        )

        ai_result = call_explanation_model(
            prompt
        )

        ai_text = ai_result.get(
            "text"
        )

        if ai_text:
            return build_chat_response(
                movement=movement,
                answer=ai_text,
                answer_source="GEMINI",
                ai_model=ai_result.get(
                    "model"
                )
            )

        # Safe fallback when Gemini quota or
        # service availability prevents generation.
        fallback_answer = (
            movement.get("ai_explanation")
            or movement.get(
                "recommendation_reason"
            )
            or (
                "The requested explanation could "
                "not be generated at this time."
            )
        )

        return build_chat_response(
            movement=movement,
            answer=fallback_answer,
            answer_source="LOCAL_FALLBACK",
            ai_model=None,
            error_code=simplify_ai_error(
                ai_result.get("error")
            )
        )

    except Exception:
        return {
            "movement_id": movement_id,
            "movement_status": None,
            "answer": (
                "The manager assistant could not process "
                "the request."
            ),
            "answer_source": "SYSTEM",
            "ai_model": None,
            "error_code": "CHAT_PROCESSING_FAILED"
        }