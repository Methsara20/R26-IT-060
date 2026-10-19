"""Pure feedback planning plus transaction-aware callback orchestration.

The planner alone does not persist. accept_campaign_feedback uses the injected
Inventory repository for atomic state/receipt persistence; no transaction replay.
One campaign is bound to an opportunity in v1. Reassignment needs a new policy.
Events are complete campaign snapshots: omitted optional fields mean unknown.
No inventory, forecast, transfer or promotion records are changed.
"""
from copy import deepcopy
from dataclasses import dataclass, field
from hashlib import sha256
from collections.abc import Mapping
from app.schemas.inventory_campaign_feedback_schema import InventoryCampaignFeedback

class CampaignFeedbackError(ValueError):
    """Safe domain error without request/document contents."""

@dataclass(frozen=True)
class CampaignFeedbackState:
    snapshot: dict | None = None
    receipts: dict[str, str] = field(default_factory=dict)

@dataclass(frozen=True)
class CampaignFeedbackResult:
    state: CampaignFeedbackState
    duplicate: bool

TRANSITIONS = {
    "DRAFT": {"DRAFT", "SCHEDULED", "CANCELLED"},
    "SCHEDULED": {"SCHEDULED", "ACTIVE", "CANCELLED"},
    "ACTIVE": {"ACTIVE", "PAUSED", "COMPLETED", "CANCELLED"},
    "PAUSED": {"PAUSED", "ACTIVE", "COMPLETED", "CANCELLED"},
    "COMPLETED": {"COMPLETED"},
    "CANCELLED": {"CANCELLED"},
}

def plan_campaign_feedback(opportunity, event: InventoryCampaignFeedback,
                           state: CampaignFeedbackState | None = None):
    """Validate/plan only. Returned duplicate=False does not imply persistence."""
    if not isinstance(event, InventoryCampaignFeedback):
        raise CampaignFeedbackError("Validated feedback required.")
    # Revalidate even instances built through model_construct/model_copy.
    event = InventoryCampaignFeedback.model_validate(event.model_dump())
    if not isinstance(opportunity, Mapping) or any(
        opportunity.get(key) != getattr(event, key)
        for key in ("opportunity_id", "product_id", "store_id")
    ):
        raise CampaignFeedbackError("Opportunity scope mismatch.")
    state = state if state is not None else CampaignFeedbackState()
    if not isinstance(state, CampaignFeedbackState):
        raise CampaignFeedbackError("Invalid feedback state.")
    previous = None
    if state.snapshot is not None:
        try:
            previous = InventoryCampaignFeedback.model_validate(state.snapshot)
        except Exception:
            raise CampaignFeedbackError("Invalid stored feedback state.") from None
        if any(getattr(previous, key) != getattr(event, key) for key in
               ("campaign_id", "opportunity_id", "product_id", "store_id")):
            raise CampaignFeedbackError("Campaign binding mismatch.")
    if (not isinstance(state.receipts, dict) or
        any(not isinstance(k, str) or not isinstance(v, str) or len(v) != 64
            for k, v in state.receipts.items()) or
        (previous is None and state.receipts)):
        raise CampaignFeedbackError("Invalid event receipts.")
    digest = sha256(event.model_dump_json().encode()).hexdigest()
    if previous is not None:
        previous_digest = sha256(previous.model_dump_json().encode()).hexdigest()
        if state.receipts.get(previous.event_id) != previous_digest:
            raise CampaignFeedbackError("Missing current event receipt.")
    if event.event_id in state.receipts:
        if state.receipts[event.event_id] != digest:
            raise CampaignFeedbackError("Event ID reused with different payload.")
        return CampaignFeedbackResult(deepcopy(state), True)
    expected = previous.revision + 1 if previous else 1
    if event.revision != expected:
        raise CampaignFeedbackError("Stale or out-of-order campaign revision.")
    allowed = TRANSITIONS[previous.campaign_status] if previous else {"DRAFT", "SCHEDULED"}
    if event.campaign_status not in allowed:
        raise CampaignFeedbackError("Invalid campaign status transition.")
    receipts = {**state.receipts, event.event_id: digest}
    return CampaignFeedbackResult(CampaignFeedbackState(event.model_dump(mode="json"), receipts), False)


# Durable API orchestration. The pure reducer above remains usable independently.
def feedback_digest(event):
    return sha256(event.model_dump_json().encode()).hexdigest()


def _ack(event, current_revision, duplicate):
    return {"event_id": event.event_id, "opportunity_id": event.opportunity_id,
            "accepted_revision": event.revision, "current_revision": current_revision,
            "duplicate": duplicate}


def _duplicate_ack(repository, producer, event, digest, session=None):
    from app.security.inventory_marketing_service_auth import feedback_error
    receipt = repository.receipt(producer, event.event_id, session)
    if receipt is None:
        return None
    if (receipt.get("digest") != digest or receipt.get("opportunity_id") != event.opportunity_id
            or receipt.get("revision") != event.revision):
        raise feedback_error(409, "EVENT_CONFLICT")
    current = repository.current(event.opportunity_id, session)
    if current is None or type(current.get("revision")) is not int or current["revision"] < event.revision:
        raise feedback_error(503, "OUTCOME_UNKNOWN")
    try:
        snapshot = InventoryCampaignFeedback.model_validate(current["snapshot"])
        if current.get("producer_id") != producer or snapshot.revision != current["revision"] or any(
            getattr(snapshot, k) != getattr(event, k)
            for k in ("campaign_id", "opportunity_id", "product_id", "store_id")
        ):
            raise ValueError()
    except Exception:
        raise feedback_error(503, "OUTCOME_UNKNOWN") from None
    return _ack(event, current["revision"], True)


def accept_campaign_feedback(repository, identity, event):
    from fastapi import HTTPException
    from pymongo.errors import DuplicateKeyError, OperationFailure
    from app.security.inventory_marketing_service_auth import MarketingServiceIdentity, feedback_error
    from app.services.inventory_campaign_feedback_repository import UnknownFeedbackCommit
    if not isinstance(identity, MarketingServiceIdentity) or identity.producer_id != "marketing-service":
        raise feedback_error(401, "INVALID_SERVICE_IDENTITY")
    identity.authorize(event.store_id)
    producer = identity.producer_id
    digest = feedback_digest(event)
    try:
        repository.require_ready()
        with repository.transaction() as session:
            opportunity = repository.opportunity(event.opportunity_id, session)
            if opportunity is None:
                raise feedback_error(404, "OPPORTUNITY_NOT_FOUND")
            # Authorize actual stored scope before disclosing mismatches.
            identity.authorize(opportunity.get("store_id"))
            if any(opportunity.get(k) != getattr(event, k) for k in ("opportunity_id", "product_id", "store_id")):
                raise feedback_error(422, "OPPORTUNITY_SCOPE_MISMATCH")
            duplicate = _duplicate_ack(repository, producer, event, digest, session)
            if duplicate is not None:
                return duplicate
            current = repository.current(event.opportunity_id, session)
            state = CampaignFeedbackState()
            previous_revision = 0
            if current is not None:
                if current.get("producer_id") != producer:
                    raise feedback_error(409, "CAMPAIGN_BINDING_CONFLICT")
                previous = InventoryCampaignFeedback.model_validate(current["snapshot"])
                previous_revision = current["revision"]
                if type(previous_revision) is not int or previous_revision != previous.revision:
                    raise feedback_error(503, "FEEDBACK_UNAVAILABLE")
                receipt = repository.receipt(producer, previous.event_id, session)
                if receipt is None or receipt.get("opportunity_id") != event.opportunity_id or receipt.get("revision") != previous_revision:
                    raise feedback_error(503, "FEEDBACK_UNAVAILABLE")
                state = CampaignFeedbackState(current["snapshot"], {previous.event_id: receipt.get("digest")})
            try:
                planned = plan_campaign_feedback(opportunity, event, state)
            except CampaignFeedbackError as exc:
                codes = {"Campaign binding mismatch.": "CAMPAIGN_BINDING_CONFLICT",
                         "Stale or out-of-order campaign revision.": "REVISION_CONFLICT",
                         "Invalid campaign status transition.": "INVALID_TRANSITION",
                         "Event ID reused with different payload.": "EVENT_CONFLICT"}
                code = codes.get(str(exc))
                raise feedback_error(409 if code else 503, code or "FEEDBACK_UNAVAILABLE") from None
            repository.save(producer, event, digest, planned.state.snapshot, previous_revision, session)
        return _ack(event, event.revision, False)
    except UnknownFeedbackCommit:
        # A majority-visible receipt proves the atomic state+receipt commit. Absence
        # does NOT prove rollback. Never rerun the transaction body here.
        try:
            acknowledgment = _duplicate_ack(repository, producer, event, digest)
            if acknowledgment is not None:
                return acknowledgment
        except HTTPException as exc:
            if exc.status_code == 409:
                raise
        except Exception:
            pass
        raise feedback_error(503, "OUTCOME_UNKNOWN") from None
    except (DuplicateKeyError, OperationFailure) as exc:
        if isinstance(exc, DuplicateKeyError) or getattr(exc, "code", None) == 112:
            try:
                acknowledgment = _duplicate_ack(repository, producer, event, digest)
                if acknowledgment is not None:
                    return acknowledgment
            except HTTPException:
                raise
            except Exception:
                raise feedback_error(503, "FEEDBACK_UNAVAILABLE") from None
            raise feedback_error(409, "REVISION_CONFLICT") from None
        raise feedback_error(503, "FEEDBACK_UNAVAILABLE") from None
    except HTTPException:
        raise
    except Exception:
        raise feedback_error(503, "FEEDBACK_UNAVAILABLE") from None
