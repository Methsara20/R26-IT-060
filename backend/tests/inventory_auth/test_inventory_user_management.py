"""Transactional management tests using an in-memory Mongo-shaped adapter only."""
import copy
import re
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import patch
from bson import ObjectId
from fastapi import HTTPException
from pydantic import ValidationError
from pymongo.errors import DuplicateKeyError, OperationFailure
from app.schemas.inventory_user_management_schema import (
    CreateInventoryUser, UpdateInventoryUser, SetInventoryUserStatus,
    ResetInventoryUserPassword, InventoryUserQuery,
)
from app.services.inventory_auth_service import InventoryAuthService, InventoryJWTSettings
from app.services.inventory_user_management_repository import (
    MongoInventoryManagementRepository, USERS, STATE, AUDIT, STORES, GUARD_ID,
)
from app.services.inventory_user_management_service import InventoryUserManagementService


def matches(row, query):
    for key, expected in query.items():
        if key == "$or":
            if not any(matches(row, item) for item in expected): return False
        elif isinstance(expected, dict):
            for operator, value in expected.items():
                if operator == "$exists" and (key in row) != value: return False
                if operator == "$regex" and not re.search(value, str(row.get(key, "")), re.I if expected.get("$options") == "i" else 0): return False
                if operator == "$in" and row.get(key) not in value: return False
        elif isinstance(row.get(key), list):
            if expected not in row[key]: return False
        elif row.get(key) != expected: return False
    return True


class Cursor:
    def __init__(self, rows): self.rows = rows
    def sort(self, keys):
        for key, order in reversed(keys):
            self.rows.sort(key=lambda row: str(row.get(key, "")), reverse=order == -1)
        return self
    def skip(self, count): self.rows = self.rows[count:]; return self
    def limit(self, count): self.rows = self.rows[:count]; return self
    def __iter__(self): return iter(self.rows)


class Collection:
    def __init__(self, database, name): self.database, self.name = database, name
    @property
    def rows(self): return self.database.data[self.name]
    def index_information(self):
        return {"username": {"key": [("username_normalized", 1)], "unique": True}} if self.database.unique_index else {}
    def find(self, query, projection, session=None):
        assert projection and "password_hash" not in projection
        self.database.reads.append((self.name, copy.deepcopy(query), copy.deepcopy(projection)))
        return Cursor([{key: copy.deepcopy(value) for key, value in row.items()
                        if projection.get(key, 1 if key == "_id" else 0)}
                       for row in self.rows if matches(row, query)])
    def find_one(self, query, projection, session=None):
        return next(iter(self.find(query, projection, session)), None)
    def count_documents(self, query, session=None):
        return sum(matches(row, query) for row in self.rows)
    def update_one(self, query, update, *, session, upsert):
        assert upsert is False and session.in_transaction
        self.database.attempts.append((self.name, "update", copy.deepcopy(update)))
        for row in self.rows:
            if matches(row, query):
                row.update(copy.deepcopy(update.get("$set", {})))
                for key, value in update.get("$inc", {}).items(): row[key] = row.get(key, 0) + value
                return SimpleNamespace(matched_count=1)
        return SimpleNamespace(matched_count=0)
    def insert_one(self, row, *, session):
        assert session.in_transaction
        self.database.attempts.append((self.name, "insert", copy.deepcopy(row)))
        if self.name == AUDIT and self.database.fail_audit:
            raise OperationFailure("private audit error")
        if self.name == USERS and any(item["username_normalized"] == row["username_normalized"] for item in self.rows):
            raise DuplicateKeyError("private duplicate detail")
        self.rows.append(copy.deepcopy(row))


class Session:
    def __init__(self, db): self.db, self.in_transaction = db, False
    def __enter__(self): return self
    def __exit__(self, *args):
        if self.in_transaction: self.abort_transaction()
    def start_transaction(self, **options):
        if self.db.unsupported: raise OperationFailure("private unsupported transaction")
        self.db.lock.acquire()
        self.db.options.append(options)
        if self.db.on_start:
            hook, self.db.on_start = self.db.on_start, None
            hook()
        self.before = copy.deepcopy(self.db.data)
        self.in_transaction = True
    def abort_transaction(self):
        self.db.data = self.before
        self.in_transaction = False
        self.db.lock.release()
    def commit_transaction(self):
        self.db.commits += 1
        self.in_transaction = False
        self.db.lock.release()
        if self.db.unknown_commit:
            raise OperationFailure("private lost acknowledgement", details={"errorLabels": ["UnknownTransactionCommitResult"]})


class Database:
    name = "smart_retail_db"
    def __init__(self, users):
        self.data = {USERS: copy.deepcopy(users), STATE: [{"_id": GUARD_ID, "revision": 0}], AUDIT: [],
                     STORES: [{"_id": "S1", "store_id": "S1"}, {"_id": "S2", "store_id": "S2"}]}
        self.client = self
        self.lock = threading.RLock()
        self.reads, self.attempts, self.accessed, self.options = [], [], [], []
        self.unique_index = True
        self.fail_audit = self.unsupported = self.unknown_commit = False
        self.on_start = None
        self.commits = self.sessions = 0
    def get_collection(self, name):
        assert name in (USERS, STATE, AUDIT, STORES)
        self.accessed.append(name)
        return Collection(self, name)
    def list_collection_names(self, *, filter):
        assert set(filter) == {"name"}
        assert isinstance(filter["name"], str)
        assert filter["name"] in (USERS, STATE, AUDIT, STORES)
        return [filter["name"]] if filter["name"] in self.data else []
    def start_session(self): self.sessions += 1; return Session(self)


class ManagementTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.auth = InventoryAuthService(InventoryJWTSettings(secret="fixture-only-management-secret-000000000000000000"))
        cls.hash = cls.auth.hash_password("fixture-password-123")
    def account(self, number, role="admin", global_access=True):
        now = datetime.now(timezone.utc)
        return {"_id": ObjectId(f"{number:024x}"), "username_normalized": f"user{number}",
                "display_name": f"User {number}", "role": role, "global_access": global_access,
                "store_ids": [] if global_access else ["S1"], "is_active": True,
                "password_hash": self.hash, "auth_version": 0, "revision": 0,
                "created_at": now, "updated_at": now}
    def setUp(self):
        for target in ("socket.create_connection", "pymongo.MongoClient"):
            guard = patch(target, side_effect=AssertionError("Real IO forbidden")); guard.start(); self.addCleanup(guard.stop)
        self.db = Database([self.account(1), self.account(2)])
        self.repo = MongoInventoryManagementRepository(self.db)
        self.service = InventoryUserManagementService(self.repo, self.auth)
        self.token = self.auth.create_token(self.auth.principal(self.db.data[USERS][0]))
        self.target = "oid:" + str(self.db.data[USERS][1]["_id"])
    def create(self, **changes):
        return CreateInventoryUser(**{"username": " NEWUSER ", "display_name": "New User", "role": "viewer",
            "store_ids": ["S1"], "password": "  password-spaces  ", **changes})
    def denied(self, function, status):
        before = copy.deepcopy(self.db.data)
        with self.assertRaises(HTTPException) as caught: function()
        self.assertEqual(caught.exception.status_code, status)
        self.assertEqual(before, self.db.data)

    def test_create_normalizes_hashes_attributes_and_commits_once(self):
        result = self.service.mutate(self.token, "create", self.create())
        record = self.db.data[USERS][-1]
        self.assertIsInstance(record["_id"], ObjectId)
        self.assertEqual(result.username_normalized, "newuser")
        self.assertTrue(self.auth.verify_password("  password-spaces  ", record["password_hash"]))
        self.assertFalse(self.auth.verify_password("password-spaces", record["password_hash"]))
        self.assertNotIn("password_hash", result.model_dump())
        self.assertNotIn("auth_version", result.model_dump())
        self.assertEqual(record["created_by"], "oid:" + str(self.db.data[USERS][0]["_id"]))
        self.assertEqual(len(self.db.data[AUDIT]), 1)
        self.assertNotIn("password-spaces", str(self.db.data[AUDIT]))
        self.assertNotIn(record["password_hash"], str(self.db.data[AUDIT]))
        self.assertEqual(self.db.commits, 1)
        self.assertEqual(self.db.options[0]["write_concern"].document, {"w": "majority"})
        self.assertEqual(self.db.options[0]["read_concern"].document, {"level": "snapshot"})

    def test_duplicate_username_race_rolls_back_guard_and_audit(self):
        self.service.mutate(self.token, "create", self.create())
        self.denied(lambda: self.service.mutate(self.token, "create", self.create(username="newuser")), 409)

    def test_password_and_scope_validation(self):
        for changes in ({"password": "short"}, {"password": "x"*1025}, {"password": 123},
                        {"global_access": "true"}, {"is_active": 1}, {"role": "owner"},
                        {"store_ids": []}, {"store_ids": ["S1", "S1"]},
                        {"global_access": True, "store_ids": ["S1"]},
                        {"username": " ", "display_name": "User"}, {"display_name": " "},
                        {"username": "\u0130"*100}):
            with self.subTest(changes=list(changes)):
                with self.assertRaises(ValidationError): self.create(**changes)
        for field in ("created_by", "auth_version", "$set", "password_hash"):
            with self.assertRaises(ValidationError): self.create(**{field: "forged"})

    def test_read_only_store_validation_rejects_missing_or_ambiguous(self):
        self.denied(lambda: self.service.mutate(self.token, "create", self.create(store_ids=["UNKNOWN"])), 422)
        self.db.data[STORES].append({"store_id": "S1"})
        self.denied(lambda: self.service.mutate(self.token, "create", self.create()), 422)
        self.assertTrue(all(name != STORES for name, *_ in self.db.attempts))
        self.assertTrue(all(proj == {"_id": 0, "store_id": 1} for name, _, proj in self.db.reads if name == STORES))

    def test_security_updates_atomically_revoke_and_increment_revision(self):
        token = self.auth.create_token(self.auth.principal(self.db.data[USERS][1]))
        result = self.service.mutate(self.token, "update", UpdateInventoryUser(
            revision=0, role="analyst", global_access=False, store_ids=["S2"]), self.target)
        self.assertEqual(result.revision, 1)
        record = self.db.data[USERS][1]
        self.assertEqual(record["auth_version"], 1)
        self.assertEqual(record["role"], "analyst")
        with self.assertRaises(HTTPException): self.auth.current_user(self.repo, token)
        self.denied(lambda: self.service.mutate(self.token, "update", UpdateInventoryUser(revision=0, display_name="Stale"), self.target), 409)
        self.service.mutate(self.token, "update", UpdateInventoryUser(revision=1, display_name=" Renamed "), self.target)
        self.assertEqual(self.db.data[USERS][1]["auth_version"], 1)
        self.assertEqual(self.db.data[USERS][1]["display_name"], "Renamed")

    def test_legacy_counters_and_metadata_preserved(self):
        record = self.db.data[USERS][1]
        del record["auth_version"]; del record["revision"]
        record["created_by"] = "oid:" + str(self.db.data[USERS][0]["_id"])
        created = record["created_at"]
        self.service.mutate(self.token, "status", SetInventoryUserStatus(revision=0, is_active=False), self.target)
        self.assertEqual(record["auth_version"], 1)
        self.assertEqual(record["revision"], 1)
        self.assertEqual(record["created_at"], created)
        self.assertIn("created_by", record)

    def test_reset_and_status_revocation_and_stale_reset_no_retry(self):
        token = self.auth.create_token(self.auth.principal(self.db.data[USERS][1]))
        data = ResetInventoryUserPassword(revision=0, password="replacement-password")
        self.service.mutate(self.token, "reset_password", data, self.target)
        self.assertTrue(self.auth.verify_password(data.password, self.db.data[USERS][1]["password_hash"]))
        with self.assertRaises(HTTPException): self.auth.current_user(self.repo, token)
        self.denied(lambda: self.service.mutate(self.token, "reset_password", data, self.target), 409)
        self.service.mutate(self.token, "status", SetInventoryUserStatus(revision=1, is_active=False), self.target)
        self.service.mutate(self.token, "status", SetInventoryUserStatus(revision=2, is_active=True), self.target)
        self.assertEqual(self.db.data[USERS][1]["auth_version"], 3)
        with self.assertRaises(HTTPException): self.auth.current_user(self.repo, token)

    def test_self_protection(self):
        own = "oid:" + str(self.db.data[USERS][0]["_id"])
        for action, data in (("status", SetInventoryUserStatus(revision=0, is_active=False)),
                             ("update", UpdateInventoryUser(revision=0, role="viewer")),
                             ("update", UpdateInventoryUser(revision=0, global_access=False, store_ids=["S1"]))):
            self.denied(lambda: self.service.mutate(self.token, action, data, own), 409)

    def test_denied_role_has_zero_write_attempts(self):
        for role in ("admin", "manager", "analyst", "operator", "viewer"):
            for global_access in (False, True):
                if role == "admin" and global_access: continue
                record = self.db.data[USERS][0]; record.update(role=role, global_access=global_access)
                token = self.auth.create_token(self.auth.principal(record))
                self.denied(lambda: self.service.mutate(token, "create", self.create()), 403)
        self.assertEqual(self.db.attempts, [])

    def test_actor_revalidated_before_transaction_write(self):
        self.db.on_start = lambda: self.db.data[USERS][0].update(role="viewer", auth_version=1)
        with self.assertRaises(HTTPException) as caught:
            self.service.mutate(self.token, "create", self.create())
        self.assertEqual(caught.exception.status_code, 401)
        self.assertEqual(self.db.attempts, [])

    def test_concurrent_admins_cannot_disable_each_other(self):
        other = self.auth.create_token(self.auth.principal(self.db.data[USERS][1]))
        own = "oid:" + str(self.db.data[USERS][0]["_id"])
        barrier = threading.Barrier(2)
        def change(token, target):
            barrier.wait(timeout=5)
            try:
                self.service.mutate(token, "status", SetInventoryUserStatus(revision=0, is_active=False), target)
                return 200
            except HTTPException as error: return error.status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(change, self.token, self.target), pool.submit(change, other, own)]
            results = [future.result(timeout=10) for future in futures]
        self.assertEqual(results.count(200), 1)
        self.assertEqual(sum(row["is_active"] for row in self.db.data[USERS]), 1)
        self.assertEqual(len(self.db.data[AUDIT]), 1)

    def test_last_admin_invariant_aborts_transaction(self):
        # Exercise the invariant independently of self-protection and routing.
        before = copy.deepcopy(self.db.data)
        with self.assertRaises(HTTPException):
            with self.repo.transaction() as session:
                self.repo.lock(session)
                for record in self.db.data[USERS]: record["is_active"] = False
                self.repo.assert_admin_remains(session)
        self.assertEqual(before, self.db.data)

    def test_missing_prerequisites_and_audit_failure_fail_closed(self):
        self.db.unsupported = True
        self.denied(lambda: self.service.mutate(self.token, "create", self.create()), 503)
        self.db.unsupported = False
        self.db.unique_index = False
        self.denied(lambda: self.service.mutate(self.token, "create", self.create()), 503)
        self.db.unique_index = True
        self.db.data[STATE] = []
        self.denied(lambda: self.service.mutate(self.token, "create", self.create()), 503)
        self.db.data[STATE] = [{"_id": GUARD_ID, "revision": 0}]
        self.db.fail_audit = True
        self.denied(lambda: self.service.mutate(self.token, "create", self.create()), 503)
        del self.db.data[AUDIT]
        self.denied(lambda: self.service.mutate(self.token, "create", self.create()), 503)

    def test_readiness_uses_independent_exact_names_without_provisioning(self):
        before = copy.deepcopy(self.db.data)
        with patch.object(self.db, "list_collection_names", wraps=self.db.list_collection_names) as metadata:
            self.repo.require_ready()
        self.assertEqual(metadata.call_args_list, [
            unittest.mock.call(filter={"name": name}) for name in (USERS, STATE, AUDIT, STORES)
        ])
        self.assertEqual(self.db.data, before)
        self.assertEqual(self.db.attempts, [])
        self.assertEqual(self.db.sessions, 0)

    def test_each_missing_collection_prevents_transaction_and_mutation(self):
        for name in (USERS, STATE, AUDIT, STORES):
            with self.subTest(collection=name):
                rows = self.db.data.pop(name)
                try:
                    with self.assertRaises(HTTPException) as caught:
                        with self.repo.transaction():
                            self.fail("Readiness failure must not enter transaction body")
                    self.assertEqual(caught.exception.status_code, 503)
                    self.assertNotIn(name, self.db.data)
                    self.assertEqual(self.db.sessions, 0)
                    self.assertEqual(self.db.attempts, [])
                finally:
                    self.db.data[name] = rows

    def test_guard_is_separately_validated_before_any_write(self):
        for guard in ([], [{"_id": "wrong", "revision": 0}],
                      [{"_id": GUARD_ID}], *[
                          [{"_id": GUARD_ID, "revision": value}]
                          for value in (None, True, -1, "0", 2**63-1)]):
            with self.subTest(guard=guard):
                self.db.data[STATE] = guard
                self.denied(lambda: self.service.mutate(self.token, "create", self.create()), 503)
                self.assertEqual(self.db.attempts, [])
                self.assertEqual(self.db.commits, 0)
        self.assertTrue(all(query == {"_id": GUARD_ID} and projection == {"_id": 1, "revision": 1}
                            for name, query, projection in self.db.reads if name == STATE))
        self.db.data[STATE] = [{"_id": GUARD_ID, "revision": 0}]
        self.service.mutate(self.token, "create", self.create())
        self.assertEqual(self.db.data[STATE][0]["revision"], 1)
        self.assertEqual(self.db.commits, 1)

    def test_unknown_commit_never_replays_reset_or_duplicates_audit(self):
        self.db.unknown_commit = True
        with self.assertRaises(HTTPException) as caught:
            self.service.mutate(self.token, "reset_password", ResetInventoryUserPassword(revision=0, password="replacement-password"), self.target)
        self.assertEqual(caught.exception.status_code, 503)
        self.assertIn("unknown", caught.exception.detail)
        self.assertEqual(self.db.commits, 1)
        self.assertEqual(self.db.sessions, 1)
        self.assertEqual(len(self.db.data[AUDIT]), 1)
        self.assertEqual(self.db.data[USERS][1]["revision"], 1)

    def test_listing_filters_before_pagination_safe_projection_and_literal_search(self):
        self.service.mutate(self.token, "create", self.create())
        page = self.service.list(self.token, InventoryUserQuery(role="viewer", store_id="S1", is_active=True, limit=1))
        self.assertEqual(page.total, 1)
        self.assertEqual(page.users[0].username_normalized, "newuser")
        self.assertEqual(self.service.list(self.token, InventoryUserQuery(search=".*")).total, 0)
        self.assertEqual(self.service.list(self.token, InventoryUserQuery(search="NEWUSER")).total, 1)
        self.assertNotIn("password_hash", page.model_dump_json())
        self.assertNotIn("auth_version", page.model_dump_json())
        with self.assertRaises(ValidationError): InventoryUserQuery(sort="$where")


if __name__ == "__main__": unittest.main()
