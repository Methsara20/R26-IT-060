"""Planning router: durable storage and dedicated service authentication fail closed.

Frontend confirmation UI and provisioned storage/credentials are deployment prerequisites.
No poster linkage. Inventory user tokens cannot authenticate Marketing actions.
"""
from fastapi import APIRouter, Depends, Request, HTTPException, Query
from starlette.concurrency import run_in_threadpool
from app.security.inventory_permissions import get_current_inventory_user
from app.schemas.inventory_marketing_planning_schema import (
    ForecastShareRequest, CampaignAnalysisRequest, CampaignRejectionRequest,
)
from app.services.inventory_marketing_planning_service import (
    ExistingPlanningSources, share_forecast, submit_campaign as submit_campaign_request, read_assessment,
    read_forecast_share, list_campaign_reviews, read_campaign_review,
    list_campaign_assessments, accept_campaign, reject_campaign, error,
)
router = APIRouter(prefix="/inventory-marketing", tags=["Inventory Campaign Planning"])


from app.services.inventory_marketing_planning_dependencies import (
    campaign_planning_repository, forecast_sharing_repository,
)
from app.security.inventory_marketing_planning_auth import require_marketing_service as marketing_planning_user


def planning_sources():
    return ExistingPlanningSources()


async def parse(request, model):
    try:
        body = bytearray()
        async for chunk in request.stream():
            body.extend(chunk)
            if len(body) > 16384:
                raise ValueError()
        return model.model_validate_json(bytes(body))
    except Exception:
        raise error(422, "INVALID_COMMUNICATION_REQUEST") from None


async def invoke(function, *args):
    try:
        return await run_in_threadpool(function, *args)
    except HTTPException:
        raise
    except Exception:
        # Storage failure might follow a successful commit: never replay automatically.
        raise error(503, "OUTCOME_UNCONFIRMED") from None


@router.post("/forecast-shares")
async def publish_selected_forecast(request: Request, user=Depends(get_current_inventory_user),
                                    repository=Depends(forecast_sharing_repository), source=Depends(planning_sources)):
    data = await parse(request, ForecastShareRequest)
    return await invoke(share_forecast, data, user, source, repository)


@router.post("/campaign-analysis")
async def submit_campaign(request: Request, caller=Depends(marketing_planning_user),
                          repository=Depends(campaign_planning_repository), source=Depends(planning_sources)):
    data = await parse(request, CampaignAnalysisRequest)
    return await invoke(submit_campaign_request, data, caller, source, repository)


@router.get("/campaign-analysis")
async def campaign_assessments(skip: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100),
                               caller=Depends(marketing_planning_user),
                               repository=Depends(campaign_planning_repository)):
    return await invoke(list_campaign_assessments, caller, repository, skip, limit)


@router.get("/campaign-analysis/{request_id}")
async def campaign_assessment(request_id: str, caller=Depends(marketing_planning_user),
                              repository=Depends(campaign_planning_repository)):
    return await invoke(read_assessment, request_id, caller, repository)


@router.get("/campaign-reviews")
async def campaign_reviews(skip: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100),
                           user=Depends(get_current_inventory_user),
                           repository=Depends(campaign_planning_repository)):
    return await invoke(list_campaign_reviews, user, repository, skip, limit)


@router.get("/campaign-reviews/{request_id}")
async def campaign_review(request_id: str, user=Depends(get_current_inventory_user),
                          repository=Depends(campaign_planning_repository)):
    return await invoke(read_campaign_review, request_id, user, repository)


@router.post("/campaign-reviews/{request_id}/accept")
async def accept_campaign_review(request_id: str, user=Depends(get_current_inventory_user),
                                 repository=Depends(campaign_planning_repository),
                                 source=Depends(planning_sources)):
    return await invoke(accept_campaign, request_id, user, source, repository)


@router.post("/campaign-reviews/{request_id}/reject")
async def reject_campaign_review(request_id: str, request: Request,
                                 user=Depends(get_current_inventory_user),
                                 repository=Depends(campaign_planning_repository)):
    data = await parse(request, CampaignRejectionRequest)
    return await invoke(reject_campaign, request_id, data.reason, user, repository)


@router.get("/forecast-shares/{share_id}")
async def selected_forecast(share_id: str, caller=Depends(marketing_planning_user),
                            repository=Depends(forecast_sharing_repository)):
    return await invoke(read_forecast_share, share_id, caller, repository)
