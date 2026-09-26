from fastapi import APIRouter, HTTPException

from app.schemas.marketing_opportunity_schema import (
    MarketingOpportunityRequest,
    MarketingOpportunityResponse,
)
from app.services.marketing_opportunity_service import (
    MarketingOpportunityValidationError,
    create_marketing_opportunity,
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
):
    try:
        return create_marketing_opportunity(data)

    except MarketingOpportunityValidationError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc

    except Exception as exc:
        print(
            "Marketing opportunity creation failed: "
            f"{exc}"
        )

        raise HTTPException(
            status_code=500,
            detail=(
                "Marketing opportunity could not be sent."
            ),
        ) from exc