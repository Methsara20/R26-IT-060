"""Pure fixtures only: no database, application startup or callback exposure."""
import copy
import unittest
from unittest.mock import patch
from pydantic import ValidationError
from app.schemas.inventory_campaign_feedback_schema import InventoryCampaignFeedback
from app.services.inventory_campaign_feedback_service import (
    CampaignFeedbackError, CampaignFeedbackState, plan_campaign_feedback,
)

class CampaignFeedbackTests(unittest.TestCase):
    def setUp(self):
        self.opportunity = dict(opportunity_id="MKT-OPP-ABC", product_id="P001", store_id="CP004",
                                current_stock=100, forecast_demand=20, status="PENDING_MARKETING")
        self.payload = dict(event_id="event-1", campaign_id="campaign-1", opportunity_id="MKT-OPP-ABC",
                            product_id="P001", store_id="CP004", revision=1, campaign_status="DRAFT",
                            campaign_start_date="2026-10-01", campaign_end_date="2026-10-31")
        self.network = patch("socket.create_connection", side_effect=AssertionError("Network forbidden"))
        self.network.start(); self.addCleanup(self.network.stop)

    def event(self, **changes):
        return InventoryCampaignFeedback(**{**self.payload, **changes})

    def test_legacy_opportunity_unchanged(self):
        original = copy.deepcopy(self.opportunity)
        result = plan_campaign_feedback(self.opportunity, self.event())
        self.assertFalse(result.duplicate)
        self.assertEqual(self.opportunity, original)
        self.assertIsNone(result.state.snapshot["performance"])
        self.assertNotIn("current_stock", result.state.snapshot)

    def test_exact_duplicate_no_new_state(self):
        first = plan_campaign_feedback(self.opportunity, self.event())
        duplicate = plan_campaign_feedback(self.opportunity, self.event(), first.state)
        self.assertTrue(duplicate.duplicate)
        self.assertEqual(duplicate.state, first.state)

    def test_conflicting_event_id(self):
        first = plan_campaign_feedback(self.opportunity, self.event()).state
        with self.assertRaises(CampaignFeedbackError):
            plan_campaign_feedback(self.opportunity, self.event(campaign_status="SCHEDULED"), first)

    def test_scope_mismatch(self):
        for key in ("opportunity_id", "product_id", "store_id"):
            with self.subTest(key=key), self.assertRaises(CampaignFeedbackError):
                plan_campaign_feedback(self.opportunity, self.event(**{key:"OTHER"}))

    def test_stale_and_skipped_revision(self):
        state = plan_campaign_feedback(self.opportunity, self.event()).state
        for revision in (1,3):
            with self.assertRaises(CampaignFeedbackError):
                plan_campaign_feedback(self.opportunity, self.event(event_id="new", revision=revision), state)

    def test_lifecycle_and_old_event_replay(self):
        state = None
        for i,status in enumerate(["DRAFT","SCHEDULED","ACTIVE","PAUSED","ACTIVE","COMPLETED"],1):
            state = plan_campaign_feedback(self.opportunity, self.event(event_id=f"event-{i}",revision=i,campaign_status=status),state).state
        replay = plan_campaign_feedback(self.opportunity,self.event(),state)
        self.assertTrue(replay.duplicate)
        self.assertEqual(replay.state.snapshot["revision"],6)
        with self.assertRaises(CampaignFeedbackError):
            plan_campaign_feedback(self.opportunity,self.event(event_id="event-7",revision=7,campaign_status="ACTIVE"),state)

    def test_campaign_binding(self):
        state = plan_campaign_feedback(self.opportunity,self.event()).state
        with self.assertRaises(CampaignFeedbackError):
            plan_campaign_feedback(self.opportunity,self.event(campaign_id="other",event_id="next",revision=2),state)

    def test_invalid_contract(self):
        for changes in [{"store_id":" CP004"},{"product_id":12},{"revision":True},
                        {"campaign_end_date":"2026-09-01"},{"campaign_status":"SENT"},
                        {"inventory_quantity":100},{"promotion":{"offer_type":"discount","discount_percent":101}}]:
            with self.subTest(changes=changes), self.assertRaises(ValidationError): self.event(**changes)

    def test_zero_metrics_not_missing(self):
        e=self.event(performance={"period_start":"2026-10-01","period_end":"2026-10-02",
             "source":"marketing","attribution_method":"reported","clicks":0})
        result=plan_campaign_feedback(self.opportunity,e).state.snapshot["performance"]
        self.assertEqual(result["clicks"],0)
        self.assertIsNone(result["redemptions"])

    def test_bad_persisted_state_fails_closed(self):
        for state in [CampaignFeedbackState({"revision":1}),CampaignFeedbackState(receipts={"old":"a"*64})]:
            with self.assertRaises(CampaignFeedbackError):plan_campaign_feedback(self.opportunity,self.event(),state)

    def test_existing_opportunity_reader_shape_remains_compatible(self):
        self.assertEqual(self.opportunity["status"], "PENDING_MARKETING")
        self.assertNotIn("campaign_id", self.opportunity)
        self.assertNotIn("publication_key", self.opportunity)
