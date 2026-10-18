"""Isolated Marketing facade tests. No application startup, network or MongoDB."""
import copy
import ast
import time
import unittest
from datetime import date, timedelta
from unittest.mock import patch
from pathlib import Path
import jwt
from argon2 import PasswordHasher
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import Encoding, NoEncryption, PrivateFormat
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from app.routes import marketing_inventory_analysis_routes as routes
from app.schemas.marketing_inventory_analysis_schema import MarketingCampaignAnalysisRequest
from app.security.marketing_staff_auth import (
    MarketingStaffAuth, MarketingStaffPrincipal, MarketingStaffSettings,
    get_marketing_staff_auth, require_marketing_staff,
)
from app.services.marketing_inventory_analysis_client import (
    MarketingInventoryAnalysisClient, MarketingInventoryClientSettings,
)


class Response:
    def __init__(self, status, body): self.status_code=status;self.body=body
    def json(self): return copy.deepcopy(self.body)


class MarketingInventoryAnalysisTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.private=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        cls.private_pem=cls.private.private_bytes(Encoding.PEM,PrivateFormat.PKCS8,NoEncryption()).decode()
        cls.password_hash=PasswordHasher().hash("fixture-password")

    def setUp(self):
        self.network=patch("socket.create_connection",side_effect=AssertionError("network forbidden"))
        self.network.start();self.addCleanup(self.network.stop)
        self.settings=MarketingStaffSettings("marketing",self.password_hash,"s"*32,("CP004",),False)
        self.auth=MarketingStaffAuth(self.settings)
        self.principal=MarketingStaffPrincipal("marketing-staff","marketing",("CP004",),False)
        today=date.today()
        self.payload=dict(campaign_reference="CAM-1",campaign_name="Campaign",product_id="P1",
            store_id="CP004",campaign_start_date=(today+timedelta(days=1)).isoformat(),
            campaign_end_date=(today+timedelta(days=3)).isoformat(),promotion_type="discount",
            discount_percent=10)
        self.request=MarketingCampaignAnalysisRequest(**self.payload)

    def client(self, transport):
        return MarketingInventoryAnalysisClient(
            MarketingInventoryClientSettings("https://inventory.example",self.private_pem),transport)

    def test_login_and_session_are_marketing_only(self):
        token=self.auth.login(" Marketing ","fixture-password")
        principal=self.auth.current(token)
        self.assertEqual(principal.username,"marketing")
        claims=jwt.decode(token,self.settings.session_secret,algorithms=["HS256"],
            audience="marketing-backend",issuer="smart-marketing")
        self.assertEqual(claims["purpose"],"marketing_staff_session")
        self.assertLessEqual(claims["exp"]-claims["iat"],600)
        for username,password in (("unknown","fixture-password"),("marketing","wrong")):
            with self.assertRaises(HTTPException) as caught:self.auth.login(username,password)
            self.assertEqual(caught.exception.status_code,401)
            self.assertEqual(caught.exception.detail,{"code":"INVALID_MARKETING_CREDENTIALS"})
        with self.assertRaises(HTTPException):self.auth.current(jwt.encode(
            {**claims,"aud":"inventory-api"},self.settings.session_secret,algorithm="HS256"))

    def test_scope_is_loaded_from_current_server_settings(self):
        token=self.auth.login("marketing","fixture-password")
        changed=MarketingStaffAuth(MarketingStaffSettings("marketing",self.password_hash,"s"*32,("CP005",),False))
        principal=changed.current(token)
        self.assertEqual(principal.store_ids,("CP005",))
        with self.assertRaises(HTTPException):principal.authorize_store("CP004")
        MarketingStaffPrincipal("marketing-staff","marketing",(),True).authorize_store("ANY")

    def test_service_jwt_and_exact_submission_contract(self):
        observed={}
        def transport(**request):
            observed.update(request)
            body=__import__("json").loads(request["content"])
            return Response(200,{**body,"request_status":"PENDING_REVIEW"})
        result=self.client(transport).submit(self.principal,self.request)
        self.assertEqual(result["request_status"],"PENDING_REVIEW")
        self.assertEqual(observed["method"],"POST")
        self.assertEqual(observed["url"],"https://inventory.example/inventory-marketing/campaign-analysis")
        self.assertFalse(observed["follow_redirects"])
        token=observed["headers"]["Authorization"].removeprefix("Bearer ")
        claims=jwt.decode(token,self.private.public_key(),algorithms=["RS256"],
            issuer="marketing-service",audience="inventory-marketing-planning")
        self.assertEqual(claims["purpose"],"campaign_planning")
        self.assertEqual(claims["permissions"],["planning:access"])
        self.assertLessEqual(claims["exp"]-claims["iat"],120)

    def test_history_uses_exact_bounded_path_and_rejects_scope_leaks(self):
        observed=[]
        def transport(**request):
            observed.append(request)
            return Response(200,{"items":[{**self.payload,"request_id":"MKT-"+"a"*40,
                "request_status":"PENDING_REVIEW"}],"total":1,"skip":0,"limit":20})
        result=self.client(transport).list(self.principal,0,20)
        self.assertEqual(result["total"],1)
        self.assertEqual(observed[0]["method"],"GET")
        self.assertEqual(observed[0]["url"],
            "https://inventory.example/inventory-marketing/campaign-analysis?skip=0&limit=20")
        leaking=self.client(lambda **kw:Response(200,{"items":[{**self.payload,
            "store_id":"OTHER","request_id":"MKT-"+"a"*40,"request_status":"PENDING_REVIEW"}],
            "total":1,"skip":0,"limit":20}))
        with self.assertRaises(HTTPException) as caught:leaking.list(self.principal,0,20)
        self.assertEqual(caught.exception.status_code,403)

    def test_stable_id_replay_and_conflicting_payload_preserved(self):
        bodies=[]
        def transport(**request):
            body=__import__("json").loads(request["content"]);bodies.append(body)
            return Response(200,{**body,"request_status":"PENDING_REVIEW"})
        client=self.client(transport)
        first=client.submit(self.principal,self.request)
        second=client.submit(self.principal,self.request)
        changed=self.request.model_copy(update={"discount_percent":20})
        third=client.submit(self.principal,changed)
        self.assertEqual(first["request_id"],second["request_id"])
        self.assertEqual(first["request_id"],third["request_id"])
        self.assertEqual([body["request_id"] for body in bodies],[first["request_id"]]*3)
        self.assertEqual(bodies[2]["discount_percent"],20)

    def test_unauthorized_store_denied_before_transport(self):
        calls=[]
        request=self.request.model_copy(update={"store_id":"OTHER"})
        with self.assertRaises(HTTPException) as caught:self.client(lambda **kw:calls.append(kw)).submit(self.principal,request)
        self.assertEqual(caught.exception.status_code,403);self.assertEqual(calls,[])

    def test_uncertain_post_not_retried_and_can_reconcile_by_id(self):
        calls=[]
        def failing(**request):calls.append(request);raise TimeoutError("private")
        client=self.client(failing)
        expected=client.request_id(self.principal,self.request)
        with self.assertRaises(HTTPException) as caught:client.submit(self.principal,self.request)
        self.assertEqual(caught.exception.status_code,503);self.assertEqual(len(calls),1)
        self.assertNotIn("private",str(caught.exception))
        def status(**request):
            return Response(200,{"request_id":expected,"store_id":"CP004","request_status":"PENDING_REVIEW"})
        self.assertEqual(self.client(status).status(self.principal,expected)["request_id"],expected)

    def test_conflict_and_response_scope_fail_closed(self):
        with self.assertRaises(HTTPException) as conflict:self.client(
            lambda **kw:Response(409,{})).submit(self.principal,self.request)
        self.assertEqual(conflict.exception.status_code,409)
        request_id=self.client(lambda **kw:None).request_id(self.principal,self.request)
        with self.assertRaises(HTTPException) as denied:self.client(lambda **kw:Response(200,
            {"request_id":request_id,"store_id":"OTHER","request_status":"PENDING_REVIEW"})).status(
                self.principal,request_id)
        self.assertEqual(denied.exception.status_code,403)

    def test_invalid_configuration_and_paths_fail_closed(self):
        for url in ("https://user@example.com","https://example.com/path","file:///tmp/x"):
            with self.assertRaises(Exception):MarketingInventoryClientSettings(url,self.private_pem).validate()
        client=self.client(lambda **kw:Response(200,{}))
        with self.assertRaises(HTTPException):client._send("POST","/unapproved",{})
        with self.assertRaises(HTTPException):client.status(self.principal,"bad")

    def test_routes_require_session_and_use_overrides(self):
        app=FastAPI();app.include_router(routes.router)
        fake=self.client(lambda **request:Response(200,{**(__import__("json").loads(request["content"])
            if request["content"] else {"request_id":request["url"].rsplit("/",1)[-1],"store_id":"CP004"}),
            "request_status":"PENDING_REVIEW"}))
        app.dependency_overrides[get_marketing_staff_auth]=lambda:self.auth
        app.dependency_overrides[require_marketing_staff]=lambda:self.principal
        app.dependency_overrides[routes.inventory_analysis_client]=lambda:fake
        with TestClient(app) as http:
            login=http.post("/marketing-inventory/login",json={"username":"marketing","password":"fixture-password"})
            self.assertEqual(login.status_code,200)
            self.assertNotIn("password",login.text)
            submitted=http.post("/marketing-inventory/campaign-analysis",json=self.payload)
            self.assertEqual(submitted.status_code,200,submitted.text)
            request_id=submitted.json()["request_id"]
            self.assertEqual(http.get("/marketing-inventory/campaign-analysis/"+request_id).status_code,200)

    def test_discount_requires_promotion_with_safe_field_error(self):
        without_optional={key:value for key,value in self.payload.items()
            if key not in ("promotion_type","discount_percent")}
        accepted=MarketingCampaignAnalysisRequest(**without_optional)
        self.assertIsNone(accepted.promotion_type);self.assertIsNone(accepted.discount_percent)
        with self.assertRaises(Exception):
            MarketingCampaignAnalysisRequest(**{**without_optional,"discount_percent":10})

        app=FastAPI();app.include_router(routes.router)
        app.dependency_overrides[require_marketing_staff]=lambda:self.principal
        app.dependency_overrides[routes.inventory_analysis_client]=lambda:object()
        with TestClient(app) as http:
            response=http.post("/marketing-inventory/campaign-analysis",
                json={**without_optional,"discount_percent":10})
            self.assertEqual(response.status_code,422)
            self.assertEqual(response.json(),{"detail":{"code":"INVALID_MARKETING_REQUEST",
                "errors":[{"field":"discount_percent","reason":"PROMOTION_TYPE_REQUIRED"}]}})
            self.assertNotIn("10",response.text)
            missing=http.post("/marketing-inventory/campaign-analysis",
                json={key:value for key,value in without_optional.items() if key!="product_id"})
            self.assertEqual(missing.status_code,422)
            self.assertEqual(missing.json()["detail"]["errors"],
                [{"field":"product_id","reason":"REQUIRED"}])

        login_app=FastAPI();login_app.include_router(routes.router)
        login_app.dependency_overrides[get_marketing_staff_auth]=lambda:self.auth
        with TestClient(login_app) as http:
            malformed=http.post("/marketing-inventory/login",json={"username":"marketing"})
            self.assertEqual(malformed.status_code,422)
            self.assertNotIn("password_hash",malformed.text)
            self.assertNotIn("fixture-password",malformed.text)

    def test_router_has_exact_three_endpoints(self):
        paths={(route.path,tuple(sorted(route.methods))) for route in routes.router.routes}
        self.assertEqual(paths,{("/marketing-inventory/login",("POST",)),
            ("/marketing-inventory/campaign-analysis",("GET",)),
            ("/marketing-inventory/campaign-analysis",("POST",)),
            ("/marketing-inventory/campaign-analysis/{request_id}",( "GET",))})

    def test_router_registered_once_in_shared_application(self):
        tree=ast.parse(Path("app/main.py").read_text())
        imports=[node for node in ast.walk(tree) if isinstance(node,ast.ImportFrom)
            and node.module=="app.routes.marketing_inventory_analysis_routes"]
        registrations=[node for node in ast.walk(tree) if isinstance(node,ast.Call)
            and isinstance(node.func,ast.Attribute) and node.func.attr=="include_router"
            and node.args and isinstance(node.args[0],ast.Name)
            and node.args[0].id=="marketing_inventory_analysis_router"]
        self.assertEqual(len(imports),1);self.assertEqual(len(registrations),1)


if __name__ == "__main__": unittest.main()
