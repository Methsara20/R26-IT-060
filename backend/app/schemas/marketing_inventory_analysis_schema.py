"""Browser-facing Marketing contracts for Inventory campaign analysis."""
from datetime import date
from pydantic import BaseModel, ConfigDict, Field, ValidationInfo, field_validator, model_validator


class MarketingModel(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)


class MarketingStaffLogin(MarketingModel):
    username: str = Field(strict=True, min_length=1, max_length=128)
    password: str = Field(strict=True, min_length=1, max_length=1024)


class MarketingSessionResponse(MarketingModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    username: str
    store_ids: list[str]
    global_access: bool


class MarketingCampaignAnalysisRequest(MarketingModel):
    campaign_reference: str = Field(strict=True, min_length=1, max_length=128)
    campaign_name: str = Field(strict=True, min_length=1, max_length=200)
    product_id: str = Field(strict=True, min_length=1, max_length=128)
    store_id: str = Field(strict=True, min_length=1, max_length=128)
    campaign_start_date: date
    campaign_end_date: date
    promotion_type: str | None = Field(default=None, min_length=1, max_length=100)
    discount_percent: float | None = Field(default=None, ge=0, le=100)

    @field_validator("campaign_reference", "campaign_name", "product_id", "store_id", "promotion_type")
    @classmethod
    def canonical(cls, value):
        if value is not None and (value != value.strip() or not value.isprintable()):
            raise ValueError("Invalid campaign value.")
        return value

    @field_validator("discount_percent")
    @classmethod
    def discount_requires_promotion(cls, value, info: ValidationInfo):
        if value is not None and info.data.get("promotion_type") is None:
            raise ValueError("Promotion type is required when a discount is provided.")
        return value

    @model_validator(mode="after")
    def valid_campaign(self):
        if self.campaign_end_date < self.campaign_start_date:
            raise ValueError("Campaign end precedes start.")
        return self
