"""Mock-only account version tests; no shared app, MongoDB or network access."""
import copy
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from threading import Event
from unittest.mock import patch

import jwt
from bson import ObjectId
from bson.int64 import Int64
from fastapi import Depends, FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.routes.inventory_auth_routes import router
from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.security.inventory_permissions import inventory_user_management_admin
from app.services.inventory_auth_service import (
    InventoryAuthService, InventoryJWTSettings, LoginThrottle, get_inventory_auth_service,
)
from app.services.inventory_user_service import get_inventory_user_repository


class ReadOnlyUsers:
    def __init__(self, record):
        self.record = record
        self.reads = []

    def find_by_username(self, username):
        self.reads.append(("username", username))
        return self.record if self.record and self.record["username_normalized"] == username else None

    def find_by_id(self, user_id):
        self.reads.append(("id", user_id))
        return self.record if self.record and "oid:" + str(self.record["_id"]) == user_id else None


class InventoryAccountRevocationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.service = InventoryAuthService(InventoryJWTSettings(
            secret="fixture-only-account-version-signing-key-000000000000000000",
        ))
        cls.encoded = cls.service.hash_password("fixture-password-before")
        cls.replacement = cls.service.hash_password("fixture-password-after")

    def setUp(self):
        for target in ("socket.create_connection", "pymongo.MongoClient"):
            guard = patch(target, side_effect=AssertionError("External access forbidden"))
            guard.start()
            self.addCleanup(guard.stop)
        self.service.throttle = LoginThrottle()
        self.record = {
            "_id": ObjectId("0123456789abcdef01234567"),
            "username_normalized": "fixtureuser", "display_name": "Fixture User",
            "password_hash": self.encoded, "role": "admin", "global_access": True,
            "store_ids": [], "is_active": True, "auth_version": 3,
        }
        self.repository = ReadOnlyUsers(self.record)
        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_inventory_auth_service] = lambda: self.service
        app.dependency_overrides[get_inventory_user_repository] = lambda: self.repository

        @app.get("/management-check")
        def check(user: InventoryPrincipal = Depends(inventory_user_management_admin)):
            return {"user_id": user.user_id}

        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def login(self, password="fixture-password-before"):
        return self.client.post("/inventory-auth/login", json={
            "username": " FIXTUREUSER ", "password": password,
        })

    def token(self):
        return self.service.create_token(self.service.principal(self.record))

    def claims(self, token):
        return jwt.decode(token, self.service.settings.secret,
                          algorithms=["HS256"], audience=self.service.settings.audience,
                          issuer=self.service.settings.issuer)

    def request(self, token, path="/inventory-auth/me"):
        return self.client.get(path, headers={"Authorization": "Bearer " + token})

    def signed(self, claims):
        return jwt.encode(claims, self.service.settings.secret, algorithm="HS256")

    def test_management_requires_admin_and_explicit_global_all_five_roles(self):
        for role in ("admin", "manager", "analyst", "operator", "viewer"):
            for global_access in (True, False):
                with self.subTest(role=role, global_access=global_access):
                    self.record.update(role=role, global_access=global_access)
                    response = self.request(self.token(), "/management-check")
                    self.assertEqual(response.status_code, 200 if role == "admin" and global_access else 403)

    def test_management_missing_invalid_expired_and_cross_component_tokens(self):
        self.assertEqual(self.client.get("/management-check").status_code, 401)
        now = int(datetime.now(timezone.utc).timestamp())
        claims = self.claims(self.token())
        tokens = ["invalid"]
        for changes in (
            {"iat": now - 1000, "nbf": now - 1000, "exp": now - 100},
            {"iss": "customer", "aud": "customer-api", "purpose": "customer_access"},
            {"iss": "marketing", "aud": "marketing-api", "purpose": "marketing_access"},
            {"purpose": "refresh"},
        ):
            tokens.append(self.signed({**claims, **changes}))
        tokens.append(jwt.encode(claims, "other-fixture-key-00000000000000000000000000", algorithm="HS256"))
        for token in tokens:
            with self.subTest():
                self.assertEqual(self.request(token, "/management-check").status_code, 401)
        self.assertEqual(self.repository.reads, [])

    def test_inactive_account_rejected_for_management(self):
        token = self.token()
        self.record["is_active"] = False
        self.assertEqual(self.request(token, "/management-check").status_code, 401)

    def test_login_token_contains_verified_version_but_public_principal_does_not(self):
        result = self.login()
        self.assertEqual(result.status_code, 200)
        body = result.json()
        self.assertEqual(self.claims(body["access_token"])["auth_version"], 3)
        self.assertEqual(set(body), {"access_token", "token_type", "expires_in", "user"})
        self.assertNotIn("auth_version", body["user"])
        me = self.request(body["access_token"])
        self.assertEqual(me.status_code, 200)
        self.assertNotIn("auth_version", me.text)
        principal = self.service.principal(self.record)
        self.assertNotIn("auth_version", principal.model_dump_json())
        self.assertNotIn("auth_version", repr(principal))
        self.assertNotIn("auth_version", principal.model_json_schema()["properties"])
        self.assertNotIn(self.encoded, result.text)
        self.assertNotIn("fixture-password-before", result.text)

    def test_missing_account_version_uses_zero_without_backfill(self):
        del self.record["auth_version"]
        before = copy.deepcopy(self.record)
        result = self.login()
        self.assertEqual(result.status_code, 200)
        token = result.json()["access_token"]
        self.assertEqual(self.claims(token)["auth_version"], 0)
        self.assertEqual(self.request(token).status_code, 200)
        self.assertEqual(self.record, before)
        self.record["auth_version"] = 1  # Simulate a future atomic account writer.
        self.assertEqual(self.request(token).status_code, 401)

    def test_missing_token_version_requires_new_login_even_for_legacy_account(self):
        del self.record["auth_version"]
        claims = self.claims(self.token())
        del claims["auth_version"]
        self.assertEqual(self.request(self.signed(claims)).status_code, 401)
        self.assertEqual(self.repository.reads, [])

    def test_malformed_token_versions_fail_closed(self):
        claims = self.claims(self.token())
        for value in (None, True, False, -1, 3.0, "3", [], {}, 2**63):
            with self.subTest(value=value):
                self.assertEqual(self.request(self.signed({**claims, "auth_version": value})).status_code, 401)

    def test_malformed_account_versions_fail_closed_and_are_redacted(self):
        token = self.token()
        for value in (None, True, False, -1, 3.0, "private-version-marker", [], {}, 2**63):
            with self.subTest(value=value):
                self.service.throttle = LoginThrottle()
                self.record["auth_version"] = value
                for response in (self.login(), self.request(token)):
                    self.assertEqual(response.status_code, 401)
                    self.assertNotIn("private-version-marker", response.text)

    def test_bson_int64_version_supported(self):
        self.record["auth_version"] = Int64(3)
        self.assertEqual(self.request(self.token()).status_code, 200)

    def test_version_mismatch_in_both_directions(self):
        token = self.token()
        for version in (2, 4):
            self.record["auth_version"] = version
            self.assertEqual(self.request(token).status_code, 401)

    def test_password_reset_revokes_old_token_and_password(self):
        token = self.token()
        self.record.update(password_hash=self.replacement, auth_version=4)
        self.assertEqual(self.request(token).status_code, 401)
        self.assertEqual(self.login().status_code, 401)
        result = self.login("fixture-password-after")
        self.assertEqual(result.status_code, 200)
        self.assertEqual(self.request(result.json()["access_token"]).status_code, 200)

    def test_role_scope_and_global_changes_with_atomic_version_revoke(self):
        for changes in ({"role": "viewer"}, {"store_ids": ["S1"]}, {"global_access": False}):
            with self.subTest(changes=changes):
                token = self.token()
                self.record.update(**changes, auth_version=self.record["auth_version"] + 1)
                self.assertEqual(self.request(token).status_code, 401)
                fresh = self.login().json()["access_token"]
                self.assertEqual(self.request(fresh).status_code, 200)

    def test_deactivation_and_reactivation_cannot_restore_old_token(self):
        token = self.token()
        self.record.update(is_active=False, auth_version=4)
        self.assertEqual(self.request(token).status_code, 401)
        self.assertEqual(self.login().status_code, 401)
        self.record.update(is_active=True, auth_version=5)
        self.assertEqual(self.request(token).status_code, 401)
        self.assertEqual(self.request(self.login().json()["access_token"]).status_code, 200)

    def test_version_reload_occurs_on_every_protected_request(self):
        token = self.token()
        self.assertEqual(self.request(token, "/management-check").status_code, 200)
        self.record["auth_version"] += 1
        self.assertEqual(self.request(token, "/management-check").status_code, 401)
        self.assertEqual(len(self.repository.reads), 2)

    def test_reset_between_authentication_and_signing_cannot_upgrade_snapshot(self):
        principal = self.service.authenticate(self.repository, "fixtureuser", "fixture-password-before")
        self.record.update(password_hash=self.replacement, auth_version=4)
        token = self.service.create_token(principal)
        self.assertEqual(self.claims(token)["auth_version"], 3)
        self.assertEqual(self.request(token).status_code, 401)
        self.assertEqual(self.repository.reads[0], ("username", "fixtureuser"))

    def test_concurrent_reset_during_password_verification_uses_original_snapshot(self):
        entered, release = Event(), Event()
        original_verify = self.service.verify_password

        def paused_verify(password, encoded):
            entered.set()
            if not release.wait(5):
                raise AssertionError("Fixture verification was not released")
            return original_verify(password, encoded)

        with patch.object(self.service, "verify_password", side_effect=paused_verify):
            with ThreadPoolExecutor(max_workers=1) as pool:
                future = pool.submit(self.service.authenticate, self.repository,
                                     "fixtureuser", "fixture-password-before")
                try:
                    self.assertTrue(entered.wait(5))
                    # Deliberately mutate the SAME fake mapping while hashing is
                    # pending: lookup must detach it before verification starts.
                    self.record.update(password_hash=self.replacement, auth_version=4,
                                       role="viewer", global_access=False, store_ids=["S2"])
                finally:
                    release.set()
                principal = future.result(timeout=5)
        token = self.service.create_token(principal)
        self.assertEqual(self.claims(token)["auth_version"], 3)
        self.assertEqual(principal.role, "admin")
        self.assertEqual(principal.store_ids, ())
        self.assertEqual(self.request(token).status_code, 401)

    def test_plain_public_principal_cannot_invent_version_for_token_issuance(self):
        public = InventoryPrincipal.model_validate(self.service.principal(self.record).model_dump())
        with self.assertRaises(HTTPException) as caught:
            self.service.create_token(public)
        self.assertEqual(caught.exception.status_code, 401)

    def test_login_and_management_validation_do_not_mutate_repository(self):
        before = copy.deepcopy(self.record)
        token = self.login().json()["access_token"]
        self.assertEqual(self.request(token, "/management-check").status_code, 200)
        self.assertEqual(before, self.record)
        self.assertEqual([item[0] for item in self.repository.reads], ["username", "id"])


if __name__ == "__main__":
    unittest.main()
