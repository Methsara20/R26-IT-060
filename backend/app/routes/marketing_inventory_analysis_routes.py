"""Authenticated Marketing facade for Inventory campaign planning."""
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import ValidationError
from starlette.concurrency import run_in_threadpool
from app.schemas.marketing_inventory_analysis_schema import (
    MarketingCampaignAnalysisRequest, MarketingSessionResponse, MarketingStaffLogin,
)
from app.security.marketing_staff_auth import (
    SESSION_SECONDS, get_marketing_staff_auth, require_marketing_staff,
)
from app.services.marketing_inventory_analysis_client import (
    MarketingInventoryAnalysisClient, MarketingInventoryClientSettings, client_error,
)

router = APIRouter(prefix="/marketing-inventory", tags=["Marketing Inventory Analysis"])


def inventory_analysis_client():
    return MarketingInventoryAnalysisClient(MarketingInventoryClientSettings.from_environment())


async def parse(request, model):
    try:
        body = bytearray()
        async for chunk in request.stream():
            body.extend(chunk)
            if len(body) > 16384:
                raise ValueError()
        return model.model_validate_json(bytes(body))
    except ValidationError as error:
        allowed = {
            "username", "password", "campaign_reference", "campaign_name",
            "product_id", "store_id", "campaign_start_date",
            "campaign_end_date", "promotion_type", "discount_percent",
        }
        errors = []
        for item in error.errors(include_input=False, include_url=False, include_context=False):
            location = item.get("loc", ())
            field = location[-1] if location and location[-1] in allowed else "request"
            if (field == "discount_percent"
                    and item.get("type") == "value_error"):
                reason = "PROMOTION_TYPE_REQUIRED"
            elif item.get("type") == "missing":
                reason = "REQUIRED"
            else:
                reason = "INVALID"
            errors.append({"field": field, "reason": reason})
        raise HTTPException(status_code=422, detail={
            "code": "INVALID_MARKETING_REQUEST", "errors": errors,
        }) from None
    except Exception:
        raise client_error(422, "INVALID_MARKETING_REQUEST") from None


async def invoke(function, *args):
    try:
        return await run_in_threadpool(function, *args)
    except HTTPException:
        raise
    except Exception:
        raise client_error(503, "INVENTORY_PLANNING_CLIENT_UNAVAILABLE") from None


@router.post("/login", response_model=MarketingSessionResponse)
async def login(request: Request, auth=Depends(get_marketing_staff_auth)):
    data = await parse(request, MarketingStaffLogin)
    token = await run_in_threadpool(auth.login, data.username, data.password)
    settings = auth.settings
    return MarketingSessionResponse(access_token=token, expires_in=SESSION_SECONDS,
        username=settings.username, store_ids=list(settings.store_ids),
        global_access=settings.global_access)


@router.post("/campaign-analysis")
async def submit_campaign(request: Request, principal=Depends(require_marketing_staff),
                          client=Depends(inventory_analysis_client)):
    data = await parse(request, MarketingCampaignAnalysisRequest)
    return await invoke(client.submit, principal, data)


@router.get("/campaign-analysis")
async def campaign_history(skip: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100),
                           principal=Depends(require_marketing_staff),
                           client=Depends(inventory_analysis_client)):
    return await invoke(client.list, principal, skip, limit)


@router.get("/campaign-analysis/{request_id}")
async def campaign_status(request_id: str, principal=Depends(require_marketing_staff),
                          client=Depends(inventory_analysis_client)):
    return await invoke(client.status, principal, request_id)
