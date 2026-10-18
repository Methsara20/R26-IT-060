from fastapi import APIRouter, HTTPException
from app.schemas.customer import CustomerProfile
from app.services import model_service

router = APIRouter(tags=["Recommendations"])

@router.get("/model/info")
def model_info():
    try:
        return model_service.get_model_info()
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.post("/recommend")
def recommend(profile: CustomerProfile):
    try:
        profile_dict = profile.model_dump()
        discount_pct = profile_dict.pop("discount_pct", 20.0)
        ranked = model_service.rank_offers(profile_dict, discount_pct=discount_pct)
        return {
            "top_recommendation": ranked[0],
            "all_offers_ranked": ranked,
        }
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
