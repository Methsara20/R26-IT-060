"""Own-account operations sharing the Inventory guard and audit transaction.

No caller-supplied account/actor identifier is accepted. No automatic retries.
The optional revision detects stale client edits; absent revisions are captured
before work begins and still checked inside the transaction. GET /me is unchanged.
"""
from datetime import datetime, timezone
from hmac import compare_digest
from fastapi import HTTPException
from app.schemas.inventory_profile_schema import InventoryProfileUpdated, InventoryPasswordChanged
from app.services.inventory_user_management_service import (
    InventoryUserManagementService, counter, safe_operation,
)
from app.services.inventory_user_management_repository import conflict
from app.services.inventory_user_service import object_id_from_subject


class _Snapshot:
    def __init__(self, record):
        self.record = record

    def find_by_id(self, user_id):
        # current_user validates both the signed subject and returned ObjectId.
        return self.record


class InventoryProfileService:
    def __init__(self, repository, auth):
        self.repository = repository
        self.auth = auth

    def current(self, token, session=None):
        return self.auth.current_user(self.repository.reader(session), token)

    def snapshot(self, token, user_id, password=False, session=None):
        record = (self.repository.find_own_credentials(user_id, session) if password
                  else self.repository.find_by_id(user_id, session))
        user = self.auth.current_user(_Snapshot(record), token)
        return user, record

    @safe_operation
    def update_display_name(self, token, data):
        user = self.current(token)
        _, before = self.snapshot(token, user.user_id)
        expected = counter(before, "revision")
        if data.revision is not None and data.revision != expected:
            raise conflict()
        with self.repository.transaction() as session:
            current = self.current(token, session)
            _, record = self.snapshot(token, current.user_id, session=session)
            if counter(record, "revision") != expected:
                raise conflict()
            self.repository.lock(session)
            self.repository.update(object_id_from_subject(current.user_id), expected,
                                   {"display_name": data.display_name,
                                    "updated_at": datetime.now(timezone.utc), "updated_by": current.user_id},
                                   False, session)
            self.repository.audit_change(current.user_id, current.user_id, "profile_update", {"display_name"}, session)
            updated = self.repository.find_by_id(current.user_id, session)
            result = InventoryProfileUpdated(user=self.auth.principal(updated), revision=counter(updated, "revision"))
        return result

    @safe_operation
    def change_password(self, token, data):
        user = self.current(token)  # Reject invalid/inactive accounts before hash reads.
        user, before = self.snapshot(token, user.user_id, password=True)
        expected = counter(before, "revision")
        version = counter(before, "auth_version")
        if data.revision is not None and data.revision != expected:
            raise conflict()
        reservation = self.auth.throttle.begin(user.username_normalized)
        encoded = before.get("password_hash")
        if not self.auth.verify_password(data.current_password, encoded):
            raise HTTPException(400, "Current password could not be verified.")
        if compare_digest(data.current_password.encode("utf-8"), data.new_password.encode("utf-8")):
            raise HTTPException(422, "Choose a different new password.")
        # Reuse the bounded hashing path, not its Admin-only mutation policy.
        replacement = InventoryUserManagementService(self.repository, self.auth).hash_password(data.new_password)
        with self.repository.transaction() as session:
            current = self.current(token, session)
            _, record = self.snapshot(token, current.user_id, password=True, session=session)
            if (counter(record, "revision") != expected or counter(record, "auth_version") != version
                    or record.get("password_hash") != encoded):
                raise conflict()
            # Both Admin mutations and self-service changes acquire this guard.
            # A competing transaction invalidates our snapshot/write and aborts;
            # we never rerun password verification against a different account.
            self.repository.lock(session)
            now = datetime.now(timezone.utc)
            self.repository.update(object_id_from_subject(current.user_id), expected,
                                   {"password_hash": replacement, "password_changed_at": now,
                                    "updated_at": now, "updated_by": current.user_id}, True, session)
            self.repository.audit_change(current.user_id, current.user_id, "password_change", {"password"}, session)
        self.auth.throttle.succeeded(reservation)
        return InventoryPasswordChanged()
