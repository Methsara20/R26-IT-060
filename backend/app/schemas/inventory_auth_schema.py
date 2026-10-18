"""Inventory-only authentication contracts; never serialize password hashes."""
from typing import Literal
from app.services.inventory_user_service import object_id_from_subject
from pydantic import BaseModel, ConfigDict, Field, field_validator

InventoryRole = Literal["admin", "manager", "analyst", "operator", "viewer"]


class InventoryLoginRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    username: str = Field(min_length=1, max_length=128)
    password: str = Field(min_length=1, max_length=1024, repr=False, strict=True)

    @field_validator("username")
    @classmethod
    def normalize_username(cls, value: str) -> str:
        value = value.strip().casefold()
        if not value:
            raise ValueError("Username is required.")
        return value


class InventoryPrincipal(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, frozen=True)
    user_id: str = Field(min_length=1)
    username_normalized: str = Field(min_length=1)
    display_name: str
    role: InventoryRole
    store_ids: tuple[str, ...]
    global_access: bool

    @field_validator("user_id")
    @classmethod
    def validate_identity(cls, value: str) -> str:
        object_id_from_subject(value)
        return value

    @field_validator("store_ids")
    @classmethod
    def validate_stores(cls, values: tuple[str, ...]) -> tuple[str, ...]:
        if any(not value or value != value.strip() for value in values):
            raise ValueError("Invalid store scope.")
        return values


class InventoryLoginResponse(BaseModel):
    access_token: str = Field(repr=False)
    token_type: Literal["bearer"] = "bearer"
    expires_in: int = 900
    user: InventoryPrincipal
