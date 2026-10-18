"""Inventory-only management contracts. Credential inputs never enter responses."""
from datetime import datetime
from typing import Annotated, Literal
from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator, model_validator
from app.schemas.inventory_auth_schema import InventoryRole, InventoryLoginRequest

Text = Annotated[str, StringConstraints(strict=True, min_length=1, max_length=128)]
StoreID = Annotated[str, StringConstraints(strict=True, min_length=1, max_length=128, pattern=r"^[A-Za-z0-9_-]+$")]
Revision = Annotated[int, Field(strict=True, ge=0, le=2**63-2)]
Password = Annotated[str, Field(strict=True, min_length=12, max_length=1024, repr=False)]


class Contract(BaseModel):
    model_config = ConfigDict(extra="forbid", hide_input_in_errors=True)


class AccountFields(Contract):
    display_name: Text
    role: InventoryRole
    store_ids: list[StoreID] = Field(default_factory=list, max_length=200)
    global_access: bool = Field(default=False, strict=True)
    is_active: bool = Field(default=True, strict=True)

    @field_validator("display_name")
    @classmethod
    def display(cls, value):
        value = value.strip()
        if not value or any(ord(c) < 32 for c in value):
            raise ValueError("Invalid display name.")
        return value

    @field_validator("store_ids")
    @classmethod
    def stores(cls, values):
        if len(set(values)) != len(values):
            raise ValueError("Duplicate store assignments.")
        return values

    @model_validator(mode="after")
    def scope(self):
        if self.global_access and self.store_ids:
            raise ValueError("Global accounts must use an empty store list.")
        if self.is_active and not self.global_access and not self.store_ids:
            raise ValueError("Active scoped accounts require stores.")
        return self


class CreateInventoryUser(AccountFields):
    username: Text
    password: Password

    @field_validator("username")
    @classmethod
    def normalize(cls, value):
        value = InventoryLoginRequest.normalize_username(value)
        if len(value) > 128 or any(ord(c) < 32 for c in value):
            raise ValueError("Invalid username.")
        return value


class UpdateInventoryUser(Contract):
    revision: Revision
    display_name: Text | None = None
    role: InventoryRole | None = None
    store_ids: list[StoreID] | None = Field(default=None, max_length=200)
    global_access: bool | None = Field(default=None, strict=True)

    @model_validator(mode="after")
    def fields_present(self):
        changes = self.model_fields_set - {"revision"}
        if not changes or any(getattr(self, name) is None for name in changes):
            raise ValueError("Provide non-null account changes.")
        return self


class SetInventoryUserStatus(Contract):
    revision: Revision
    is_active: bool = Field(strict=True)


class ResetInventoryUserPassword(Contract):
    revision: Revision
    password: Password


class InventoryUserView(Contract):
    user_id: str
    username_normalized: str
    display_name: str
    role: InventoryRole
    store_ids: list[str]
    global_access: bool
    is_active: bool
    revision: int
    created_at: datetime
    updated_at: datetime
    created_by: str | None = None
    updated_by: str | None = None
    password_changed_at: datetime | None = None


class InventoryUserPage(Contract):
    users: list[InventoryUserView]
    total: int
    limit: int
    offset: int


class InventoryUserQuery(Contract):
    search: str = Field(default="", max_length=128)
    role: InventoryRole | None = None
    is_active: bool | None = None
    store_id: StoreID | None = None
    limit: int = Field(default=20, ge=1, le=100)
    offset: int = Field(default=0, ge=0, le=10000)
    sort: Literal["username_normalized", "display_name", "created_at", "updated_at"] = "username_normalized"
    descending: bool = False
