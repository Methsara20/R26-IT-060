"""Self-service Inventory inputs; identity and privileges never come from callers."""
from typing import Literal
from pydantic import Field, field_validator, model_validator
from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.schemas.inventory_user_management_schema import Contract, Text, Revision, Password, AccountFields


class UpdateInventoryProfile(Contract):
    display_name: Text
    revision: Revision | None = None

    @field_validator("display_name")
    @classmethod
    def validate_name(cls, value):
        return AccountFields.display(value)


class ChangeInventoryPassword(Contract):
    # Existing accounts can have older passwords; apply the creation policy to
    # the NEW password, without locking legacy users out of changing theirs.
    current_password: str = Field(strict=True, min_length=1, max_length=1024, repr=False)
    new_password: Password
    new_password_confirmation: Password
    revision: Revision | None = None

    @model_validator(mode="after")
    def confirmed(self):
        if self.new_password != self.new_password_confirmation:
            raise ValueError("New password confirmation must match.")
        return self


class InventoryProfileUpdated(Contract):
    user: InventoryPrincipal
    revision: int


class InventoryPasswordChanged(Contract):
    message: Literal["Password changed. Sign in again."] = "Password changed. Sign in again."
    reauthentication_required: Literal[True] = True
