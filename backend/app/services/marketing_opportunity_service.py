from datetime import datetime, timezone
from hashlib import sha256
import json
import math
from uuid import uuid4

from fastapi import HTTPException

from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.security.inventory_permissions import require_roles, require_store_access


class MarketingOpportunityValidationError(Exception):
    """Retained for import compatibility with earlier callers."""


def _conflict():
    return HTTPException(409, detail="Submitted opportunity data does not match the stored workflow.")


def _text(value):
    if not isinstance(value, str) or not value or value != value.strip() or not value.isprintable():
        raise HTTPException(422, detail="Stored workflow data is invalid.")
    return value


def _quantity(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
        raise HTTPException(422, detail="Stored workflow data is invalid.")
    return value


def _fingerprint(value):
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
    return sha256(encoded).hexdigest()


def create_marketing_opportunity(data, user, repository):
    if not isinstance(user, InventoryPrincipal):
        raise HTTPException(401, detail="Invalid Inventory identity.")
    require_roles(user, "admin", "manager", "analyst")
    workflow = repository.workflow(data.workflow_id)
    if not isinstance(workflow, dict):
        raise HTTPException(404, detail="Stored decision workflow was not found.")
    workflow_id = _text(workflow.get("workflow_id"))
    if workflow_id != data.workflow_id or workflow.get("_id", workflow_id) != workflow_id:
        raise _conflict()
    if workflow.get("workflow_status") in {
        None, "PROCESSING", "FORECAST_READY", "INTELLIGENCE_READY",
        "OPTIMIZATION_REQUIRED", "FAILED",
    }:
        raise HTTPException(409, detail="The stored decision workflow is not ready for publication.")

    product_id = _text(workflow.get("product_id"))
    store_id = _text(workflow.get("store_id"))
    require_store_access(user, store_id)
    product = repository.product(product_id)
    if not isinstance(product, dict) or product.get("_id", product_id) != product_id:
        raise HTTPException(422, detail="Stored product data is unavailable.")
    if product.get("product_id", product_id) != product_id:
        raise HTTPException(422, detail="Stored product data is invalid.")

    forecast = workflow.get("forecast_result")
    inventory = workflow.get("inventory_snapshot")
    intelligence = workflow.get("inventory_intelligence")
    if not all(isinstance(value, dict) for value in (forecast, inventory, intelligence)):
        raise HTTPException(422, detail="Stored workflow data is incomplete.")
    recommended_action = _text(intelligence.get("recommended_action")).upper()
    if recommended_action != "PROMOTE":
        raise HTTPException(409, detail="The stored workflow is not a Marketing opportunity.")

    authoritative = {
        "workflow_id": workflow_id,
        "product_id": product_id,
        "product_name": _text(product.get("product_name")),
        "store_id": store_id,
        "category": product.get("category"),
        "subcategory": product.get("subcategory"),
        "brand": product.get("brand"),
        "gender": product.get("gender"),
        "current_stock": int(_quantity(inventory.get("current_stock"))),
        "forecast_demand": int(_quantity(intelligence.get(
            "forecast_demand", forecast.get("forecast_total_demand")))),
        "required_stock": int(_quantity(inventory.get("required_stock_before_demand"))),
        "excess_quantity": int(_quantity(intelligence.get("excess_qty"))),
        "selling_price": _quantity(workflow.get("selling_price")),
        "promotion_percent": _quantity(workflow.get("promotion_percent", 0)),
        "stock_health": _text(intelligence.get("stock_health")),
        "recommended_action": recommended_action,
    }
    if authoritative["promotion_percent"] > 100:
        raise HTTPException(422, detail="Stored workflow data is invalid.")

    submitted = data.model_dump()
    for field, expected in authoritative.items():
        actual = submitted[field]
        if field == "promotion_percent" and actual is None and expected == 0:
            continue
        if field in {"category", "subcategory", "brand", "gender", "selling_price"} and actual is None:
            continue
        if actual != expected:
            raise _conflict()

    identity = {"workflow_id": workflow_id, "product_id": product_id,
                "store_id": store_id, "opportunity_type": "FORECAST_PROMOTION"}
    publication_key = _fingerprint(identity)
    snapshot = {**authoritative, "source_component": "SMART_INVENTORY",
                "status": "PENDING_MARKETING", "opportunity_type": "FORECAST_PROMOTION"}
    publication_fingerprint = _fingerprint(snapshot)
    opportunity_id = "MKT-OPP-" + uuid4().hex[:12].upper()
    document = {"_id": opportunity_id, "opportunity_id": opportunity_id,
                **snapshot, "publication_key": publication_key,
                "publication_fingerprint": publication_fingerprint,
                "created_at": datetime.now(timezone.utc).isoformat()}
    stored = repository.publish(document, publication_key, publication_fingerprint)
    return {"opportunity_id": stored.get("opportunity_id") or stored.get("_id"),
            "workflow_id": workflow_id,
            "status": stored.get("status", "PENDING_MARKETING"),
            "message": "Marketing opportunity sent successfully."}
