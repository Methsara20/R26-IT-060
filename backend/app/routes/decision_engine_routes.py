from fastapi import APIRouter, Depends, HTTPException
from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.security.inventory_permissions import inventory_analysis_user, require_global_access

from app.services.decision_engine_service import analyze_candidate
from app.services.optimization_candidate_service import get_candidate_by_id
from app.security.inventory_resource_access import require_optimization_candidate_access


router = APIRouter(
    prefix="/decision-engine",
    tags=["Decision Engine"]
)


@router.post("/analyze/{candidate_id}")
def analyze_optimization_candidate(candidate_id: str, user: InventoryPrincipal = Depends(inventory_analysis_user())):
    # This unchanged service scans all donor stores and writes before analysis.
    # Explicit global access is required until scoped service analysis is approved.
    require_global_access(user)
    candidate = get_candidate_by_id(candidate_id)
    if candidate is None:
        raise HTTPException(status_code=404, detail="Optimization candidate not found")
    require_optimization_candidate_access(user, candidate)
    result = analyze_candidate(candidate_id)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Optimization candidate not found"
        )

    return result
