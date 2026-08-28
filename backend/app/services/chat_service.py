from typing import Optional
from app.utils.intent_detector import detect_intent
from app.utils.chat_context_builder import (
    build_chat_context
)
from app.services.ai_service import (
    generate_ai_answer
)
from app.services.inventory_service import (
    get_inventory_by_product
)
from app.services.stock_movement_service import (
    get_stock_movement_by_id,
    get_all_stock_movements
)
from app.services.firebase_service import (
    get_document_by_id
)
from app.services.session_memory import (
    add_message,
    get_movement_id as get_session_movement_id,
    set_movement_id
)
from app.services.chat_history_service import (
    save_chat_turn
)
from app.constants.collections import (
    ANALYTICS_SUMMARY_COLLECTION
)


# ==========================================================
# GENERAL HELPERS
# ==========================================================

def format_number(value) -> str:
    try:
        number = float(value)

        if number.is_integer():
            return f"{int(number):,}"

        return f"{number:,.2f}"

    except (TypeError, ValueError):
        return "Unavailable"


def format_currency(value) -> str:
    try:
        return f"LKR {float(value):,.2f}"

    except (TypeError, ValueError):
        return "Unavailable"


def build_response(
    intent: str,
    category: str,
    answer: str,
    answer_source: str = "LOCAL_RULES",
    movement: Optional[dict] = None,
    movement_id: Optional[str] = None,
    ai_model: Optional[str] = None,
    error_code: Optional[str] = None,
    session_id: Optional[str] = None
) -> dict:
    """
    Build one consistent chatbot API response.
    """

    resolved_movement_id = movement_id

    if movement:
        resolved_movement_id = movement.get(
            "movement_id"
        )

    return {
        "session_id": session_id,

        "movement_id": resolved_movement_id,

        "movement_status": (
            movement.get("movement_status")
            if movement
            else None
        ),

        "intent": intent,
        "category": category,

        "answer": answer,

        "answer_source": answer_source,

        "ai_model": ai_model,

        "error_code": error_code
    }


# ==========================================================
# SAFE HISTORY PERSISTENCE
# ==========================================================

def persist_chat_turn_safely(
    session_id: Optional[str],
    question: str,
    response: dict,
    user_id: Optional[str] = None,
    mode: str = "GENERAL"
) -> None:
    """
    Persist the visible conversation to Firestore.

    Important:
    Chat history failure must NEVER cause the chatbot
    itself to fail.
    """

    if not session_id:
        return

    try:
        save_chat_turn(
            session_id=session_id,

            question=question,

            answer=response.get(
                "answer",
                ""
            ),

            movement_id=response.get(
                "movement_id"
            ),

            answer_source=response.get(
                "answer_source"
            ),

            ai_model=response.get(
                "ai_model"
            ),

            intent=response.get(
                "intent"
            ),

            category=response.get(
                "category"
            ),

            user_id=user_id,

            mode=mode
        )

    except Exception as exc:
        print(
            "Chat history persistence failed: "
            f"{exc}"
        )


# ==========================================================
# LOCAL SESSION MEMORY
# ==========================================================

def save_local_turn_to_memory(
    session_id: Optional[str],
    question: str,
    answer: str
) -> None:
    """
    Local-rule questions must also be stored in short-term
    session memory.

    Groq answers do NOT use this function because
    ai_service.py already stores its own user/assistant
    messages.
    """

    if not session_id:
        return

    add_message(
        session_id,
        "user",
        question
    )

    add_message(
        session_id,
        "assistant",
        answer
    )


# ==========================================================
# FINALIZE RESPONSE
# ==========================================================

def finalize_local_response(
    question: str,
    response: dict,
    session_id: Optional[str],
    user_id: Optional[str],
    mode: str
) -> dict:
    """
    Finalize LOCAL_RULES or SYSTEM responses.

    Saves:
    - short-term RAM history
    - persistent Firestore history
    """

    if response.get(
        "answer_source"
    ) == "LOCAL_RULES":

        save_local_turn_to_memory(
            session_id=session_id,
            question=question,
            answer=response.get(
                "answer",
                ""
            )
        )

    persist_chat_turn_safely(
        session_id=session_id,
        question=question,
        response=response,
        user_id=user_id,
        mode=mode
    )

    return response


def finalize_ai_response(
    question: str,
    response: dict,
    session_id: Optional[str],
    user_id: Optional[str],
    mode: str
) -> dict:
    """
    Finalize Groq responses.

    ai_service.py already stores the conversation in
    short-term session memory.

    Therefore this function only persists it to Firestore.
    """

    persist_chat_turn_safely(
        session_id=session_id,
        question=question,
        response=response,
        user_id=user_id,
        mode=mode
    )

    return response


# ==========================================================
# GENERAL RESPONSES
# ==========================================================

def answer_greeting() -> str:
    return (
        "Hello. I can help you with inventory, "
        "stock movements, recommendations, analytics "
        "and inventory summaries."
    )


def answer_help() -> str:
    return (
        "You can ask about current stock, inventory health, "
        "pending recommendations, stock movements, transfer "
        "quantities, recommendation confidence, risks, "
        "alternative stores, dashboard summaries and "
        "managerial inventory questions."
    )


# ==========================================================
# INVENTORY
# ==========================================================

def answer_current_stock(
    product_id: Optional[str],
    store_id: Optional[str]
) -> str:

    if not product_id:
        return (
            "Please specify the product ID so I can "
            "check the current stock."
        )

    inventory = get_inventory_by_product(
        product_id
    )

    if not inventory:
        return (
            f"No inventory records were found for "
            f"{product_id}."
        )

    if store_id:

        items = [
            item
            for item in inventory
            if item.get("store_id") == store_id
        ]

        if not items:
            return (
                f"No inventory record was found for "
                f"{product_id} at {store_id}."
            )

        item = items[0]

        return (
            f"The current stock of {product_id} at "
            f"{store_id} is "
            f"{format_number(item.get('current_stock'))} "
            f"units."
        )

    stock_parts = []

    for item in inventory:

        stock_parts.append(
            f"{item.get('store_id')}: "
            f"{format_number(item.get('current_stock'))} "
            f"units"
        )

    return (
        f"Current stock for {product_id}: "
        + "; ".join(stock_parts)
        + "."
    )


def calculate_inventory_health(
    item: dict
) -> str:

    stored_health = item.get(
        "stock_health"
    )

    if stored_health:
        return stored_health

    try:
        current_stock = int(
            item.get(
                "current_stock",
                0
            )
        )

        reorder_level = int(
            item.get(
                "reorder_level",
                0
            )
        )

        max_stock = int(
            item.get(
                "max_stock",
                0
            )
        )

    except (TypeError, ValueError):
        return "UNKNOWN"

    if current_stock <= reorder_level:
        return "LOW_STOCK"

    if (
        max_stock > 0
        and current_stock
        >= max_stock * 0.85
    ):
        return "OVERSTOCK"

    return "HEALTHY"


def answer_inventory_health(
    product_id: Optional[str],
    store_id: Optional[str]
) -> str:

    if not product_id:
        return (
            "Please specify the product ID so I can "
            "check its inventory health."
        )

    inventory = get_inventory_by_product(
        product_id
    )

    if not inventory:
        return (
            f"No inventory records were found for "
            f"{product_id}."
        )

    if store_id:
        inventory = [
            item
            for item in inventory
            if item.get("store_id") == store_id
        ]

    if not inventory:
        return (
            f"No matching inventory record was found "
            f"for {product_id}."
        )

    results = []

    for item in inventory:

        health = calculate_inventory_health(
            item
        )

        results.append(
            f"{item.get('store_id')}: "
            f"{health} "
            f"(stock "
            f"{format_number(item.get('current_stock'))}, "
            f"reorder level "
            f"{format_number(item.get('reorder_level'))})"
        )

    return (
        f"Inventory health for {product_id}: "
        + "; ".join(results)
        + "."
    )


# ==========================================================
# DASHBOARD
# ==========================================================

def answer_pending_approvals() -> str:

    movements = get_all_stock_movements()

    pending = [
        movement
        for movement in movements
        if movement.get(
            "movement_status"
        ) == "RECOMMENDED"
    ]

    count = len(pending)

    if count == 0:
        return (
            "There are currently no recommendations "
            "waiting for a manager decision."
        )

    if count == 1:
        return (
            "There is currently 1 recommendation "
            "waiting for a manager decision."
        )

    return (
        f"There are currently {count} recommendations "
        f"waiting for a manager decision."
    )


def answer_dashboard_summary() -> str:

    dashboard = get_document_by_id(
        ANALYTICS_SUMMARY_COLLECTION,
        "dashboard"
    )

    if dashboard is None:
        return (
            "The inventory dashboard summary is "
            "currently unavailable."
        )

    return (
        f"The current inventory contains "
        f"{format_number(dashboard.get('total_inventory_quantity'))} "
        f"units with an estimated inventory value of "
        f"{format_currency(dashboard.get('total_inventory_value'))}. "
        f"There are "
        f"{format_number(dashboard.get('low_stock_items'))} "
        f"low-stock items and "
        f"{format_number(dashboard.get('overstock_items'))} "
        f"overstock items."
    )


# ==========================================================
# MOVEMENT ANSWERS
# ==========================================================

def answer_movement_status(
    movement: dict
) -> str:

    status = movement.get(
        "movement_status",
        "UNKNOWN"
    )

    return (
        f"The current movement status is "
        f"{status}."
    )


def answer_movement_details(
    movement: dict
) -> str:

    return (
        f"The recommendation is to transfer "
        f"{format_number(movement.get('recommended_qty'))} "
        f"units of "
        f"{movement.get('product_name', movement.get('product_id'))} "
        f"from {movement.get('from_store')} "
        f"to {movement.get('to_store')}."
    )


def answer_transfer_quantity(
    movement: dict
) -> str:

    return (
        f"The recommended transfer quantity is "
        f"{format_number(movement.get('recommended_qty'))} "
        f"units."
    )


def answer_confidence(
    movement: dict
) -> str:

    confidence = movement.get(
        "decision_confidence"
    )

    if confidence is None:
        return (
            "The recommendation confidence is "
            "not available for this movement."
        )

    try:
        confidence_value = float(
            confidence
        )

    except (TypeError, ValueError):
        return (
            "The recommendation confidence is "
            "not available for this movement."
        )

    if confidence_value >= 90:
        label = "VERY HIGH"

    elif confidence_value >= 75:
        label = "HIGH"

    elif confidence_value >= 60:
        label = "MEDIUM"

    else:
        label = "LOW"

    return (
        f"The recommendation confidence is "
        f"{format_number(confidence_value)}% "
        f"and is classified as {label}."
    )


def answer_risk(
    movement: dict
) -> str:

    simulation_status = movement.get(
        "simulation_status",
        "UNKNOWN"
    )

    remaining_buffer = movement.get(
        "remaining_buffer"
    )

    source_stock_after = movement.get(
        "source_stock_after"
    )

    source_reorder_level = movement.get(
        "source_reorder_level"
    )

    return (
        f"The transfer simulation status is "
        f"{simulation_status}. "
        f"After the proposed transfer, the source store "
        f"is expected to have "
        f"{format_number(source_stock_after)} units remaining, "
        f"with a reorder level of "
        f"{format_number(source_reorder_level)} units. "
        f"This leaves a remaining buffer of "
        f"{format_number(remaining_buffer)} units."
    )


def answer_alternatives(
    movement: dict
) -> str:

    alternatives = (
        movement.get(
            "alternative_sources"
        )
        or []
    )

    evaluated_sources = (
        movement.get(
            "evaluated_sources"
        )
        or []
    )

    if not alternatives:
        return (
            "No alternative source stores were "
            "recorded for this recommendation."
        )

    details = []

    for store_id in alternatives:

        source = next(
            (
                item
                for item in evaluated_sources
                if item.get("store_id")
                == store_id
            ),
            None
        )

        if source:

            details.append(
                f"{store_id} "
                f"(score "
                f"{format_number(source.get('transfer_score'))}, "
                f"distance "
                f"{format_number(source.get('distance_km'))} km, "
                f"cost "
                f"{format_currency(source.get('estimated_transfer_cost'))})"
            )

        else:
            details.append(
                store_id
            )

    return (
        "The main alternative source stores are "
        + "; ".join(details)
        + "."
    )


def answer_transaction(
    movement: dict
) -> str:

    transaction_id = movement.get(
        "transaction_id"
    )

    if not transaction_id:
        return (
            "No inventory transaction has been recorded "
            "for this movement yet."
        )

    return (
        f"The inventory transaction ID is "
        f"{transaction_id}."
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
        movement.get(
            "movement_status"
        )
        != "EXECUTED"
    ):
        return (
            "An execution summary is not available "
            "because this movement has not been executed."
        )

    return (
        f"The transfer was executed from "
        f"{movement.get('from_store')} to "
        f"{movement.get('to_store')}. "
        f"The source stock changed from "
        f"{format_number(movement.get('actual_source_stock_before'))} "
        f"to "
        f"{format_number(movement.get('actual_source_stock_after'))}, "
        f"while the target stock changed from "
        f"{format_number(movement.get('actual_target_stock_before'))} "
        f"to "
        f"{format_number(movement.get('actual_target_stock_after'))}."
    )


def answer_saved_explanation(
    movement: dict
) -> str:

    explanation = movement.get(
        "ai_explanation"
    )

    if explanation:
        return explanation

    recommendation_reason = movement.get(
        "recommendation_reason"
    )

    if recommendation_reason:
        return recommendation_reason

    return (
        "A saved explanation is not available "
        "for this recommendation."
    )


# ==========================================================
# STORE COMPARISON
# ==========================================================

def answer_store_comparison(
    movement: dict,
    compare_store_id: Optional[str]
) -> str:

    if not compare_store_id:
        return (
            "Please specify the store you want "
            "to compare."
        )

    selected_store = movement.get(
        "from_store"
    )

    evaluated_sources = (
        movement.get(
            "evaluated_sources"
        )
        or []
    )

    selected = next(
        (
            item
            for item in evaluated_sources
            if item.get("store_id")
            == selected_store
        ),
        None
    )

    alternative = next(
        (
            item
            for item in evaluated_sources
            if item.get("store_id")
            == compare_store_id
        ),
        None
    )

    if alternative is None:
        return (
            f"{compare_store_id} was not found among "
            f"the evaluated source stores."
        )

    if selected is None:
        return (
            f"{selected_store} was selected, but its "
            f"detailed evaluation data is unavailable."
        )

    return (
        f"{selected_store} was selected instead of "
        f"{compare_store_id} because it achieved a higher "
        f"transfer score "
        f"({format_number(selected.get('transfer_score'))} vs "
        f"{format_number(alternative.get('transfer_score'))}). "
        f"{selected_store} is "
        f"{format_number(selected.get('distance_km'))} km away "
        f"with an estimated transfer cost of "
        f"{format_currency(selected.get('estimated_transfer_cost'))}, "
        f"while {compare_store_id} is "
        f"{format_number(alternative.get('distance_km'))} km away "
        f"with an estimated cost of "
        f"{format_currency(alternative.get('estimated_transfer_cost'))}. "
        f"The selected store also retains "
        f"{format_number(selected.get('remaining_buffer'))} units "
        f"above its reorder level after the transfer."
    )


# ==========================================================
# MAIN CHAT HANDLER
# ==========================================================

def handle_chat(
    message: str,
    movement_id: Optional[str] = None,
    session_id: Optional[str] = None,
    user_id: Optional[str] = None,
    mode: str = "GENERAL"
) -> dict:

    try:

        # --------------------------------------------------
        # INTENT DETECTION
        # --------------------------------------------------

        detection = detect_intent(
            message
        )

        intent = detection.get(
            "intent",
            "unknown"
        )

        category = detection.get(
            "category",
            "unknown"
        )

        entities = detection.get(
            "entities",
            {}
        )

        # --------------------------------------------------
        # RESOLVE MOVEMENT
        # --------------------------------------------------

        detected_movement_id = entities.get(
            "movement_id"
        )

        session_movement_id = None

        if session_id:
            session_movement_id = (
                get_session_movement_id(
                    session_id
                )
            )

        resolved_movement_id = (
            detected_movement_id
            or movement_id
            or session_movement_id
        )

        # Remember most recently used movement.
        if (
            session_id
            and resolved_movement_id
        ):
            set_movement_id(
                session_id,
                resolved_movement_id
            )

        # --------------------------------------------------
        # GREETING
        # --------------------------------------------------

        if intent == "greeting":

            response = build_response(
                intent=intent,
                category=category,
                answer=answer_greeting(),
                session_id=session_id
            )

            return finalize_local_response(
                question=message,
                response=response,
                session_id=session_id,
                user_id=user_id,
                mode=mode
            )

        # --------------------------------------------------
        # HELP
        # --------------------------------------------------

        if intent == "help":

            response = build_response(
                intent=intent,
                category=category,
                answer=answer_help(),
                session_id=session_id
            )

            return finalize_local_response(
                question=message,
                response=response,
                session_id=session_id,
                user_id=user_id,
                mode=mode
            )

        # --------------------------------------------------
        # CURRENT STOCK
        # --------------------------------------------------

        if intent == "current_stock":

            answer = answer_current_stock(
                product_id=entities.get(
                    "product_id"
                ),
                store_id=entities.get(
                    "store_id"
                )
            )

            response = build_response(
                intent=intent,
                category=category,
                answer=answer,
                session_id=session_id
            )

            return finalize_local_response(
                question=message,
                response=response,
                session_id=session_id,
                user_id=user_id,
                mode=mode
            )

        # --------------------------------------------------
        # INVENTORY HEALTH
        # --------------------------------------------------

        if intent == "inventory_health":

            answer = answer_inventory_health(
                product_id=entities.get(
                    "product_id"
                ),
                store_id=entities.get(
                    "store_id"
                )
            )

            response = build_response(
                intent=intent,
                category=category,
                answer=answer,
                session_id=session_id
            )

            return finalize_local_response(
                question=message,
                response=response,
                session_id=session_id,
                user_id=user_id,
                mode=mode
            )

        # --------------------------------------------------
        # PENDING APPROVALS
        # --------------------------------------------------

        if intent == "pending_approvals":

            response = build_response(
                intent=intent,
                category=category,
                answer=answer_pending_approvals(),
                session_id=session_id
            )

            return finalize_local_response(
                question=message,
                response=response,
                session_id=session_id,
                user_id=user_id,
                mode=mode
            )

        # --------------------------------------------------
        # DASHBOARD SUMMARY
        # --------------------------------------------------

        if intent == "dashboard_summary":

            response = build_response(
                intent=intent,
                category=category,
                answer=answer_dashboard_summary(),
                session_id=session_id
            )

            return finalize_local_response(
                question=message,
                response=response,
                session_id=session_id,
                user_id=user_id,
                mode=mode
            )

        # --------------------------------------------------
        # MOVEMENT-SPECIFIC LOCAL QUESTION
        # --------------------------------------------------

        if detection.get(
            "requires_movement"
        ):

            if not resolved_movement_id:

                response = build_response(
                    intent=intent,
                    category=category,
                    answer=(
                        "Please select a stock movement "
                        "before asking this question."
                    ),
                    answer_source="SYSTEM",
                    error_code="MOVEMENT_REQUIRED",
                    session_id=session_id
                )

                return finalize_local_response(
                    question=message,
                    response=response,
                    session_id=session_id,
                    user_id=user_id,
                    mode=mode
                )

            movement = (
                get_stock_movement_by_id(
                    resolved_movement_id
                )
            )

            if movement is None:

                response = build_response(
                    intent=intent,
                    category=category,
                    answer=(
                        "The requested stock movement "
                        "could not be found."
                    ),
                    answer_source="SYSTEM",
                    movement_id=resolved_movement_id,
                    error_code="MOVEMENT_NOT_FOUND",
                    session_id=session_id
                )

                return finalize_local_response(
                    question=message,
                    response=response,
                    session_id=session_id,
                    user_id=user_id,
                    mode=mode
                )

            if intent == "movement_status":

                answer = answer_movement_status(
                    movement
                )

            elif intent == "movement_details":

                answer = answer_movement_details(
                    movement
                )

            elif intent == "transfer_quantity":

                answer = answer_transfer_quantity(
                    movement
                )

            elif intent == "recommendation_confidence":

                answer = answer_confidence(
                    movement
                )

            elif intent == "recommendation_risk":

                answer = answer_risk(
                    movement
                )

            elif intent == "alternative_stores":

                answer = answer_alternatives(
                    movement
                )

            elif intent == "transaction_details":

                answer = answer_transaction(
                    movement
                )

            elif intent == "execution_summary":

                answer = answer_execution_summary(
                    movement
                )

            elif intent == "recommendation_explanation":

                answer = answer_saved_explanation(
                    movement
                )


            elif intent == "store_comparison":

                selected_store = movement.get(

                    "from_store"

                )

                detected_store_ids = entities.get(

                    "store_ids",

                    []

                )

                compare_store_id = next(

                    (

                        store_id

                        for store_id in detected_store_ids

                        if store_id != selected_store

                    ),

                    None

                )

                # Fallback for questions containing only

                # one comparison store.

                if compare_store_id is None:

                    detected_store = entities.get(

                        "store_id"

                    )

                    if (

                            detected_store

                            and detected_store != selected_store

                    ):
                        compare_store_id = (

                            detected_store

                        )

                answer = answer_store_comparison(

                    movement=movement,

                    compare_store_id=compare_store_id

                )

            else:

                answer = (
                    "I could not determine the requested "
                    "movement information."
                )

            response = build_response(
                intent=intent,
                category=category,
                answer=answer,
                answer_source="LOCAL_RULES",
                movement=movement,
                session_id=session_id
            )

            return finalize_local_response(
                question=message,
                response=response,
                session_id=session_id,
                user_id=user_id,
                mode=mode
            )

        # --------------------------------------------------
        # OPEN-ENDED GROQ QUESTION
        # --------------------------------------------------

        if detection.get(
            "requires_ai"
        ):

            movement = None

            if resolved_movement_id:

                movement = (
                    get_stock_movement_by_id(
                        resolved_movement_id
                    )
                )

            context = build_chat_context(
                movement=movement
            )

            ai_result = generate_ai_answer(
                question=message,
                context=context,
                session_id=session_id,
                mode=mode
            )

            ai_text = ai_result.get(
                "text"
            )

            if ai_text:

                response = build_response(
                    intent=intent,
                    category=category,
                    answer=ai_text,
                    answer_source="GROQ",
                    movement=movement,
                    movement_id=resolved_movement_id,
                    ai_model=ai_result.get(
                        "model"
                    ),
                    session_id=session_id
                )

                return finalize_ai_response(
                    question=message,
                    response=response,
                    session_id=session_id,
                    user_id=user_id,
                    mode=mode
                )

            # ----------------------------------------------
            # GROQ FAILURE
            # ----------------------------------------------

            response = build_response(
                intent=intent,
                category=category,
                answer=(
                    "The AI assistant is temporarily "
                    "unavailable. Please try again."
                ),
                answer_source="SYSTEM",
                movement=movement,
                movement_id=resolved_movement_id,
                ai_model=ai_result.get(
                    "model"
                ),
                error_code=ai_result.get(
                    "error"
                ),
                session_id=session_id
            )

            return finalize_ai_response(
                question=message,
                response=response,
                session_id=session_id,
                user_id=user_id,
                mode=mode
            )

        # --------------------------------------------------
        # UNKNOWN FALLBACK
        # --------------------------------------------------

        response = build_response(
            intent=intent,
            category=category,
            answer=(
                "I could not understand the question."
            ),
            answer_source="SYSTEM",
            movement_id=resolved_movement_id,
            error_code="UNKNOWN_INTENT",
            session_id=session_id
        )

        return finalize_local_response(
            question=message,
            response=response,
            session_id=session_id,
            user_id=user_id,
            mode=mode
        )

    # ======================================================
    # GLOBAL CHAT FAILURE
    # ======================================================

    except Exception as exc:

        print(
            f"Manager assistant error: {exc}"
        )

        response = build_response(
            intent="unknown",
            category="unknown",
            answer=(
                "The manager assistant could not "
                "process the request."
            ),
            answer_source="SYSTEM",
            movement_id=movement_id,
            error_code="CHAT_PROCESSING_FAILED",
            session_id=session_id
        )

        return response