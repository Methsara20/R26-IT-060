"""Communication-only contracts; no poster or forecasting algorithm changes."""
from datetime import date
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

class PlanningModel(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)

class ForecastShareRequest(PlanningModel):
    workflow_id: str = Field(strict=True, min_length=1, max_length=128)
    confirmed: bool = Field(strict=True)

    @field_validator("workflow_id")
    @classmethod
    def canonical(cls, value):
        if value != value.strip() or not value.isprintable():
            raise ValueError("Invalid identifier.")
        return value

    @field_validator("confirmed")
    @classmethod
    def explicit_confirmation(cls, value):
        if value is not True:
            raise ValueError("Explicit sharing confirmation required.")
        return value

class CampaignAnalysisRequest(PlanningModel):
    request_id: str = Field(strict=True, min_length=1, max_length=128)
    campaign_reference: str = Field(strict=True, min_length=1, max_length=128)
    campaign_name: str = Field(strict=True, min_length=1, max_length=200)
    product_id: str = Field(strict=True, min_length=1, max_length=128)
    store_id: str = Field(strict=True, min_length=1, max_length=128)
    campaign_start_date: date
    campaign_end_date: date
    promotion_type: str | None = Field(default=None, min_length=1, max_length=100)
    discount_percent: float | None = Field(default=None, ge=0, le=100)
    request_status: Literal["SUBMITTED"] = "SUBMITTED"

    @field_validator("request_id", "campaign_reference", "campaign_name", "product_id", "store_id")
    @classmethod
    def canonical(cls, value):
        if value != value.strip() or not value.isprintable():
            raise ValueError("Invalid identifier or name.")
        return value

    @model_validator(mode="after")
    def valid_dates(self):
        if self.campaign_end_date < self.campaign_start_date:
            raise ValueError("Campaign end precedes start.")
        if self.discount_percent is not None and self.promotion_type is None:
            raise ValueError("Discount requires promotion type.")
        return self


class CampaignRejectionRequest(PlanningModel):
    reason: str = Field(strict=True, min_length=3, max_length=500)

    @field_validator("reason")
    @classmethod
    def meaningful_reason(cls, value):
        if value != value.strip() or not value.isprintable():
            raise ValueError("Invalid rejection reason.")
        return value
