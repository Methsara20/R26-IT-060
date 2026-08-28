from fastapi import APIRouter, HTTPException

from app.schemas.stock_movement_schema import (
    ApproveMovementRequest,
    RejectMovementRequest,
    CancelMovementRequest,
    ExecuteMovementRequest
)

from app.services.stock_movement_service import (
    recommend_transfer,
    get_all_stock_movements,
    get_stock_movement_by_id,
    approve_movement,
    reject_movement,
    cancel_movement,
    execute_movement
)

from app.services.explanation_service import (
    generate_stock_movement_explanation,
    generate_execution_summary,
    generate_intelligent_recommendation_explanation,
    generate_intelligent_execution_summary,
    build_stock_movement_explanation_context
)



router = APIRouter(
    prefix="/stock-movement",
    tags=["Stock Movement"]
)


@router.post("/recommend-transfer/{candidate_id}")
def create_transfer_recommendation(candidate_id: str):
    result = recommend_transfer(candidate_id)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Candidate not found"
        )

    if "error" in result:
        raise HTTPException(
            status_code=400,
            detail=result
        )

    return result


@router.get("/")
def all_stock_movements():
    movements = get_all_stock_movements()

    return {
        "count": len(movements),
        "movements": movements
    }


@router.get("/{movement_id}")
def stock_movement_by_id(movement_id: str):
    movement = get_stock_movement_by_id(movement_id)

    if movement is None:
        raise HTTPException(
            status_code=404,
            detail="Stock movement not found"
        )

    return movement


@router.post("/approve/{movement_id}")
def approve_stock_movement(
    movement_id: str,
    data: ApproveMovementRequest
):
    result = approve_movement(movement_id)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Stock movement not found"
        )

    if "error" in result:
        raise HTTPException(
            status_code=400,
            detail=result
        )

    return result


@router.post("/reject/{movement_id}")
def reject_stock_movement(
    movement_id: str,
    data: RejectMovementRequest
):
    result = reject_movement(
        movement_id=movement_id,
        rejection_reason=data.rejection_reason
    )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Stock movement not found"
        )

    if "error" in result:
        raise HTTPException(
            status_code=400,
            detail=result
        )

    return result


@router.post("/cancel/{movement_id}")
def cancel_stock_movement(
    movement_id: str,
    data: CancelMovementRequest
):
    result = cancel_movement(
        movement_id=movement_id,
        cancel_reason=data.cancel_reason
    )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Stock movement not found"
        )

    if "error" in result:
        raise HTTPException(
            status_code=400,
            detail=result
        )

    return result


@router.post("/execute/{movement_id}")
def execute_stock_movement(
    movement_id: str,
    data: ExecuteMovementRequest
):
    result = execute_movement(movement_id)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Stock movement not found"
        )

    if "error" in result:
        raise HTTPException(
            status_code=400,
            detail=result
        )

    return result


@router.post("/explain/{movement_id}")
def explain_stock_movement(movement_id: str):
    movement = get_stock_movement_by_id(movement_id)

    if movement is None:
        raise HTTPException(
            status_code=404,
            detail="Stock movement not found"
        )

    explanation = generate_stock_movement_explanation(
        movement
    )

    return {
        "movement_id": movement_id,
        "movement_status": movement.get("movement_status"),
        "explanation": explanation
    }


@router.post("/execution-summary/{movement_id}")
def stock_movement_execution_summary(movement_id: str):
    movement = get_stock_movement_by_id(movement_id)

    if movement is None:
        raise HTTPException(
            status_code=404,
            detail="Stock movement not found"
        )

    summary = generate_execution_summary(
        movement
    )

    return {
        "movement_id": movement_id,
        "movement_status": movement.get("movement_status"),
        "summary": summary
    }


@router.post("/explain/{movement_id}")
def explain_stock_movement(movement_id: str):
    movement = get_stock_movement_by_id(movement_id)

    if movement is None:
        raise HTTPException(
            status_code=404,
            detail="Stock movement not found"
        )

    explanation = generate_intelligent_recommendation_explanation(
        movement
    )

    return {
        "movement_id": movement_id,
        "movement_status": movement.get("movement_status"),
        "explanation": explanation
    }


@router.get("/explain-context/{movement_id}")
def stock_movement_explain_context(movement_id: str):
    movement = get_stock_movement_by_id(movement_id)

    if movement is None:
        raise HTTPException(
            status_code=404,
            detail="Stock movement not found"
        )

    context = build_stock_movement_explanation_context(
        movement
    )

    return {
        "movement_id": movement_id,
        "movement_status": movement.get("movement_status"),
        "explanation_context": context
    }


@router.post("/execution-summary/{movement_id}")
def stock_movement_execution_summary(movement_id: str):
    movement = get_stock_movement_by_id(movement_id)

    if movement is None:
        raise HTTPException(
            status_code=404,
            detail="Stock movement not found"
        )

    summary = generate_intelligent_execution_summary(
        movement
    )

    return {
        "movement_id": movement_id,
        "movement_status": movement.get("movement_status"),
        "summary": summary
    }