"""Minimal FastAPI integration; all persistence is fake, shared app never imported."""
import copy
import unittest
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
import jwt
from fastapi import FastAPI
from fastapi.testclient import TestClient
import test_inventory_user_management as fixtures
from app.routes.inventory_user_management_routes import router
from app.routes.inventory_auth_routes import router as auth_router
from app.services.inventory_auth_service import InventoryAuthService, InventoryJWTSettings, get_inventory_auth_service
from app.services.inventory_user_service import get_inventory_user_repository
from app.services.inventory_user_management_dependencies import get_management_repository
from app.services.inventory_user_management_repository import MongoInventoryManagementRepository, USERS, AUDIT, STATE, STORES


class ManagementIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.auth = InventoryAuthService(InventoryJWTSettings(secret="fixture-only-integration-secret-000000000000000000"))
        cls.hash = cls.auth.hash_password("fixture-password-123")

    def setUp(self):
        for target in ("socket.create_connection", "pymongo.MongoClient"):
            guard = patch(target, side_effect=AssertionError("Real IO forbidden")); guard.start(); self.addCleanup(guard.stop)
        self.db = fixtures.Database([fixtures.ManagementTests.account(self, 1), fixtures.ManagementTests.account(self, 2)])
        self.repo = MongoInventoryManagementRepository(self.db)
        self.app = FastAPI()
        self.app.include_router(router)
        self.app.include_router(auth_router)
        self.app.dependency_overrides[get_inventory_auth_service] = lambda: self.auth
        self.app.dependency_overrides[get_inventory_user_repository] = lambda: self.repo
        self.app.dependency_overrides[get_management_repository] = lambda: self.repo
        self.client = TestClient(self.app)
        self.addCleanup(self.client.close)
        self.target = "oid:" + str(self.db.data[USERS][1]["_id"])
        self.body = {"username": "newuser", "display_name": "New User", "role": "viewer",
                     "store_ids": ["S1"], "password": "fixture-password-123"}

    def headers(self):
        return {"Authorization": "Bearer " + self.auth.create_token(self.auth.principal(self.db.data[USERS][0]))}

    def operations(self):
        base = "/inventory-users/" + self.target
        return [("GET", "/inventory-users", None), ("GET", base, None),
                ("POST", "/inventory-users", self.body),
                ("PATCH", base, {"revision": 0, "display_name": "Changed"}),
                ("PATCH", base + "/status", {"revision": 0, "is_active": False}),
                ("POST", base + "/reset-password", {"revision": 0, "password": "replacement-password"})]

    def test_all_endpoints_require_jwt_and_global_admin_all_roles(self):
        for role in ("admin", "manager", "analyst", "operator", "viewer"):
            for global_access in (False, True):
                if role == "admin" and global_access: continue
                self.db.data[USERS][0].update(role=role, global_access=global_access)
                for method, path, body in self.operations():
                    for headers, status in (({}, 401), (self.headers(), 403)):
                        response = self.client.request(method, path, json=body, headers=headers)
                        self.assertEqual(response.status_code, status)
        self.assertEqual(self.db.attempts, [])
        self.assertEqual(self.db.data[AUDIT], [])

    def test_invalid_expired_customer_tokens_rejected_before_effects(self):
        token = self.headers()["Authorization"].split()[1]
        claims = jwt.decode(token, options={"verify_signature": False})
        now = int(datetime.now(timezone.utc).timestamp())
        for token in ("invalid", jwt.encode({**claims, "iat": now-1000, "nbf": now-1000, "exp": now-100}, self.auth.settings.secret, algorithm="HS256"),
                      jwt.encode({**claims, "aud": "customer-api", "purpose": "customer_access"}, self.auth.settings.secret, algorithm="HS256")):
            for method, path, body in self.operations():
                self.assertEqual(self.client.request(method, path, json=body, headers={"Authorization": "Bearer " + token}).status_code, 401)
        self.assertEqual(self.db.attempts, [])

    def test_create_detail_list_update_status_and_reset_contracts(self):
        headers = self.headers()
        response = self.client.post("/inventory-users", json=self.body, headers=headers)
        self.assertEqual(response.status_code, 201, response.text)
        self.assertEqual(response.headers["cache-control"], "no-store")
        user_id = response.json()["user_id"]
        path = "/inventory-users/" + user_id
        self.assertEqual(self.client.get(path, headers=headers).status_code, 200)
        page = self.client.get("/inventory-users?role=viewer&store_id=S1&limit=1", headers=headers)
        self.assertEqual(page.status_code, 200, page.text)
        self.assertEqual(page.json()["total"], 1)
        self.assertEqual(self.client.patch(path, json={"revision": 0, "display_name": "Renamed"}, headers=headers).json()["revision"], 1)
        self.assertEqual(self.client.patch(path+"/status", json={"revision": 1, "is_active": False}, headers=headers).status_code, 200)
        reset = self.client.post(path+"/reset-password", json={"revision": 2, "password": "replacement-password"}, headers=headers)
        self.assertEqual(reset.status_code, 200, reset.text)
        self.assertEqual(reset.json()["revision"], 3)
        for forbidden in ("password_hash", "auth_version", "replacement-password", "fixture-password-123"):
            self.assertNotIn(forbidden, reset.text)
        self.assertEqual(len(self.db.data[AUDIT]), 4)

    def test_validation_redacts_passwords_and_rejects_operator_and_identity_fields(self):
        marker = "private-password-marker"
        for password in (marker*100, {"password": marker}, [marker], None):
            response = self.client.post("/inventory-users", json={**self.body, "password": password}, headers=self.headers())
            self.assertEqual(response.status_code, 422)
            self.assertNotIn(marker, response.text)
        for payload in ({"revision": 0, "username": "renamed"}, {"revision": 0, "$set": {"role": "admin"}},
                        {"revision": 0, "created_by": "forged"}, {"revision": 0, "global_access": "true"},
                        {"revision": 0, "role": None}):
            response = self.client.patch("/inventory-users/"+self.target, json=payload, headers=self.headers())
            self.assertEqual(response.status_code, 422)
        self.assertEqual(self.db.attempts, [])

    def test_missing_and_malformed_ids_and_invalid_queries_are_safe(self):
        headers = self.headers()
        self.assertEqual(self.client.get("/inventory-users/oid:"+"f"*24, headers=headers).status_code, 404)
        self.assertEqual(self.client.get("/inventory-users/not-an-id", headers=headers).status_code, 422)
        for query in ("limit=101", "offset=-1", "sort=password_hash", "role=owner"):
            self.assertEqual(self.client.get("/inventory-users?"+query, headers=headers).status_code, 422)

    def test_reset_replay_conflicts_and_old_jwt_is_revoked(self):
        old = self.auth.create_token(self.auth.principal(self.db.data[USERS][1]))
        path = "/inventory-users/"+self.target+"/reset-password"
        body = {"revision": 0, "password": "replacement-password"}
        self.assertEqual(self.client.post(path, json=body, headers=self.headers()).status_code, 200)
        self.assertEqual(self.client.post(path, json=body, headers=self.headers()).status_code, 409)
        self.assertEqual(len(self.db.data[AUDIT]), 1)
        self.assertEqual(self.client.get("/inventory-auth/me", headers={"Authorization": "Bearer "+old}).status_code, 401)

    def test_lazy_wiring_reuses_existing_wrapper_only_approved_names(self):
        wrapper = SimpleNamespace(db=self.db, client=self.db.client)
        with patch("app.services.inventory_user_management_dependencies.get_existing_inventory_mongo_wrapper", return_value=wrapper):
            repository = get_management_repository(_admin=self.auth.principal(self.db.data[USERS][0]))
        self.assertIs(repository.db, self.db)
        self.assertEqual(set(self.db.accessed), {USERS, STATE, AUDIT, STORES})
        self.assertEqual(self.db.sessions, 0)
        self.assertEqual(self.db.attempts, [])
        with patch("app.services.inventory_user_management_dependencies.get_existing_inventory_mongo_wrapper", side_effect=RuntimeError("private")):
            from fastapi import HTTPException
            with self.assertRaises(HTTPException) as caught: get_management_repository(_admin=None)
        self.assertEqual(caught.exception.status_code, 503)
        self.assertNotIn("private", caught.exception.detail)

    def test_failure_rolls_back_account_and_audit_without_private_errors(self):
        before = copy.deepcopy(self.db.data)
        self.db.fail_audit = True
        response = self.client.post("/inventory-users", json=self.body, headers=self.headers())
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("private", response.text)
        self.assertEqual(before, self.db.data)

    def test_readiness_failures_are_sanitized_and_never_mutate(self):
        from pymongo.errors import OperationFailure
        for missing in (STATE, AUDIT):
            rows = self.db.data.pop(missing)
            try:
                before = copy.deepcopy(self.db.data)
                for method, path, body in self.operations():
                    response = self.client.request(method, path, json=body, headers=self.headers())
                    self.assertEqual(response.status_code, 503)
                    self.assertEqual(self.db.data, before)
                self.assertEqual(self.db.attempts, [])
                self.assertEqual(self.db.sessions, 0)
            finally:
                self.db.data[missing] = rows
        with patch.object(self.db, "list_collection_names", side_effect=OperationFailure("private metadata detail", code=8000)):
            for method, path, body in self.operations():
                response = self.client.request(method, path, json=body, headers=self.headers())
                self.assertEqual(response.status_code, 503)
                self.assertNotIn("private", response.text)
        self.assertEqual(self.db.attempts, [])
        self.assertEqual(self.db.sessions, 0)

    def test_missing_guard_blocks_all_mutations_without_provisioning(self):
        self.db.data[STATE] = []
        before = copy.deepcopy(self.db.data)
        for method, path, body in self.operations():
            if method == "GET":
                continue
            response = self.client.request(method, path, json=body, headers=self.headers())
            self.assertEqual(response.status_code, 503)
            self.assertEqual(self.db.data, before)
        self.assertEqual(self.db.attempts, [])
        self.assertEqual(self.db.commits, 0)

    def test_router_registered_once_and_has_only_six_operations(self):
        self.assertEqual(len(router.routes), 6)
        main = Path(__file__).resolve().parents[2] / "app/main.py"
        self.assertEqual(main.read_text().count("app.include_router(inventory_user_management_router)"), 1)


if __name__ == "__main__": unittest.main()
