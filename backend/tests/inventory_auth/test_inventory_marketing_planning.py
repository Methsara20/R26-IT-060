"""Isolated planning contracts/services/routes; no application or live IO."""
import copy
from datetime import date, timedelta
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import Mock, patch
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError
from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.schemas.inventory_marketing_planning_schema import ForecastShareRequest, CampaignAnalysisRequest
from app.services.inventory_marketing_planning_service import (
    PlanningClaim, MarketingPlanningCaller, share_forecast, submit_campaign,
    accept_campaign, reject_campaign, read_assessment, read_forecast_share,
    list_campaign_assessments, ExistingPlanningSources,
)
from app.routes import inventory_marketing_planning_routes as routes
from app.security.inventory_permissions import get_current_inventory_user

class FakeRepository:
    def __init__(self):self.records={};self.lock=threading.Lock();self.writes=[]
    def publish(self,key,digest,owner,store,result):
        claim=self.claim("forecast-share",key,digest,owner,store)
        if claim.acquired:self.complete(claim,result);return result
        if claim.result is None:raise HTTPException(409,"REQUEST_IN_PROGRESS")
        return claim.result
    def claim(self,namespace,key,fingerprint,owner_id,store_id,payload=None):
        with self.lock:
            identity=(namespace,key)
            existing=self.records.get(identity)
            if existing:
                if (existing["fingerprint"],existing["owner_id"],existing["store_id"]) != (fingerprint,owner_id,store_id):
                    raise HTTPException(409,"REQUEST_CONFLICT")
                return PlanningClaim(namespace,key,"lease",False,copy.deepcopy(existing["result"]))
            self.records[identity]=dict(_id=key,fingerprint=fingerprint,owner_id=owner_id,store_id=store_id,
                lease="lease",state="PROCESSING",request=copy.deepcopy(payload),result=None)
            self.writes.append((namespace,"claim"))
            return PlanningClaim(namespace,key,"lease",True)
    def complete(self,claim,result):
        with self.lock:
            assert claim.acquired and claim.lease=="lease"
            record=self.records[(claim.namespace,claim.key)]
            assert record["result"] is None
            record["result"]=copy.deepcopy(result)
            self.writes.append((claim.namespace,"complete"))
    def get(self,namespace,key):return copy.deepcopy(self.records.get((namespace,key)))
    def public_campaign(self,record):
        value={**record.get("request",{}),"request_id":record["_id"],"request_status":record["state"]}
        if record.get("result") is not None:value["assessment"]=copy.deepcopy(record["result"])
        if record.get("review") is not None:value["review"]=copy.deepcopy(record["review"])
        if record["state"]=="REJECTED":value["rejection_reason"]=record["rejection_reason"]
        return value
    def submit_campaign(self,key,digest,owner,store,payload):
        identity=("campaign-analysis",key)
        with self.lock:
            current=self.records.get(identity)
            if current:
                if (current["fingerprint"],current["owner_id"],current["store_id"]) != (digest,owner,store):
                    raise HTTPException(409,"REQUEST_CONFLICT")
                return self.public_campaign(current)
            self.records[identity]=dict(_id=key,fingerprint=digest,owner_id=owner,store_id=store,
                lease="lease",state="PENDING_REVIEW",request=copy.deepcopy(payload),result=None)
            self.writes.append(("campaign-analysis","submit"))
            return self.public_campaign(self.records[identity])
    def begin_review(self,key,review):
        with self.lock:
            record=self.records[("campaign-analysis",key)]
            if record["state"]!="PENDING_REVIEW":raise HTTPException(409,"decided")
            record["state"]="PROCESSING";record["review"]=copy.deepcopy(review)
            self.writes.append(("campaign-analysis","begin"))
            return PlanningClaim("campaign-analysis",key,"lease",True,payload=copy.deepcopy(record["request"]))
    def finish_review(self,claim,state,result):
        with self.lock:
            record=self.records[(claim.namespace,claim.key)]
            if record["state"]!="PROCESSING":raise HTTPException(409,"decided")
            record["state"]=state;record["result"]=copy.deepcopy(result)
            self.writes.append(("campaign-analysis","finish"))
    def reject_campaign(self,key,reason,review):
        with self.lock:
            record=self.records[("campaign-analysis",key)]
            if record["state"]!="PENDING_REVIEW":raise HTTPException(409,"decided")
            record.update(state="REJECTED",review=copy.deepcopy(review),rejection_reason=reason)
            self.writes.append(("campaign-analysis","reject"));return self.public_campaign(record)
    def list_campaigns(self,store_ids,skip,limit,owner_id=None):
        rows=[record for (namespace,_),record in self.records.items()
              if namespace=="campaign-analysis" and (store_ids is None or record["store_id"] in store_ids)
              and (owner_id is None or record["owner_id"]==owner_id)]
        return {"items":[self.public_campaign(row) for row in rows[skip:skip+limit]],
                "total":len(rows),"skip":skip,"limit":limit}

class PlanningTests(unittest.TestCase):
    def setUp(self):
        self.mongo=patch("pymongo.MongoClient",side_effect=AssertionError("Mongo forbidden"))
        self.mongo.start();self.addCleanup(self.mongo.stop)
        self.network=patch("socket.create_connection",side_effect=AssertionError("Network forbidden"))
        self.network.start();self.addCleanup(self.network.stop)
        self.repo=FakeRepository()
        self.user=InventoryPrincipal(user_id="oid:0123456789abcdef01234567",username_normalized="fixture",
           display_name="Fixture",role="manager",store_ids=("CP004",),global_access=False)
        self.caller=MarketingPlanningCaller("marketing-staff-1",("CP004",))
        self.source=Mock()
        self.workflow={"workflow_id":"WF1","workflow_status":"NO_ACTION_REQUIRED","product_id":"P1","store_id":"CP004",
          "forecast_result":{"forecast_start_date":"2026-11-01","forecast_end_date":"2026-11-03","forecast_total_demand":12},
          "inventory_snapshot":{"current_stock":30},"inventory_intelligence":{"recommended_action":"PROMOTE","recommendation_reason":"Excess stock"},
          "updated_at":"2026-10-16T00:00:00Z"}
        self.source.workflow.return_value=self.workflow
        self.source.stock.return_value={"store_id":"CP004","product_id":"P1","current_stock":30}
        self.source.product.return_value={"product_id":"P1","selling_price":100}
        today=date.today()
        self.payload=dict(request_id="REQ1",campaign_reference="CAM1",campaign_name="Campaign",product_id="P1",store_id="CP004",
          campaign_start_date=(today+timedelta(days=1)).isoformat(),campaign_end_date=(today+timedelta(days=3)).isoformat(),
          promotion_type="discount",discount_percent=20)
        self.source.baseline.return_value={"start_date":self.payload["campaign_start_date"],"end_date":self.payload["campaign_end_date"],"total_predicted_demand":12}
    def request(self,**changes):return CampaignAnalysisRequest(**{**self.payload,**changes})
    def share(self):return share_forecast(ForecastShareRequest(workflow_id="WF1",confirmed=True),self.user,self.source,self.repo)

    def test_explicit_share_dedup_and_legacy_projection(self):
        original=copy.deepcopy(self.workflow)
        result=self.share();replay=self.share()
        self.assertEqual(result,replay);self.assertEqual(len(self.repo.writes),2)
        self.assertEqual(result["forecast_demand"],12)
        self.assertEqual(result["promotion_recommendation"],"PROMOTE")
        self.assertEqual(original,self.workflow)
        self.source.baseline.assert_not_called()
        self.assertEqual(read_forecast_share(result["share_id"],self.caller,self.repo),result)

    def test_confirmation_required(self):
        for value in (False,"true",1):
            with self.assertRaises(ValidationError):ForecastShareRequest(workflow_id="WF1",confirmed=value)
        self.assertEqual(self.repo.writes,[])

    def test_share_roles_and_scope(self):
        for role in ("operator","viewer"):
            with self.assertRaises(HTTPException):share_forecast(ForecastShareRequest(workflow_id="WF1",confirmed=True),self.user.model_copy(update={"role":role}),self.source,self.repo)
        self.workflow["store_id"]="OTHER"
        with self.assertRaises(HTTPException):self.share()
        self.assertEqual(self.repo.writes,[])
        self.source.baseline.assert_not_called()

    def test_admin_does_not_imply_global(self):
        self.user=self.user.model_copy(update={"role":"admin","store_ids":()})
        with self.assertRaises(HTTPException):self.share()
        self.user=self.user.model_copy(update={"global_access":True})
        self.assertEqual(self.share()["share_status"],"SHARED")

    def test_changed_workflow_conflict(self):
        self.share();self.workflow["forecast_result"]["forecast_total_demand"]=99
        with self.assertRaises(HTTPException) as caught:self.share()
        self.assertEqual(caught.exception.status_code,409)

    def test_analysis_submission_then_manual_baseline(self):
        pending=submit_campaign(self.request(),self.caller,self.source,self.repo)
        self.assertEqual(pending["request_status"],"PENDING_REVIEW");self.source.baseline.assert_not_called()
        result=accept_campaign("REQ1",self.user,self.source,self.repo)
        self.source.baseline.assert_called_once()
        self.assertFalse(result["promotion_adjusted"])
        self.assertEqual(result["stock_sufficiency"],"SUFFICIENT")
        self.assertEqual(result["assessment_status"],"COMPLETED")
        self.assertEqual(read_assessment("REQ1",self.caller,self.repo)["assessment"],{k:v for k,v in result.items() if k!="review"})
        self.assertEqual({w[0] for w in self.repo.writes},{"campaign-analysis"})

    def test_completed_replay_does_not_reread_changed_inventory(self):
        submit_campaign(self.request(),self.caller,self.source,self.repo)
        result=accept_campaign("REQ1",self.user,self.source,self.repo)
        self.source.stock.reset_mock();self.source.product.reset_mock()
        self.source.stock.side_effect=AssertionError("must not reread stock")
        self.assertEqual(read_assessment("REQ1",self.caller,self.repo)["assessment"],{k:v for k,v in result.items() if k!="review"})
        self.source.stock.assert_not_called();self.source.product.assert_not_called()

    def test_unsupported_period_never_infers_uplift(self):
        submit_campaign(self.request(campaign_end_date=(date.today()+timedelta(days=30)).isoformat()),self.caller,self.source,self.repo)
        result=accept_campaign("REQ1",self.user,self.source,self.repo)
        self.assertIsNone(result["forecast_demand"])
        self.assertEqual(result["assessment_status"],"UNSUPPORTED_PERIOD")
        self.source.baseline.assert_not_called()

    def test_missing_price_or_model_failure(self):
        self.source.product.return_value={"product_id":"P1"}
        submit_campaign(self.request(),self.caller,self.source,self.repo)
        result=accept_campaign("REQ1",self.user,self.source,self.repo)
        self.assertEqual(result["assessment_status"],"FAILED")
        self.source.baseline.assert_not_called()
        self.assertIsNone(result["forecast_demand"])

    def test_campaign_authorization_before_reads(self):
        with self.assertRaises(HTTPException):submit_campaign(self.request(),MarketingPlanningCaller("x",("OTHER",)),self.source,self.repo)
        self.source.stock.assert_not_called();self.source.baseline.assert_not_called()
        self.assertEqual(self.repo.writes,[])

    def test_request_validation_and_forged_stock(self):
        for changes in ({"store_id":" CP004"},{"product_id":4},{"campaign_end_date":"2000-01-01"},{"request_status":"COMPLETED"},{"discount_percent":101}):
            with self.assertRaises(ValidationError):self.request(**changes)
        self.source.stock.return_value={"store_id":"OTHER","product_id":"P1","current_stock":30}
        with self.assertRaises(HTTPException):submit_campaign(self.request(),self.caller,self.source,self.repo)
        self.assertEqual(self.repo.writes,[])

    def test_request_conflict_and_ownership(self):
        submit_campaign(self.request(),self.caller,self.source,self.repo)
        with self.assertRaises(HTTPException):submit_campaign(self.request(discount_percent=30),self.caller,self.source,self.repo)
        with self.assertRaises(HTTPException):read_assessment("REQ1",MarketingPlanningCaller("other",("CP004",)),self.repo)

    def test_marketing_history_is_owner_and_store_scoped(self):
        submit_campaign(self.request(),self.caller,self.source,self.repo)
        other=self.request(request_id="REQ2",campaign_reference="CAM2")
        submit_campaign(other,MarketingPlanningCaller("other",("CP004",)),self.source,self.repo)
        hidden=self.request(request_id="REQ3",campaign_reference="CAM3",store_id="CP999")
        self.source.stock.return_value={"store_id":"CP999","product_id":"P1","current_stock":30}
        submit_campaign(hidden,MarketingPlanningCaller(self.caller.subject,("CP999",)),self.source,self.repo)
        result=list_campaign_assessments(self.caller,self.repo,0,50)
        self.assertEqual([item["request_id"] for item in result["items"]],["REQ1"])

    def test_concurrent_share_one_result(self):
        def attempt(_):
            try:return self.share()
            except HTTPException as exc:
                self.assertEqual(exc.status_code,409)
                return None
        with ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(attempt,range(2)))
        completed=[r for r in results if r is not None]
        self.assertTrue(completed)
        self.assertEqual(self.share(),completed[0]);self.assertEqual(len(self.repo.writes),2)

    def test_routes_disabled_without_marketing_auth_or_storage(self):
        app=FastAPI();app.include_router(routes.router)
        app.dependency_overrides[get_current_inventory_user]=lambda:self.user
        with TestClient(app) as client:
            response=client.post("/inventory-marketing/campaign-analysis",json=self.payload)
            self.assertEqual(response.status_code,503)
            self.assertEqual(client.post("/inventory-marketing/forecast-shares",json={"workflow_id":"WF1","confirmed":True}).status_code,503)
        self.assertEqual(self.repo.writes,[])

    def test_isolated_routes_explicit_share_and_analysis(self):
        app=FastAPI();app.include_router(routes.router)
        app.dependency_overrides[get_current_inventory_user]=lambda:self.user
        app.dependency_overrides[routes.marketing_planning_user]=lambda:self.caller
        app.dependency_overrides[routes.campaign_planning_repository]=lambda:self.repo
        app.dependency_overrides[routes.forecast_sharing_repository]=lambda:self.repo
        app.dependency_overrides[routes.planning_sources]=lambda:self.source
        with TestClient(app) as client:
            self.assertEqual(client.post("/inventory-marketing/forecast-shares",json={"workflow_id":"WF1","confirmed":False}).status_code,422)
            self.assertEqual(client.post("/inventory-marketing/campaign-analysis",json=self.payload).status_code,200)
            self.source.baseline.assert_not_called()
            self.assertEqual(self.repo.writes[0][0],"campaign-analysis")
            # Analysis never publishes a share.
            self.assertNotIn("forecast-share",[w[0] for w in self.repo.writes])
            self.assertEqual(client.get("/inventory-marketing/campaign-reviews").json()["total"],1)
            accepted=client.post("/inventory-marketing/campaign-reviews/REQ1/accept")
            self.assertEqual(accepted.status_code,200,accepted.text)
            self.assertEqual(accepted.json()["assessment_status"],"COMPLETED")
            second={**self.payload,"request_id":"REQ2","campaign_reference":"CAM2"}
            self.assertEqual(client.post("/inventory-marketing/campaign-analysis",json=second).status_code,200)
            rejected=client.post("/inventory-marketing/campaign-reviews/REQ2/reject",
                json={"reason":"Inventory review declined this campaign."})
            self.assertEqual(rejected.status_code,200,rejected.text)
            self.assertEqual(rejected.json()["request_status"],"REJECTED")
            self.assertEqual(client.post("/inventory-marketing/forecast-shares",json={"workflow_id":"WF1","confirmed":True}).status_code,200)
            self.assertEqual(client.get("/inventory-marketing/campaign-analysis/REQ1").status_code,200)


    def test_existing_custom_forecast_adapter_baseline_only(self):
        import sys,types
        module=types.ModuleType("app.services.daily_forecast_service")
        module.generate_custom_forecast=Mock(return_value=self.source.baseline.return_value)
        with patch.dict(sys.modules,{"app.services.daily_forecast_service":module}):
            result=ExistingPlanningSources().baseline(self.request(discount_percent=90),100)
        args=module.generate_custom_forecast.call_args.kwargs
        self.assertEqual(args["payload"]["promotion_percent"],0)
        self.assertEqual(args["payload"]["price_lkr"],100)
        self.assertEqual(args["payload"]["store_id"],"CP004")
        self.assertEqual(args["start_date"],self.request().campaign_start_date)
        self.assertEqual(result["total_predicted_demand"],12)

    def test_stock_adapter_exact_scope_duplicate_denial(self):
        query=Mock()
        query.where.return_value=query;query.limit.return_value=query
        query.stream.return_value=[Mock(to_dict=lambda:{"store_id":"CP004","product_id":"P1","current_stock":30})]
        with patch("app.services.firebase_service.get_collection",return_value=query) as collection:
            stock=ExistingPlanningSources().stock("CP004","P1")
        collection.assert_called_once_with("inventory_current")
        self.assertEqual(stock["current_stock"],30)
        self.assertEqual(query.where.call_args_list[0].args,("store_id","==","CP004"))
        self.assertEqual(query.where.call_args_list[1].args,("product_id","==","P1"))
        query.stream.return_value=[Mock(),Mock()]
        with patch("app.services.firebase_service.get_collection",return_value=query):
            with self.assertRaises(HTTPException):ExistingPlanningSources().stock("CP004","P1")

    def test_shortfall_and_in_progress_no_reinference(self):
        self.source.baseline.return_value["total_predicted_demand"]=30.1
        submit_campaign(self.request(),self.caller,self.source,self.repo)
        result=accept_campaign("REQ1",self.user,self.source,self.repo)
        self.assertEqual(result["stock_sufficiency"],"SHORTFALL")
        with self.assertRaises(HTTPException) as caught:
            accept_campaign("REQ1",self.user,self.source,self.repo)
        self.assertEqual(caught.exception.status_code,409)
        self.source.baseline.assert_called_once()
