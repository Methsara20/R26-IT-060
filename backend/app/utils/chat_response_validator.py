import re
from typing import Optional


# ==========================================================
# HELPERS
# ==========================================================

def format_number(value) -> str:
    try:
        number = float(value)

        if number.is_integer():
            return f"{int(number):,}"

        return f"{number:,.2f}"

    except (TypeError, ValueError):
        return "Unavailable"


def normalize_text(text: str) -> str:
    if not text:
        return ""

    return " ".join(
        text.lower().split()
    )


# ==========================================================
# FACT BUILDERS
# ==========================================================

def build_expected_facts(
    context: Optional[dict]
) -> dict:
    """
    Build deterministic facts from supplied chatbot context.

    This does NOT:
    - call Groq
    - call Gemini
    - query Firestore
    - recalculate recommendations
    """

    if not context:
        return {}

    movement = context.get(
        "movement",
        {}
    )

    decision = movement.get(
        "decision",
        {}
    )

    inventory = movement.get(
        "inventory_impact",
        {}
    )

    logistics = movement.get(
        "logistics",
        {}
    )

    safety = movement.get(
        "safety",
        {}
    )

    facts = {
        "source_store": decision.get(
            "source_store"
        ),

        "target_store": decision.get(
            "target_store"
        ),

        "recommended_qty": decision.get(
            "recommended_qty"
        ),

        "transfer_score": decision.get(
            "transfer_score"
        ),

        "decision_confidence": decision.get(
            "decision_confidence"
        ),

        "source_stock_before": inventory.get(
            "source_stock_before"
        ),

        "source_stock_after": inventory.get(
            "source_stock_after"
        ),

        "source_reorder_level": inventory.get(
            "source_reorder_level"
        ),

        "source_remaining_buffer": (
            inventory.get(
                "source_remaining_buffer"
            )
            if inventory.get(
                "source_remaining_buffer"
            ) is not None
            else inventory.get(
                "remaining_buffer"
            )
        ),

        "target_stock_before": inventory.get(
            "target_stock_before"
        ),

        "target_stock_after": inventory.get(
            "target_stock_after"
        ),

        "target_reorder_level": inventory.get(
            "target_reorder_level"
        ),

        "distance_km": logistics.get(
            "distance_km"
        ),

        "estimated_transfer_cost": logistics.get(
            "estimated_transfer_cost"
        ),

        "currency": logistics.get(
            "currency",
            "LKR"
        ),

        "simulation_status": safety.get(
            "simulation_status"
        )
    }

    return facts


# ==========================================================
# NUMERIC RELATIONSHIPS
# ==========================================================

def compare_values(
    left,
    right
) -> Optional[str]:
    """
    Return:
    - ABOVE
    - BELOW
    - EQUAL
    """

    try:
        left_value = float(left)
        right_value = float(right)

    except (TypeError, ValueError):
        return None

    if left_value > right_value:
        return "ABOVE"

    if left_value < right_value:
        return "BELOW"

    return "EQUAL"


# ==========================================================
# CORRECTION RULES
# ==========================================================

def correct_source_stock_relationship(
    answer: str,
    facts: dict
) -> tuple[str, bool]:

    source_after = facts.get(
        "source_stock_after"
    )

    reorder_level = facts.get(
        "source_reorder_level"
    )

    source_store = facts.get(
        "source_store"
    )

    remaining_buffer = facts.get(
        "source_remaining_buffer"
    )

    relation = compare_values(
        source_after,
        reorder_level
    )

    if not relation:
        return answer, False

    normalized = normalize_text(
        answer
    )

    changed = False

    if relation == "ABOVE":

        incorrect_patterns = [
            r"below (?:its|the) reorder level",
            r"under (?:its|the) reorder level",
            r"lower than (?:its|the) reorder level"
        ]

        for pattern in incorrect_patterns:

            if re.search(
                pattern,
                normalized
            ):

                replacement = (
                    f"{format_number(source_after)} units "
                    f"remaining after the transfer, which is "
                    f"above its reorder level of "
                    f"{format_number(reorder_level)} units"
                )

                if remaining_buffer is not None:
                    replacement += (
                        f" by "
                        f"{format_number(remaining_buffer)} units"
                    )

                original_pattern = re.compile(
                    r"\d[\d,.]* units remaining after the transfer, "
                    r"which is (?:below|under|lower than) "
                    r"(?:its|the) reorder level of "
                    r"\d[\d,.]* units",
                    flags=re.IGNORECASE
                )

                if original_pattern.search(answer):

                    answer = original_pattern.sub(
                        replacement,
                        answer
                    )

                else:
                    answer += (
                        "\n\nCorrection: "
                        f"{source_store or 'The source store'} "
                        f"will have "
                        f"{format_number(source_after)} units after "
                        f"the transfer, which is above its reorder "
                        f"level of "
                        f"{format_number(reorder_level)} units."
                    )

                changed = True

                break

    elif relation == "EQUAL":

        incorrect_patterns = [
            "above its reorder level",
            "below its reorder level"
        ]

        if any(
            phrase in normalized
            for phrase in incorrect_patterns
        ):
            answer += (
                "\n\nCorrection: The source stock after transfer "
                f"is equal to its reorder level at "
                f"{format_number(source_after)} units."
            )

            changed = True

    return answer, changed


def correct_target_stock_relationship(
    answer: str,
    facts: dict
) -> tuple[str, bool]:

    target_after = facts.get(
        "target_stock_after"
    )

    reorder_level = facts.get(
        "target_reorder_level"
    )

    target_store = facts.get(
        "target_store"
    )

    relation = compare_values(
        target_after,
        reorder_level
    )

    if not relation:
        return answer, False

    normalized = normalize_text(
        answer
    )

    changed = False

    if relation == "EQUAL":

        if (
            "above its reorder level" in normalized
            or "below its reorder level" in normalized
        ):
            answer += (
                "\n\nCorrection: "
                f"{target_store or 'The target store'} "
                f"will have "
                f"{format_number(target_after)} units after "
                f"the transfer, which is equal to its reorder "
                f"level of "
                f"{format_number(reorder_level)} units."
            )

            changed = True

    return answer, changed


def correct_currency(
    answer: str,
    facts: dict
) -> tuple[str, bool]:

    currency = facts.get(
        "currency",
        "LKR"
    )

    if currency != "LKR":
        return answer, False

    changed = False

    patterns = [
        r"\$\s?([\d,.]+)",
        r"USD\s?([\d,.]+)",
        r"([\d,.]+)\s?USD"
    ]

    for pattern in patterns:

        if re.search(
            pattern,
            answer,
            flags=re.IGNORECASE
        ):

            answer = re.sub(
                pattern,
                lambda match: (
                    f"LKR {match.group(1)}"
                ),
                answer,
                flags=re.IGNORECASE
            )

            changed = True

    return answer, changed


# ==========================================================
# UNSUPPORTED CLAIM CHECKS
# ==========================================================

def detect_unsupported_claims(
    answer: str,
    context: Optional[dict]
) -> list[str]:

    issues = []

    normalized = normalize_text(
        answer
    )

    movement = (
        context.get("movement", {})
        if context
        else {}
    )

    inventory = movement.get(
        "inventory_impact",
        {}
    )

    # ------------------------------------------------------
    # Demand-related claims
    # ------------------------------------------------------

    has_demand_data = any(
        key in inventory
        for key in [
            "forecast_demand",
            "predicted_demand",
            "demand"
        ]
    )

    if not has_demand_data:

        demand_claims = [
            "meet its current demand",
            "meet demand",
            "sufficient stock to meet",
            "reduce stockouts",
            "prevent stockouts"
        ]

        if any(
            phrase in normalized
            for phrase in demand_claims
        ):
            issues.append(
                "UNSUPPORTED_DEMAND_CLAIM"
            )

    # ------------------------------------------------------
    # Revenue / profit claims
    # ------------------------------------------------------

    has_revenue_data = any(
        key in movement
        for key in [
            "revenue",
            "sales_revenue",
            "potential_revenue",
            "profit",
            "potential_profit"
        ]
    )

    if not has_revenue_data:

        revenue_claims = [
            "increase revenue",
            "improve revenue",
            "increase sales",
            "improve sales",
            "increase profit",
            "improve profit"
        ]

        if any(
            phrase in normalized
            for phrase in revenue_claims
        ):
            issues.append(
                "UNSUPPORTED_REVENUE_CLAIM"
            )

    return issues


# ==========================================================
# SAFE FALLBACK
# ==========================================================

def build_grounded_fallback(
    facts: dict
) -> str:
    """
    Build a deterministic fallback using verified facts.
    """

    parts = []

    source_store = facts.get(
        "source_store"
    )

    target_store = facts.get(
        "target_store"
    )

    qty = facts.get(
        "recommended_qty"
    )

    if (
        source_store
        and target_store
        and qty is not None
    ):
        parts.append(
            f"The stored recommendation is to transfer "
            f"{format_number(qty)} units from "
            f"{source_store} to {target_store}."
        )

    source_after = facts.get(
        "source_stock_after"
    )

    source_reorder = facts.get(
        "source_reorder_level"
    )

    relation = compare_values(
        source_after,
        source_reorder
    )

    if (
        relation
        and source_after is not None
        and source_reorder is not None
    ):

        relation_text = {
            "ABOVE": "above",
            "BELOW": "below",
            "EQUAL": "equal to"
        }[relation]

        parts.append(
            f"The source stock after transfer is "
            f"{format_number(source_after)} units, which is "
            f"{relation_text} its reorder level of "
            f"{format_number(source_reorder)} units."
        )

    target_after = facts.get(
        "target_stock_after"
    )

    target_reorder = facts.get(
        "target_reorder_level"
    )

    relation = compare_values(
        target_after,
        target_reorder
    )

    if (
        relation
        and target_after is not None
        and target_reorder is not None
    ):

        relation_text = {
            "ABOVE": "above",
            "BELOW": "below",
            "EQUAL": "equal to"
        }[relation]

        parts.append(
            f"The target stock after transfer is "
            f"{format_number(target_after)} units, which is "
            f"{relation_text} its reorder level of "
            f"{format_number(target_reorder)} units."
        )

    simulation_status = facts.get(
        "simulation_status"
    )

    if simulation_status:
        parts.append(
            f"The stored simulation status is "
            f"{simulation_status}."
        )

    if not parts:
        return (
            "The available system context is insufficient "
            "to provide a verified answer."
        )

    return " ".join(parts)


# ==========================================================
# MAIN VALIDATOR
# ==========================================================

def validate_ai_response(
    answer: str,
    context: Optional[dict]
) -> dict:
    """
    Validate a Groq-generated manager response.

    Returns:
    {
        "text": "...",
        "is_valid": True/False,
        "was_corrected": True/False,
        "issues": [...]
    }
    """

    if not answer:
        return {
            "text": None,
            "is_valid": False,
            "was_corrected": False,
            "issues": [
                "EMPTY_RESPONSE"
            ]
        }

    facts = build_expected_facts(
        context
    )

    validated_answer = answer

    was_corrected = False

    issues = []

    # ------------------------------------------------------
    # Currency correction
    # ------------------------------------------------------

    validated_answer, changed = (
        correct_currency(
            validated_answer,
            facts
        )
    )

    if changed:
        was_corrected = True
        issues.append(
            "CURRENCY_CORRECTED"
        )

    # ------------------------------------------------------
    # Source-stock relationship correction
    # ------------------------------------------------------

    validated_answer, changed = (
        correct_source_stock_relationship(
            validated_answer,
            facts
        )
    )

    if changed:
        was_corrected = True
        issues.append(
            "SOURCE_STOCK_RELATIONSHIP_CORRECTED"
        )

    # ------------------------------------------------------
    # Target-stock relationship correction
    # ------------------------------------------------------

    validated_answer, changed = (
        correct_target_stock_relationship(
            validated_answer,
            facts
        )
    )

    if changed:
        was_corrected = True
        issues.append(
            "TARGET_STOCK_RELATIONSHIP_CORRECTED"
        )

    # ------------------------------------------------------
    # Unsupported business claims
    # ------------------------------------------------------

    unsupported = detect_unsupported_claims(
        validated_answer,
        context
    )

    issues.extend(
        unsupported
    )

    # ------------------------------------------------------
    # Unsupported factual/business claims
    # ------------------------------------------------------

    unsupported = detect_unsupported_claims(
        validated_answer,
        context
    )

    managerial_issues = (
        detect_unsupported_managerial_claims(
            validated_answer,
            context
        )
    )

    alternative_cost_issues = (
        validate_alternative_cost_claims(
            validated_answer,
            context
        )
    )

    issues.extend(
        unsupported
    )

    issues.extend(
        managerial_issues
    )

    issues.extend(
        alternative_cost_issues
    )

    blocking_issues = (
            unsupported
            + managerial_issues
            + alternative_cost_issues
    )

    if blocking_issues:
        return {
            "text": build_grounded_fallback(
                facts
            ),

            "is_valid": False,

            "was_corrected": True,

            "issues": issues
        }



    # If unsupported claims remain, do NOT trust
    # the AI-generated explanation.
    if unsupported:

        return {
            "text": build_grounded_fallback(
                facts
            ),

            "is_valid": False,

            "was_corrected": True,

            "issues": issues
        }

    return {
        "text": validated_answer.strip(),

        "is_valid": True,

        "was_corrected": was_corrected,

        "issues": issues
    }

def detect_unsupported_managerial_claims(
    answer: str,
    context: Optional[dict]
) -> list[str]:

    issues = []

    normalized = normalize_text(answer)

    movement = (
        context.get("movement", {})
        if context
        else {}
    )

    # ------------------------------------------------------
    # DEMAND / STOCKOUT CLAIMS
    # ------------------------------------------------------

    has_demand_data = any(
        key in movement
        for key in [
            "forecast",
            "forecast_demand",
            "predicted_demand",
            "demand"
        ]
    )

    if not has_demand_data:

        unsupported_demand_phrases = [
            "sufficient to meet demand",
            "sufficient to meet potential demand",
            "sufficient to meet current demand",
            "reduce stockouts",
            "prevent stockouts",
            "meet customer demand",
            "critical to meeting customer demand"
        ]

        if any(
            phrase in normalized
            for phrase in unsupported_demand_phrases
        ):
            issues.append(
                "UNSUPPORTED_DEMAND_INTERPRETATION"
            )

    # ------------------------------------------------------
    # UNSUPPORTED SAFETY INTERPRETATION
    # ------------------------------------------------------

    unsupported_safety_phrases = [
        "safe inventory level",
        "healthy inventory level"
    ]

    if any(
        phrase in normalized
        for phrase in unsupported_safety_phrases
    ):
        issues.append(
            "UNSUPPORTED_INVENTORY_SAFETY_INTERPRETATION"
        )

    return issues

def validate_alternative_cost_claims(
    answer: str,
    context: Optional[dict]
) -> list[str]:

    issues = []

    if not context:
        return issues

    movement = context.get(
        "movement",
        {}
    )

    evaluated = movement.get(
        "evaluated_sources",
        []
    )

    decision = movement.get(
        "decision",
        {}
    )

    selected_store = decision.get(
        "source_store"
    )

    selected = next(
        (
            item
            for item in evaluated
            if item.get("store_id")
            == selected_store
        ),
        None
    )

    if not selected:
        return issues

    selected_cost = selected.get(
        "estimated_transfer_cost"
    )

    if selected_cost is None:
        return issues

    alternatives = [
        item
        for item in evaluated
        if item.get("store_id")
        != selected_store
    ]

    cheaper_exists = any(
        item.get("estimated_transfer_cost") is not None
        and float(
            item.get("estimated_transfer_cost")
        ) < float(selected_cost)
        for item in alternatives
    )

    normalized = normalize_text(
        answer
    )

    broad_claims = [
        "alternatives have higher estimated transfer costs",
        "alternative stores have higher estimated transfer costs",
        "all alternatives are more expensive",
        "all alternative stores are more expensive"
    ]

    if (
        cheaper_exists
        and any(
            phrase in normalized
            for phrase in broad_claims
        )
    ):
        issues.append(
            "INCORRECT_ALTERNATIVE_COST_GENERALIZATION"
        )

    return issues