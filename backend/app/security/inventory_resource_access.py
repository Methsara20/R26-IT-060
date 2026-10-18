"""Inventory-only scope guards; pure functions with no database or AI imports."""
from collections.abc import Mapping
from fastapi import HTTPException

from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.security.inventory_permissions import require_store_access

_STORE_FIELDS = frozenset({
    "store_id", "from_store", "to_store", "selected_store", "target_store",
    "source_store", "source_store_id", "target_store_id",
})
_STORE_LIST_FIELDS = frozenset({"alternative_sources", "qualified_source_stores", "eligible_source_stores"})
_SOURCE_DETAIL_FIELDS = frozenset({"evaluated_sources", "qualified_source_details"})


def denied():
    return HTTPException(status_code=403, detail="Inventory access denied.")


def _check_references(user: InventoryPrincipal, value, depth=0):
    # Check all donor/alternative references, including nested evaluated sources.
    # Deny the complete record rather than redact/rerank business recommendations.
    if depth > 32:
        raise denied()
    if isinstance(value, Mapping):
        for key, item in value.items():
            if key in _STORE_FIELDS:
                if item is not None:
                    require_store_access(user, item)
            elif key in _STORE_LIST_FIELDS:
                if not isinstance(item, (list, tuple)):
                    raise denied()
                for store in item:
                    require_store_access(user, store)
            elif key in _SOURCE_DETAIL_FIELDS:
                if not isinstance(item, (list, tuple)):
                    raise denied()
                for source in item:
                    if not isinstance(source, Mapping):
                        raise denied()
                    require_store_access(user, source.get("store_id"))
                    _check_references(user, source, depth + 1)
            elif isinstance(item, (Mapping, list, tuple)):
                _check_references(user, item, depth + 1)
    elif isinstance(value, (list, tuple)):
        for item in value:
            _check_references(user, item, depth + 1)


def require_movement_access(user: InventoryPrincipal, movement):
    if not isinstance(movement, Mapping):
        raise denied()
    require_store_access(user, movement.get("from_store"), movement.get("to_store"))
    _check_references(user, movement)
    return movement


def readable_movement(user: InventoryPrincipal, movement):
    """Manager participation grants read access, never mutation authority.

    Return a copy so response filtering cannot alter persisted recommendations.
    Unscoped AI caches can mention other donors and are not safe to disclose.
    """
    if not isinstance(movement, Mapping):
        raise denied()
    source, target = movement.get("from_store"), movement.get("to_store")
    if any(not isinstance(s, str) or not s or s != s.strip() for s in (source, target)) or source == target:
        raise denied()
    for field, expected in (("source_store", source), ("source_store_id", source),
                            ("target_store", target), ("target_store_id", target),
                            ("selected_store", source)):
        if field in movement and movement[field] is not None and movement[field] != expected:
            raise denied()
    if user.role != "manager" or user.global_access:
        return require_movement_access(user, movement)
    if source not in user.store_ids and target not in user.store_ids:
        raise denied()
    try:
        # Preserve complete existing responses when every disclosed store is authorized.
        return require_movement_access(user, movement)
    except HTTPException:
        pass
    from copy import deepcopy
    result = deepcopy(dict(movement))
    # Only the actual transfer endpoints gain participation-based visibility.
    scoped = user.model_copy(update={"store_ids": list(set(user.store_ids) | {source, target})})
    for field in _STORE_LIST_FIELDS:
        if field in result:
            values = result[field]
            if not isinstance(values, (list, tuple)):
                raise denied()
            result[field] = [s for s in values if isinstance(s, str) and s in scoped.store_ids]
    for field in _SOURCE_DETAIL_FIELDS:
        if field in result:
            values = result[field]
            if not isinstance(values, (list, tuple)):
                raise denied()
            result[field] = [s for s in values if isinstance(s, Mapping) and s.get("store_id") in scoped.store_ids]
    for field in list(result):
        if field.startswith("ai_explanation") or field.startswith("ai_execution_"):
            result[field] = False if field.endswith("_generated") else None
    _check_references(scoped, result)
    return result


def require_candidate_access(user: InventoryPrincipal, candidate):
    if not isinstance(candidate, Mapping):
        raise denied()
    require_store_access(user, candidate.get("store_id"))
    sources = candidate.get("qualified_source_details") or []
    if not isinstance(sources, (list, tuple)):
        raise denied()
    for source in sources:
        if not isinstance(source, Mapping):
            raise denied()
        require_store_access(user, source.get("store_id"))
    _check_references(user, candidate)
    return candidate


def visible_movements(user: InventoryPrincipal, movements):
    """Filter before any future pagination and count calculation."""
    result = []
    for movement in movements:
        try:
            readable = readable_movement(user, movement)
        except HTTPException:
            continue
        result.append(readable)
    return result

def require_optimization_candidate_access(user: InventoryPrincipal, candidate):
    """Do not expose aggregate donor data whose complete scope is unknown."""
    require_candidate_access(user, candidate)
    from app.security.inventory_permissions import require_global_access
    details = candidate.get("qualified_source_details") or []
    count = candidate.get("available_source_stores", 0)
    if type(count) is not int or count < 0:
        raise denied()
    if count and count != len(details):
        require_global_access(user)
    # Older analyzed low-stock records can contain donor aggregates without IDs.
    if (
        candidate.get("candidate_type") == "LOW_STOCK"
        and candidate.get("total_available_surplus", 0)
        and not details
    ):
        require_global_access(user)
    return candidate


def visible_optimization_candidates(user: InventoryPrincipal, candidates):
    result = []
    for candidate in candidates:
        try:
            require_optimization_candidate_access(user, candidate)
        except HTTPException:
            continue
        result.append(candidate)
    return result


def scoped_candidate_summary(candidates):
    """Same summary keys/count rules as the existing service, after filtering."""
    from datetime import datetime
    summary = {
        "total_candidates": len(candidates),
        "high_priority": 0, "medium_priority": 0, "low_priority": 0,
        "low_stock": 0, "overstock": 0, "pending": 0, "analyzing": 0,
        "recommended": 0, "approved": 0, "completed": 0,
        "last_generated": datetime.now().isoformat(),
    }
    for item in candidates:
        priority = {"HIGH": "high_priority", "MEDIUM": "medium_priority", "LOW": "low_priority"}.get(item.get("priority"))
        kind = {"LOW_STOCK": "low_stock", "OVERSTOCK": "overstock"}.get(item.get("candidate_type"))
        status = {"PENDING": "pending", "ANALYZING": "analyzing", "RECOMMENDED": "recommended", "APPROVED": "approved", "COMPLETED": "completed"}.get(item.get("status"))
        for key in (priority, kind, status):
            if key:
                summary[key] += 1
    return summary


class VerifiedWorkflowUser:
    """Workflow capability minted only by existing JWT/current-account validation.

    Service entry points accept this context, never a body-supplied principal.
    The auth service and repository are trusted dependency-injected infrastructure.
    No token is retained in the context.
    """
    __slots__ = ("_principal",)

    def __init__(self, token, auth_service, repository):
        self._principal = auth_service.current_user(repository, token)

    @property
    def principal(self):
        return self._principal


def require_workflow_user(user):
    from app.services.inventory_auth_service import unauthorized
    from app.security.inventory_permissions import require_roles
    if not isinstance(user, VerifiedWorkflowUser) or not isinstance(user.principal, InventoryPrincipal):
        raise unauthorized()
    require_roles(user.principal, "admin", "manager", "analyst", "operator", "viewer")
    return user.principal


def require_workflow_access(user: InventoryPrincipal, workflow):
    """Reject a complete record if any embedded scope is outside authorization."""
    if not isinstance(workflow, Mapping):
        raise denied()
    require_store_access(user, workflow.get("store_id"))
    _check_references(user, workflow)
    for key in ("candidate", "decision_result"):
        record = workflow.get(key)
        if record is not None:
            if not isinstance(record, Mapping):
                raise denied()
            # Decisions can carry donor aggregates without a candidate_type.
            scoped = {"candidate_type": "LOW_STOCK", "store_id": workflow["store_id"], **record}
            require_optimization_candidate_access(user, scoped)
    movement = workflow.get("movement")
    if movement is not None:
        require_movement_access(user, movement)
    return workflow
