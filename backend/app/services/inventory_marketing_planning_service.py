"""Explicit forecast sharing and campaign analysis; no automatic publication.

Storage is injected and unavailable by default. A production adapter must provide
atomic claims with unique (namespace,key), payload/owner binding, lease/CAS completion
and durable results. Never reclaim an unknown/in-progress claim automatically.
These results belong only to communication storage, not marketing_opportunities,
inventory, model predictions, movements or Marketing campaigns. The legacy publisher
is deliberately not called. Sharing this projection does not invoke forecasting.
"""
from dataclasses import dataclass
from datetime import date, datetime, timezone
from hashlib import sha256
import json
import math
from typing import Protocol
from fastapi import HTTPException
from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.schemas.inventory_marketing_planning_schema import ForecastShareRequest, CampaignAnalysisRequest
from app.security.inventory_permissions import require_roles, require_store_access
from app.security.inventory_resource_access import require_workflow_access


def error(status, code):
    return HTTPException(status, detail={"code": code})


@dataclass(frozen=True)
class MarketingPlanningCaller:
    """Mint only in a trusted backend-verifiable Marketing authorization adapter.

    This is not a request schema or an authentication implementation.
    """
    subject: str
    store_ids: tuple[str, ...]
    global_access: bool = False

    def authorize(self, store_id):
        if (not self.subject or type(self.global_access) is not bool or
                not isinstance(self.store_ids, tuple) or
                (not self.global_access and store_id not in self.store_ids)):
            raise error(403, "SCOPE_DENIED")


@dataclass(frozen=True)
class PlanningClaim:
    namespace: str
    key: str
    lease: str
    acquired: bool
    result: dict | None = None
    payload: dict | None = None


class PlanningRepository(Protocol):
    def publish(self, key, digest, owner, store, result):
        """Atomically persist the complete immutable share or return its exact replay."""
        ...
    def claim(self, namespace, key, fingerprint, owner_id, store_id, payload=None) -> PlanningClaim:
        """Atomic immutable binding; conflict on different payload/owner; no auto-retry."""
        ...
    def complete(self, claim, result):
        """CAS lease/state PROCESSING -> terminal result; return only after confirmed durability."""
        ...
    def get(self, namespace, key):
        """Return {owner_id, store_id, result}; projected read, no claim side effects."""
        ...


def fingerprint(value):
    return sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def quantity(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
        raise error(422, "INVALID_SOURCE_DATA")
    return value


def share_forecast(request: ForecastShareRequest, user: InventoryPrincipal, source, repository):
    if not isinstance(user, InventoryPrincipal):
        raise error(401, "INVALID_INVENTORY_IDENTITY")
    require_roles(user, "admin", "manager", "analyst")
    if request.confirmed is not True:
        raise error(422, "CONFIRMATION_REQUIRED")
    workflow = source.workflow(request.workflow_id)
    if workflow is None:
        raise error(404, "WORKFLOW_NOT_FOUND")
    require_workflow_access(user, workflow)
    if workflow.get("workflow_id") != request.workflow_id:
        raise error(422, "INVALID_SOURCE_DATA")
    if workflow.get("workflow_status") in ("ANALYZING", "FAILED", "PROCESSING"):
        raise error(409, "WORKFLOW_NOT_READY")
    forecast = workflow.get("forecast_result") or {}
    stock = workflow.get("inventory_snapshot") or {}
    try:
        start = date.fromisoformat(forecast["forecast_start_date"])
        end = date.fromisoformat(forecast["forecast_end_date"])
        if end < start:
            raise ValueError()
        product_id, store_id = workflow["product_id"], workflow["store_id"]
        if any(not isinstance(v, str) or not v or v != v.strip() or not v.isprintable() for v in (product_id, store_id)):
            raise ValueError()
        demand = quantity(forecast["forecast_total_demand"])
        available = quantity(stock["current_stock"])
    except (KeyError, TypeError, ValueError):
        raise error(422, "INVALID_SOURCE_DATA") from None
    intelligence = workflow.get("inventory_intelligence") or {}
    result = {"share_id": "FS-" + sha256(request.workflow_id.encode()).hexdigest(),
        "workflow_id": request.workflow_id, "product_id": product_id, "store_id": store_id,
        "forecast_start_date": start.isoformat(), "forecast_end_date": end.isoformat(),
        "forecast_demand": demand, "available_stock_snapshot": available,
        "snapshot_at": workflow.get("updated_at") or workflow.get("created_at"),
        "promotion_recommendation": intelligence.get("recommended_action") if intelligence.get("recommended_action") == "PROMOTE" else None,
        "recommendation_reason": intelligence.get("recommendation_reason"), "share_status": "SHARED"}
    # Any authorized Inventory user can reselect the same immutable workflow share;
    # attribution belongs to the first accepted share, not the latest caller.
    return repository.publish(result["share_id"], fingerprint(result),
        "inventory-workflow:" + request.workflow_id, store_id,
        {**result, "shared_by": user.user_id, "shared_at": datetime.now(timezone.utc).isoformat()})


def reviewer_snapshot(user, decision):
    if not isinstance(user, InventoryPrincipal):
        raise error(401, "INVALID_INVENTORY_IDENTITY")
    return {"reviewer_id": user.user_id,
        "reviewer_username_snapshot": user.username_normalized,
        "reviewer_display_name_snapshot": user.display_name,
        "reviewer_role_snapshot": user.role, "decision": decision,
        "decided_at": datetime.now(timezone.utc).isoformat()}


def submit_campaign(request: CampaignAnalysisRequest, caller, source, repository):
    if not isinstance(caller, MarketingPlanningCaller):
        raise error(401, "INVALID_MARKETING_IDENTITY")
    caller.authorize(request.store_id)
    stock = source.stock(request.store_id, request.product_id)
    product = source.product(request.product_id)
    if stock is None or product is None:
        raise error(404, "PRODUCT_OR_STORE_NOT_FOUND")
    if (stock.get("store_id") != request.store_id or stock.get("product_id") != request.product_id or
            product.get("product_id", request.product_id) != request.product_id):
        raise error(422, "INVALID_SOURCE_DATA")
    quantity(stock.get("current_stock"))
    return repository.submit_campaign(request.request_id,
        fingerprint(request.model_dump(mode="json")), caller.subject,
        request.store_id, request.model_dump(mode="json"))


def list_campaign_reviews(user, repository, skip=0, limit=50):
    require_roles(user, "admin", "manager", "analyst")
    return repository.list_campaigns(None if user.global_access else user.store_ids, skip, limit)


def list_campaign_assessments(caller, repository, skip=0, limit=50):
    if not isinstance(caller, MarketingPlanningCaller):
        raise error(401, "INVALID_MARKETING_IDENTITY")
    return repository.list_campaigns(
        None if caller.global_access else caller.store_ids,
        skip,
        limit,
        owner_id=caller.subject,
    )


def read_campaign_review(request_id, user, repository):
    require_roles(user, "admin", "manager", "analyst")
    record = repository.get("campaign-analysis", request_id)
    if record is None:
        raise error(404, "REQUEST_NOT_FOUND")
    require_store_access(user, record["store_id"])
    return repository.public_campaign(record)


def accept_campaign(request_id, user, source, repository, today=None):
    require_roles(user, "admin", "manager")
    record = repository.get("campaign-analysis", request_id)
    if record is None:
        raise error(404, "REQUEST_NOT_FOUND")
    require_store_access(user, record["store_id"])
    review = reviewer_snapshot(user, "ACCEPTED")
    claim = repository.begin_review(request_id, review)
    request = CampaignAnalysisRequest.model_validate(claim.payload)
    result = {"request_id": request.request_id, "campaign_reference": request.campaign_reference,
        "product_id": request.product_id, "store_id": request.store_id,
        "available_stock": None, "stock_read_at": None,
        "forecast_start_date": request.campaign_start_date.isoformat(),
        "forecast_end_date": request.campaign_end_date.isoformat(), "forecast_demand": None,
        "forecast_basis": "BASELINE_NO_PROMOTION", "promotion_adjusted": False,
        "stock_sufficiency": "UNKNOWN", "assessment_status": "UNSUPPORTED_PERIOD",
        "explanation": "Baseline forecasting supports future dates within 14 days. Promotional uplift is not assessed."}
    terminal = "UNSUPPORTED_PERIOD"
    today = today or date.today()
    try:
        stock = source.stock(request.store_id, request.product_id)
        product = source.product(request.product_id)
        if (stock is None or product is None or stock.get("store_id") != request.store_id or
                stock.get("product_id") != request.product_id or
                product.get("product_id", request.product_id) != request.product_id):
            raise ValueError()
        available = quantity(stock.get("current_stock"))
        result.update(available_stock=available,
            stock_read_at=datetime.now(timezone.utc).isoformat())
    except Exception:
        result.update(assessment_status="FAILED",
            explanation="Stock assessment failed. No promotional uplift prediction was produced.")
        repository.finish_review(claim, "FAILED", result)
        return {**result, "review": review}
    if today < request.campaign_start_date <= request.campaign_end_date and (request.campaign_end_date - today).days <= 14:
        try:
            price = quantity(product.get("selling_price"))
            if price == 0:
                raise ValueError()
            forecast = source.baseline(request, price)
            if (forecast.get("start_date") != request.campaign_start_date.isoformat() or
                    forecast.get("end_date") != request.campaign_end_date.isoformat()):
                raise ValueError()
            demand = quantity(forecast.get("total_predicted_demand"))
            result.update(forecast_demand=demand,
                stock_sufficiency="SUFFICIENT" if available >= math.ceil(demand) else "SHORTFALL",
                assessment_status="COMPLETED",
                explanation="Baseline demand uses existing custom-forecast defaults and zero promotion. Campaign discount is not modeled; stock is a read snapshot, not a reservation.")
            terminal = "COMPLETED"
        except Exception:
            result.update(assessment_status="FAILED", explanation="Baseline assessment failed. No promotional uplift prediction was produced.")
            terminal = "FAILED"
    repository.finish_review(claim, terminal, result)
    return {**result, "review": review}


def reject_campaign(request_id, reason, user, repository):
    require_roles(user, "admin", "manager")
    record = repository.get("campaign-analysis", request_id)
    if record is None:
        raise error(404, "REQUEST_NOT_FOUND")
    require_store_access(user, record["store_id"])
    return repository.reject_campaign(request_id, reason, reviewer_snapshot(user, "REJECTED"))


assess_campaign = submit_campaign


def read_assessment(request_id, caller, repository):
    if not isinstance(caller, MarketingPlanningCaller):
        raise error(401, "INVALID_MARKETING_IDENTITY")
    record = repository.get("campaign-analysis", request_id)
    if record is None:
        raise error(404, "REQUEST_NOT_FOUND")
    caller.authorize(record["store_id"])
    if record["owner_id"] != caller.subject:
        raise error(403, "REQUEST_ACCESS_DENIED")
    return repository.public_campaign(record)


class ExistingPlanningSources:
    """Lazy read/inference adapters. Never run decision-workflow analysis (it writes)."""
    def workflow(self, workflow_id):
        from app.services.firebase_service import get_document_by_id
        return get_document_by_id("decision_workflows", workflow_id)

    def stock(self, store_id, product_id):
        from app.services.firebase_service import get_collection
        rows = list(get_collection("inventory_current").where("store_id", "==", store_id)
                    .where("product_id", "==", product_id).limit(2).stream())
        if len(rows) > 1:
            raise error(422, "AMBIGUOUS_INVENTORY")
        return rows[0].to_dict() if rows else None

    def product(self, product_id):
        from app.services.firebase_service import get_document_by_id
        record = get_document_by_id("products", product_id)
        if record and record.get("product_id", product_id) != product_id:
            raise error(422, "INVALID_SOURCE_DATA")
        return record

    def baseline(self, request, price):
        from app.schemas.forecast_schema import CustomForecastRequest
        from app.services.daily_forecast_service import generate_custom_forecast
        baseline = CustomForecastRequest(store_id=request.store_id, product_id=request.product_id,
            price_lkr=price, promotion_percent=0, start_date=request.campaign_start_date,
            end_date=request.campaign_end_date)
        return generate_custom_forecast(payload=baseline.model_dump(exclude={"start_date", "end_date"}),
            start_date=baseline.start_date, end_date=baseline.end_date)


def read_forecast_share(share_id, caller, repository):
    if not isinstance(caller, MarketingPlanningCaller):
        raise error(401, "INVALID_MARKETING_IDENTITY")
    record = repository.get("forecast-share", share_id)
    if record is None:
        raise error(404, "SHARE_NOT_FOUND")
    caller.authorize(record["store_id"])
    if record["result"] is None:
        raise error(409, "SHARE_IN_PROGRESS")
    return record["result"]
