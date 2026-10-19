"""Evaluate only main's include_router AST nodes; never import shared startup."""
import ast
from collections import Counter
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from fastapi import APIRouter, FastAPI
from fastapi.testclient import TestClient
from app.routes.inventory_auth_routes import router as auth
from app.routes.inventory_profile_routes import router as profile
from app.routes.inventory_marketing_planning_routes import router as planning
from app.routes.inventory_user_management_routes import router as management
from app.services.inventory_auth_service import InventoryAuthService, InventoryJWTSettings, get_inventory_auth_service

MAIN = Path(__file__).resolve().parents[2] / "app/main.py"
EXISTING = ["zone.router", "profile.router", "tryon.router", "monitoring.router",
            "product_routes.router", "smart_inventory.router", "stylist.router",
            "inventory_routes.router", "store_routes.router", "forecast_routes.router",
            "intelligence_routes.router", "recommendation_routes.router", "analytics_routes.router",
            "optimization_candidate_routes.router", "decision_engine_routes.router", "stock_movement_routes.router",
            "chat_router", "weather_routes.router", "decision_workflow_routes.router", "marketing_opportunity_router",
            "inventory_auth_router", "kpi_routes.router", "recommend_routes.router", "poster_routes.router",
            "calendar_routes.router", "customer_routes.router", "upload_routes.router", "report_routes.router"]
NEW = {"inventory_user_management_router": management, "inventory_profile_router": profile,
       "inventory_marketing_planning_router": planning,
       "marketing_inventory_analysis_router": APIRouter()}


class InventoryRouterRegistrationTests(unittest.TestCase):
    def setUp(self):
        for target in ("pymongo.MongoClient", "socket.create_connection"):
            guard = patch(target, side_effect=AssertionError("Live IO forbidden"))
            guard.start(); self.addCleanup(guard.stop)
        self.tree = ast.parse(MAIN.read_text())
        self.nodes = [node for node in self.tree.body if isinstance(node, ast.Expr)
                      and isinstance(node.value, ast.Call) and ast.unparse(node.value.func) == "app.include_router"]
        self.app = FastAPI()
        namespace = {"app": self.app, "inventory_auth_router": auth, **NEW}
        self.sentinels = []
        for node in self.nodes:
            name = ast.unparse(node.value.args[0])
            if name in namespace: continue
            stub = APIRouter()
            def sentinel(): return {"existing": True}
            path = "/registration-sentinel-" + name.replace(".", "-")
            stub.add_api_route(path, sentinel, methods=["GET"])
            self.sentinels.append(path)
            if "." in name:
                namespace[name.split(".")[0]] = SimpleNamespace(router=stub)
            else: namespace[name] = stub
        # Only registration expressions are executed. All unrelated routers are stubs.
        exec(compile(ast.Module(body=self.nodes, type_ignores=[]), str(MAIN), "exec"), namespace)
        service = InventoryAuthService(InventoryJWTSettings(secret="fixture-registration-only-0000000000000000000000"))
        self.app.dependency_overrides[get_inventory_auth_service] = lambda: service
        from app.services.inventory_user_service import get_inventory_user_repository
        self.app.dependency_overrides[get_inventory_user_repository] = lambda: SimpleNamespace(find_by_id=lambda _: None)
        self.client = TestClient(self.app)
        self.addCleanup(self.client.close)

    def test_imports_and_existing_registration_order_preserved(self):
        names = [ast.unparse(node.value.args[0]) for node in self.nodes]
        self.assertEqual([name for name in names if name not in NEW], EXISTING)
        for name in NEW: self.assertEqual(names.count(name), 1)
        imports = {(node.module, alias.name, alias.asname) for node in self.tree.body
                   if isinstance(node, ast.ImportFrom) for alias in node.names}
        self.assertIn(("app.routes.inventory_user_management_routes", "router", "inventory_user_management_router"), imports)
        self.assertIn(("app.routes.inventory_profile_routes", "router", "inventory_profile_router"), imports)
        # Prefix and tag arguments of pre-existing registrations stay intact.
        for node in self.nodes[:4]:
            keywords = {kw.arg: ast.literal_eval(kw.value) for kw in node.value.keywords}
            self.assertTrue(keywords["prefix"].startswith("/"))
            self.assertEqual(len(keywords["tags"]), 1)

    def test_ten_inventory_auth_management_operations_once_without_conflicts(self):
        counts = Counter((method, route.path) for route in self.app.routes
                         for method in getattr(route, "methods", []))
        expected = {("GET", "/inventory-users"), ("GET", "/inventory-users/{user_id}"),
                    ("POST", "/inventory-users"), ("PATCH", "/inventory-users/{user_id}"),
                    ("PATCH", "/inventory-users/{user_id}/status"),
                    ("POST", "/inventory-users/{user_id}/reset-password"),
                    ("GET", "/inventory-auth/me"), ("POST", "/inventory-auth/login"),
                    ("PATCH", "/inventory-auth/me"), ("POST", "/inventory-auth/change-password")}
        expected.update({("POST", "/inventory-marketing/forecast-shares"),
                         ("GET", "/inventory-marketing/forecast-shares/{share_id}"),
                         ("POST", "/inventory-marketing/campaign-analysis"),
                         ("GET", "/inventory-marketing/campaign-analysis"),
                         ("GET", "/inventory-marketing/campaign-analysis/{request_id}"),
                         ("GET", "/inventory-marketing/campaign-reviews"),
                         ("GET", "/inventory-marketing/campaign-reviews/{request_id}"),
                         ("POST", "/inventory-marketing/campaign-reviews/{request_id}/accept"),
                         ("POST", "/inventory-marketing/campaign-reviews/{request_id}/reject")})
        for operation in expected: self.assertEqual(counts[operation], 1)
        self.assertTrue(all(count == 1 for count in counts.values()))
        original = next(route for route in auth.routes if route.path == "/inventory-auth/me")
        registered = next(route for route in self.app.routes if getattr(route, "path", None) == "/inventory-auth/me" and "GET" in route.methods)
        self.assertIs(registered.endpoint, original.endpoint)
        self.assertEqual(len(self.sentinels), len(EXISTING)-1)

    def test_missing_and_invalid_tokens_denied_without_repository_resolution(self):
        from app.services.inventory_user_management_dependencies import get_management_repository, get_profile_repository
        def forbidden_repository(): raise AssertionError("Repository must not resolve")
        self.app.dependency_overrides[get_management_repository] = forbidden_repository
        self.app.dependency_overrides[get_profile_repository] = forbidden_repository
        for router in (management, profile):
            for route in router.routes:
                for headers in ({}, {"Authorization": "Bearer invalid"}):
                    path = route.path.replace("{user_id}", "oid:" + "1"*24)
                    response = self.client.request(next(iter(route.methods)), path, headers=headers, json={})
                    self.assertEqual(response.status_code, 401, (route.path, response.text))


if __name__ == "__main__": unittest.main()
