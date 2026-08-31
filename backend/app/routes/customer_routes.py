from fastapi import APIRouter, HTTPException
from app.services import customer_service

router = APIRouter(prefix="/customer-intelligence", tags=["Customer Intelligence"])

@router.get("/")
def customer_intelligence(at_risk_days: int = 60, top_n: int = 10):
    result = customer_service.get_customer_intelligence(at_risk_days=at_risk_days, top_n=top_n)
    if "error" in result:
        raise HTTPException(status_code=404, detail=result["error"])
    return result
