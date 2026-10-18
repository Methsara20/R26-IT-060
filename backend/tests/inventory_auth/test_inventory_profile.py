"""Self-service tests: minimal apps and fake transactions, never real MongoDB."""
import copy
import unittest
from concurrent.futures import ThreadPoolExecutor
from threading import Event
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import patch
import jwt
from fastapi import FastAPI
from fastapi.testclient import TestClient
import test_inventory_user_management as fixtures
from app.routes.inventory_auth_routes import router as auth_router
from app.routes.inventory_profile_routes import router
from app.schemas.inventory_profile_schema import ChangeInventoryPassword
from app.schemas.inventory_user_management_schema import ResetInventoryUserPassword, SetInventoryUserStatus
from app.services.inventory_auth_service import InventoryAuthService, InventoryJWTSettings, LoginThrottle, get_inventory_auth_service
from app.services.inventory_user_service import get_inventory_user_repository
from app.services.inventory_user_management_dependencies import get_profile_repository
from app.services.inventory_user_management_repository import MongoInventoryManagementRepository, USERS, STATE, AUDIT, STORES, GUARD_ID
from app.services.inventory_user_management_service import InventoryUserManagementService
from app.services.inventory_profile_service import InventoryProfileService


class OwnCredentialCollection(fixtures.Collection):
    def find_one(self, query, projection, session=None):
        if "password_hash" not in projection:
            return super().find_one(query, projection, session)
        assert set(query) == {"_id"}
        assert projection["password_hash"] == 1
        self.database.reads.append((self.name, copy.deepcopy(query), copy.deepcopy(projection)))
        matches = [row for row in self.rows if row["_id"] == query["_id"]]
        return {key: copy.deepcopy(value) for key, value in matches[0].items() if projection.get(key)} if matches else None


class ProfileDatabase(fixtures.Database):
    def get_collection(self, name):
        if name == USERS:
            self.accessed.append(name)
            return OwnCredentialCollection(self, name)
        return super().get_collection(name)


class InventoryProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.auth = InventoryAuthService(InventoryJWTSettings(secret="fixture-only-profile-key-0000000000000000000000000"))
        cls.hash = cls.auth.hash_password("fixture-password-123")

    def setUp(self):
        for target in ("socket.create_connection", "pymongo.MongoClient"):
            guard = patch(target, side_effect=AssertionError("Real IO forbidden")); guard.start(); self.addCleanup(guard.stop)
        self.auth.throttle = LoginThrottle()
        self.db = ProfileDatabase([fixtures.ManagementTests.account(self, 1), fixtures.ManagementTests.account(self, 2)])
        self.repo = MongoInventoryManagementRepository(self.db)
        self.service = InventoryProfileService(self.repo, self.auth)
        self.app = FastAPI()
        self.app.include_router(auth_router)
        self.app.include_router(router)
        self.app.dependency_overrides[get_inventory_auth_service] = lambda: self.auth
        self.app.dependency_overrides[get_inventory_user_repository] = lambda: self.repo
        self.app.dependency_overrides[get_profile_repository] = lambda: self.repo
        self.client = TestClient(self.app)
        self.addCleanup(self.client.close)

    def token(self, index=0):
        return self.auth.create_token(self.auth.principal(self.db.data[USERS][index]))

    def headers(self, token=None): return {"Authorization": "Bearer " + (token or self.token())}

    def password_body(self, **changes):
        return {"current_password": "fixture-password-123", "new_password": "replacement-password",
                "new_password_confirmation": "replacement-password", **changes}

    def change(self, body=None, token=None):
        return self.client.post("/inventory-auth/change-password", json=self.password_body() if body is None else body,
                                headers=self.headers(token))

    def test_all_roles_read_and_update_only_own_profile(self):
        for role in ("admin", "manager", "analyst", "operator", "viewer"):
            for global_access in (True, False):
                with self.subTest(role=role, global_access=global_access):
                    own = self.db.data[USERS][0]
                    own.update(role=role, global_access=global_access, store_ids=[] if global_access else ["S1"])
                    token = self.token()
                    before = copy.deepcopy(self.db.data[USERS])
                    me = self.client.get("/inventory-auth/me", headers=self.headers(token))
                    self.assertEqual(me.status_code, 200)
                    self.assertEqual(set(me.json()), {"user_id", "username_normalized", "display_name", "role", "store_ids", "global_access"})
                    result = self.client.patch("/inventory-auth/me", json={"display_name": " Updated Name "}, headers=self.headers(token))
                    self.assertEqual(result.status_code, 200, result.text)
                    self.assertEqual(result.json()["user"]["display_name"], "Updated Name")
                    for key in ("username_normalized", "role", "store_ids", "global_access", "is_active", "password_hash", "auth_version"):
                        self.assertEqual(before[0][key], own[key])
                    self.assertEqual(before[1], self.db.data[USERS][1])
                    self.assertEqual(self.client.get("/inventory-auth/me", headers=self.headers(token)).status_code, 200)
        self.assertTrue(all("password_hash" not in projection for _, _, projection in self.db.reads))

    def test_all_roles_can_change_own_password_without_global_access(self):
        for role in ("admin", "manager", "analyst", "operator", "viewer"):
            with self.subTest(role=role):
                own = self.db.data[USERS][0]
                own.update(role=role, global_access=False, store_ids=["S1"], password_hash=self.hash)
                response = self.change()
                self.assertEqual(response.status_code, 200, response.text)

    def test_missing_invalid_expired_customer_tokens_and_inactive_accounts(self):
        now = int(datetime.now(timezone.utc).timestamp())
        token = self.token()
        claims = jwt.decode(token, options={"verify_signature": False})
        invalid = [None, "invalid", jwt.encode({**claims, "iat": now-1000, "nbf": now-1000, "exp": now-100}, self.auth.settings.secret, algorithm="HS256"),
                   jwt.encode({**claims, "aud": "customer-api", "purpose": "customer_access"}, self.auth.settings.secret, algorithm="HS256")]
        self.db.data[USERS][0]["is_active"] = False
        invalid.append(token)
        for token in invalid:
            headers = {} if token is None else self.headers(token)
            for method, path, body in (("GET", "/inventory-auth/me", None),
                                       ("PATCH", "/inventory-auth/me", {"display_name": "Changed"}),
                                       ("POST", "/inventory-auth/change-password", self.password_body())):
                self.assertEqual(self.client.request(method, path, json=body, headers=headers).status_code, 401)
        self.assertEqual(self.db.attempts, [])
        self.assertTrue(all("password_hash" not in projection for _, _, projection in self.db.reads))

    def test_privileged_and_cross_user_fields_rejected(self):
        before = copy.deepcopy(self.db.data)
        for key, value in (("role", "admin"), ("store_ids", ["S2"]), ("global_access", True),
                           ("is_active", False), ("username", "other"), ("user_id", "oid:"+str(self.db.data[USERS][1]["_id"])),
                           ("actor_id", "forged"), ("$set", {"role": "admin"}), ("auth_version", 0)):
            response = self.client.patch("/inventory-auth/me", json={"display_name": "Changed", key: value}, headers=self.headers())
            self.assertEqual(response.status_code, 422)
        response = self.change(self.password_body(user_id="oid:"+str(self.db.data[USERS][1]["_id"])))
        self.assertEqual(response.status_code, 422)
        self.assertEqual(before, self.db.data)
        self.assertEqual(self.db.attempts, [])
        self.assertEqual(self.client.patch("/inventory-auth/me/other", json={"display_name": "Changed"}, headers=self.headers()).status_code, 404)

    def test_display_validation_and_explicit_revision_conflict(self):
        for name in ("", "   ", "x"*129, "bad\nname", 123, None):
            result = self.client.patch("/inventory-auth/me", json={"display_name": name}, headers=self.headers())
            self.assertEqual(result.status_code, 422)
        first = self.client.patch("/inventory-auth/me", json={"display_name": "One", "revision": 0}, headers=self.headers())
        self.assertEqual(first.status_code, 200)
        before = copy.deepcopy(self.db.data)
        stale = self.client.patch("/inventory-auth/me", json={"display_name": "Two", "revision": 0}, headers=self.headers())
        self.assertEqual(stale.status_code, 409)
        self.assertEqual(before, self.db.data)

    def test_wrong_current_password_rejected_and_throttled_without_writes(self):
        before = copy.deepcopy(self.db.data)
        for _ in range(5):
            self.assertEqual(self.change(self.password_body(current_password="wrong-password")).status_code, 400)
        self.assertEqual(self.change().status_code, 429)
        self.assertEqual(before, self.db.data)
        self.assertEqual(self.db.attempts, [])

    def test_confirmation_policy_reuse_and_password_redaction(self):
        marker = "private-fixture-password"
        for changes in ({"new_password_confirmation": marker}, {"new_password": "short", "new_password_confirmation": "short"},
                        {"new_password": marker*100, "new_password_confirmation": marker*100},
                        {"current_password": {"private": marker}}, {"new_password": None},
                        {"new_password": "fixture-password-123", "new_password_confirmation": "fixture-password-123"}):
            response = self.change(self.password_body(**changes))
            self.assertEqual(response.status_code, 422)
            self.assertNotIn(marker, response.text)
            self.assertNotIn("fixture-password-123", response.text)
        self.assertEqual(self.db.attempts, [])

    def test_password_change_atomic_revocation_no_trim_and_safe_audit(self):
        token = self.token()
        before_other = copy.deepcopy(self.db.data[USERS][1])
        response = self.change(self.password_body(new_password="  replacement-password  ", new_password_confirmation="  replacement-password  "), token)
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json(), {"message": "Password changed. Sign in again.", "reauthentication_required": True})
        self.assertEqual(response.headers["cache-control"], "no-store")
        own = self.db.data[USERS][0]
        self.assertEqual((own["auth_version"], own["revision"]), (1, 1))
        self.assertIsInstance(own["password_changed_at"], datetime)
        self.assertTrue(self.auth.verify_password("  replacement-password  ", own["password_hash"]))
        self.assertFalse(self.auth.verify_password("replacement-password", own["password_hash"]))
        self.assertFalse(self.auth.verify_password("fixture-password-123", own["password_hash"]))
        self.assertEqual(self.client.get("/inventory-auth/me", headers=self.headers(token)).status_code, 401)
        self.assertEqual(self.change(token=token).status_code, 401)
        self.assertEqual(self.db.data[USERS][1], before_other)
        audit = self.db.data[AUDIT][0]
        self.assertEqual(audit["actor_id"], audit["target_id"])
        self.assertEqual(audit["action"], "password_change")
        for forbidden in ("fixture-password-123", "replacement-password", own["password_hash"], token):
            self.assertNotIn(forbidden, str(audit))
            self.assertNotIn(forbidden, response.text)
        for name, query, projection in self.db.reads:
            if "password_hash" in projection:
                self.assertEqual(query, {"_id": own["_id"]})
        self.assertEqual(self.db.commits, 1)

    def test_concurrent_admin_reset_and_deactivation_during_verification(self):
        from fastapi import HTTPException
        for action in ("reset_password", "status"):
            with self.subTest(action=action):
                self.auth.throttle = LoginThrottle()
                own = self.db.data[USERS][0]
                own.update(is_active=True, password_hash=self.hash)
                token, admin_token = self.token(0), self.token(1)
                target = "oid:"+str(own["_id"])
                entered, release = Event(), Event()
                original = self.auth.verify_password
                def verify(password, encoded):
                    entered.set()
                    if not release.wait(5): raise AssertionError("Fixture not released")
                    return original(password, encoded)
                admin = InventoryUserManagementService(self.repo, self.auth)
                with patch.object(self.auth, "verify_password", side_effect=verify):
                    with ThreadPoolExecutor(max_workers=1) as pool:
                        pending = pool.submit(self.service.change_password, token, ChangeInventoryPassword(**self.password_body()))
                        try:
                            self.assertTrue(entered.wait(5))
                            data = (ResetInventoryUserPassword(revision=own["revision"], password="admin-reset-password") if action == "reset_password"
                                    else SetInventoryUserStatus(revision=own["revision"], is_active=False))
                            admin.mutate(admin_token, action, data, target)
                            after_admin = copy.deepcopy(self.db.data)
                        finally:
                            release.set()
                        with self.assertRaises(HTTPException) as caught: pending.result(timeout=5)
                        self.assertEqual(caught.exception.status_code, 401)
                self.assertEqual(after_admin, self.db.data)

    def test_revision_race_without_client_revision_aborts(self):
        self.db.on_start = lambda: self.db.data[USERS][0].update(display_name="Concurrent edit", revision=1)
        result = self.client.patch("/inventory-auth/me", json={"display_name": "Overwrite"}, headers=self.headers())
        self.assertEqual(result.status_code, 409)
        self.assertEqual(self.db.data[USERS][0]["display_name"], "Concurrent edit")
        self.assertEqual(self.db.attempts, [])

    def test_audit_failure_rolls_back_password_and_display_changes(self):
        self.db.fail_audit = True
        before = copy.deepcopy(self.db.data)
        for operation in (lambda: self.change(), lambda: self.client.patch("/inventory-auth/me", json={"display_name": "Changed"}, headers=self.headers())):
            result = operation()
            self.assertEqual(result.status_code, 503)
            self.assertNotIn("private", result.text)
            self.assertEqual(before, self.db.data)

    def test_missing_guard_and_unsupported_transactions_fail_closed(self):
        self.db.unsupported = True
        before = copy.deepcopy(self.db.data)
        self.assertEqual(self.change().status_code, 503)
        self.assertEqual(before, self.db.data)
        self.db.unsupported = False
        self.db.data[STATE] = []
        before = copy.deepcopy(self.db.data)
        self.assertEqual(self.change().status_code, 503)
        self.assertEqual(before, self.db.data)

    def test_unknown_commit_never_replays_password_change(self):
        self.db.unknown_commit = True
        response = self.change()
        self.assertEqual(response.status_code, 503)
        self.assertEqual(self.db.commits, 1)
        self.assertEqual(self.db.sessions, 1)
        self.assertEqual(len(self.db.data[AUDIT]), 1)
        self.assertEqual(self.db.data[USERS][0]["auth_version"], 1)

    def test_dependencies_reuse_wrapper_and_do_not_weaken_admin_management(self):
        wrapper = SimpleNamespace(db=self.db, client=self.db.client)
        self.db.data[USERS][0].update(role="viewer", global_access=False, store_ids=["S1"])
        self.app.dependency_overrides.pop(get_profile_repository)
        with patch("app.services.inventory_user_management_dependencies.get_existing_inventory_mongo_wrapper", return_value=wrapper):
            response = self.client.patch("/inventory-auth/me", json={"display_name": "Viewer Name"}, headers=self.headers())
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(set(self.db.accessed), {USERS, STATE, AUDIT, STORES})
        self.assertTrue(all(name != STORES for name, *_ in self.db.reads))

    def test_only_new_write_routes_registered_once_without_get_override(self):
        from pathlib import Path
        self.assertEqual({(next(iter(route.methods)), route.path) for route in router.routes},
                         {("PATCH", "/inventory-auth/me"), ("POST", "/inventory-auth/change-password")})
        self.assertEqual((Path(__file__).resolve().parents[2]/"app/main.py").read_text().count("app.include_router(inventory_profile_router)"), 1)
        gets = [route for route in self.app.routes if getattr(route, "path", None) == "/inventory-auth/me" and "GET" in getattr(route, "methods", set())]
        self.assertEqual(len(gets), 1)


if __name__ == "__main__": unittest.main()
