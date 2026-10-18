"""Inventory-side campaign contract; no HTTP registration or persistence."""
from datetime import date
from typing import Annotated, Literal
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

Identifier = Annotated[str, Field(strict=True, min_length=1, max_length=128)]
Count = Annotated[int, Field(strict=True, ge=0)]

class FeedbackModel(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True, allow_inf_nan=False)

class CampaignPromotion(FeedbackModel):
    offer_type: str = Field(min_length=1, max_length=100)
    discount_percent: float | None = Field(default=None, ge=0, le=100)

class CampaignPerformance(FeedbackModel):
    period_start: date
    period_end: date
    source: str = Field(min_length=1, max_length=100)
    attribution_method: str = Field(min_length=1, max_length=200)
    impressions: Count | None = None
    clicks: Count | None = None
    redemptions: Count | None = None
    units_sold: Count | None = None
    revenue: float | None = Field(default=None, ge=0)
    currency: str | None = Field(default=None, pattern=r"^[A-Z]{3}$")

    @model_validator(mode="after")
    def valid_period(self):
        if self.period_end < self.period_start:
            raise ValueError("Invalid metric period.")
        if self.revenue is not None and self.currency is None:
            raise ValueError("Revenue requires currency.")
        return self

class InventoryCampaignFeedback(FeedbackModel):
    schema_version: Literal[1] = 1
    event_id: Identifier
    campaign_id: Identifier
    opportunity_id: Identifier
    product_id: Identifier
    store_id: Identifier
    revision: Annotated[int, Field(strict=True, ge=1)]
    campaign_status: Literal["DRAFT", "SCHEDULED", "ACTIVE", "PAUSED", "COMPLETED", "CANCELLED"]
    campaign_start_date: date
    campaign_end_date: date
    promotion: CampaignPromotion | None = None
    performance: CampaignPerformance | None = None

    @field_validator("event_id", "campaign_id", "opportunity_id", "product_id", "store_id")
    @classmethod
    def canonical_identifier(cls, value):
        # Canonical business IDs are matched exactly, never case-folded/coerced.
        if value != value.strip() or not value.isprintable():
            raise ValueError("Invalid canonical identifier.")
        return value

    @model_validator(mode="after")
    def valid_dates(self):
        if self.campaign_end_date < self.campaign_start_date:
            raise ValueError("Campaign end precedes start.")
        return self


class CampaignFeedbackAcknowledgment(FeedbackModel):
    event_id: Identifier
    opportunity_id: Identifier
    accepted_revision: Annotated[int, Field(strict=True, ge=1)]
    current_revision: Annotated[int, Field(strict=True, ge=1)]
    duplicate: bool
