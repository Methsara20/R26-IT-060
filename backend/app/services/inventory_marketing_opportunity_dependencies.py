"""Lazy Inventory-only wiring; never creates a MongoDB client or index."""
from app.services.inventory_auth_dependencies import get_existing_inventory_mongo_wrapper
from app.services.inventory_marketing_opportunity_repository import (
    InventoryMarketingOpportunityRepository,
    unavailable,
)


def get_inventory_marketing_opportunity_repository():
    try:
        wrapper = get_existing_inventory_mongo_wrapper()
        if wrapper.db.client is not wrapper.client:
            raise ValueError()
        return InventoryMarketingOpportunityRepository(wrapper.db).require_ready()
    except Exception:
        raise unavailable() from None
