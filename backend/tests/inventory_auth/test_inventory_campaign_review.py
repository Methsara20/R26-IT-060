"""Manual campaign-review tests; all persistence and inference are mocked."""
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta
from unittest.mock import Mock, patch

from fastapi import HTTPException

from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.schemas.inventory_marketing_planning_schema import CampaignAnalysisRequest
from app.services.inventory_marketing_planning_service import (
    MarketingPlanningCaller, accept_campaign, list_campaign_reviews,
    read_assessment, read_campaign_review, reject_campaign, submit_campaign,
)
from tests.inventory_auth.test_inventory_marketing_planning import FakeRepository


class CampaignReviewTests(unittest.TestCase):
    def setUp(self):
        for target in ("pymongo.MongoClient", "socket.create_connection"):
            guard=patch(target,side_effect=AssertionError("live IO forbidden"));guard.start();self.addCleanup(guard.stop)
        self.repo=FakeRepository();self.source=Mock();self.caller=MarketingPlanningCaller("marketing-service",("CP004",))
        self.source.stock.return_value={"store_id":"CP004","product_id":"P1","current_stock":40}
        self.source.product.return_value={"product_id":"P1","selling_price":100}
        start=date.today()+timedelta(days=1);end=start+timedelta(days=2)
        self.request=CampaignAnalysisRequest(request_id="REQ1",campaign_reference="CAM1",
            campaign_name="Campaign",product_id="P1",store_id="CP004",
            campaign_start_date=start,campaign_end_date=end,promotion_type="discount",discount_percent=10)
        self.source.baseline.return_value={"start_date":start.isoformat(),"end_date":end.isoformat(),"total_predicted_demand":20}
        self.manager=self.user("manager",("CP004",))
    @staticmethod
    def user(role,stores=(),global_access=False):
        return InventoryPrincipal(user_id="oid:0123456789abcdef01234567",username_normalized="reviewer",
            display_name="Inventory Reviewer",role=role,store_ids=stores,global_access=global_access)
    def submit(self):return submit_campaign(self.request,self.caller,self.source,self.repo)

    def test_submission_is_pending_and_never_forecasts(self):
        result=self.submit();self.assertEqual(result["request_status"],"PENDING_REVIEW")
        self.source.baseline.assert_not_called()
        self.assertEqual(read_assessment("REQ1",self.caller,self.repo)["request_status"],"PENDING_REVIEW")

    def test_read_roles_store_scope_and_admin_not_implicitly_global(self):
        self.submit()
        for role in ("admin","manager","analyst"):
            self.assertEqual(read_campaign_review("REQ1",self.user(role,("CP004",)),self.repo)["request_id"],"REQ1")
        for user in (self.user("operator",("CP004",)),self.user("viewer",("CP004",)),self.user("admin",())):
            with self.assertRaises(HTTPException):read_campaign_review("REQ1",user,self.repo)
        self.assertEqual(read_campaign_review("REQ1",self.user("admin",(),True),self.repo)["request_id"],"REQ1")

    def test_accept_roles_identity_and_assessment_once(self):
        self.submit();result=accept_campaign("REQ1",self.manager,self.source,self.repo)
        self.assertEqual(result["assessment_status"],"COMPLETED")
        self.assertEqual(result["review"]["reviewer_id"],self.manager.user_id)
        self.assertEqual(result["review"]["reviewer_role_snapshot"],"manager")
        self.source.baseline.assert_called_once()
        with self.assertRaises(HTTPException):accept_campaign("REQ1",self.manager,self.source,self.repo)
        self.source.baseline.assert_called_once()

    def test_reject_never_assesses_and_records_server_identity(self):
        self.submit();result=reject_campaign("REQ1","Campaign timing is unsafe.",self.manager,self.repo)
        self.assertEqual(result["request_status"],"REJECTED")
        self.assertEqual(result["review"]["reviewer_username_snapshot"],"reviewer")
        self.assertEqual(result["rejection_reason"],"Campaign timing is unsafe.")
        self.source.baseline.assert_not_called()
        self.assertEqual(read_assessment("REQ1",self.caller,self.repo)["request_status"],"REJECTED")

    def test_analyst_cannot_decide_and_unrelated_store_denied_before_inference(self):
        self.submit()
        for user in (self.user("analyst",("CP004",)),self.user("manager",("OTHER",))):
            with self.assertRaises(HTTPException):accept_campaign("REQ1",user,self.source,self.repo)
            with self.assertRaises(HTTPException):reject_campaign("REQ1","Rejected safely.",user,self.repo)
        self.source.baseline.assert_not_called()

    def test_concurrent_reviewers_only_one_decides(self):
        self.submit();barrier=threading.Barrier(2)
        def decide(action):
            barrier.wait()
            try:
                return ("ok",accept_campaign("REQ1",self.manager,self.source,self.repo)) if action=="accept" else (
                    "ok",reject_campaign("REQ1","Not approved.",self.user("admin",("CP004",)),self.repo))
            except HTTPException as exc:return ("denied",exc.status_code)
        with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(decide,("accept","reject")))
        self.assertEqual(sum(value[0]=="ok" for value in results),1)
        self.assertIn(self.repo.get("campaign-analysis","REQ1")["state"],("COMPLETED","REJECTED"))

    def test_list_filters_before_count(self):
        self.submit();listing=list_campaign_reviews(self.manager,self.repo)
        self.assertEqual(listing["total"],1)
        with self.assertRaises(HTTPException):list_campaign_reviews(self.user("viewer",("CP004",)),self.repo)


if __name__ == "__main__": unittest.main()
