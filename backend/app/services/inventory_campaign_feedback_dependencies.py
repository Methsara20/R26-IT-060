"""Lazy Inventory-only wiring. Never initialize a client or shared application."""
from fastapi import Depends
from app.security.inventory_marketing_service_auth import require_marketing_service, feedback_error
from app.services.inventory_auth_dependencies import get_existing_inventory_mongo_wrapper
from app.services.inventory_campaign_feedback_repository import InventoryCampaignFeedbackRepository


def get_campaign_feedback_repository(identity=Depends(require_marketing_service)):
    try:
        wrapper = get_existing_inventory_mongo_wrapper()
        if wrapper.db.client is not wrapper.client:
            raise ValueError()
        return InventoryCampaignFeedbackRepository(wrapper.db)
    except Exception:
        raise feedback_error(503, "FEEDBACK_UNAVAILABLE") from None
