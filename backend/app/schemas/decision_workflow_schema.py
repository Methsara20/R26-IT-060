from datetime import date
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


class DecisionWorkflowForecastType(str, Enum):
    DAILY = "DAILY"
    SEVEN_DAY = "SEVEN_DAY"
    CUSTOM = "CUSTOM"


class DecisionWorkflowRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    forecast_type: DecisionWorkflowForecastType
    store_id: str = Field(min_length=1, max_length=100)
    product_id: str = Field(min_length=1, max_length=100)
    selling_price: float = Field(gt=0)
    promotion_percent: float = Field(default=0, ge=0, le=100)
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    idempotency_key: str = Field(min_length=8, max_length=200)

    @field_validator("store_id", "product_id", "idempotency_key")
    @classmethod
    def strip_required_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Value must not be blank.")
        return value


class DecisionWorkflowListItem(BaseModel):
    model_config = ConfigDict(extra="allow")

    workflow_id: str
    workflow_status: str
    next_action: str
    forecast_type: DecisionWorkflowForecastType
    store_id: str
    product_id: str
    candidate_id: Optional[str] = None
    movement_id: Optional[str] = None
    created_at: str
    updated_at: str


class DecisionWorkflowResponse(DecisionWorkflowListItem):
    forecast_result: Optional[dict[str, Any]] = None
    inventory_snapshot: Optional[dict[str, Any]] = None
    inventory_intelligence: Optional[dict[str, Any]] = None
    decision_result: Optional[dict[str, Any]] = None
    candidate: Optional[dict[str, Any]] = None
    movement: Optional[dict[str, Any]] = None
    failure_stage: Optional[str] = None
    error_message: Optional[str] = None
