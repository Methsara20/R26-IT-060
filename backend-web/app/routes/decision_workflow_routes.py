from fastapi import APIRouter, HTTPException, Query

from app.schemas.decision_workflow_schema import (
    DecisionWorkflowListItem,
    DecisionWorkflowRequest,
    DecisionWorkflowResponse,
)
from app.services.decision_workflow_service import (
    DecisionWorkflowExecutionError,
    DecisionWorkflowNotFoundError,
    DecisionWorkflowQuotaError,
    DecisionWorkflowValidationError,
    analyze_decision_workflow,
    get_decision_workflow,
    list_decision_workflows,
)


router = APIRouter(
    prefix="/decision-workflow",
    tags=["Connected Decision Workflow"],
)


@router.post("/analyze", response_model=DecisionWorkflowResponse)
def analyze_workflow(data: DecisionWorkflowRequest):
    try:
        return analyze_decision_workflow(data)
    except DecisionWorkflowValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except DecisionWorkflowQuotaError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except DecisionWorkflowExecutionError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/", response_model=list[DecisionWorkflowListItem])
def workflow_history(limit: int = Query(default=20, ge=1, le=100)):
    try:
        return list_decision_workflows(limit=limit)
    except DecisionWorkflowQuotaError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.get("/{workflow_id}", response_model=DecisionWorkflowResponse)
def workflow_by_id(workflow_id: str):
    try:
        return get_decision_workflow(workflow_id)
    except DecisionWorkflowNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except DecisionWorkflowQuotaError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
