"""Read-only repositories and canonical Inventory identities; no client creation."""
from collections.abc import Mapping
from typing import Any, Protocol

from bson import ObjectId


class InvalidInventoryUser(ValueError):
    """Malformed or ambiguous account; never include record contents in errors."""


def canonical_user_id(value: Any) -> str:
    """New Inventory users use native ObjectId _ids, exposed as oid:<lowercase hex>.

    String _ids are deliberately unsupported: they cannot shadow ObjectIds.
    Future provisioning must supply native ObjectIds, not their string forms.
    """
    if not isinstance(value, ObjectId):
        raise InvalidInventoryUser("Invalid Inventory identity.")
    return "oid:" + str(value)


def object_id_from_subject(subject: str) -> ObjectId:
    if (
        not isinstance(subject, str)
        or not subject.startswith("oid:")
        or len(subject) != 28
        or any(c not in "0123456789abcdef" for c in subject[4:])
    ):
        raise InvalidInventoryUser("Invalid Inventory identity.")
    return ObjectId(subject[4:])


class InventoryUserRepository(Protocol):
    def find_by_username(self, username: str) -> Mapping[str, Any] | None: ...
    def find_by_id(self, user_id: str) -> Mapping[str, Any] | None: ...


class MongoInventoryUserRepository:
    """Inject smart_retail_db['inventory_users']; performs bounded reads only."""

    def __init__(self, collection: Any):
        self._collection = collection

    def find_by_username(self, username: str) -> Mapping[str, Any] | None:
        records = list(
            self._collection.find({"username_normalized": username}).limit(2)
        )
        if len(records) > 1:
            raise InvalidInventoryUser("Ambiguous Inventory account.")
        return records[0] if records else None

    def find_by_id(self, user_id: str) -> Mapping[str, Any] | None:
        # Native ObjectId lookup never falls back to a string _id.
        return self._collection.find_one({"_id": object_id_from_subject(user_id)})


def get_inventory_user_repository() -> InventoryUserRepository:
    """Override explicitly at the future integration boundary."""
    from fastapi import HTTPException
    raise HTTPException(status_code=503, detail="Inventory authentication is unavailable.")
