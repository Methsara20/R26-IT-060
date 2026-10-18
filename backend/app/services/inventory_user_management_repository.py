"""Native MongoDB adapter; never initializes clients, collections or indexes.

All mutations require pre-provisioned namespaces and the singleton guard:
  inventory_user_management_state: {_id: "user_management", revision: 0}
Use a replica set/sharded deployment with transactions and majority writes.
Out-of-band writers must honor this guard/version contract; collection DDL is
not supported while management is running. No body or reset retry is performed.
"""
from contextlib import contextmanager
from datetime import datetime, timezone
import re
from bson import ObjectId
from fastapi import HTTPException
from pymongo import ReadPreference
from pymongo.errors import DuplicateKeyError, PyMongoError
from pymongo.read_concern import ReadConcern
from pymongo.write_concern import WriteConcern
from app.services.inventory_user_service import object_id_from_subject

DATABASE = "smart_retail_db"
USERS = "inventory_users"
STATE = "inventory_user_management_state"
AUDIT = "inventory_user_audit"
STORES = "stores"
GUARD_ID = "user_management"
PROJECTION = {name: 1 for name in (
    "_id", "username_normalized", "display_name", "role", "store_ids",
    "global_access", "is_active", "created_at", "updated_at", "created_by",
    "updated_by", "password_changed_at", "revision", "auth_version",
)}


def unavailable():
    return HTTPException(503, "Inventory user management is unavailable.")


def conflict():
    return HTTPException(409, "Account conflict. Reload before making another change.")


class MongoInventoryManagementRepository:
    def __init__(self, database):
        if database.name != DATABASE:
            raise unavailable()
        self.db = database
        for name in (USERS, STATE, AUDIT, STORES):
            collection = database.get_collection(name)
            if collection.name != name or collection.database is not database:
                raise unavailable()
        self.users = database.get_collection(USERS)
        self.state = database.get_collection(STATE)
        self.audit = database.get_collection(AUDIT)
        self.stores = database.get_collection(STORES)

    def require_ready(self):
        # Exact-name metadata filters are supported by the deployed Atlas server.
        for name in (USERS, STATE, AUDIT, STORES):
            if self.db.list_collection_names(filter={"name": name}) != [name]:
                raise unavailable()
        indexes = self.users.index_information()
        if not any(
            list(spec.get("key", [])) == [("username_normalized", 1)]
            and spec.get("unique") is True and not spec.get("sparse", False)
            and "partialFilterExpression" not in spec
            and spec.get("collation", {}).get("locale", "simple") == "simple"
            for spec in indexes.values()
        ):
            raise unavailable()

    def find_by_id(self, user_id, session=None):
        return self.users.find_one({"_id": object_id_from_subject(user_id)}, PROJECTION, session=session)

    def find_own_credentials(self, user_id, session=None):
        """Private password-change read, called only with the verified JWT subject.

        Never use for listings or public serialization. Exactly one native _id
        is queried; unrelated user credentials are never requested.
        """
        return self.users.find_one({"_id": object_id_from_subject(user_id)},
                                   {**PROJECTION, "password_hash": 1}, session=session)

    def reader(self, session):
        repository = self
        class Reader:
            def find_by_id(self, user_id):
                return repository.find_by_id(user_id, session)
        return Reader()

    def list_users(self, query):
        filters = {}
        if query.search:
            literal = re.escape(query.search.strip())
            filters["$or"] = [{"username_normalized": {"$regex": re.escape(query.search.strip().casefold())}},
                              {"display_name": {"$regex": literal, "$options": "i"}}]
        for key in ("role", "is_active"):
            value = getattr(query, key)
            if value is not None:
                filters[key] = value
        if query.store_id is not None:
            filters["store_ids"] = query.store_id
        total = self.users.count_documents(filters)
        rows = list(self.users.find(filters, PROJECTION).sort(
            [(query.sort, -1 if query.descending else 1), ("_id", 1)]
        ).skip(query.offset).limit(query.limit))
        return rows, total

    def validate_stores(self, store_ids, session):
        # Canonical business store_id only; no fallback to arbitrary Mongo _id.
        for store_id in store_ids:
            rows = list(self.stores.find({"store_id": store_id}, {"_id": 0, "store_id": 1}, session=session).limit(2))
            if len(rows) != 1:
                raise HTTPException(422, "One or more assigned stores are unavailable.")

    @contextmanager
    def transaction(self):
        self.require_ready()
        # Explicit start/commit: do not use with_transaction (replays callbacks).
        with self.db.client.start_session() as session:
            session.start_transaction(read_concern=ReadConcern("snapshot"),
                                      write_concern=WriteConcern("majority"),
                                      read_preference=ReadPreference.PRIMARY)
            try:
                yield session
            except BaseException:
                if session.in_transaction:
                    session.abort_transaction()
                raise
            else:
                try:
                    session.commit_transaction()
                except PyMongoError:
                    # A lost commit acknowledgement is ambiguous. Never replay
                    # account/password mutations or emit a second audit event.
                    raise HTTPException(503, "Account change outcome is unknown. Reload the account before any further action.") from None

    def lock(self, session):
        guard = self.state.find_one({"_id": GUARD_ID}, {"_id": 1, "revision": 1}, session=session)
        version = guard.get("revision") if guard else None
        if isinstance(version, bool) or not isinstance(version, int) or not 0 <= version < 2**63-1:
            raise unavailable()
        result = self.state.update_one({"_id": GUARD_ID, "revision": version},
                                       {"$inc": {"revision": 1}}, session=session, upsert=False)
        if result.matched_count != 1:
            raise conflict()

    def insert(self, document, session):
        self.users.insert_one(document, session=session)

    def update(self, target, expected, changes, revoke, session):
        # Missing legacy revision behaves as zero, but explicit null is invalid.
        revision_filter = {"$or": [{"revision": 0}, {"revision": {"$exists": False}}]} if expected == 0 else {"revision": expected}
        query = {"_id": target, **revision_filter}
        increments = {"revision": 1}
        if revoke:
            increments["auth_version"] = 1
        result = self.users.update_one(query, {"$set": changes, "$inc": increments}, session=session, upsert=False)
        if result.matched_count != 1:
            raise conflict()

    def assert_admin_remains(self, session):
        if self.users.count_documents({"role": "admin", "global_access": True, "is_active": True}, session=session) < 1:
            raise HTTPException(409, "At least one active global Inventory Admin must remain.")

    def audit_change(self, actor_id, target_id, action, fields, session):
        # Values and request payloads are deliberately not audited.
        self.audit.insert_one({"_id": ObjectId(), "actor_id": actor_id,
                               "target_id": target_id, "action": action,
                               "changed_fields": sorted(fields),
                               "occurred_at": datetime.now(timezone.utc)}, session=session)
