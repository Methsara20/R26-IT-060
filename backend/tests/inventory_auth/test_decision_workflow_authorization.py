"""Isolated workflow security tests; imports cannot initialize DB/models/AI."""
import copy
import importlib.util
import sys
import types
import unittest
from functools import lru_cache
from pathlib import Path
from unittest.mock import Mock, patch

import jwt
from bson import ObjectId
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pymongo.errors import DuplicateKeyError
from app.services.inventory_auth_service import InventoryAuthService, InventoryJWTSettings, get_inventory_auth_service
from app.services.inventory_user_service import get_inventory_user_repository, canonical_user_id
from app.security.inventory_resource_access import VerifiedWorkflowUser
from app.schemas.decision_workflow_schema import DecisionWorkflowRequest

ROOT = Path(__file__).resolve().parents[2]

@lru_cache(maxsize=1)
def auth():
    return InventoryAuthService(InventoryJWTSettings(secret="isolated-workflow-test-key-000000000000000000"))

class Users:
    def __init__(self, record): self.record = record
    def find_by_id(self, identity):
        return self.record if canonical_user_id(self.record["_id"]) == identity else None

def record(role="admin", global_access=True, stores=("S1", "S2"), identity="0123456789abcdef01234567"):
    return {"_id": ObjectId(identity), "username_normalized": "fixture", "display_name": "Fixture",
            "role": role, "global_access": global_access, "store_ids": list(stores), "is_active": True}

def verified_user(**kwargs):
    user = record(**kwargs)
    return VerifiedWorkflowUser(auth().create_token(auth().principal(user)), auth(), Users(user))

def load_workflow_modules():
    """Load real workflow code with every expensive imported dependency replaced."""
    modules = {}
    def fake(name, **attrs):
        module = types.ModuleType(name)
        module.__dict__.update(attrs)
        modules[name] = module
        return module
    def forbidden(*args, **kwargs): raise AssertionError("Unmocked external dependency")
    for name in ["google", "google.api_core", "google.cloud", "google.cloud.firestore_v1"]:
        fake(name)
    fake("google.api_core.exceptions", AlreadyExists=type("AlreadyExists", (Exception,), {}),
         ResourceExhausted=type("ResourceExhausted", (Exception,), {}))
    fake("google.cloud.firestore_v1.base_query", FieldFilter=lambda *args: args)
    for name, funcs in {
        "daily_forecast_service": ["generate_7_day_forecast", "generate_custom_forecast", "predict_next_day"],
        "decision_engine_service": ["analyze_candidate"],
        "firebase_service": ["create_or_update_document", "get_collection", "get_document_by_id"],
        "product_service": ["get_product_by_id"],
        "stock_movement_service": ["get_stock_movement_by_id", "recommend_transfer"],
        "store_service": ["get_store_by_id"],
    }.items():
        fake("app.services." + name, **{f: Mock(side_effect=forbidden) for f in funcs})
    def load(name, path):
        spec = importlib.util.spec_from_file_location(name, ROOT / path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    with patch.dict(sys.modules, modules):
        service = load("isolated_workflow_service", "app/services/decision_workflow_service.py")
        with patch.dict(sys.modules, {"app.services.decision_workflow_service": service}):
            routes = load("isolated_workflow_routes", "app/routes/decision_workflow_routes.py")
    return service, routes

class WorkflowAuthorizationTests(unittest.TestCase):
    def setUp(self):
        for target in ["socket.create_connection", "pymongo.MongoClient"]:
            guard = patch(target, side_effect=AssertionError("Real network forbidden"))
            guard.start(); self.addCleanup(guard.stop)
        self.service, self.routes = load_workflow_modules()
        self.record = record()
        app = FastAPI()
        app.include_router(self.routes.router)
        app.dependency_overrides[get_inventory_auth_service] = auth
        app.dependency_overrides[get_inventory_user_repository] = lambda: Users(self.record)
        self.client = TestClient(app)
        self.addCleanup(self.client.close)
        self.request = DecisionWorkflowRequest(forecast_type="DAILY", store_id="S1", product_id="P1", selling_price=10, idempotency_key="workflow-fixture-key")

    def headers(self, **claims):
        token = auth().create_token(auth().principal(self.record))
        if claims:
            data = jwt.decode(token, options={"verify_signature": False})
            data.update(claims)
            token = jwt.encode(data, auth().settings.secret, algorithm="HS256")
        return {"Authorization": "Bearer " + token}

    def workflow(self, **changes):
        return {**self.service._request_identity(self.request), "workflow_id": "WF-TEST", "workflow_status": "NO_ACTION_REQUIRED", "next_action": "NONE", "created_at": "2026-01-01", "updated_at": "2026-01-01", "actor_id": canonical_user_id(self.record["_id"]), **changes}

    def assert_no_effects(self):
        for name in ["get_collection", "get_store_by_id", "get_product_by_id", "create_or_update_document", "predict_next_day", "generate_7_day_forecast", "generate_custom_forecast", "analyze_candidate", "recommend_transfer"]:
            getattr(self.service, name).assert_not_called()

    def test_all_endpoints_reject_missing_invalid_expired_and_customer_tokens(self):
        for headers in [{}, {"Authorization": "Bearer invalid"}, self.headers(exp=1), self.headers(purpose="customer_access"), self.headers(aud="customer-api")]:
            for path in ["/decision-workflow/", "/decision-workflow/WF-TEST", "/decision-workflow/analyze"]:
                with self.subTest(path=path, kind=bool(headers)):
                    response = self.client.post(path, json=self.request.model_dump(mode="json"), headers=headers) if path.endswith("analyze") else self.client.get(path, headers=headers)
                    self.assertEqual(response.status_code, 401)
        self.assert_no_effects()

    def test_inactive_account_reloaded(self):
        headers = self.headers()
        self.record["is_active"] = False
        self.assertEqual(self.client.get("/decision-workflow/", headers=headers).status_code, 401)
        self.assert_no_effects()

    def test_denied_role_and_global_matrix_has_zero_effects(self):
        for role in ["admin", "manager", "analyst", "operator", "viewer"]:
            for global_access in [False, True]:
                if global_access and role in ["admin", "manager", "analyst"]: continue
                self.record.update(role=role, global_access=global_access)
                response = self.client.post("/decision-workflow/analyze", json=self.request.model_dump(mode="json"), headers=self.headers())
                self.assertEqual(response.status_code, 403)
                self.assert_no_effects()

    def test_direct_calls_reject_unverified_principal(self):
        for user in [None, self.record, auth().principal(self.record)]:
            with self.assertRaises(HTTPException) as caught:
                self.service.analyze_decision_workflow(self.request, user=user)
            self.assertEqual(caught.exception.status_code, 401)
        self.assert_no_effects()

    def test_global_analysis_roles_replay_compatible_response(self):
        for role in ["admin", "manager", "analyst"]:
            self.record["role"] = role
            with patch.object(self.service, "_read_resource", return_value=self.workflow()):
                response = self.client.post("/decision-workflow/analyze", json=self.request.model_dump(mode="json"), headers=self.headers())
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["workflow_id"], "WF-TEST")
            self.assertIn("forecast_result", response.json())
        self.assert_no_effects()

    def test_every_role_reads_scoped_workflow(self):
        for role in ["admin", "manager", "analyst", "operator", "viewer"]:
            self.record.update(role=role, global_access=False)
            with patch.object(self.service, "_read_resource", return_value=self.workflow()):
                response = self.client.get("/decision-workflow/WF-TEST", headers=self.headers())
            self.assertEqual(response.status_code, 200)

    def test_missing_and_unauthorized_details_are_indistinguishable(self):
        self.record["global_access"] = False
        bodies = []
        for value in [None, self.workflow(store_id="HIDDEN"), self.workflow(decision_result={"qualified_source_stores": ["HIDDEN"]}), self.workflow(decision_result={"total_available_surplus": 9})]:
            with patch.object(self.service, "_read_resource", return_value=value):
                response = self.client.get("/decision-workflow/WF-TEST", headers=self.headers())
            self.assertEqual(response.status_code, 404)
            bodies.append(response.json())
        self.assertTrue(all(body == bodies[0] for body in bodies))

    def test_linked_donor_and_embedded_movement_are_checked(self):
        self.record["global_access"] = False
        for workflow, linked in [
            (self.workflow(candidate_id="C1"), {"store_id": "S1", "qualified_source_details": [{"store_id": "HIDDEN"}]}),
            (self.workflow(movement_id="M1"), {"from_store": "S1", "to_store": "HIDDEN"}),
            (self.workflow(movement={"from_store": "S1", "to_store": "S2", "alternative_sources": ["HIDDEN"]}), None),
        ]:
            with patch.object(self.service, "_read_resource", side_effect=[workflow, linked]):
                response = self.client.get("/decision-workflow/WF-TEST", headers=self.headers())
            self.assertEqual(response.status_code, 404)

    def test_history_filters_before_limit_with_server_target_query(self):
        self.record["global_access"] = False
        items = [self.workflow(workflow_id="DENIED", decision_result={"qualified_source_stores": ["HIDDEN"]}), self.workflow(workflow_id="VISIBLE")]
        query = Mock()
        query.where.return_value = query
        query.order_by.return_value = query
        query.stream.return_value = [types.SimpleNamespace(id=item["workflow_id"], to_dict=lambda item=item: copy.deepcopy(item)) for item in items]
        with patch.object(self.service, "get_collection", return_value=query):
            response = self.client.get("/decision-workflow/?limit=1", headers=self.headers())
        self.assertEqual(response.status_code, 200)
        self.assertEqual([r["workflow_id"] for r in response.json()], ["VISIBLE"])
        query.where.assert_called_once_with("store_id", "in", ["S1", "S2"])
        query.limit.assert_not_called()

    def test_claim_records_actor_and_same_actor_replays(self):
        user = verified_user()
        collection = Mock()
        with patch.object(self.service, "_read_resource", return_value=None), patch.object(self.service, "get_collection", return_value=collection):
            workflow, claimed = self.service._claim_workflow(self.request, user.principal)
        self.assertTrue(claimed)
        self.assertEqual(workflow["actor_id"], user.principal.user_id)
        self.assertEqual(workflow["actor_username_snapshot"], user.principal.username_normalized)
        self.assertEqual(workflow["actor_display_name_snapshot"], user.principal.display_name)
        self.assertEqual(workflow["actor_role_snapshot"], user.principal.role)
        self.assertNotIn("token", workflow)
        with patch.object(self.service, "_read_resource", return_value=workflow):
            _, claimed = self.service._claim_workflow(self.request, user.principal)
        self.assertFalse(claimed)
        collection.document.return_value.create.assert_called_once()

    def test_legacy_replay_does_not_backfill_snapshots(self):
        legacy = self.workflow()
        user = verified_user()
        with patch.object(self.service, "_read_resource", return_value=legacy), patch.object(self.service, "get_collection") as collection:
            result, claimed = self.service._claim_workflow(self.request, user.principal)
        self.assertFalse(claimed)
        self.assertNotIn("actor_display_name_snapshot", result)
        self.assertNotIn("actor_username_snapshot", legacy)
        collection.assert_not_called()

    def test_malformed_claim_identity_fails_without_writes(self):
        principal = verified_user().principal
        for invalid in (None, {}, principal.model_copy(update={"display_name": ""}), principal.model_copy(update={"role": "forged"})):
            with patch.object(self.service, "get_collection") as collection, patch.object(self.service, "_read_resource") as read:
                with self.assertRaises(HTTPException):
                    self.service._claim_workflow(self.request, invalid)
                collection.assert_not_called()
                read.assert_not_called()

    def test_cross_actor_and_ownerless_replay_are_denied_without_writes(self):
        user = verified_user(identity="1123456789abcdef01234567")
        for actor in [canonical_user_id(self.record["_id"]), None]:
            with patch.object(self.service, "_read_resource", return_value=self.workflow(actor_id=actor)):
                with self.assertRaises(HTTPException) as caught:
                    self.service.analyze_decision_workflow(self.request, user=user)
                self.assertEqual(caught.exception.status_code, 403)
        self.assert_no_effects()

    def test_changed_payload_rejected_without_writes(self):
        with patch.object(self.service, "_read_resource", return_value=self.workflow(product_id="OTHER")):
            with self.assertRaises(self.service.DecisionWorkflowValidationError):
                self.service.analyze_decision_workflow(self.request, user=verified_user())
        self.assert_no_effects()

    def test_duplicate_key_race_reloads_winning_claim(self):
        collection = Mock()
        collection.document.return_value.create.side_effect = DuplicateKeyError("fixture collision")
        with patch.object(self.service, "_read_resource", side_effect=[None, self.workflow()]), patch.object(self.service, "get_collection", return_value=collection):
            _, claimed = self.service._claim_workflow(self.request, verified_user().principal)
        self.assertFalse(claimed)
        collection.document.return_value.create.assert_called_once()

    def test_partial_failure_preserves_safe_failure_record(self):
        saved = Mock()
        with patch.object(self.service, "_claim_workflow", return_value=(self.workflow(workflow_status="PROCESSING"), True)), patch.object(self.service, "get_store_by_id", side_effect=RuntimeError("private DB error")), patch.object(self.service, "_save_workflow", saved):
            with self.assertRaises(self.service.DecisionWorkflowExecutionError) as caught:
                self.service.analyze_decision_workflow(self.request, user=verified_user())
        self.assertNotIn("private", str(caught.exception))
        self.assertEqual(saved.call_args.args[1]["workflow_status"], "FAILED")

    def test_database_read_error_is_not_disguised_as_missing(self):
        collection = Mock()
        collection.document.return_value.get.side_effect = RuntimeError("fixture storage failure")
        with patch.object(self.service, "get_collection", return_value=collection):
            with self.assertRaises(RuntimeError):
                self.service.get_decision_workflow("WF-TEST", user=verified_user())


    def test_history_quota_failure_keeps_existing_503_mapping(self):
        with patch.object(self.service, "get_collection", side_effect=self.service.ResourceExhausted("fixture")):
            response = self.client.get("/decision-workflow/", headers=self.headers())
        self.assertEqual(response.status_code, 503)

    def test_forged_actor_field_is_rejected_before_effects(self):
        payload = {**self.request.model_dump(mode="json"), "actor_id": "forged"}
        response = self.client.post("/decision-workflow/analyze", json=payload, headers=self.headers())
        self.assertEqual(response.status_code, 422)
        self.assert_no_effects()

    def test_auth_denial_is_not_saved_as_processing_failure(self):
        with patch.object(self.service, "_claim_workflow", side_effect=HTTPException(status_code=403, detail="Inventory access denied.")), patch.object(self.service, "_save_workflow") as save:
            response = self.client.post("/decision-workflow/analyze", json=self.request.model_dump(mode="json"), headers=self.headers())
        self.assertEqual(response.status_code, 403)
        save.assert_not_called()
        self.assert_no_effects()

    def test_direct_read_entry_points_require_verified_context(self):
        for user in [None, self.record, auth().principal(self.record)]:
            with self.assertRaises(HTTPException):
                self.service.get_decision_workflow("WF-TEST", user=user)
            with self.assertRaises(HTTPException):
                self.service.list_decision_workflows(user=user)
        self.assert_no_effects()
