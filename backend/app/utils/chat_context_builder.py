from typing import Optional

def safe_float(value) -> Optional[float]:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None

def build_source_comparisons(
    movement: dict
) -> dict:
    """
    Build deterministic comparisons between the selected
    source and every evaluated source.

    This does NOT recalculate the recommendation.
    """

    selected_store = movement.get("from_store")

    evaluated_sources = (
        movement.get("evaluated_sources")
        or []
    )

    if not selected_store or not evaluated_sources:
        return {}

    selected = next(
        (
            source
            for source in evaluated_sources
            if source.get("store_id") == selected_store
        ),
        None
    )

    if not selected:
        return {}

    selected_distance = safe_float(
        selected.get("distance_km")
    )

    selected_cost = safe_float(
        selected.get("estimated_transfer_cost")
    )

    selected_score = safe_float(
        selected.get("transfer_score")
    )

    selected_buffer = safe_float(
        selected.get("remaining_buffer")
    )

    comparisons = []

    for source in evaluated_sources:

        store_id = source.get("store_id")

        if store_id == selected_store:
            continue

        distance = safe_float(
            source.get("distance_km")
        )

        cost = safe_float(
            source.get("estimated_transfer_cost")
        )

        score = safe_float(
            source.get("transfer_score")
        )

        buffer_value = safe_float(
            source.get("remaining_buffer")
        )

        comparison = {
            "store_id": store_id,
            "rank": source.get("rank"),

            "distance_km": distance,
            "estimated_transfer_cost": cost,
            "currency": "LKR",
            "transfer_score": score,
            "source_remaining_buffer": buffer_value,

            "compared_with_selected": {
                "distance": None,
                "cost": None,
                "transfer_score": None,
                "remaining_buffer": None
            }
        }

        if (
            distance is not None
            and selected_distance is not None
        ):
            if distance < selected_distance:
                comparison[
                    "compared_with_selected"
                ]["distance"] = "CLOSER"

            elif distance > selected_distance:
                comparison[
                    "compared_with_selected"
                ]["distance"] = "FARTHER"

            else:
                comparison[
                    "compared_with_selected"
                ]["distance"] = "EQUAL"

        if (
            cost is not None
            and selected_cost is not None
        ):
            if cost < selected_cost:
                comparison[
                    "compared_with_selected"
                ]["cost"] = "LOWER"

            elif cost > selected_cost:
                comparison[
                    "compared_with_selected"
                ]["cost"] = "HIGHER"

            else:
                comparison[
                    "compared_with_selected"
                ]["cost"] = "EQUAL"

        if (
            score is not None
            and selected_score is not None
        ):
            if score < selected_score:
                comparison[
                    "compared_with_selected"
                ]["transfer_score"] = "LOWER"

            elif score > selected_score:
                comparison[
                    "compared_with_selected"
                ]["transfer_score"] = "HIGHER"

            else:
                comparison[
                    "compared_with_selected"
                ]["transfer_score"] = "EQUAL"

        if (
            buffer_value is not None
            and selected_buffer is not None
        ):
            if buffer_value < selected_buffer:
                comparison[
                    "compared_with_selected"
                ]["remaining_buffer"] = "LOWER"

            elif buffer_value > selected_buffer:
                comparison[
                    "compared_with_selected"
                ]["remaining_buffer"] = "HIGHER"

            else:
                comparison[
                    "compared_with_selected"
                ]["remaining_buffer"] = "EQUAL"

        comparisons.append(comparison)

    valid_distances = [
        source
        for source in evaluated_sources
        if safe_float(
            source.get("distance_km")
        ) is not None
    ]

    valid_costs = [
        source
        for source in evaluated_sources
        if safe_float(
            source.get("estimated_transfer_cost")
        ) is not None
    ]

    valid_scores = [
        source
        for source in evaluated_sources
        if safe_float(
            source.get("transfer_score")
        ) is not None
    ]

    closest_store = (
        min(
            valid_distances,
            key=lambda x: safe_float(
                x.get("distance_km")
            )
        ).get("store_id")
        if valid_distances
        else None
    )

    lowest_cost_store = (
        min(
            valid_costs,
            key=lambda x: safe_float(
                x.get("estimated_transfer_cost")
            )
        ).get("store_id")
        if valid_costs
        else None
    )

    highest_score_store = (
        max(
            valid_scores,
            key=lambda x: safe_float(
                x.get("transfer_score")
            )
        ).get("store_id")
        if valid_scores
        else None
    )

    return {
        "selected_store": selected_store,

        "closest_store": closest_store,

        "lowest_cost_store": lowest_cost_store,

        "highest_transfer_score_store": (
            highest_score_store
        ),

        "selected_store_is_closest": (
            closest_store == selected_store
            if closest_store
            else None
        ),

        "selected_store_is_lowest_cost": (
            lowest_cost_store == selected_store
            if lowest_cost_store
            else None
        ),

        "selected_store_has_highest_score": (
            highest_score_store == selected_store
            if highest_score_store
            else None
        ),

        "comparisons": comparisons
    }

def build_movement_context(
    movement: Optional[dict]
) -> dict:
    """
    Build compact context for movement-related AI questions.

    Important:
    - Does NOT recalculate recommendation
    - Does NOT call Firestore
    - Does NOT call Gemini
    - Does NOT call Groq
    """

    if not movement:
        return {}

    return {
        "movement_id": movement.get("movement_id"),
        "movement_status": movement.get("movement_status"),

        "product": {
            "product_id": movement.get("product_id"),
            "product_name": movement.get("product_name"),
            "brand": movement.get("brand"),
            "category": movement.get("category"),
            "subcategory": movement.get("subcategory"),
            "gender": movement.get("gender")
        },

        "decision": {
            "source_store": movement.get("from_store"),
            "target_store": movement.get("to_store"),
            "recommended_qty": movement.get("recommended_qty"),
            "transfer_score": movement.get("transfer_score"),
            "decision_confidence": movement.get(
                "decision_confidence"
            ),
            "transfer_priority": movement.get(
                "transfer_priority"
            )
        },

        "inventory_impact": {
            "source_stock_before": movement.get(
                "source_stock_before"
            ),
            "source_stock_after": movement.get(
                "source_stock_after"
            ),
            "source_reorder_level": movement.get(
                "source_reorder_level"
            ),
            "target_stock_before": movement.get(
                "target_stock_before"
            ),
            "target_stock_after": movement.get(
                "target_stock_after"
            ),
            "target_reorder_level": movement.get(
                "target_reorder_level"
            ),
            "source_remaining_buffer": movement.get(
                "remaining_buffer"
            )
        },

        "logistics": {
            "distance_km": movement.get("distance_km"),
            "estimated_time_minutes": movement.get(
            "estimated_time_minutes"
        ),
                "estimated_transfer_cost": movement.get(
                    "estimated_transfer_cost"
                ),
            "currency": "LKR"
        },

        "safety": {
            "simulation_status": movement.get(
                "simulation_status"
            ),
            "coverage_percentage": movement.get(
                "coverage_percentage"
            )
        },

        "alternative_sources": (
            movement.get("alternative_sources")
            or []
        ),


        "evaluated_sources": [
            {
                "store_id": source.get("store_id"),
                "rank": source.get("rank"),
                "transfer_score": source.get(
                    "transfer_score"
                ),
                "coverage_percentage": source.get(
                    "coverage_percentage"
                ),
                "distance_km": source.get(
                    "distance_km"
                ),
                "estimated_transfer_cost": source.get(
                    "estimated_transfer_cost"
                ),
                "currency": "LKR",
                "remaining_buffer": source.get(
                    "remaining_buffer"
                ),
                "reorder_level": source.get(
                    "reorder_level"
                ),

                "score_breakdown": {
                    "coverage_score": (
                        source.get("score_breakdown", {})
                        .get("coverage_score")
                    ),
                    "distance_score": (
                        source.get("score_breakdown", {})
                        .get("distance_score")
                    ),
                    "safety_score": (
                        source.get("score_breakdown", {})
                        .get("safety_score")
                    ),
                    "buffer_score": (
                        source.get("score_breakdown", {})
                        .get("buffer_score")
                    ),
                    "surplus_score": (
                        source.get("score_breakdown", {})
                        .get("surplus_score")
                    )
                },

            }
            for source in (
                movement.get("evaluated_sources")
                or []
            )
        ],

        "source_comparison": build_source_comparisons(
            movement
        ),

        "saved_explanation": movement.get(
            "ai_explanation"
        )
        or movement.get(
            "recommendation_reason"
        ),

        "execution_summary": movement.get(
            "ai_execution_summary"
        )
    }


def build_inventory_context(
    inventory_items: list[dict]
) -> dict:
    """
    Build compact inventory context for AI reasoning.
    """

    if not inventory_items:
        return {}

    compact_items = []

    for item in inventory_items[:10]:
        compact_items.append({
            "inventory_id": item.get("inventory_id")
                or item.get("id"),
            "product_id": item.get("product_id"),
            "store_id": item.get("store_id"),
            "current_stock": item.get(
                "current_stock"
            ),
            "reorder_level": item.get(
                "reorder_level"
            ),
            "max_stock": item.get(
                "max_stock"
            ),
            "stock_health": item.get(
                "stock_health"
            )
        })

    return {
        "items": compact_items,
        "item_count": len(inventory_items)
    }


def build_dashboard_context(
    dashboard: Optional[dict]
) -> dict:
    """
    Build compact dashboard context.
    """

    if not dashboard:
        return {}

    return {
        "total_inventory_quantity": dashboard.get(
            "total_inventory_quantity"
        ),
        "total_inventory_value": dashboard.get(
            "total_inventory_value"
        ),
        "low_stock_items": dashboard.get(
            "low_stock_items"
        ),
        "overstock_items": dashboard.get(
            "overstock_items"
        ),
        "total_potential_revenue": dashboard.get(
            "total_potential_revenue"
        ),
        "total_potential_profit": dashboard.get(
            "total_potential_profit"
        ),
        "last_updated": dashboard.get(
            "last_updated"
        )
    }


def build_chat_context(
    movement: Optional[dict] = None,
    inventory_items: Optional[list[dict]] = None,
    dashboard: Optional[dict] = None
) -> dict:
    """
    Build the final minimal context that can later
    be sent to Groq.
    """

    context = {}

    if movement:
        context["movement"] = build_movement_context(
            movement
        )

    if inventory_items:
        context["inventory"] = build_inventory_context(
            inventory_items
        )

    if dashboard:
        context["dashboard"] = build_dashboard_context(
            dashboard
        )

    return context