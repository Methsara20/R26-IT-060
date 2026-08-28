from datetime import datetime, timezone
from uuid import uuid4

from app.constants.collections import (
    MARKETING_OPPORTUNITIES_COLLECTION,
)
from app.services.firebase_service import (
    create_or_update_document,
)


class MarketingOpportunityValidationError(Exception):
    pass


def create_marketing_opportunity(data):
    recommended_action = (
        data.recommended_action
        .strip()
        .upper()
    )

    if recommended_action != "PROMOTE":
        raise MarketingOpportunityValidationError(
            "Only inventory results with recommended_action "
            "'PROMOTE' can be sent to Marketing."
        )

    opportunity_id = (
        "MKT-OPP-"
        + uuid4().hex[:12].upper()
    )

    payload = {
        "opportunity_id": opportunity_id,
        "workflow_id": data.workflow_id,
        "source_component": "SMART_INVENTORY",

        "product_id": data.product_id,
        "product_name": data.product_name,

        "store_id": data.store_id,

        "category": data.category,
        "subcategory": data.subcategory,
        "brand": data.brand,
        "gender": data.gender,

        "current_stock": data.current_stock,
        "forecast_demand": data.forecast_demand,
        "required_stock": data.required_stock,
        "excess_quantity": data.excess_quantity,

        "selling_price": data.selling_price,

        "stock_health": data.stock_health,
        "recommended_action": recommended_action,

        "status": "PENDING_MARKETING",

        "created_at": datetime.now(
            timezone.utc
        ).isoformat(),
    }

    # Add promotion_percent only when the frontend sends a value.
    if data.promotion_percent is not None:
        payload["promotion_percent"] = data.promotion_percent

    create_or_update_document(
        MARKETING_OPPORTUNITIES_COLLECTION,
        opportunity_id,
        payload,
        merge=False,
    )

    return {
        "opportunity_id": opportunity_id,
        "workflow_id": data.workflow_id,
        "status": "PENDING_MARKETING",
        "message": (
            "Marketing opportunity sent successfully."
        ),
    }