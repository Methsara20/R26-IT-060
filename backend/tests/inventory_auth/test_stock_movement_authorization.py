"""Real movement functions with fake IO; never import shared main or AI services."""
import ast
import copy
import importlib.util
import socket
import sys
import types
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import Mock, patch

import jwt
from bson import ObjectId
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.constants import collections
from app.services.inventory_auth_service import (
    InventoryAuthService, InventoryJWTSettings, LoginThrottle, get_inventory_auth_service,
)
from app.services.inventory_user_service import (
    canonical_user_id, get_inventory_user_repository,
)

BACKEND = Path(__file__).resolve().parents[2]


class FakeUsers:
    def __init__(self, user):
        self.user = user

    def find_by_username(self, username):
        return self.user if username == self.user["username_normalized"] else None

    def find_by_id(self, user_id):
        return self.user if canonical_user_id(self.user["_id"]) == user_id else None


class StockMovementAuthorizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.auth = InventoryAuthService(
            InventoryJWTSettings(secret="test-only-stock-movement-signing-key-000000-000000")
        )

    def setUp(self):
        self.network = patch.object(socket, "create_connection", side_effect=AssertionError("Network forbidden"))
        self.network.start()
        self.addCleanup(self.network.stop)
        self.mongo = patch("pymongo.MongoClient", side_effect=AssertionError("Mongo forbidden"))
        self.mongo.start()
        self.addCleanup(self.mongo.stop)
        self.auth.throttle = LoginThrottle()
        self.user = {
            "_id": ObjectId("0123456789abcdef01234567"),
            "username_normalized": "teststaff", "display_name": "Test Staff",
            "role": "admin", "store_ids": ["SOURCE", "TARGET", "ALT"],
            "global_access": False, "is_active": True,
        }
        self.mov = {
            "id": "M1", "movement_id": "M1", "candidate_id": "C1",
            "movement_type": "TRANSFER", "movement_status": "RECOMMENDED",
            "from_store": "SOURCE", "to_store": "TARGET", "product_id": "P1",
            "recommended_qty": 15, "is_executed": False,
            "alternative_sources": ["ALT"],
            "evaluated_sources": [{"store_id": "SOURCE"}, {"store_id": "ALT"}],
            "status_history": [],
        }
        self.candidate = {
            "id": "C1", "product_id": "P1", "store_id": "TARGET",
            "current_stock": 5, "reorder_level": 20, "max_stock": 100,
            "shortage_qty": 15, "recommended_action": "TRANSFER",
            "transfer_ready": True, "priority": "HIGH",
            "qualified_source_details": [
                {"store_id": "SOURCE", "current_stock": 60, "reorder_level": 20,
                 "surplus_qty": 40, "possible_transfer_qty": 15, "stock_after_transfer": 45}
            ],
        }
        self.records = {
            collections.STOCK_MOVEMENTS_COLLECTION: {"M1": self.mov},
            collections.OPTIMIZATION_CANDIDATES_COLLECTION: {"C1": self.candidate},
            collections.INVENTORY_COLLECTION: {
                "IS": {"id": "IS", "store_id": "SOURCE", "product_id": "P1", "current_stock": 60, "reorder_level": 20},
                "IT": {"id": "IT", "store_id": "TARGET", "product_id": "P1", "current_stock": 5, "reorder_level": 20},
            },
            collections.INVENTORY_TRANSACTIONS_COLLECTION: {},
        }
        self.writes = []
        self.ai = []
        service = types.ModuleType("app.services.stock_movement_service")
        service.__dict__.update(vars(collections))
        source = (BACKEND / "app/services/stock_movement_service.py").read_text()
        tree = ast.parse(source)
        allowed = []
        for node in tree.body:
            if isinstance(node, (ast.Import, ast.ImportFrom)):
                if isinstance(node, ast.ImportFrom) and (
                    node.module in ("datetime", "typing", "app.schemas.inventory_auth_schema")
                    or node.module.startswith("app.security.")
                ):
                    allowed.append(node)
            else:
                allowed.append(node)
        exec(compile(ast.Module(body=allowed, type_ignores=[]), "isolated-stock-service", "exec"), service.__dict__)
        service.get_document_by_id = lambda col, ident: copy.deepcopy(self.records.get(col, {}).get(ident))
        service.get_all_documents = lambda col: copy.deepcopy(list(self.records.get(col, {}).values()))
        def update(col, ident, data):
            self.writes.append(("update", col, ident, copy.deepcopy(data)))
            if ident not in self.records.get(col, {}):
                return None
            self.records[col][ident].update(copy.deepcopy(data))
            return {"message": "updated"}
        def create(col, ident, data, merge=True):
            self.writes.append(("create", col, ident, copy.deepcopy(data)))
            self.records.setdefault(col, {})[ident] = copy.deepcopy(data)
            return {"message": "created"}
        service.update_document = update
        service.create_or_update_document = create
        service.get_inventory_by_store_and_product = lambda store, product: next(
            (copy.deepcopy(item) for item in self.records[collections.INVENTORY_COLLECTION].values()
             if item["store_id"] == store and item["product_id"] == product), None
        )
        service.refresh_summaries_after_inventory_update = Mock()
        service.update_optimization_candidate = Mock()
        service.clear_inventory_cache = Mock()
        service.get_route_information = lambda *args: {
            "distance_km": 5, "estimated_transfer_cost": 500, "estimated_time_minutes": 10,
        }
        service.generate_and_save_recommendation_explanation = Mock(side_effect=lambda *a, **k: self.ai.append("recommend"))
        service.generate_and_save_execution_summary = Mock(side_effect=lambda *a, **k: self.ai.append("execute"))
        explanations = types.ModuleType("app.services.explanation_service")
        for name in (
            "generate_stock_movement_explanation", "generate_execution_summary",
            "generate_intelligent_recommendation_explanation", "generate_intelligent_execution_summary",
            "build_stock_movement_explanation_context",
        ):
            setattr(explanations, name, Mock(side_effect=lambda *a, **k: self.ai.append("route") or "safe explanation"))
        spec = importlib.util.spec_from_file_location(
            "isolated_stock_movement_routes", BACKEND / "app/routes/stock_movement_routes.py"
        )
        routes = importlib.util.module_from_spec(spec)
        with patch.dict(sys.modules, {
            "app.services.stock_movement_service": service,
            "app.services.explanation_service": explanations,
        }):
            spec.loader.exec_module(routes)
        self.service, self.routes = service, routes
        self.app = FastAPI()
        self.app.include_router(routes.router)
        self.app.dependency_overrides[get_inventory_auth_service] = lambda: self.auth
        self.app.dependency_overrides[get_inventory_user_repository] = lambda: FakeUsers(self.user)
        self.client = TestClient(self.app)
        self.addCleanup(self.client.close)

    def headers(self):
        return {"Authorization": "Bearer " + self.auth.create_token(self.auth.principal(self.user))}

    def request(self, path, method="GET", body=None, headers=None):
        return self.client.request(method, "/stock-movement" + path, json=body,
                                   headers=self.headers() if headers is None else headers)

    def assert_no_effects(self):
        self.assertEqual(self.writes, [])
        self.assertEqual(self.ai, [])

    def test_missing_jwt_all_routes(self):
        for route in self.routes.router.routes:
            method = next(iter(route.methods))
            response = self.client.request(method, route.path.replace("{movement_id}", "M1").replace("{candidate_id}", "C1"), json={}, headers={})
            self.assertEqual(response.status_code, 401)
        self.assert_no_effects()

    def test_invalid_expired_customer_jwt(self):
        claims = jwt.decode(self.headers()["Authorization"].split()[1], options={"verify_signature": False})
        now = int(datetime.now(timezone.utc).timestamp())
        tokens = ["invalid"] + [
            jwt.encode({**claims, **changes}, self.auth.settings.secret, algorithm="HS256")
            for changes in [
                {"iat": now-1000, "nbf": now-1000, "exp": now-100},
                {"iss": "customer", "aud": "customer-api", "purpose": "customer_access"},
            ]
        ]
        for token in tokens:
            self.assertEqual(self.request("/approve/M1", "POST", {}, {"Authorization": "Bearer " + token}).status_code, 401)
        self.assert_no_effects()

    def test_inactive_and_current_role(self):
        headers = self.headers()
        self.user["is_active"] = False
        self.assertEqual(self.request("/approve/M1", "POST", {}, headers).status_code, 401)
        self.user["is_active"] = True
        self.user["role"] = "viewer"
        self.assertEqual(self.request("/approve/M1", "POST", {}, headers).status_code, 403)
        self.assert_no_effects()

    def test_role_matrix(self):
        from app.security.inventory_permissions import STOCK_MOVEMENT_ROLES
        paths = {
            "read": ("/M1", "GET"), "recommend": ("/recommend-transfer/C1", "POST"),
            "approve": ("/approve/M1", "POST"), "reject": ("/reject/M1", "POST"),
            "cancel": ("/cancel/M1", "POST"), "execute": ("/execute/M1", "POST"),
            "explain": ("/explain/M1", "POST"), "summary": ("/execution-summary/M1", "POST"),
        }
        for role in ("admin", "manager", "analyst", "operator", "viewer"):
            for operation, (path, method) in paths.items():
                with self.subTest(role=role, operation=operation):
                    self.user["role"] = role
                    self.mov["movement_status"] = "APPROVED" if operation == "execute" else "RECOMMENDED"
                    self.mov["is_executed"] = False
                    self.writes.clear()
                    self.ai.clear()
                    response = self.request(path, method, {} if method == "POST" else None)
                    if role in STOCK_MOVEMENT_ROLES[operation]:
                        self.assertEqual(response.status_code, 200, response.text)
                    else:
                        self.assertEqual(response.status_code, 403)
                        self.assert_no_effects()
                    # Restore balances and movement identity for the next scenario.
                    self.records[collections.INVENTORY_COLLECTION]["IS"]["current_stock"] = 60
                    self.records[collections.INVENTORY_COLLECTION]["IT"]["current_stock"] = 5

    def test_unauthorized_source_destination_and_alternative(self):
        for stores in (["TARGET", "ALT"], ["SOURCE", "ALT"], ["SOURCE", "TARGET"]):
            self.user["store_ids"] = stores
            for path, method in [
                ("/M1", "GET"), ("/approve/M1", "POST"), ("/reject/M1", "POST"),
                ("/cancel/M1", "POST"), ("/execute/M1", "POST"),
                ("/explain/M1", "POST"), ("/execution-summary/M1", "POST"),
                ("/explain-context/M1", "GET"),
            ]:
                self.assertEqual(self.request(path, method, {} if method == "POST" else None).status_code, 403)
        self.assert_no_effects()

    def test_manager_participant_visibility_and_unrelated_denial(self):
        self.mov.update(recommended_by="other-admin", approved_by="other-manager",
                        ai_explanation="Private ALT donor", ai_explanation_context={"store_id": "ALT"})
        original = copy.deepcopy(self.mov)
        self.user["role"] = "manager"
        for stores in (["SOURCE"], ["TARGET"], ["SOURCE", "TARGET"], ["OTHER"]):
            with self.subTest(stores=stores):
                self.user["store_ids"] = stores
                allowed = stores != ["OTHER"]
                response = self.request("/")
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json()["count"], int(allowed))
                detail = self.request("/M1")
                self.assertEqual(detail.status_code, 200 if allowed else 403)
                if allowed:
                    self.assertEqual(response.json()["movements"][0], detail.json())
                    self.assertEqual(detail.json()["recommended_by"], "other-admin")
                    self.assertNotIn("ALT", detail.text)
                    self.assertIsNone(detail.json()["ai_explanation"])
                    self.assertEqual(detail.json()["status_history"], original["status_history"])
                    self.assertEqual(self.request("/approve/M1", "POST", {}).status_code, 403)
        self.assertEqual(self.mov, original)
        self.assert_no_effects()

    def test_manager_ambiguous_legacy_scope_denied(self):
        self.user.update(role="manager", store_ids=["SOURCE"])
        for changes in ({"to_store": None}, {"from_store": " SOURCE"},
                        {"to_store": "SOURCE"}, {"source_store_id": "OTHER"},
                        {"target_store_id": "OTHER"}):
            original = copy.deepcopy(self.mov)
            self.mov.update(changes)
            self.assertEqual(self.request("/M1").status_code, 403)
            self.assertEqual(self.request("/").json()["count"], 0)
            self.mov.clear()
            self.mov.update(original)
        self.assert_no_effects()

    def test_admin_requires_explicit_global_for_unrelated_movement(self):
        self.user.update(role="admin", store_ids=[])
        self.assertEqual(self.request("/M1").status_code, 403)
        self.assertEqual(self.request("/").json()["count"], 0)
        self.user["global_access"] = True
        self.assertEqual(self.request("/M1").status_code, 200)
        self.assertEqual(self.request("/").json()["count"], 1)
        self.assert_no_effects()

    def test_denied_recommendation_zero_effects(self):
        for stores in (["TARGET"], ["SOURCE"]):
            self.user["store_ids"] = stores
            self.assertEqual(self.request("/recommend-transfer/C1", "POST", {}).status_code, 403)
        self.assert_no_effects()

    def test_candidate_unknown_or_malformed(self):
        self.assertEqual(self.request("/recommend-transfer/missing", "POST", {}).status_code, 404)
        self.candidate["qualified_source_details"] = [{"current_stock": 60}]
        self.assertEqual(self.request("/recommend-transfer/C1", "POST", {}).status_code, 403)
        self.assert_no_effects()

    def test_filtered_lists_and_counts(self):
        self.records[collections.STOCK_MOVEMENTS_COLLECTION]["M2"] = {
            **self.mov, "movement_id": "M2", "from_store": "HIDDEN",
        }
        self.records[collections.STOCK_MOVEMENTS_COLLECTION]["M3"] = {
            **self.mov, "movement_id": "M3", "to_store": None,
        }
        response = self.request("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["count"], 1)
        self.assertEqual([m["movement_id"] for m in response.json()["movements"]], ["M1"])
        self.assertNotIn("HIDDEN", response.text)
        self.assert_no_effects()

    def test_unauthorized_id_and_missing_id(self):
        self.mov["to_store"] = "HIDDEN"
        self.assertEqual(self.request("/M1").status_code, 403)
        self.assertEqual(self.request("/missing").status_code, 404)
        self.assert_no_effects()

    def test_duplicate_routes_preserved_and_protected(self):
        for suffix, operation in (("/explain/{movement_id}", "explain"), ("/execution-summary/{movement_id}", "summary")):
            duplicates = [r for r in self.routes.router.routes if r.path.endswith(suffix)]
            self.assertEqual(len(duplicates), 2)
            for route in duplicates:
                app = FastAPI()
                app.add_api_route(route.path, route.endpoint, methods=["POST"])
                app.dependency_overrides.update(self.app.dependency_overrides)
                with TestClient(app) as client:
                    self.user["role"] = "viewer"
                    response = client.post(route.path.replace("{movement_id}", "M1"), headers=self.headers())
                    self.assertEqual(response.status_code, 403)
                    self.user["role"] = "manager"
                    self.user["store_ids"] = ["TARGET"]
                    response = client.post(route.path.replace("{movement_id}", "M1"), headers=self.headers())
                    self.assertEqual(response.status_code, 403)
                self.user["store_ids"] = ["SOURCE", "TARGET", "ALT"]
        self.assert_no_effects()

    def assert_snapshot(self, event):
        self.assertEqual(event["actor_id"], canonical_user_id(self.user["_id"]))
        self.assertEqual(event["actor_username_snapshot"], self.user["username_normalized"])
        self.assertEqual(event["actor_display_name_snapshot"], self.user["display_name"])
        self.assertEqual(event["actor_role_snapshot"], self.user["role"])
        self.assertTrue(event["time"])

    def test_forged_actor_ignored_and_actor_persisted(self):
        response = self.request("/approve/M1", "POST", {
            "approved_by": "forged", "from_store": "forged", "to_store": "forged",
            "actor_username_snapshot": "forged", "actor_display_name_snapshot": "forged", "actor_role_snapshot": "viewer",
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["approved_by"], canonical_user_id(self.user["_id"]))
        self.assert_snapshot(response.json()["status_history"][-1])

    def test_execution_preserves_inventory_math_and_logs_actor(self):
        self.user["role"] = "operator"
        self.mov["movement_status"] = "APPROVED"
        response = self.request("/execute/M1", "POST", {"executed_by": "forged"})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["movement_status"], "EXECUTED")
        for event in response.json()["status_history"]: self.assert_snapshot(event)
        self.assertEqual(self.records[collections.INVENTORY_COLLECTION]["IS"]["current_stock"], 45)
        self.assertEqual(self.records[collections.INVENTORY_COLLECTION]["IT"]["current_stock"], 20)
        transactions = list(self.records[collections.INVENTORY_TRANSACTIONS_COLLECTION].values())
        self.assertEqual(len(transactions), 1)
        self.assertEqual(transactions[0]["executed_by"], canonical_user_id(self.user["_id"]))

    def test_recommendation_actor_and_quantity(self):
        response = self.request("/recommend-transfer/C1", "POST", {"actor_id": "forged"})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["recommended_qty"], 15)
        self.assertIsNone(response.json()["executed_by"])
        self.assertIsNone(response.json()["cancelled_by"])
        self.assertEqual(response.json()["from_store"], "SOURCE")
        self.assertEqual(response.json()["recommended_by"], canonical_user_id(self.user["_id"]))
        self.assert_snapshot(response.json()["status_history"][0])

    def test_failure_event_snapshot_and_legacy_history_preserved(self):
        legacy = {"status": "RECOMMENDED", "time": "old", "actor_id": "legacy"}
        self.mov["status_history"] = [copy.deepcopy(legacy)]
        self.mov["movement_status"] = "APPROVED"
        original = self.service.update_document
        def fail_inventory(col, ident, data):
            if col == collections.INVENTORY_COLLECTION:
                raise RuntimeError("mock failure")
            return original(col, ident, data)
        with patch.object(self.service, "update_document", side_effect=fail_inventory):
            response = self.request("/execute/M1", "POST", {})
        self.assertEqual(response.status_code, 400)
        stored = self.records[collections.STOCK_MOVEMENTS_COLLECTION]["M1"]
        self.assertEqual(stored["status_history"][0], legacy)
        self.assertEqual(stored["status_history"][-1]["status"], "FAILED")
        self.assert_snapshot(stored["status_history"][-1])

    def test_missing_and_malformed_principals_fail_before_effects(self):
        from fastapi import HTTPException
        valid = self.auth.principal(self.user)
        for principal in (None, {}, valid.model_copy(update={"display_name": ""}),
                          valid.model_copy(update={"role": "forged"}),
                          valid.model_copy(update={"user_id": "invalid"})):
            for method in ("recommend_transfer", "approve_movement", "reject_movement", "cancel_movement", "execute_movement"):
                with self.assertRaises(HTTPException):
                    getattr(self.service, method)("M1", user=principal)
                self.assert_no_effects()

    def test_recheck_scope_in_service(self):
        user = self.auth.principal(self.user)
        self.mov["to_store"] = "HIDDEN"
        from fastapi import HTTPException
        with self.assertRaises(HTTPException):
            self.service.approve_movement("M1", user=user)
        self.assert_no_effects()

    def test_execution_still_requires_approval(self):
        self.user["role"] = "operator"
        response = self.request("/execute/M1", "POST", {})
        self.assertEqual(response.status_code, 400)
        self.assert_no_effects()

    def test_global_permission_is_explicit(self):
        self.mov["to_store"] = "HIDDEN"
        self.assertEqual(self.request("/M1").status_code, 403)
        self.user["global_access"] = True
        self.assertEqual(self.request("/M1").status_code, 200)


    def test_store_permissions_reloaded_after_token_issue(self):
        headers = self.headers()
        self.user["store_ids"] = ["SOURCE", "ALT"]
        response = self.request("/approve/M1", "POST", {}, headers)
        self.assertEqual(response.status_code, 403)
        self.assert_no_effects()

    def test_reject_and_cancel_audit_actors(self):
        for operation, field in (("reject", "rejected_by"), ("cancel", "cancelled_by")):
            self.mov["movement_status"] = "RECOMMENDED"
            response = self.request("/" + operation + "/M1", "POST", {field: "forged"})
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()[field], canonical_user_id(self.user["_id"]))
            self.assert_snapshot(response.json()["status_history"][-1])

    def test_malformed_or_unauthorized_donor_details_fail_closed(self):
        for details in ("malformed", [{"current_stock": 100}], [{"store_id": "HIDDEN", "current_stock": 100}]):
            self.mov["evaluated_sources"] = details
            self.assertEqual(self.request("/M1").status_code, 403)
            self.assertEqual(self.request("/explain/M1", "POST", {}).status_code, 403)
        self.assert_no_effects()

if __name__ == "__main__":
    unittest.main()
