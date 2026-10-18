from fastapi import APIRouter, Depends, HTTPException, Query

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


from app.security.inventory_permissions import get_bearer_credentials
from app.security.inventory_resource_access import VerifiedWorkflowUser
from app.services.inventory_auth_service import get_inventory_auth_service
from app.services.inventory_user_service import get_inventory_user_repository


def workflow_user(
    credentials=Depends(get_bearer_credentials),
    auth_service=Depends(get_inventory_auth_service),
    repository=Depends(get_inventory_user_repository),
):
    return VerifiedWorkflowUser(credentials.credentials, auth_service, repository)


router = APIRouter(
    prefix="/decision-workflow",
    tags=["Connected Decision Workflow"],
)


@router.post("/analyze", response_model=DecisionWorkflowResponse)
def analyze_workflow(data: DecisionWorkflowRequest, user=Depends(workflow_user)):
    try:
        return analyze_decision_workflow(data, user=user)
    except DecisionWorkflowNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Decision workflow not found.") from exc
    except DecisionWorkflowValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except DecisionWorkflowQuotaError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except DecisionWorkflowExecutionError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/", response_model=list[DecisionWorkflowListItem])
def workflow_history(limit: int = Query(default=20, ge=1, le=100), user=Depends(workflow_user)):
    try:
        return list_decision_workflows(limit=limit, user=user)
    except DecisionWorkflowQuotaError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.get("/{workflow_id}", response_model=DecisionWorkflowResponse)
def workflow_by_id(workflow_id: str, user=Depends(workflow_user)):
    try:
        return get_decision_workflow(workflow_id, user=user)
    except DecisionWorkflowNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except DecisionWorkflowQuotaError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
