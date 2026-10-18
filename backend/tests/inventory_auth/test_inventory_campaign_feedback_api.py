"""Real router/repository with fake MongoDB/session; no full app or network."""
import copy
import threading
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace
from unittest.mock import patch
import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pymongo.errors import OperationFailure
from app.routes.marketing_opportunity_routes import router
from app.schemas.inventory_campaign_feedback_schema import InventoryCampaignFeedback
from app.security.inventory_marketing_service_auth import (
    MarketingServiceSettings, MarketingServiceIdentity, get_marketing_service_settings,
)
from app.services.inventory_campaign_feedback_dependencies import get_campaign_feedback_repository
from app.services.inventory_campaign_feedback_repository import InventoryCampaignFeedbackRepository, STATE, EVENTS
from app.services.inventory_campaign_feedback_service import accept_campaign_feedback


class Collection:
    def __init__(self, db, name):
        self.db, self.name = db, name
        self.rows = []
        self.indexes = [{"key": {"_id": 1}}] if name == STATE else [
            {"key": {"producer_id": 1, "event_id": 1}, "unique": True},
            {"key": {"opportunity_id": 1, "revision": 1}, "unique": True}]

    def list_indexes(self): return copy.deepcopy(self.indexes)
    def with_options(self, **options):
        assert options["read_concern"].level == "majority"
        return self
    def find_one(self, query, projection, session=None):
        self.db.reads.append((self.name, query, projection, session))
        return next((copy.deepcopy(r) for r in self.rows if all(r.get(k) == v for k,v in query.items())), None)
    def insert_one(self, document, session=None):
        assert session is not None and self.name in (STATE, EVENTS)
        self.db.writes.append((self.name, "insert"))
        if self.db.fail_event and self.name == EVENTS: raise OperationFailure("private detail")
        self.rows.append(copy.deepcopy(document))
        return SimpleNamespace(acknowledged=True)
    def update_one(self, query, update, session=None, upsert=False):
        assert session is not None and not upsert and self.name == STATE
        self.db.writes.append((self.name, "update"))
        for r in self.rows:
            if all(r.get(k)==v for k,v in query.items()):
                r.update(copy.deepcopy(update["$set"]))
                return SimpleNamespace(acknowledged=True, matched_count=1)
        return SimpleNamespace(acknowledged=True, matched_count=0)


class Session:
    def __init__(self, db): self.db, self.in_transaction = db, False
    def __enter__(self): return self
    def __exit__(self, *args):
        if self.in_transaction: self.abort_transaction()
    def start_transaction(self, **options):
        if self.db.unsupported: raise OperationFailure("transactions unavailable")
        assert options["write_concern"].document["w"] == "majority"
        assert options["read_concern"].level == "snapshot"
        self.db.lock.acquire()
        self.before = {k:copy.deepcopy(c.rows) for k,c in self.db.collections.items()}
        self.in_transaction = True
    def abort_transaction(self):
        for k,rows in self.before.items(): self.db.collections[k].rows = rows
        self.in_transaction = False
        self.db.lock.release()
    def commit_transaction(self):
        self.db.commits += 1
        if self.db.commit_mode == "unknown_absent":
            self.abort_transaction()
            raise OperationFailure("unknown private commit detail")
        self.in_transaction = False
        self.db.lock.release()
        if self.db.commit_mode == "unknown_present": raise OperationFailure("lost ack")


class Database:
    name = "smart_retail_db"
    def __init__(self):
        self.client = self
        self.collections = {}
        self.reads, self.writes = [], []
        self.commits = 0
        self.lock = threading.RLock()
        self.unsupported = self.fail_event = False
        self.commit_mode = "ok"
        self.missing = set()
    def get_collection(self, name):
        assert name in (STATE, EVENTS, "marketing_opportunities")
        if name not in self.collections: self.collections[name] = Collection(self, name)
        return self.collections[name]
    def list_collection_names(self, filter):
        name=filter["name"]
        return [] if name in self.missing else [name]
    def start_session(self):return Session(self)


class FeedbackApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Ephemeral test-only key; never persisted, configured or printed.
        cls.key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        cls.public=cls.key.public_key().public_bytes(serialization.Encoding.PEM,
            serialization.PublicFormat.SubjectPublicKeyInfo).decode()

    def setUp(self):
        self.mongo=patch("pymongo.MongoClient",side_effect=AssertionError("Mongo forbidden"))
        self.mongo.start();self.addCleanup(self.mongo.stop)
        self.network=patch("socket.create_connection",side_effect=AssertionError("Network forbidden"))
        self.network.start();self.addCleanup(self.network.stop)
        self.db=Database();self.repo=InventoryCampaignFeedbackRepository(self.db)
        self.repo.opportunities.rows=[{"_id":"OPP1","opportunity_id":"OPP1","store_id":"CP004","product_id":"P1"}]
        self.payload={"event_id":"E1","campaign_id":"C1","opportunity_id":"OPP1","product_id":"P1",
          "store_id":"CP004","revision":1,"campaign_status":"SCHEDULED",
          "campaign_start_date":"2026-10-01","campaign_end_date":"2026-10-31"}
        self.settings=MarketingServiceSettings(self.public,("CP004",))
        self.app=FastAPI();self.app.include_router(router)
        self.app.dependency_overrides[get_marketing_service_settings]=lambda:self.settings
        self.app.dependency_overrides[get_campaign_feedback_repository]=lambda:self.repo
        self.client=TestClient(self.app);self.addCleanup(self.client.close)

    def headers(self, **changes):
        now=int(time.time())
        claims={"iss":"marketing-service","sub":"marketing-service","aud":"inventory-campaign-feedback",
          "purpose":"campaign_feedback","iat":now,"nbf":now,"exp":now+120,"jti":"test",
          "permissions":["campaign-feedback:write"],**changes}
        return {"Authorization":"Bearer "+jwt.encode(claims,self.key,algorithm="RS256")}
    def send(self, changes=None, headers=None):
        return self.client.post("/marketing-opportunities/campaign-feedback",json={**self.payload,**(changes or {})},
          headers=self.headers() if headers is None else headers)

    def test_valid_and_duplicate(self):
        first=self.send();self.assertEqual(first.status_code,200,first.text)
        self.assertFalse(first.json()["duplicate"])
        count=len(self.db.writes)
        replay=self.send();self.assertEqual(replay.status_code,200)
        self.assertTrue(replay.json()["duplicate"]);self.assertEqual(len(self.db.writes),count)
        self.assertEqual({w[0] for w in self.db.writes},{STATE,EVENTS})
        self.assertEqual(self.repo.opportunities.rows[0]["store_id"],"CP004")

    def test_invalid_tokens_no_io(self):
        variants=[{}, {"Authorization":"Bearer invalid"}]
        for claims in [{"exp":int(time.time())-1},{"iss":"customer"},{"aud":"inventory-api"},
                       {"sub":"inventory-user"},{"purpose":"inventory_access"},{"permissions":[]},
                       {"exp":int(time.time())+600},{"iat":int(time.time())+20}]:
            variants.append(self.headers(**claims))
        for header in variants:
            response=self.send(headers=header)
            self.assertEqual(response.status_code,401,response.text)
        self.assertEqual(self.db.reads,[]);self.assertEqual(self.db.writes,[])

    def test_unconfigured_service(self):
        del self.app.dependency_overrides[get_marketing_service_settings]
        with patch.dict("os.environ",{},clear=True):
            self.assertEqual(self.send().status_code,503)
        self.assertEqual(self.db.writes,[])

    def test_store_scope_and_claim_escalation(self):
        response=self.send({"store_id":"CP002"},headers=self.headers(global_access=True,store_ids=["CP002"]))
        self.assertEqual(response.status_code,403)
        self.assertEqual(self.db.reads,[])
        self.settings=MarketingServiceSettings(self.public,(),True)
        self.repo.opportunities.rows[0]["store_id"]="CP002"
        self.assertEqual(self.send({"store_id":"CP002"}).status_code,200)

    def test_conflicts_and_linkage(self):
        self.assertEqual(self.send().status_code,200)
        for changes,code in [({"campaign_status":"DRAFT"},"EVENT_CONFLICT"),
          ({"event_id":"E2"},"REVISION_CONFLICT"),
          ({"event_id":"E2","revision":2,"campaign_id":"OTHER"},"CAMPAIGN_BINDING_CONFLICT"),
          ({"event_id":"E2","revision":2,"campaign_status":"COMPLETED"},"INVALID_TRANSITION")]:
            response=self.send(changes)
            self.assertEqual(response.status_code,409,response.text)
            self.assertEqual(response.json()["detail"]["code"],code)
        self.assertEqual(self.send({"product_id":"OTHER"}).status_code,422)
        self.assertEqual(self.send({"opportunity_id":"MISSING"}).status_code,404)
        self.assertEqual(len(self.repo.events.rows),1)

    def test_sanitized_validation(self):
        for changes in [{"store_id":" CP004"},{"revision":True},{"campaign_end_date":"invalid-private-value"},
                        {"password":"never-echo-this"},{"performance":{"clicks":-1}}]:
            response=self.send(changes)
            self.assertEqual(response.status_code,422,response.text)
            self.assertEqual(response.json(),{"detail":{"code":"INVALID_FEEDBACK"}})
        self.assertEqual(self.db.writes,[])

    def test_unknown_commit_reconciliation(self):
        self.db.commit_mode="unknown_present"
        response=self.send();self.assertEqual(response.status_code,200,response.text)
        self.assertEqual(self.db.commits,1);self.assertEqual(len(self.repo.events.rows),1)

    def test_unresolved_commit_no_replay(self):
        self.db.commit_mode="unknown_absent"
        response=self.send();self.assertEqual(response.status_code,503)
        self.assertEqual(response.json()["detail"]["code"],"OUTCOME_UNKNOWN")
        self.assertEqual(self.db.commits,1);self.assertEqual(self.repo.events.rows,[])

    def test_missing_storage_and_transactions(self):
        self.db.missing.add(STATE)
        self.assertEqual(self.send().status_code,503);self.assertEqual(self.db.writes,[])
        self.db.missing.clear();self.repo.events.indexes=[]
        self.assertEqual(self.send().status_code,503);self.assertEqual(self.db.writes,[])
        self.repo.events.indexes=[{"key":{"producer_id":1,"event_id":1},"unique":True},
                                {"key":{"opportunity_id":1,"revision":1},"unique":True}]
        self.db.unsupported=True
        self.assertEqual(self.send().status_code,503);self.assertEqual(self.db.writes,[])

    def test_receipt_failure_rolls_back_state(self):
        self.db.fail_event=True
        self.assertEqual(self.send().status_code,503)
        self.assertEqual(self.repo.state.rows,[]);self.assertEqual(self.repo.events.rows,[])

    def test_concurrent_revision_one_winner(self):
        identity=MarketingServiceIdentity("marketing-service",("CP004",))
        def attempt(event_id):
            try:
                return accept_campaign_feedback(self.repo,identity,InventoryCampaignFeedback(**{**self.payload,"event_id":event_id}))
            except HTTPException as e:return e.status_code
        with ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(attempt,["A","B"]))
        self.assertEqual(sum(isinstance(r,dict) for r in results),1)
        self.assertIn(409,results);self.assertEqual(len(self.repo.events.rows),1)

    def test_full_snapshot_zero_and_old_duplicate(self):
        self.assertEqual(self.send().status_code,200)
        metrics={"period_start":"2026-10-01","period_end":"2026-10-02","source":"marketing",
                 "attribution_method":"reported","clicks":0}
        response=self.send({"event_id":"E2","revision":2,"campaign_status":"ACTIVE","performance":metrics})
        self.assertEqual(response.status_code,200,response.text)
        saved=self.repo.state.rows[0]["snapshot"]["performance"]
        self.assertEqual(saved["clicks"],0);self.assertIsNone(saved["redemptions"])
        replay=self.send();self.assertTrue(replay.json()["duplicate"])
        self.assertEqual(replay.json()["current_revision"],2)

    def test_existing_publication_route_now_requires_inventory_identity(self):
        response=self.client.post("/marketing-opportunities/",json={"workflow_id":"WF1","product_id":"P1",
          "product_name":"Product","store_id":"CP004","current_stock":100,"forecast_demand":10,
          "required_stock":20,"excess_quantity":80,"stock_health":"OVERSTOCK","recommended_action":"PROMOTE"})
        self.assertEqual(response.status_code,401,response.text)
        paths=[r.path for r in self.app.routes]
        self.assertEqual(paths.count("/marketing-opportunities/"),1)
        self.assertEqual(paths.count("/marketing-opportunities/campaign-feedback"),1)


    def test_wrong_key_algorithm_and_missing_claims(self):
        bad_key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        original=self.headers()["Authorization"].split()[1]
        claims=jwt.decode(original,options={"verify_signature":False})
        tokens=[jwt.encode(claims,bad_key,algorithm="RS256"),
                jwt.encode(claims,"test-only-unrelated-key-0000000000000000",algorithm="HS256")]
        for field in ("sub","iss","aud","purpose","exp","iat","nbf","jti","permissions"):
            reduced={k:v for k,v in claims.items() if k!=field}
            tokens.append(jwt.encode(reduced,self.key,algorithm="RS256"))
        for token in tokens:
            self.assertEqual(self.send(headers={"Authorization":"Bearer "+token}).status_code,401)
        self.assertEqual(self.db.reads,[])

    def test_unsafe_indexes_fail_closed(self):
        original=copy.deepcopy(self.repo.events.indexes)
        for changes in [{"unique":False},{"sparse":True},{"partialFilterExpression":{"revision":{"$gt":0}}},
                        {"collation":{"locale":"en","strength":2}}]:
            self.repo.events.indexes=copy.deepcopy(original)
            self.repo.events.indexes[0].update(changes)
            self.assertEqual(self.send().status_code,503)
        self.repo.events.indexes=original+[{"key":{"received_at":1},"expireAfterSeconds":60}]
        self.assertEqual(self.send().status_code,503)
        self.assertEqual(self.db.writes,[])

    def test_lazy_dependency_reuses_handle(self):
        from app.services.inventory_campaign_feedback_dependencies import get_campaign_feedback_repository
        identity=MarketingServiceIdentity("marketing-service",("CP004",))
        wrapper=SimpleNamespace(db=self.db,client=self.db.client)
        with patch("app.services.inventory_campaign_feedback_dependencies.get_existing_inventory_mongo_wrapper",return_value=wrapper):
            repository=get_campaign_feedback_repository(identity)
        self.assertIs(repository.db,self.db)
        self.assertEqual(set(self.db.collections),{STATE,EVENTS,"marketing_opportunities"})
        self.assertEqual(self.db.reads,[])
        with patch("app.services.inventory_campaign_feedback_dependencies.get_existing_inventory_mongo_wrapper",side_effect=RuntimeError("private")):
            with self.assertRaises(HTTPException) as caught:get_campaign_feedback_repository(identity)
        self.assertEqual(caught.exception.detail,{"code":"FEEDBACK_UNAVAILABLE"})

    def test_same_event_different_opportunity_conflicts(self):
        self.assertEqual(self.send().status_code,200)
        self.repo.opportunities.rows.append({"_id":"OPP2","opportunity_id":"OPP2","product_id":"P1","store_id":"CP004"})
        response=self.send({"opportunity_id":"OPP2"})
        self.assertEqual(response.status_code,409)
        self.assertEqual(response.json()["detail"]["code"],"EVENT_CONFLICT")
        self.assertEqual(len(self.repo.state.rows),1)

    def test_concurrent_exact_replay_has_one_receipt(self):
        identity=MarketingServiceIdentity("marketing-service",("CP004",))
        event=InventoryCampaignFeedback(**self.payload)
        with ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(lambda _:accept_campaign_feedback(self.repo,identity,event),range(2)))
        self.assertEqual(sorted(r["duplicate"] for r in results),[False,True])
        self.assertEqual(len(self.repo.events.rows),1)
