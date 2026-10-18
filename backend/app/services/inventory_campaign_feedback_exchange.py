"""Independent Inventory-contract exchange tooling; not wired into Marketing.

Disabled by default. No environment loading, scheduler, database client or HTTP
transport is supplied here. Marketing ownership approval is required for adapters.

Required durable adapter semantics:
* commit_linked_schedule must authenticate/authorize the caller, resolve the
  authoritative opportunity, and atomically save scheduled poster + immutable
  event. request_key must bind an identical payload to the same scheduled ID;
  conflicting reuse must fail. Unknown commit must be reconciled, not recreated.
* claim_committed returns only committed, due events under an exclusive expiring
  lease. Delivery/ retry/blocked updates MUST compare the lease token (CAS).
* Never regenerate payload/event ID on retry; callbacks never resend email.
There is intentionally no in-memory/non-transactional production fallback.
"""
from dataclasses import dataclass, field
from hashlib import sha256
from typing import Protocol, Callable
from urllib.parse import urlsplit
from uuid import uuid4
import time
import jwt
from cryptography.hazmat.primitives.serialization import load_pem_private_key
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey
from app.schemas.inventory_campaign_feedback_schema import (
    InventoryCampaignFeedback, CampaignFeedbackAcknowledgment,
)


class ExchangeUnavailable(ValueError):
    pass


@dataclass(frozen=True)
class ExchangeSettings:
    enabled: bool = False
    base_url: str = ""
    private_key: str = field(default="", repr=False)
    store_ids: tuple[str, ...] = ()
    global_access: bool = False

    def validate(self):
        try:
            if self.enabled is not True or type(self.global_access) is not bool:
                raise ValueError()
            url = urlsplit(self.base_url)
            if (url.scheme != "https" or not url.hostname or url.username or url.password
                    or url.query or url.fragment or url.path not in ("", "/")):
                raise ValueError()
            if not isinstance(self.store_ids, tuple) or any(
                not isinstance(s, str) or not s or s != s.strip() or not s.isprintable()
                for s in self.store_ids
            ) or (not self.store_ids and not self.global_access):
                raise ValueError()
            key = load_pem_private_key(self.private_key.encode(), password=None)
            if not isinstance(key, RSAPrivateKey) or key.key_size < 2048:
                raise ValueError()
            return key
        except Exception:
            raise ExchangeUnavailable("Feedback exchange is disabled or unavailable.") from None

    def authorize_store(self, store_id):
        if not self.global_access and store_id not in self.store_ids:
            raise ExchangeUnavailable("Feedback store scope denied.")


class LinkedScheduleStore(Protocol):
    def commit_linked_schedule(self, *, request_key: str, opportunity_id: str,
                              build_event: Callable) -> InventoryCampaignFeedback:
        """Atomic idempotent poster+outbox save; no email, HTTP or AI operations.

        Invoke build_event(stable_post_id, authoritative_opportunity) within the
        transaction before any writes. Do not return until commit is confirmed.
        Caller identity must be established by the approved Marketing adapter.
        """
        ...


def schedule_linked_feedback(*, settings, store, authorize, request_key,
                             opportunity_id, product_id, store_id, start_date, end_date):
    """Integration hook only; unlinked scheduling never calls this function.

    authorize is a trusted server-owned authorization adapter, never a body field.
    It must revalidate a backend-verifiable Marketing user and exact store scope.
    No default authorization provider or durable storage implementation exists.
    """
    settings.validate()
    settings.authorize_store(store_id)
    if not callable(authorize) or store is None or not isinstance(request_key, str) or not request_key.strip():
        raise ExchangeUnavailable("Linked scheduling authorization/storage is unavailable.")
    if authorize(opportunity_id, store_id) is not True:
        raise ExchangeUnavailable("Linked scheduling access denied.")

    def build_event(post_id, opportunity):
        if authorize(opportunity_id, store_id) is not True:
            raise ExchangeUnavailable("Linked scheduling access denied.")
        if not isinstance(opportunity, dict) or any(opportunity.get(k) != v for k, v in
                (("opportunity_id", opportunity_id), ("product_id", product_id), ("store_id", store_id))):
            raise ExchangeUnavailable("Linked opportunity scope mismatch.")
        if not isinstance(post_id, str) or not post_id or post_id != post_id.strip():
            raise ExchangeUnavailable("Invalid scheduled campaign identity.")
        campaign_id = "marketing-scheduled:" + post_id
        event_id = "marketing-scheduled-v1:" + sha256(campaign_id.encode()).hexdigest()
        try:
            return InventoryCampaignFeedback(event_id=event_id, campaign_id=campaign_id,
                opportunity_id=opportunity_id, product_id=product_id, store_id=store_id,
                revision=1, campaign_status="SCHEDULED", campaign_start_date=start_date,
                campaign_end_date=end_date)
        except Exception:
            raise ExchangeUnavailable("Invalid linked campaign fields.") from None
    return store.commit_linked_schedule(request_key=request_key, opportunity_id=opportunity_id,
                                       build_event=build_event)


@dataclass(frozen=True)
class FeedbackLease:
    event_id: str
    payload: str = field(repr=False)
    lease_token: str = field(repr=False)
    attempts: int = 0


class FeedbackOutbox(Protocol):
    def claim_committed(self) -> FeedbackLease | None: ...
    def delivered(self, lease: FeedbackLease): ...
    def retry(self, lease: FeedbackLease, delay_seconds: int, code: str): ...
    def blocked(self, lease: FeedbackLease, code: str): ...


def dispatch_feedback(settings, outbox, transport):
    """Deliver one leased committed event. transport must disable redirects.

    Transport interface: (url, headers, content, timeout, follow_redirects) ->
    response with status_code and json(). No default transport or live activation.
    Lease update failures propagate; lease expiry allows SAME-event replay later.
    """
    key = settings.validate()
    if outbox is None or not callable(transport):
        raise ExchangeUnavailable("Feedback delivery adapters are unavailable.")
    lease = outbox.claim_committed()
    if lease is None:
        return "EMPTY"
    try:
        event = InventoryCampaignFeedback.model_validate_json(lease.payload)
        if event.event_id != lease.event_id or type(lease.attempts) is not int or lease.attempts < 0:
            raise ValueError()
        settings.authorize_store(event.store_id)
    except Exception:
        outbox.blocked(lease, "INVALID_EVENT_OR_SCOPE")
        return "BLOCKED"
    if lease.attempts >= 6:
        outbox.blocked(lease, "RETRY_LIMIT")
        return "BLOCKED"
    now = int(time.time())
    token = jwt.encode({"iss": "marketing-service", "sub": "marketing-service",
        "aud": "inventory-campaign-feedback", "purpose": "campaign_feedback",
        "permissions": ["campaign-feedback:write"], "iat": now, "nbf": now,
        "exp": now + 120, "jti": uuid4().hex}, key, algorithm="RS256")
    try:
        response = transport(url=settings.base_url.rstrip("/") + "/marketing-opportunities/campaign-feedback",
            headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"},
            content=lease.payload, timeout=10, follow_redirects=False)
    except (TimeoutError, ConnectionError):
        response = None
    except Exception:
        # Transport adapters must normalize transient connection/timeout errors.
        outbox.blocked(lease, "TRANSPORT_FAILURE")
        return "BLOCKED"
    if response is None or response.status_code == 429 or 500 <= response.status_code <= 599:
        outbox.retry(lease, min(30 * 2 ** lease.attempts, 900), "OUTCOME_UNCONFIRMED")
        return "RETRY"
    if response.status_code != 200:
        outbox.blocked(lease, "CALLBACK_REJECTED")
        return "BLOCKED"
    try:
        acknowledgment = CampaignFeedbackAcknowledgment.model_validate(response.json())
        if (acknowledgment.event_id != event.event_id or acknowledgment.opportunity_id != event.opportunity_id
            or acknowledgment.accepted_revision != event.revision or acknowledgment.current_revision < event.revision):
            raise ValueError()
    except Exception:
        outbox.blocked(lease, "INVALID_ACKNOWLEDGMENT")
        return "BLOCKED"
    outbox.delivered(lease)
    return "DELIVERED"
