"""Fake native MongoDB handles only. Never import shared application startup."""
import ast
import copy
import threading
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from fastapi import FastAPI, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from fastapi.testclient import TestClient
from pymongo.errors import DuplicateKeyError, AutoReconnect
from app.services.inventory_marketing_planning_repository import InventoryMarketingPlanningRepository, COLLECTIONS
from app.services.inventory_marketing_planning_service import fingerprint
from app.services import inventory_marketing_planning_dependencies as dependencies
from app.security import inventory_marketing_planning_auth as auth
from app.routes import inventory_marketing_planning_routes as routes


class Collection:
    def __init__(self):
        self.rows = {}; self.lock = threading.Lock(); self.writes = []
        self.insert_error = None; self.update_error = None; self.indexes = [{"name": "_id_", "key": {"_id": 1}}]
    def list_indexes(self): return self.indexes
    def find_one(self, query, projection):
        with self.lock:
            row = self.rows.get(query["_id"])
            return {k: copy.deepcopy(v) for k,v in row.items() if projection.get(k)} if row else None
    def count_documents(self, query):
        return len([row for row in self.rows.values() if _matches(row, query)])
    def find(self, query, projection):
        return Cursor([{k:copy.deepcopy(v) for k,v in row.items() if projection.get(k)}
                       for row in self.rows.values() if _matches(row, query)])
    def insert_one(self, row):
        with self.lock:
            self.writes.append("insert")
            if self.insert_error == "before": raise AutoReconnect("sensitive")
            if row["_id"] in self.rows: raise DuplicateKeyError("duplicate")
            self.rows[row["_id"]] = copy.deepcopy(row)
            if self.insert_error == "after": raise AutoReconnect("sensitive")
            return SimpleNamespace(acknowledged=True)
    def update_one(self, query, update):
        with self.lock:
            self.writes.append("update")
            if self.update_error == "before": raise AutoReconnect("sensitive")
            row = self.rows.get(query["_id"])
            match = row is not None and all(row.get(k)==v for k,v in query.items())
            if match: row.update(copy.deepcopy(update["$set"]))
            if self.update_error == "after": raise AutoReconnect("sensitive")
            return SimpleNamespace(acknowledged=True, matched_count=int(match))


class Database:
    name = "smart_retail_db"
    def __init__(self):
        self.client = object(); self.collections = {n:Collection() for n in COLLECTIONS.values()}
        self.accesses = []; self.metadata_error = False
    def list_collections(self, filter):
        assert set(filter)=={"name"}
        if self.metadata_error: raise RuntimeError("sensitive")
        return [{"name":filter["name"],"type":"collection"}] if filter["name"] in self.collections else []
    def get_collection(self, name, **options):
        assert name in COLLECTIONS.values()
        assert options["write_concern"].document == {"w":"majority","wtimeout":15000}
        assert options["read_concern"].document == {"level":"majority"}
        self.accesses.append(name)
        return self.collections[name]


def _matches(row, query):
    return all(row.get(key) in value["$in"] if isinstance(value,dict) and "$in" in value
               else row.get(key)==value for key,value in query.items())


class Cursor(list):
    def sort(self, *args): return self
    def skip(self, count): return Cursor(self[count:])
    def limit(self, count): return Cursor(self[:count])


class StorageTests(unittest.TestCase):
    def setUp(self):
        self.guard=patch("pymongo.MongoClient",side_effect=AssertionError("live Mongo forbidden"));self.guard.start();self.addCleanup(self.guard.stop)
        self.db=Database();self.repo=InventoryMarketingPlanningRepository(self.db).ready()
    def claim(self, payload=None):
        payload=payload or {"request_id":"R1","product_id":"P1"}
        return self.repo.claim("campaign-analysis","R1",fingerprint(payload),"marketing-service","CP004",payload)
    def test_atomic_share_and_immutable_replay(self):
        result={"share_id":"S1","forecast_demand":3,"shared_by":"first"}
        self.assertEqual(self.repo.publish("S1","digest","workflow:W1","CP004",result),result)
        self.assertEqual(self.repo.publish("S1","digest","workflow:W1","CP004",{**result,"shared_by":"second"}),result)
        collection=self.db.collections[COLLECTIONS["forecast-share"]]
        self.assertEqual(len(collection.rows),1);self.assertEqual(collection.rows["S1"]["state"],"COMPLETE")
        with self.assertRaises(HTTPException) as caught:self.repo.publish("S1","changed","workflow:W1","CP004",result)
        self.assertEqual(caught.exception.status_code,409)
    def test_claim_request_persistence_and_duplicate(self):
        claim=self.claim();self.assertTrue(claim.acquired)
        self.assertFalse(self.claim().acquired)
        self.assertEqual(self.db.collections[COLLECTIONS["campaign-analysis"]].rows["R1"]["request"]["product_id"],"P1")
        self.repo.complete(claim,{"assessment_status":"COMPLETED"})
        self.assertEqual(self.claim().result,{"assessment_status":"COMPLETED"})
    def test_pending_submission_and_atomic_review_transitions(self):
        payload={"request_id":"R2","product_id":"P1","store_id":"CP004"}
        pending=self.repo.submit_campaign("R2",fingerprint(payload),"marketing-service","CP004",payload)
        self.assertEqual(pending["request_status"],"PENDING_REVIEW")
        review={"reviewer_id":"oid:test","decision":"ACCEPTED"}
        claim=self.repo.begin_review("R2",review)
        self.assertEqual(claim.payload,payload)
        with self.assertRaises(HTTPException):self.repo.begin_review("R2",review)
        self.repo.finish_review(claim,"COMPLETED",{"assessment_status":"COMPLETED"})
        self.assertEqual(self.repo.get("campaign-analysis","R2")["state"],"COMPLETED")
    def test_reject_is_conditional_and_list_filters_stores(self):
        for key,store in (("A","CP004"),("B","OTHER")):
            payload={"request_id":key,"product_id":"P1","store_id":store}
            self.repo.submit_campaign(key,fingerprint(payload),"marketing-service",store,payload)
        rejected=self.repo.reject_campaign("A","No stock",{"reviewer_id":"oid:test","decision":"REJECTED"})
        self.assertEqual(rejected["request_status"],"REJECTED")
        with self.assertRaises(HTTPException):self.repo.reject_campaign("A","Again",{"reviewer_id":"x"})
        listing=self.repo.list_campaigns(("CP004",),0,50,owner_id="marketing-service")
        self.assertEqual(listing["total"],1);self.assertEqual(listing["items"][0]["request_id"],"A")
    def test_concurrent_claims_one_owner(self):
        with ThreadPoolExecutor(max_workers=8) as pool:claims=list(pool.map(lambda _:self.claim(),range(16)))
        self.assertEqual(sum(c.acquired for c in claims),1)
    def test_conflicting_campaign_rejected(self):
        self.claim()
        with self.assertRaises(HTTPException) as caught:self.claim({"request_id":"R1","product_id":"P2"})
        self.assertEqual(caught.exception.status_code,409)
    def test_unknown_insert_reconciled_only_if_confirmed(self):
        collection=self.db.collections[COLLECTIONS["campaign-analysis"]];collection.insert_error="after"
        self.assertTrue(self.claim().acquired)
        self.assertEqual(len(collection.writes),1)
    def test_unknown_insert_unconfirmed_fail_closed(self):
        collection=self.db.collections[COLLECTIONS["campaign-analysis"]];collection.insert_error="before"
        with self.assertRaises(HTTPException) as caught:self.claim()
        self.assertEqual(caught.exception.status_code,503);self.assertNotIn("sensitive",str(caught.exception))
        self.assertEqual(len(collection.writes),1)
    def test_unknown_completion_confirmed(self):
        claim=self.claim();collection=self.db.collections[COLLECTIONS["campaign-analysis"]];collection.update_error="after"
        self.repo.complete(claim,{"answer":1})
        self.assertEqual(self.claim().result,{"answer":1});self.assertEqual(collection.writes.count("update"),1)
    def test_unknown_completion_no_reclaim(self):
        claim=self.claim();collection=self.db.collections[COLLECTIONS["campaign-analysis"]];collection.update_error="before"
        with self.assertRaises(HTTPException):self.repo.complete(claim,{"answer":1})
        self.assertFalse(self.claim().acquired);self.assertIsNone(self.claim().result)
    def test_completion_cas_and_result_immutable(self):
        claim=self.claim();self.repo.complete(claim,{"answer":1});self.repo.complete(claim,{"answer":1})
        with self.assertRaises(HTTPException):self.repo.complete(claim,{"answer":2})
        self.assertEqual(self.claim().result,{"answer":1})
    def test_missing_collections_indexes_metadata_fail_closed(self):
        for case in ("collection","index","metadata","ttl"):
            db=Database()
            if case=="collection":del db.collections[COLLECTIONS["forecast-share"]]
            if case=="index":db.collections[COLLECTIONS["forecast-share"]].indexes=[]
            if case=="ttl":db.collections[COLLECTIONS["forecast-share"]].indexes.append({"expireAfterSeconds":1})
            if case=="metadata":db.metadata_error=True
            with self.assertRaises(HTTPException):InventoryMarketingPlanningRepository(db).ready()
            self.assertTrue(all(not c.writes for c in db.collections.values()))
    def test_campaign_readiness_does_not_require_forecast_collection(self):
        db=Database();del db.collections[COLLECTIONS["forecast-share"]]
        repo=InventoryMarketingPlanningRepository(db).ready(("campaign-analysis",))
        self.assertEqual(db.accesses,[COLLECTIONS["campaign-analysis"]])
        payload={"request_id":"R3","product_id":"P1","store_id":"CP004"}
        result=repo.submit_campaign("R3",fingerprint(payload),"marketing-service","CP004",payload)
        self.assertEqual(result["request_status"],"PENDING_REVIEW")
    def test_forecast_readiness_fails_without_forecast_collection(self):
        db=Database();del db.collections[COLLECTIONS["forecast-share"]]
        with self.assertRaises(HTTPException) as caught:
            InventoryMarketingPlanningRepository(db).ready(("forecast-share",))
        self.assertEqual(caught.exception.status_code,503)
        self.assertTrue(all(not collection.writes for collection in db.collections.values()))
    def test_scoped_dependency_providers_access_only_required_collection(self):
        self.db.accesses.clear()
        wrapper=SimpleNamespace(db=self.db,client=self.db.client)
        with patch.object(dependencies,"get_existing_inventory_mongo_wrapper",return_value=wrapper):
            campaign=dependencies.campaign_planning_repository()
        self.assertIs(campaign.database,self.db)
        self.assertEqual(self.db.accesses,[COLLECTIONS["campaign-analysis"]])
        self.db.accesses.clear()
        with patch.object(dependencies,"get_existing_inventory_mongo_wrapper",return_value=wrapper):
            forecast=dependencies.forecast_sharing_repository()
        self.assertIs(forecast.database,self.db)
        self.assertEqual(self.db.accesses,[COLLECTIONS["forecast-share"]])
    def test_invalid_readiness_namespace_fails_closed(self):
        for namespaces in ((),("unknown",),("campaign-analysis","campaign-analysis")):
            with self.assertRaises(HTTPException):
                InventoryMarketingPlanningRepository(Database()).ready(namespaces)
    def test_wrong_database(self):
        self.db.name="wrong"
        with self.assertRaises(HTTPException):InventoryMarketingPlanningRepository(self.db)
    def test_existing_wrapper_only(self):
        wrapper=SimpleNamespace(db=self.db,client=self.db.client)
        with patch.object(dependencies,"get_existing_inventory_mongo_wrapper",return_value=wrapper):
            self.assertIs(dependencies.planning_repository().database,self.db)
        self.assertEqual(set(self.db.accesses),set(COLLECTIONS.values()))
    def test_no_wrapper_no_initialization(self):
        with patch.object(dependencies,"get_existing_inventory_mongo_wrapper",side_effect=RuntimeError("secret")):
            with self.assertRaises(HTTPException) as caught:dependencies.planning_repository()
        self.assertNotIn("secret",str(caught.exception))


class IdentityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Ephemeral mocked-test key, never stored or used as deployment credentials.
        cls.key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        cls.settings=auth.MarketingServiceSettings(cls.key.public_key().public_bytes(Encoding.PEM,PublicFormat.SubjectPublicKeyInfo).decode(),("CP004",),False)
    def token(self, **changes):
        now=int(time.time());claims=dict(sub="marketing-service",iss="marketing-service",aud="inventory-marketing-planning",purpose="campaign_planning",iat=now,nbf=now,exp=now+120,jti="test",permissions=["planning:access"])
        claims.update(changes)
        return HTTPAuthorizationCredentials(scheme="Bearer",credentials=jwt.encode(claims,self.key,algorithm="RS256"))
    def test_valid_identity_server_scope(self):
        caller=auth.require_marketing_service(self.token(store_ids=["OTHER"],global_access=True),self.settings)
        caller.authorize("CP004")
        with self.assertRaises(HTTPException):caller.authorize("OTHER")
    def test_wrong_identity_expiry_audience_permission(self):
        for changes in ({"sub":"customer"},{"aud":"inventory-campaign-feedback"},{"purpose":"campaign_feedback"},{"permissions":[]},{"exp":1},{"iat":int(time.time())+500}):
            with self.assertRaises(HTTPException):auth.require_marketing_service(self.token(**changes),self.settings)
        with self.assertRaises(HTTPException):auth.require_marketing_service(None,self.settings)
    def test_missing_configuration(self):
        with patch.dict("os.environ",{},clear=True):
            with self.assertRaises(HTTPException) as caught:auth.get_marketing_service_settings()
        self.assertEqual(caught.exception.status_code,503)
    def test_routes_reject_browser_and_feedback_tokens(self):
        app=FastAPI();app.include_router(routes.router)
        app.dependency_overrides[auth.get_marketing_service_settings]=lambda:self.settings
        with TestClient(app) as client:
            for path in ("/inventory-marketing/campaign-analysis/R1","/inventory-marketing/forecast-shares/S1"):
                self.assertEqual(client.get(path).status_code,401)
                self.assertEqual(client.get(path,headers={"Authorization":"Bearer "+self.token(aud="inventory-campaign-feedback").credentials}).status_code,401)
    def test_registration_once_without_importing_application(self):
        source=Path("app/main.py").read_text();tree=ast.parse(source)
        registrations=[n for n in ast.walk(tree) if isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute) and n.func.attr=="include_router"]
        self.assertEqual(sum(bool(n.args) and isinstance(n.args[0],ast.Name) and n.args[0].id=="inventory_marketing_planning_router" for n in registrations),1)
        app=FastAPI();app.include_router(routes.router)
        paths=[(r.path,tuple(sorted(r.methods))) for r in app.routes if r.path.startswith("/inventory-marketing")]
        self.assertEqual(len(paths),9);self.assertEqual(len(set(paths)),9)
