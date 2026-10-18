from fastapi import APIRouter, Depends, HTTPException

from app.schemas.marketing_opportunity_schema import (
    MarketingOpportunityRequest,
    MarketingOpportunityResponse,
)
from app.services.marketing_opportunity_service import (
    create_marketing_opportunity,
)
from app.security.inventory_permissions import get_current_inventory_user
from app.services.inventory_marketing_opportunity_dependencies import (
    get_inventory_marketing_opportunity_repository,
)


router = APIRouter(
    prefix="/marketing-opportunities",
    tags=["Marketing Integration"],
)


@router.post(
    "/",
    response_model=MarketingOpportunityResponse,
)
def send_marketing_opportunity(
    data: MarketingOpportunityRequest,
    user=Depends(get_current_inventory_user),
    repository=Depends(get_inventory_marketing_opportunity_repository),
):
    try:
        return create_marketing_opportunity(data, user, repository)

    except HTTPException:
        raise

    except Exception:
        raise HTTPException(
            status_code=503,
            detail="Marketing opportunity publication is unavailable.",
        ) from None

# Dedicated callback: manual bounded validation keeps sensitive input out of
# validation responses without changing the existing publication route.
from fastapi import Request
from starlette.concurrency import run_in_threadpool
from app.schemas.inventory_campaign_feedback_schema import InventoryCampaignFeedback, CampaignFeedbackAcknowledgment
from app.security.inventory_marketing_service_auth import require_marketing_service, feedback_error
from app.services.inventory_campaign_feedback_dependencies import get_campaign_feedback_repository
from app.services.inventory_campaign_feedback_service import accept_campaign_feedback


@router.post("/campaign-feedback", response_model=CampaignFeedbackAcknowledgment)
async def campaign_feedback(request: Request,
                            identity=Depends(require_marketing_service),
                            repository=Depends(get_campaign_feedback_repository)):
    try:
        body = bytearray()
        async for chunk in request.stream():
            body.extend(chunk)
            if len(body) > 65536:
                raise ValueError()
        event = InventoryCampaignFeedback.model_validate_json(bytes(body))
    except Exception:
        raise feedback_error(422, "INVALID_FEEDBACK") from None
    return await run_in_threadpool(accept_campaign_feedback, repository, identity, event)
