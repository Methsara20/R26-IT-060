from fastapi import APIRouter, HTTPException

from app.services.decision_engine_service import analyze_candidate


router = APIRouter(
    prefix="/decision-engine",
    tags=["Decision Engine"]
)


@router.post("/analyze/{candidate_id}")
def analyze_optimization_candidate(candidate_id: str):
    result = analyze_candidate(candidate_id)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Optimization candidate not found"
        )

    return result