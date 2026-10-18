"""Isolated tests: no shared application import, Mongo client, or real users."""
import copy
import socket
from concurrent.futures import ThreadPoolExecutor
from threading import Event, Lock
from bson import ObjectId
import unittest
from datetime import datetime, timezone
from unittest.mock import Mock, patch

import jwt
from fastapi import Depends, FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.routes.inventory_auth_routes import router
from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.security.inventory_permissions import (
    require_global_access, require_roles, require_store_access, roles_required,
)
from app.services.inventory_auth_service import (
    InventoryAuthService, InventoryJWTSettings, LoginThrottle, get_inventory_auth_service,
    _cached_inventory_auth_service,
)
from app.services.inventory_user_service import (
    MongoInventoryUserRepository, get_inventory_user_repository,
    canonical_user_id, InvalidInventoryUser,
)


class FakeRepository:
    def __init__(self, user):
        self.user = user
        self.reads = []

    def find_by_username(self, username):
        self.reads.append(("username", username))
        return self.user if self.user and self.user["username_normalized"] == username else None

    def find_by_id(self, user_id):
        self.reads.append(("id", user_id))
        return self.user if self.user and canonical_user_id(self.user["_id"]) == user_id else None


class InventoryAuthTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Explicit test-only key; never loaded into application configuration.
        cls.service = InventoryAuthService(
            InventoryJWTSettings(secret="test-only-inventory-signing-key-000000-000000-000000-000000")
        )
        cls.password_hash = cls.service.hash_password("test-only-password")

    def setUp(self):
        self.network = patch.object(socket, "create_connection", side_effect=AssertionError("Network forbidden"))
        self.network.start()
        self.addCleanup(self.network.stop)
        self.service.throttle = LoginThrottle()
        self.user = {
            "_id": ObjectId("0123456789abcdef01234567"), "username_normalized": "testuser",
            "display_name": "Test User", "password_hash": self.password_hash,
            "role": "manager", "store_ids": ["CP001"], "global_access": False,
            "is_active": True, "created_at": "test", "updated_at": "test",
        }
        self.repo = FakeRepository(self.user)
        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_inventory_auth_service] = lambda: self.service
        app.dependency_overrides[get_inventory_user_repository] = lambda: self.repo

        @app.get("/admin-only")
        def admin_only(user: InventoryPrincipal = Depends(roles_required("admin"))):
            return {"user_id": user.user_id}

        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def login(self, **changes):
        data = {"username": " TESTUSER ", "password": "test-only-password"}
        data.update(changes)
        return self.client.post("/inventory-auth/login", json=data)

    def headers(self):
        principal = self.service.principal(self.user)
        return {"Authorization": "Bearer " + self.service.create_token(principal)}

    def mutated_token(self, **changes):
        now = int(datetime.now(timezone.utc).timestamp())
        claims = {
            "sub": canonical_user_id(self.user["_id"]), "iss": self.service.settings.issuer,
            "aud": self.service.settings.audience, "purpose": "inventory_access",
            "iat": now, "nbf": now, "exp": now + 900, "jti": "test-token",
            "auth_version": 0,
        }
        claims.update(changes)
        return jwt.encode(claims, self.service.settings.secret, algorithm="HS256")

    def assert_denied_token(self, token):
        response = self.client.get("/inventory-auth/me", headers={"Authorization": "Bearer " + token})
        self.assertEqual(response.status_code, 401)

    def test_valid_credentials(self):
        before = copy.deepcopy(self.user)
        response = self.login()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["expires_in"], 900)
        self.assertEqual(response.json()["user"]["user_id"], canonical_user_id(self.user["_id"]))
        self.assertNotIn("password_hash", response.text)
        self.assertEqual(before, self.user)

    def test_generic_invalid_login(self):
        responses = [self.login(username="unknown"), self.login(password="wrong")]
        self.user["is_active"] = False
        responses.append(self.login())
        self.user["is_active"] = True
        self.user["role"] = "unsupported"
        responses.append(self.login())
        for response in responses:
            self.assertEqual(response.status_code, 401)
            self.assertEqual(response.json()["detail"], "Invalid authentication credentials.")

    def test_valid_jwt(self):
        self.assertEqual(self.client.get("/inventory-auth/me", headers=self.headers()).status_code, 200)

    def test_expired_jwt(self):
        now = int(datetime.now(timezone.utc).timestamp())
        self.assert_denied_token(self.mutated_token(iat=now-1000, nbf=now-1000, exp=now-100))

    def test_tampered_jwt(self):
        token = self.mutated_token()
        parts = token.split(".")
        parts[1] = ("A" if parts[1][0] != "A" else "B") + parts[1][1:]
        self.assert_denied_token(".".join(parts))

    def test_incorrect_issuer(self):
        self.assert_denied_token(self.mutated_token(iss="customer"))

    def test_incorrect_audience(self):
        self.assert_denied_token(self.mutated_token(aud="customer-api"))

    def test_incorrect_purpose(self):
        self.assert_denied_token(self.mutated_token(purpose="refresh"))

    def test_missing_bearer(self):
        self.assertEqual(self.client.get("/inventory-auth/me").status_code, 401)

    def test_missing_required_claim(self):
        claims = jwt.decode(self.mutated_token(), options={"verify_signature": False})
        del claims["jti"]
        self.assert_denied_token(jwt.encode(claims, self.service.settings.secret, algorithm="HS256"))

    def test_disallowed_algorithm(self):
        claims = jwt.decode(self.mutated_token(), options={"verify_signature": False})
        self.assert_denied_token(jwt.encode(claims, self.service.settings.secret, algorithm="HS384"))

    def test_excessive_lifetime(self):
        self.assert_denied_token(self.mutated_token(exp=int(datetime.now(timezone.utc).timestamp())+1800))

    def test_current_account_state(self):
        headers = self.headers()
        self.user["is_active"] = False
        self.assertEqual(self.client.get("/inventory-auth/me", headers=headers).status_code, 401)
        self.user["is_active"] = True
        self.user["role"] = "unsupported"
        self.assertEqual(self.client.get("/inventory-auth/me", headers=headers).status_code, 403)

    def test_live_permissions(self):
        headers = self.headers()
        self.user["role"] = "viewer"
        self.user["store_ids"] = ["CP002"]
        response = self.client.get("/inventory-auth/me", headers=headers)
        self.assertEqual(response.json()["role"], "viewer")
        self.assertEqual(response.json()["store_ids"], ["CP002"])

    def test_unauthorized_role(self):
        self.assertEqual(self.client.get("/admin-only", headers=self.headers()).status_code, 403)

    def test_unauthorized_store(self):
        user = self.service.principal(self.user)
        self.assertIs(require_store_access(user, "CP001"), user)
        for stores in [("CP002",), ("CP001", "CP002"), (), ("",)]:
            with self.assertRaises(HTTPException) as caught:
                require_store_access(user, *stores)
            self.assertEqual(caught.exception.status_code, 403)

    def test_global_access_rules(self):
        user = self.service.principal(self.user)
        with self.assertRaises(HTTPException):
            require_global_access(user)
        self.user["global_access"] = True
        user = self.service.principal(self.user)
        self.assertIs(require_global_access(user), user)
        self.assertIs(require_store_access(user, "CP002"), user)
        with self.assertRaises(HTTPException):
            require_roles(user, "admin")

    def test_admin_is_not_implicitly_global(self):
        self.user["role"] = "admin"
        with self.assertRaises(HTTPException):
            require_store_access(self.service.principal(self.user), "CP002")

    def test_permissions_not_accepted_from_login(self):
        self.assertEqual(self.login(role="admin", global_access=True).status_code, 422)

    def test_password_format(self):
        self.assertTrue(self.password_hash.startswith("$argon2id$"))
        self.assertTrue(self.service.verify_password("test-only-password", self.password_hash))
        self.assertFalse(self.service.verify_password("test-only-password", "plaintext"))
        self.assertFalse(self.service.verify_password("test-only-password", "$argon2id$invalid"))

    def test_repository_failure_is_sanitized(self):
        self.repo.find_by_username = Mock(side_effect=RuntimeError("private database detail"))
        response = self.login()
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("private", response.text)

    def test_missing_token_precedes_configuration_and_repository(self):
        app = FastAPI()
        app.include_router(router)
        with TestClient(app) as client:
            self.assertEqual(client.get("/inventory-auth/me").status_code, 401)

    def test_missing_configuration_is_safe(self):
        _cached_inventory_auth_service.cache_clear()
        self.addCleanup(_cached_inventory_auth_service.cache_clear)
        with patch.dict("os.environ", {}, clear=True):
            with self.assertRaises(HTTPException) as caught:
                get_inventory_auth_service()
            self.assertEqual(caught.exception.status_code, 503)

    def test_malformed_scope_denied(self):
        for field, value in [("global_access", "true"), ("store_ids", "CP001"), ("store_ids", [""])]:
            record = copy.deepcopy(self.user)
            record[field] = value
            with self.assertRaises(HTTPException) as caught:
                self.service.principal(record)
            self.assertEqual(caught.exception.status_code, 403)

    def test_no_database_writes(self):
        collection = Mock()
        repository = MongoInventoryUserRepository(collection)
        collection.find.return_value.limit.return_value = []
        repository.find_by_username("testuser")
        repository.find_by_id(canonical_user_id(self.user["_id"]))
        self.assertEqual([call[0] for call in collection.mock_calls], ["find", "find().limit", "find_one"])
        before = copy.deepcopy(self.user)
        self.login()
        self.client.get("/inventory-auth/me", headers=self.headers())
        self.assertEqual(before, self.user)



    def test_password_redaction(self):
        marker = "synthetic-private-value"
        inputs = [
            {"password": marker * 100},
            {"password": {"nested": marker}},
            {"password": [marker]},
            {"password": None},
            {"password": ""},
            {"password": 123},
            {"username": {"nested": marker}, "password": marker},
        ]
        for changes in inputs:
            response = self.login(**changes)
            self.assertEqual(response.status_code, 422)
            self.assertNotIn(marker, response.text)
            self.assertNotIn("password_hash", response.text)
            self.assertNotIn(self.service.settings.secret, response.text)
            self.assertEqual(response.headers["cache-control"], "no-store")
        response = self.client.post("/inventory-auth/login", json={"username": "testuser"})
        self.assertEqual(response.status_code, 422)
        response = self.client.post("/inventory-auth/login", content='{"password":"'+marker)
        self.assertEqual(response.status_code, 422)
        self.assertNotIn(marker, response.text)

    def test_validation_is_inventory_only(self):
        from pydantic import BaseModel
        from fastapi import Body
        class OtherInput(BaseModel):
            count: int
        app = FastAPI()
        app.include_router(router)
        @app.post("/customer-example")
        def other(body: OtherInput = Body()):
            return body
        # Resolve the local annotation explicitly for FastAPI.
        with TestClient(app) as client:
            response = client.post("/customer-example", json={"count": "not-an-int"})
            self.assertEqual(response.status_code, 422)
            self.assertIsInstance(response.json()["detail"], list)

    def test_failure_throttling_and_expiration(self):
        clock = [0.0]
        self.service.throttle = LoginThrottle(clock=lambda: clock[0])
        for _ in range(5):
            self.assertEqual(self.login(password="wrong").status_code, 401)
        response = self.login(password="wrong")
        self.assertEqual(response.status_code, 429)
        self.assertEqual(response.headers["retry-after"], "60")
        clock[0] = 60.0
        self.assertEqual(self.login().status_code, 200)

    def test_unknown_user_has_identical_throttle(self):
        for _ in range(5):
            self.assertEqual(self.login(username="missing", password="wrong").status_code, 401)
        self.assertEqual(self.login(username="missing", password="wrong").status_code, 429)

    def test_success_does_not_clear_failures(self):
        for _ in range(3):
            self.assertEqual(self.login(password="wrong").status_code, 401)
        self.assertEqual(self.login().status_code, 200)
        for _ in range(2):
            self.assertEqual(self.login(password="wrong").status_code, 401)
        self.assertEqual(self.login().status_code, 429)

    def test_throttle_memory_and_global_bound(self):
        clock = [0.0]
        limiter = LoginThrottle(clock=lambda: clock[0])
        for i in range(100):
            limiter.begin("account-" + str(i))
        with self.assertRaises(HTTPException) as caught:
            limiter.begin("new-account")
        self.assertEqual(caught.exception.status_code, 429)
        self.assertLessEqual(len(limiter._accounts), 1024)
        for window in range(1, 15):
            clock[0] = window * 60.0
            for i in range(100):
                limiter.begin(str(window) + "-" + str(i))
            self.assertLessEqual(len(limiter._accounts), 100)

    def test_concurrent_verification_bound(self):
        entered = Event()
        release = Event()
        lock = Lock()
        count = [0]
        def blocked_verify(*args):
            with lock:
                count[0] += 1
                if count[0] == 2:
                    entered.set()
            if not release.wait(5):
                raise RuntimeError("Test timed out")
            return True
        with patch.object(self.service, "hasher", Mock(verify=blocked_verify)):
            with ThreadPoolExecutor(max_workers=2) as pool:
                futures = [pool.submit(self.service.verify_password, "test", self.password_hash) for _ in range(2)]
                try:
                    self.assertTrue(entered.wait(5))
                    with self.assertRaises(HTTPException) as caught:
                        self.service.verify_password("test", self.password_hash)
                    self.assertEqual(caught.exception.status_code, 429)
                    self.assertEqual(count[0], 2)
                finally:
                    release.set()
                for future in futures:
                    self.assertTrue(future.result(timeout=5))
        self.assertTrue(self.service.verify_password("test-only-password", self.password_hash))

    def test_verification_slot_released_on_failure(self):
        for _ in range(4):
            self.assertFalse(self.service.verify_password("wrong", self.password_hash))
        self.assertTrue(self.service.verify_password("test-only-password", self.password_hash))

    def test_service_reuse(self):
        _cached_inventory_auth_service.cache_clear()
        self.addCleanup(_cached_inventory_auth_service.cache_clear)
        with patch.dict("os.environ", {"INVENTORY_JWT_SECRET": self.service.settings.secret}):
            with patch("app.services.inventory_auth_service.InventoryAuthService", return_value=self.service) as build:
                with ThreadPoolExecutor(max_workers=4) as pool:
                    services = list(pool.map(lambda _: get_inventory_auth_service(), range(8)))
                self.assertTrue(all(service is self.service for service in services))
                self.assertEqual(build.call_count, 1)

    def test_wrong_signing_key(self):
        claims = jwt.decode(self.mutated_token(), options={"verify_signature": False})
        token = jwt.encode(claims, "different-test-only-signing-key-000000", algorithm="HS256")
        self.assert_denied_token(token)

    def test_future_timestamps(self):
        now = int(datetime.now(timezone.utc).timestamp())
        self.assert_denied_token(self.mutated_token(iat=now+100, nbf=now+100, exp=now+900))

    def test_every_required_claim(self):
        claims = jwt.decode(self.mutated_token(), options={"verify_signature": False})
        for name in ("sub", "iss", "aud", "purpose", "iat", "nbf", "exp", "jti", "auth_version"):
            altered = dict(claims)
            del altered[name]
            self.assert_denied_token(jwt.encode(altered, self.service.settings.secret, algorithm="HS256"))

    def test_deleted_account(self):
        headers = self.headers()
        self.repo.user = None
        self.assertEqual(self.client.get("/inventory-auth/me", headers=headers).status_code, 401)

    def test_malformed_repository_results(self):
        headers = self.headers()
        for malformed in ([], "private-data", 42, {"is_active": True}):
            self.repo.find_by_id = Mock(return_value=malformed)
            response = self.client.get("/inventory-auth/me", headers=headers)
            self.assertIn(response.status_code, (401, 403))
            self.assertNotIn("private-data", response.text)
            self.assertNotIn("traceback", response.text)

    def test_unexpected_dependency_and_service_errors_redacted(self):
        app = FastAPI()
        app.include_router(router)
        marker = "synthetic-private-exception"
        def broken():
            raise RuntimeError(marker)
        app.dependency_overrides[get_inventory_auth_service] = broken
        app.dependency_overrides[get_inventory_user_repository] = lambda: self.repo
        with TestClient(app) as client:
            response = client.post("/inventory-auth/login", json={"username": "test", "password": marker})
            self.assertEqual(response.status_code, 503)
            self.assertNotIn(marker, response.text)

    def test_objectid_policy_and_string_shadow(self):
        collection = Mock()
        collection.find_one.return_value = self.user
        repository = MongoInventoryUserRepository(collection)
        subject = canonical_user_id(self.user["_id"])
        repository.find_by_id(subject)
        collection.find_one.assert_called_once_with({"_id": self.user["_id"]})
        for bad in (str(self.user["_id"]), "oid:" + str(self.user["_id"]).upper(), "staff-test"):
            with self.assertRaises(InvalidInventoryUser):
                repository.find_by_id(bad)
        record = dict(self.user)
        record["_id"] = str(self.user["_id"])
        with self.assertRaises(HTTPException):
            self.service.principal(record)

    def test_duplicate_usernames_fail_closed(self):
        collection = Mock()
        collection.find.return_value.limit.return_value = [self.user, dict(self.user)]
        repository = MongoInventoryUserRepository(collection)
        with self.assertRaises(InvalidInventoryUser):
            repository.find_by_username("testuser")
        self.client.app.dependency_overrides[get_inventory_user_repository] = lambda: repository
        response = self.login()
        self.assertEqual(response.status_code, 401)
        collection.find.return_value.limit.assert_called_with(2)

    def test_username_record_mismatch(self):
        self.repo.find_by_username = Mock(return_value={**self.user, "username_normalized": "another"})
        self.assertEqual(self.login().status_code, 401)


if __name__ == "__main__":
    unittest.main()
