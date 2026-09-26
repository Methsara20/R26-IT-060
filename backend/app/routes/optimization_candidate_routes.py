from fastapi import APIRouter, HTTPException

from app.services.optimization_candidate_service import (
    get_all_candidates,
    get_candidate_by_id,
    get_candidates_by_store,
    get_candidates_by_priority,
    get_candidates_by_type,
    get_candidate_summary
)


router = APIRouter(
    prefix="/optimization-candidates",
    tags=["Optimization Candidates"]
)


@router.get("/")
def all_candidates():
    candidates = get_all_candidates()

    return {
        "count": len(candidates),
        "candidates": candidates
    }


@router.get("/summary")
def candidate_summary():
    return get_candidate_summary()


@router.get("/{candidate_id}")
def candidate_by_id(candidate_id: str):
    candidate = get_candidate_by_id(candidate_id)

    if candidate is None:
        raise HTTPException(
            status_code=404,
            detail="Optimization candidate not found"
        )

    return candidate


@router.get("/store/{store_id}")
def candidates_by_store(store_id: str):
    candidates = get_candidates_by_store(store_id)

    return {
        "store_id": store_id,
        "count": len(candidates),
        "candidates": candidates
    }


@router.get("/priority/{priority}")
def candidates_by_priority(priority: str):
    candidates = get_candidates_by_priority(priority)

    return {
        "priority": priority.upper(),
        "count": len(candidates),
        "candidates": candidates
    }


@router.get("/type/{candidate_type}")
def candidates_by_type(candidate_type: str):
    candidates = get_candidates_by_type(candidate_type)

    return {
        "candidate_type": candidate_type.upper(),
        "count": len(candidates),
        "candidates": candidates
    }