"""Fake-only router tests; no models, weather requests, AI, or shared app import."""
import ast
import copy
import importlib.util
import socket
import sys
import types
import unittest
from datetime import date, datetime, timezone
from pathlib import Path
from unittest.mock import Mock, patch

import jwt
from bson import ObjectId
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.services.inventory_auth_service import (
    InventoryAuthService, InventoryJWTSettings, get_inventory_auth_service,
)
from app.services.inventory_user_service import (
    canonical_user_id, get_inventory_user_repository,
)
from app.schemas.forecast_schema import InventoryForecastRequest

BACKEND = Path(__file__).resolve().parents[2]


class FakeUsers:
    def __init__(self, user):
        self.user = user

    def find_by_id(self, user_id):
        return self.user if canonical_user_id(self.user["_id"]) == user_id else None


class ForecastOptimizationAuthorizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.auth = InventoryAuthService(
            InventoryJWTSettings(secret="test-only-forecast-signing-key-000000-000000")
        )

    def setUp(self):
        for target in ("socket.create_connection", "pymongo.MongoClient"):
            guard = patch(target, side_effect=AssertionError("Network/client forbidden"))
            guard.start()
            self.addCleanup(guard.stop)
        self.user = {
            "_id": ObjectId("0123456789abcdef01234567"),
            "username_normalized": "teststaff", "display_name": "Test Staff",
            "role": "admin", "store_ids": ["TARGET", "DONOR"],
            "is_active": True, "global_access": False,
        }
        self.candidate = {
            "id": "C1", "candidate_id": "C1", "store_id": "TARGET",
            "candidate_type": "LOW_STOCK", "priority": "HIGH", "status": "PENDING",
            "qualified_source_details": [{"store_id": "DONOR", "current_stock": 60}],
            "qualified_source_stores": ["DONOR"], "available_source_stores": 1,
        }
        self.records = [
            self.candidate,
            {**self.candidate, "id": "C2", "store_id": "HIDDEN"},
            {**self.candidate, "id": "C3", "qualified_source_details": [{"store_id": "HIDDEN", "current_stock": 99}], "qualified_source_stores": ["HIDDEN"]},
        ]
        self.effects = []
        def effect(name, result):
            def call(*args, **kwargs):
                self.effects.append(name)
                return copy.deepcopy(result)
            return Mock(side_effect=call)
        daily = types.ModuleType("app.services.daily_forecast_service")
        daily.predict_next_day = effect("model", {"predicted_demand": 7, "confidence_percentage": 75})
        daily.generate_7_day_forecast = effect("model", {"total_predicted_demand": 49, "forecast": []})
        daily.generate_custom_forecast = effect("model", {"total_predicted_demand": 21, "forecast": []})
        monthly = types.ModuleType("app.services.inventory_forecast_service")
        monthly.predict_monthly_inventory_demand = effect("model", {"predicted_monthly_demand": 10, "confidence_percentage": 75, "confidence": "75%"})
        monthly.predict_quarterly_inventory_demand = effect("model", {"predicted_quarterly_demand": 30})
        features = types.ModuleType("app.services.inventory_forecast_feature_service")
        features.build_auto_monthly_payload = effect("features", {"store_id": "TARGET"})
        weather = types.ModuleType("app.services.weather_service")
        weather.get_monthly_weather_profile = effect("weather", {
            "avg_temperature": 30, "avg_humidity": 70, "total_rainfall": 1,
            "rainy_days": 1, "storm_days": 0, "sunny_days": 20,
        })
        from app.services.intelligence_service import generate_inventory_intelligence
        intelligence = types.ModuleType("app.services.intelligence_service")
        intelligence.generate_inventory_intelligence = Mock(
            side_effect=lambda **kwargs: self.effects.append("intelligence") or generate_inventory_intelligence(**kwargs)
        )
        # Load the unchanged numerical recommendation functions without services.
        recommend = types.ModuleType("app.services.recommendation_service")
        original = ast.parse((BACKEND / "app/services/recommendation_service.py").read_text())
        functions = [n for n in original.body if isinstance(n, ast.FunctionDef)]
        recommend.generate_inventory_intelligence = generate_inventory_intelligence
        exec(compile(ast.Module(body=functions, type_ignores=[]), "pure-recommendations", "exec"), recommend.__dict__)
        real_recommend = recommend.generate_recommendation
        recommend.generate_recommendation = Mock(
            side_effect=lambda **kwargs: self.effects.append("recommendation") or real_recommend(**kwargs)
        )
        candidates = types.ModuleType("app.services.optimization_candidate_service")
        candidates.get_all_candidates = lambda: copy.deepcopy(self.records)
        candidates.get_candidate_by_id = lambda ident: copy.deepcopy(next((r for r in self.records if r["id"] == ident), None))
        candidates.get_candidates_by_store = lambda store: copy.deepcopy([r for r in self.records if r["store_id"] == store])
        candidates.get_candidates_by_priority = lambda priority: copy.deepcopy([r for r in self.records if r["priority"] == priority.upper()])
        candidates.get_candidates_by_type = lambda kind: copy.deepcopy([r for r in self.records if r["candidate_type"] == kind.upper()])
        candidates.get_candidate_summary = Mock(side_effect=AssertionError("Unscoped summary forbidden"))
        decisions = types.ModuleType("app.services.decision_engine_service")
        decisions.analyze_candidate = effect("write", {"candidate_id": "C1", "decision": {"recommended_action": "TRANSFER"}, "candidate": self.candidate})
        modules = {module.__name__: module for module in [daily, monthly, features, weather, intelligence, recommend, candidates, decisions]}
        self.app = FastAPI()
        self.routers = []
        with patch.dict(sys.modules, modules):
            for name in ["forecast_routes", "intelligence_routes", "recommendation_routes", "optimization_candidate_routes", "decision_engine_routes"]:
                spec = importlib.util.spec_from_file_location(
                    "isolated_" + name, BACKEND / "app/routes" / (name + ".py")
                )
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                self.app.include_router(module.router)
                self.routers.append(module.router)
        self.app.dependency_overrides[get_inventory_auth_service] = lambda: self.auth
        self.app.dependency_overrides[get_inventory_user_repository] = lambda: FakeUsers(self.user)
        self.client = TestClient(self.app)
        self.addCleanup(self.client.close)

    def headers(self):
        return {"Authorization": "Bearer " + self.auth.create_token(self.auth.principal(self.user))}

    def payload(self, path):
        numeric = {"current_stock": 20, "reorder_level": 5, "max_stock": 100, "forecast_demand": 10, "cost_price": 1, "selling_price": 2}
        if path.startswith("/intelligence"):
            return numeric
        if path.startswith("/recommendations"):
            return {**numeric, "store_id": "TARGET", "product_id": "P1"}
        if path.endswith("/auto"):
            return {"store_id": "TARGET", "category": "Tops", "brand": "Brand", "gender": "Men", "year": 2026, "month": 10, "quarter": 4}
        if "/inventory/" in path:
            result = {}
            for name, field in InventoryForecastRequest.model_fields.items():
                result[name] = "test" if field.annotation is str else 1
            result.update(store_id="TARGET", year=2026, month=10, quarter=4)
            return result
        if path == "/forecast/custom":
            return {"store_id": "TARGET", "product_id": "P1", "price_lkr": 100, "start_date": "2026-10-14", "end_date": "2026-10-16"}
        if path.startswith("/forecast"):
            return {"store_id": "TARGET", "product_id": "P1", "price_lkr": 100, "month": 10, "day": 14, "day_of_week_num": 2}
        return {}

    def request(self, path, method="GET", body=None, headers=None):
        return self.client.request(method, path, json=body if body is not None else (self.payload(path) if method=="POST" else None),
                                   headers=self.headers() if headers is None else headers)

    def test_missing_jwt_every_registration(self):
        for router in self.routers:
            for route in router.routes:
                path = route.path.replace("{candidate_id}", "C1").replace("{store_id}", "TARGET").replace("{priority}", "HIGH").replace("{candidate_type}", "LOW_STOCK")
                method = next(iter(route.methods))
                response = self.request(path, method, headers={})
                self.assertEqual(response.status_code, 401, path)
        self.assertEqual(self.effects, [])

    def test_invalid_expired_and_customer_tokens(self):
        claims = jwt.decode(self.headers()["Authorization"].split()[1], options={"verify_signature": False})
        now = int(datetime.now(timezone.utc).timestamp())
        tokens = ["invalid"] + [jwt.encode({**claims, **change}, self.auth.settings.secret, algorithm="HS256") for change in [
            {"iat": now-1000, "nbf": now-1000, "exp": now-100},
            {"iss": "customer", "aud": "customer-api", "purpose": "customer_access"},
        ]]
        for token in tokens:
            for path, method in [("/forecast/daily", "POST"), ("/intelligence/analyze", "POST"), ("/optimization-candidates/", "GET"), ("/decision-engine/analyze/C1", "POST")]:
                self.assertEqual(self.request(path, method, headers={"Authorization": "Bearer "+token}).status_code, 401)
        self.assertEqual(self.effects, [])

    def test_inactive_and_changed_permissions(self):
        headers = self.headers()
        self.user["is_active"] = False
        self.assertEqual(self.request("/forecast/daily", "POST", headers=headers).status_code, 401)
        self.user["is_active"] = True
        self.user["store_ids"] = ["DONOR"]
        self.assertEqual(self.request("/forecast/daily", "POST", headers=headers).status_code, 403)
        self.assertEqual(self.effects, [])

    def test_all_roles(self):
        for role in ("admin", "manager", "analyst", "operator", "viewer"):
            self.user["role"] = role
            self.user["global_access"] = True
            for path in ["/forecast/daily", "/intelligence/analyze", "/recommendations/generate", "/decision-engine/analyze/C1"]:
                self.effects.clear()
                response = self.request(path, "POST")
                if role in ("admin", "manager", "analyst"):
                    self.assertEqual(response.status_code, 200, response.text)
                else:
                    self.assertEqual(response.status_code, 403)
                    self.assertEqual(self.effects, [])
            self.assertEqual(self.request("/optimization-candidates/").status_code, 200)

    def test_authorized_forecasts_preserve_outputs(self):
        cases = {
            "/forecast/daily": ("predicted_demand", 7),
            "/forecast/7-day": ("total_predicted_demand", 49),
            "/forecast/custom": ("total_predicted_demand", 21),
            "/forecast/inventory/monthly": ("predicted_monthly_demand", 10),
            "/forecast/inventory/quarterly": ("predicted_quarterly_demand", 30),
            "/forecast/inventory/monthly/auto": ("predicted_monthly_demand", 10),
            "/forecast/inventory/quarterly/auto": ("predicted_quarterly_demand", 30),
        }
        for path, (key, value) in cases.items():
            response = self.request(path, "POST")
            self.assertEqual(response.status_code, 200, response.text)
            self.assertEqual(response.json()[key], value)
            self.assertEqual(response.json()["store_id"], "TARGET")

    def test_denied_forecasts_no_model_weather_or_features(self):
        self.user["store_ids"] = ["DONOR"]
        for router in self.routers[:1]:
            for route in router.routes:
                self.assertEqual(self.request(route.path, "POST").status_code, 403)
        self.assertEqual(self.effects, [])

    def test_recommendation_store_access(self):
        self.user["store_ids"] = ["DONOR"]
        self.assertEqual(self.request("/recommendations/generate", "POST").status_code, 403)
        self.assertEqual(self.effects, [])

    def test_numeric_intelligence_has_no_inventory_lookup(self):
        response = self.request("/intelligence/analyze", "POST")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["current_stock"], 20)
        self.assertEqual(self.effects, ["intelligence"])

    def test_direct_candidate_scope(self):
        self.assertEqual(self.request("/optimization-candidates/C1").status_code, 200)
        self.assertEqual(self.request("/optimization-candidates/C2").status_code, 403)
        self.assertEqual(self.request("/optimization-candidates/C3").status_code, 403)
        self.assertEqual(self.request("/optimization-candidates/missing").status_code, 404)
        self.assertEqual(self.effects, [])

    def test_filtered_lists_and_summary(self):
        for path in ["/optimization-candidates/", "/optimization-candidates/store/TARGET", "/optimization-candidates/priority/HIGH", "/optimization-candidates/type/LOW_STOCK"]:
            response = self.request(path)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["count"], 1)
            self.assertEqual(response.json()["candidates"][0]["id"], "C1")
            self.assertNotIn("HIDDEN", response.text)
        summary = self.request("/optimization-candidates/summary").json()
        self.assertEqual(summary["total_candidates"], 1)
        self.assertEqual(summary["high_priority"], 1)
        self.assertEqual(summary["low_stock"], 1)
        self.assertEqual(summary["pending"], 1)
        self.assertEqual(set(summary), {"total_candidates", "high_priority", "medium_priority", "low_priority", "low_stock", "overstock", "pending", "analyzing", "recommended", "approved", "completed", "last_generated"})
        self.assertEqual(self.effects, [])

    def test_store_filter_cannot_grant_access(self):
        self.assertEqual(self.request("/optimization-candidates/store/HIDDEN").status_code, 403)
        self.assertEqual(self.effects, [])

    def test_global_analysis_gate_precedes_writes(self):
        self.assertEqual(self.request("/decision-engine/analyze/C1", "POST").status_code, 403)
        self.assertEqual(self.effects, [])
        self.user["global_access"] = True
        self.assertEqual(self.request("/decision-engine/analyze/C1", "POST").status_code, 200)
        self.assertEqual(self.effects, ["write"])

    def test_admin_not_implicitly_global(self):
        self.user["role"] = "admin"
        self.assertEqual(self.request("/decision-engine/analyze/C1", "POST").status_code, 403)
        self.assertEqual(self.effects, [])

    def test_malformed_scope_denied_before_analysis(self):
        self.user["global_access"] = True
        self.candidate["store_id"] = None
        self.assertEqual(self.request("/decision-engine/analyze/C1", "POST").status_code, 403)
        self.assertEqual(self.effects, [])

    def test_unattributed_donor_aggregates_require_global(self):
        self.candidate["qualified_source_details"] = []
        self.candidate["qualified_source_stores"] = []
        self.candidate["total_available_surplus"] = 100
        self.assertEqual(self.request("/optimization-candidates/C1").status_code, 403)
        self.assertEqual(self.request("/optimization-candidates/summary").json()["total_candidates"], 0)
        self.user["global_access"] = True
        self.assertEqual(self.request("/optimization-candidates/C1").status_code, 200)


    def test_legacy_donor_references_do_not_leak(self):
        self.candidate["eligible_source_stores"] = ["HIDDEN"]
        self.assertEqual(self.request("/optimization-candidates/C1").status_code, 403)
        response = self.request("/optimization-candidates/")
        self.assertEqual(response.json()["count"], 0)
        self.assertNotIn("HIDDEN", response.text)
        self.assertEqual(self.effects, [])

if __name__ == "__main__":
    unittest.main()
