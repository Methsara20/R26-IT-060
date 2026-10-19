"""Fake-wrapper integration tests: no shared main or real database import."""
import copy
import importlib
import socket
import sys
import types
import unittest
from unittest.mock import Mock, patch

import jwt
from bson import ObjectId
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.mongo_client import MongoFirestoreClient
from app.routes.inventory_auth_routes import router
from app.services.inventory_auth_dependencies import (
    configure_inventory_auth_dependencies, get_existing_inventory_mongo_wrapper,
    get_inventory_mongo_repository,
)
from app.services.inventory_auth_service import (
    InventoryAuthService, InventoryJWTSettings, LoginThrottle, get_inventory_auth_service,
)
from app.services.inventory_user_service import (
    canonical_user_id, get_inventory_user_repository,
)


class FakeCursor:
    def __init__(self, records):
        self.records = records

    def limit(self, count):
        return self.records[:count]


class FakeCollection:
    name = "inventory_users"

    def __init__(self, database, records):
        self.database = database
        self.records = records
        self.calls = []
        self.failure = None

    def find(self, query):
        self.calls.append(("find", query))
        if self.failure:
            raise self.failure
        return FakeCursor([
            record for record in self.records
            if record.get("username_normalized") == query["username_normalized"]
        ])

    def find_one(self, query):
        self.calls.append(("find_one", query))
        if self.failure:
            raise self.failure
        return next((r for r in self.records if r.get("_id") == query["_id"]), None)


class FakeDatabase:
    name = "smart_retail_db"

    def __init__(self, client, records):
        self.client = client
        self.accessed = []
        self.inventory = FakeCollection(self, records)

    def get_collection(self, name):
        if name != "inventory_users":
            raise AssertionError("Other collections are forbidden.")
        self.accessed.append(name)
        return self.inventory


class FakeWrapper(MongoFirestoreClient):
    def __init__(self, records):
        # Deliberately bypass parent constructor: no MongoClient.
        self.client = object()
        self.db = FakeDatabase(self.client, records)


class InventoryMongoIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.service = InventoryAuthService(
            InventoryJWTSettings(secret="test-only-integration-signing-key-000000-000000")
        )
        cls.password_hash = cls.service.hash_password("test-only-password")

    def setUp(self):
        self.client_guard = patch(
            "pymongo.MongoClient", side_effect=AssertionError("MongoClient forbidden")
        )
        self.mongo_constructor = self.client_guard.start()
        self.addCleanup(self.client_guard.stop)
        self.network_guard = patch.object(
            socket, "create_connection", side_effect=AssertionError("Network forbidden")
        )
        self.network_guard.start()
        self.addCleanup(self.network_guard.stop)
        self.service.throttle = LoginThrottle()
        self.user = {
            "_id": ObjectId("0123456789abcdef01234567"),
            "username_normalized": "inventorytest",
            "display_name": "Inventory Test",
            "password_hash": self.password_hash,
            "role": "manager", "store_ids": ["CP001"],
            "global_access": False, "is_active": True,
        }
        self.wrapper = FakeWrapper([self.user])
        self.configuration = types.ModuleType("app.firebase_config")
        self.configuration.db_type = "mongodb"
        self.configuration.db = self.wrapper
        self.module_guard = patch.dict(
            sys.modules, {"app.firebase_config": self.configuration}
        )
        self.module_guard.start()
        self.addCleanup(self.module_guard.stop)
        self.app = FastAPI()
        configure_inventory_auth_dependencies(self.app)
        self.app.include_router(router)
        self.app.dependency_overrides[get_inventory_auth_service] = lambda: self.service
        self.client = TestClient(self.app)
        self.addCleanup(self.client.close)

    def login(self):
        return self.client.post(
            "/inventory-auth/login",
            json={"username": " INVENTORYTEST ", "password": "test-only-password"},
        )

    def headers(self):
        return {"Authorization": "Bearer " + self.service.create_token(
            self.service.principal(self.user)
        )}

    def test_existing_wrapper_is_reused(self):
        self.assertIs(get_existing_inventory_mongo_wrapper(), self.wrapper)
        repository = get_inventory_mongo_repository(self.wrapper)
        self.assertIs(repository._collection, self.wrapper.db.inventory)
        self.mongo_constructor.assert_not_called()

    def test_login_and_me_only_inventory_reads(self):
        before = copy.deepcopy(self.user)
        response = self.login()
        self.assertEqual(response.status_code, 200)
        token = response.json()["access_token"]
        response = self.client.get(
            "/inventory-auth/me", headers={"Authorization": "Bearer " + token}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.wrapper.db.accessed, ["inventory_users", "inventory_users"])
        self.assertEqual(
            self.wrapper.db.inventory.calls,
            [("find", {"username_normalized": "inventorytest"}),
             ("find_one", {"_id": self.user["_id"]})],
        )
        self.assertEqual(before, self.user)
        self.mongo_constructor.assert_not_called()

    def test_current_active_state(self):
        headers = self.headers()
        self.user["is_active"] = False
        self.assertEqual(
            self.client.get("/inventory-auth/me", headers=headers).status_code, 401
        )

    def test_current_permissions_reload(self):
        headers = self.headers()
        self.user["role"] = "viewer"
        self.user["store_ids"] = ["CP002"]
        response = self.client.get("/inventory-auth/me", headers=headers)
        self.assertEqual(response.json()["role"], "viewer")
        self.assertEqual(response.json()["store_ids"], ["CP002"])

    def test_duplicate_username_rejected(self):
        self.wrapper.db.inventory.records.append(
            {**self.user, "_id": ObjectId("1123456789abcdef01234567")}
        )
        self.assertEqual(self.login().status_code, 401)

    def test_objectid_exact_lookup(self):
        repository = get_inventory_mongo_repository(self.wrapper)
        self.assertIs(
            repository.find_by_id(canonical_user_id(self.user["_id"])), self.user
        )
        self.assertEqual(
            self.wrapper.db.inventory.calls[-1],
            ("find_one", {"_id": self.user["_id"]}),
        )

    def test_missing_configuration_does_not_initialize(self):
        with patch.dict(sys.modules):
            sys.modules.pop("app.firebase_config", None)
            response = self.login()
        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json()["detail"], "Inventory authentication is unavailable."
        )
        self.assertEqual(self.wrapper.db.accessed, [])
        self.mongo_constructor.assert_not_called()

    def test_wrong_backend_or_wrapper(self):
        self.configuration.db_type = "firebase"
        self.assertEqual(self.login().status_code, 503)
        self.configuration.db_type = "mongodb"
        self.configuration.db = object()
        self.assertEqual(self.login().status_code, 503)
        self.assertEqual(self.wrapper.db.accessed, [])

    def test_wrong_database_name(self):
        self.wrapper.db.name = "other_database"
        self.assertEqual(self.login().status_code, 503)
        self.assertEqual(self.wrapper.db.accessed, [])

    def test_wrong_client_rejected(self):
        self.wrapper.db.client = object()
        self.assertEqual(self.login().status_code, 503)
        self.assertEqual(self.wrapper.db.accessed, [])

    def test_unavailable_mongo_read_is_sanitized(self):
        self.wrapper.db.inventory.failure = RuntimeError("private-connection-details")
        response = self.login()
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("private-connection-details", response.text)

    def test_collection_handle_error_is_sanitized(self):
        self.wrapper.db.get_collection = Mock(
            side_effect=RuntimeError("private-collection-details")
        )
        response = self.login()
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("private-collection-details", response.text)

    def test_wiring_is_lazy_and_inventory_only(self):
        app = FastAPI()
        unrelated = lambda: None
        other = lambda: "unchanged"
        app.dependency_overrides[unrelated] = other
        configure_inventory_auth_dependencies(app)
        configure_inventory_auth_dependencies(app)
        self.assertIs(app.dependency_overrides[unrelated], other)
        self.assertEqual(len(app.dependency_overrides), 2)
        self.assertEqual(self.wrapper.db.accessed, [])
        self.mongo_constructor.assert_not_called()

    def test_custom_override_is_not_overwritten(self):
        app = FastAPI()
        original = lambda: None
        app.dependency_overrides[get_inventory_user_repository] = original
        with self.assertRaises(RuntimeError):
            configure_inventory_auth_dependencies(app)
        self.assertIs(app.dependency_overrides[get_inventory_user_repository], original)

    def test_customer_tokens_rejected_even_with_inventory_key(self):
        claims = jwt.decode(
            self.headers()["Authorization"].split(" ", 1)[1],
            options={"verify_signature": False},
        )
        for changes in [
            {"iss": "customer-auth"}, {"aud": "customer-api"},
            {"purpose": "customer_access"},
        ]:
            token = jwt.encode(
                {**claims, **changes}, self.service.settings.secret, algorithm="HS256"
            )
            response = self.client.get(
                "/inventory-auth/me", headers={"Authorization": "Bearer " + token}
            )
            self.assertEqual(response.status_code, 401)

    def test_inventory_token_has_inventory_only_claims(self):
        token = self.headers()["Authorization"].split(" ", 1)[1]
        claims = jwt.decode(
            token, self.service.settings.secret, algorithms=["HS256"],
            audience="inventory-api", issuer="smart-inventory",
        )
        self.assertEqual(claims["purpose"], "inventory_access")
        with self.assertRaises(jwt.InvalidTokenError):
            jwt.decode(
                token, self.service.settings.secret, algorithms=["HS256"],
                audience="customer-api", issuer="customer-auth",
            )

    def test_import_wiring_does_not_initialize_configuration(self):
        with patch.dict(sys.modules):
            sys.modules.pop("app.firebase_config", None)
            import app.services.inventory_auth_dependencies as dependencies
            importlib.reload(dependencies)
            self.assertNotIn("app.firebase_config", sys.modules)
        self.mongo_constructor.assert_not_called()


if __name__ == "__main__":
    unittest.main()
