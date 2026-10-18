"""Lazy reuse of the already initialized native MongoDB handle."""
from app.services.inventory_auth_dependencies import get_existing_inventory_mongo_wrapper
from app.services.inventory_marketing_planning_repository import InventoryMarketingPlanningRepository
from app.services.inventory_marketing_planning_service import error


def _planning_repository(namespaces):
    try:
        wrapper = get_existing_inventory_mongo_wrapper()
        if wrapper.db.client is not wrapper.client:
            raise ValueError()
        return InventoryMarketingPlanningRepository(wrapper.db).ready(namespaces)
    except Exception:
        raise error(503, "COMMUNICATION_STORAGE_UNAVAILABLE") from None


def campaign_planning_repository():
    return _planning_repository(("campaign-analysis",))


def forecast_sharing_repository():
    return _planning_repository(("forecast-share",))


def planning_repository():
    """Compatibility provider for callers that require both storage areas."""
    return _planning_repository(("forecast-share", "campaign-analysis"))
