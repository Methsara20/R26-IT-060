from fastapi import APIRouter, Depends, HTTPException
from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.security.inventory_permissions import inventory_candidate_reader, require_store_access

from app.services.optimization_candidate_service import (
    get_all_candidates,
    get_candidate_by_id,
    get_candidates_by_store,
    get_candidates_by_priority,
    get_candidates_by_type,
    get_candidate_summary
)

from app.security.inventory_resource_access import (
    require_optimization_candidate_access, visible_optimization_candidates, scoped_candidate_summary,
)

router = APIRouter(
    prefix="/optimization-candidates",
    tags=["Optimization Candidates"]
)


@router.get("/")
def all_candidates(user: InventoryPrincipal = Depends(inventory_candidate_reader())):
    candidates = visible_optimization_candidates(user, get_all_candidates())

    return {
        "count": len(candidates),
        "candidates": candidates
    }


@router.get("/summary")
def candidate_summary(user: InventoryPrincipal = Depends(inventory_candidate_reader())):
    return scoped_candidate_summary(visible_optimization_candidates(user, get_all_candidates()))


@router.get("/{candidate_id}")
def candidate_by_id(candidate_id: str, user: InventoryPrincipal = Depends(inventory_candidate_reader())):
    candidate = get_candidate_by_id(candidate_id)

    if candidate is None:
        raise HTTPException(
            status_code=404,
            detail="Optimization candidate not found"
        )

    require_optimization_candidate_access(user, candidate)
    return candidate


@router.get("/store/{store_id}")
def candidates_by_store(store_id: str, user: InventoryPrincipal = Depends(inventory_candidate_reader())):
    require_store_access(user, store_id)
    candidates = visible_optimization_candidates(user, get_candidates_by_store(store_id))

    return {
        "store_id": store_id,
        "count": len(candidates),
        "candidates": candidates
    }


@router.get("/priority/{priority}")
def candidates_by_priority(priority: str, user: InventoryPrincipal = Depends(inventory_candidate_reader())):
    candidates = visible_optimization_candidates(user, get_candidates_by_priority(priority))

    return {
        "priority": priority.upper(),
        "count": len(candidates),
        "candidates": candidates
    }


@router.get("/type/{candidate_type}")
def candidates_by_type(candidate_type: str, user: InventoryPrincipal = Depends(inventory_candidate_reader())):
    candidates = visible_optimization_candidates(user, get_candidates_by_type(candidate_type))

    return {
        "candidate_type": candidate_type.upper(),
        "count": len(candidates),
        "candidates": candidates
    }
