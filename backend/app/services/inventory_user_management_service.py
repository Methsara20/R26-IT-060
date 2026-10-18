"""Inventory management policy; all writes use the injected transactional adapter."""
from datetime import datetime, timezone
from functools import wraps
from threading import BoundedSemaphore
from bson import ObjectId
from fastapi import HTTPException
from pymongo.errors import DuplicateKeyError
from app.schemas.inventory_user_management_schema import AccountFields, InventoryUserView, InventoryUserPage
from app.security.inventory_permissions import inventory_user_management_admin
from app.services.inventory_user_service import canonical_user_id, object_id_from_subject
from app.services.inventory_user_management_repository import unavailable, conflict

_HASH_SLOTS = BoundedSemaphore(2)
_FIELDS = ("display_name", "role", "store_ids", "global_access", "is_active")
_SECURITY_FIELDS = {"role", "store_ids", "global_access", "is_active"}


def safe_operation(method):
    @wraps(method)
    def call(*args, **kwargs):
        try:
            return method(*args, **kwargs)
        except HTTPException:
            raise
        except DuplicateKeyError:
            raise HTTPException(409, "An Inventory account with that username already exists.") from None
        except Exception:
            raise unavailable() from None
    return call


def counter(record, name):
    value = record.get(name, 0)
    if isinstance(value, bool) or not isinstance(value, int) or not 0 <= value < 2**63-1:
        raise unavailable()
    return int(value)


class InventoryUserManagementService:
    def __init__(self, repository, auth, store_validator=None):
        self.repository = repository
        self.auth = auth
        self.validate_stores = store_validator or repository.validate_stores

    def actor(self, token, session=None):
        return inventory_user_management_admin(self.auth.current_user(self.repository.reader(session), token))

    @staticmethod
    def view(record):
        if record is None:
            raise HTTPException(404, "Inventory account not found.")
        return InventoryUserView(
            user_id=canonical_user_id(record["_id"]),
            username_normalized=record["username_normalized"],
            **{key: record[key] for key in _FIELDS},
            revision=counter(record, "revision"),
            created_at=record["created_at"], updated_at=record["updated_at"],
            **{key: record.get(key) for key in ("created_by", "updated_by", "password_changed_at")},
        )

    @safe_operation
    def list(self, token, query):
        self.actor(token)
        self.repository.require_ready()
        records, total = self.repository.list_users(query)
        return InventoryUserPage(users=[self.view(row) for row in records], total=total,
                                 limit=query.limit, offset=query.offset)

    @safe_operation
    def get(self, token, user_id):
        self.actor(token)
        self.repository.require_ready()
        self.identity(user_id)
        return self.view(self.repository.find_by_id(user_id))

    @staticmethod
    def identity(user_id):
        try:
            return object_id_from_subject(user_id)
        except ValueError:
            raise HTTPException(422, "Invalid Inventory account identifier.") from None

    def hash_password(self, password):
        if not _HASH_SLOTS.acquire(blocking=False):
            raise HTTPException(429, "Too many password operations. Try again later.")
        try:
            return self.auth.hash_password(password)
        finally:
            _HASH_SLOTS.release()

    @safe_operation
    def mutate(self, token, action, data, user_id=None):
        if action not in {"create", "update", "status", "reset_password"}:
            raise HTTPException(422, "Invalid account operation.")
        self.actor(token)  # Deny before password hashing or transaction effects.
        target_id = ObjectId() if action == "create" else self.identity(user_id)
        encoded = self.hash_password(data.password) if action in {"create", "reset_password"} else None
        with self.repository.transaction() as session:
            actor = self.actor(token, session)  # Denial causes no write attempt.
            self.repository.lock(session)
            actor = self.actor(token, session)
            now = datetime.now(timezone.utc)
            if action == "create":
                document = {
                    "_id": target_id, "username_normalized": data.username,
                    **{key: getattr(data, key) for key in _FIELDS},
                    "password_hash": encoded, "auth_version": 0, "revision": 0,
                    "created_at": now, "updated_at": now,
                    "created_by": actor.user_id, "updated_by": actor.user_id,
                    "password_changed_at": now,
                }
                self.validate_stores(document["store_ids"], session)
                self.repository.insert(document, session)
                changed = {*_FIELDS, "username_normalized", "password"}
            else:
                record = self.repository.find_by_id(user_id, session)
                self.view(record)  # Fail closed on missing/malformed target data.
                if counter(record, "revision") != data.revision:
                    raise conflict()
                counter(record, "auth_version")
                if action == "update":
                    changes = data.model_dump(exclude_unset=True, exclude={"revision"})
                elif action == "status":
                    changes = {"is_active": data.is_active}
                else:
                    changes = {"password_hash": encoded, "password_changed_at": now}
                merged = {**record, **changes}
                if user_id == actor.user_id and (
                    merged["is_active"] is not True or merged["role"] != "admin"
                    or merged["global_access"] is not True
                ):
                    raise HTTPException(409, "You cannot remove your own active global Admin access.")
                # Apply the same scope/display validation to merged PATCH state.
                try:
                    validated = AccountFields(**{key: merged[key] for key in _FIELDS})
                except ValueError:
                    raise HTTPException(422, "Invalid account fields or store scope.") from None
                if action in {"update", "status"}:
                    self.validate_stores(validated.store_ids, session)
                    for key in set(changes) & set(_FIELDS):
                        changes[key] = getattr(validated, key)
                revoke = action == "reset_password" or any(
                    key in changes and record[key] != changes[key] for key in _SECURITY_FIELDS
                )
                changed = {"password"} if action == "reset_password" else set(changes)
                changes.update(updated_at=now, updated_by=actor.user_id)
                self.repository.update(target_id, data.revision, changes, revoke, session)
            self.repository.assert_admin_remains(session)
            self.repository.audit_change(actor.user_id, canonical_user_id(target_id), action, changed, session)
            result = self.view(self.repository.find_by_id(canonical_user_id(target_id), session))
        return result  # Never return success before commit acknowledgement.
