"""Independent exchange helpers with fake storage/transport; no live IO."""
import unittest
from dataclasses import replace
from unittest.mock import Mock, patch
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
import jwt
from app.services.inventory_campaign_feedback_exchange import (
    ExchangeSettings, ExchangeUnavailable, FeedbackLease, schedule_linked_feedback, dispatch_feedback,
)

class FakeAtomicStore:
    def __init__(self):
        self.saved = None
        self.writes = []
        self.opportunity = {"opportunity_id":"OPP1","product_id":"P1","store_id":"CP004"}
    def commit_linked_schedule(self, *, request_key, opportunity_id, build_event):
        event = build_event("POST1", self.opportunity)
        if self.saved is not None:
            if self.saved != (request_key,event): raise ExchangeUnavailable("Conflicting scheduling retry")
            return self.saved[1]
        self.saved = (request_key,event)
        self.writes.extend(["scheduled_poster","feedback_outbox"])
        return event

class ExchangeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.key = rsa.generate_private_key(public_exponent=65537,key_size=2048)
        cls.pem = cls.key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,
                                       serialization.NoEncryption()).decode()
    def setUp(self):
        self.settings=ExchangeSettings(True,"https://inventory.example",self.pem,("CP004",))
        self.store=FakeAtomicStore()
        self.arguments=dict(settings=self.settings,store=self.store,authorize=lambda *args:True,
            request_key="request-1",opportunity_id="OPP1",product_id="P1",store_id="CP004",
            start_date="2026-11-01",end_date="2026-11-30")
        self.network=patch("socket.create_connection",side_effect=AssertionError("Network forbidden"))
        self.network.start();self.addCleanup(self.network.stop)
        self.mongo=patch("pymongo.MongoClient",side_effect=AssertionError("Mongo forbidden"))
        self.mongo.start();self.addCleanup(self.mongo.stop)
    def lease(self):
        event=schedule_linked_feedback(**self.arguments)
        return event,FeedbackLease(event.event_id,event.model_dump_json(),"lease-1")
    def response(self,event,duplicate=False):
        return Mock(status_code=200,json=lambda:dict(event_id=event.event_id,opportunity_id=event.opportunity_id,
            accepted_revision=1,current_revision=1,duplicate=duplicate))

    def test_stable_schedule_event_and_no_extra_data(self):
        event=schedule_linked_feedback(**self.arguments)
        replay=schedule_linked_feedback(**self.arguments)
        self.assertEqual(event,replay)
        self.assertEqual(event.campaign_id,"marketing-scheduled:POST1")
        self.assertEqual(event.campaign_status,"SCHEDULED")
        self.assertEqual(event.revision,1)
        self.assertEqual(self.store.writes,["scheduled_poster","feedback_outbox"])
        self.assertFalse(set(event.model_dump()) & {"current_stock","forecast_demand","recipient_emails"})
        with self.assertRaises(ExchangeUnavailable):
            schedule_linked_feedback(**{**self.arguments,"end_date":"2026-12-01"})
        self.assertEqual(len(self.store.writes),2)

    def test_missing_authorization_disabled_and_scope(self):
        for changes in [{"authorize":None},{"authorize":lambda *a:False},{"store":None},
                        {"settings":ExchangeSettings()},{"store_id":"OTHER"}]:
            with self.assertRaises(ExchangeUnavailable):schedule_linked_feedback(**{**self.arguments,**changes})
        self.assertEqual(self.store.writes,[])

    def test_forged_linkage_no_writes(self):
        for key in ("product_id","store_id","opportunity_id"):
            with self.assertRaises(ExchangeUnavailable):schedule_linked_feedback(**{**self.arguments,key:"OTHER"})
        self.assertEqual(self.store.writes,[])

    def test_invalid_dates_before_persistence(self):
        with self.assertRaises(ExchangeUnavailable):
            schedule_linked_feedback(**{**self.arguments,"end_date":"2026-10-01"})
        self.assertEqual(self.store.writes,[])

    def test_success_duplicate_and_matching_service_claims(self):
        event,lease=self.lease()
        for duplicate in (False,True):
            outbox=Mock();outbox.claim_committed.return_value=lease
            transport=Mock(return_value=self.response(event,duplicate))
            self.assertEqual(dispatch_feedback(self.settings,outbox,transport),"DELIVERED")
            outbox.delivered.assert_called_once_with(lease)
            args=transport.call_args.kwargs
            self.assertFalse(args["follow_redirects"])
            self.assertEqual(args["content"],lease.payload)
            self.assertEqual(args["url"],"https://inventory.example/marketing-opportunities/campaign-feedback")
            claims=jwt.decode(args["headers"]["Authorization"].split()[1],self.key.public_key(),
                algorithms=["RS256"],issuer="marketing-service",audience="inventory-campaign-feedback")
            self.assertEqual(claims["purpose"],"campaign_feedback")
            self.assertEqual(claims["permissions"],["campaign-feedback:write"])
            self.assertLessEqual(claims["exp"]-claims["iat"],300)
            self.assertNotIn(self.pem,repr(self.settings))

    def test_transient_retry_preserves_event_and_payload(self):
        event,lease=self.lease()
        outbox=Mock();outbox.claim_committed.side_effect=[lease,replace(lease,attempts=1)]
        transport=Mock(side_effect=[TimeoutError(),self.response(event,True)])
        self.assertEqual(dispatch_feedback(self.settings,outbox,transport),"RETRY")
        self.assertEqual(dispatch_feedback(self.settings,outbox,transport),"DELIVERED")
        payloads=[call.kwargs["content"] for call in transport.call_args_list]
        self.assertEqual(payloads,[lease.payload,lease.payload])
        outbox.retry.assert_called_once_with(lease,30,"OUTCOME_UNCONFIRMED")
        self.assertEqual(len(self.store.writes),2)

    def test_http_failure_policy(self):
        _,lease=self.lease()
        for status in (401,403,409,422,302,429,500,503):
            outbox=Mock();outbox.claim_committed.return_value=lease
            result=dispatch_feedback(self.settings,outbox,Mock(return_value=Mock(status_code=status)))
            self.assertEqual(result,"RETRY" if status in (429,500,503) else "BLOCKED")
            outbox.delivered.assert_not_called()

    def test_disabled_invalid_config_no_claim_or_network(self):
        for settings in (ExchangeSettings(),replace(self.settings,private_key="invalid"),
                         replace(self.settings,base_url="http://inventory.example"),
                         replace(self.settings,base_url="https://user:secret@inventory.example")):
            outbox,transport=Mock(),Mock()
            with self.assertRaises(ExchangeUnavailable):dispatch_feedback(settings,outbox,transport)
            outbox.claim_committed.assert_not_called();transport.assert_not_called()

    def test_no_committed_event_no_delivery(self):
        outbox,transport=Mock(),Mock()
        outbox.claim_committed.return_value=None
        self.assertEqual(dispatch_feedback(self.settings,outbox,transport),"EMPTY")
        transport.assert_not_called()

    def test_bad_ack_and_exhausted_retries(self):
        event,lease=self.lease()
        outbox=Mock();outbox.claim_committed.return_value=lease
        response=self.response(event);response.json=lambda:{"event_id":"wrong"}
        self.assertEqual(dispatch_feedback(self.settings,outbox,Mock(return_value=response)),"BLOCKED")
        outbox.delivered.assert_not_called()
        outbox.claim_committed.return_value=replace(lease,attempts=6)
        transport=Mock()
        self.assertEqual(dispatch_feedback(self.settings,outbox,transport),"BLOCKED")
        transport.assert_not_called()
