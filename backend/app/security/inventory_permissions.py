"""Backend authorization helpers; UI visibility is never an access check."""
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.services.inventory_auth_service import InventoryAuthService, get_inventory_auth_service, unauthorized
from app.services.inventory_user_service import InventoryUserRepository, get_inventory_user_repository

bearer = HTTPBearer(auto_error=False)
ROLES = frozenset({"admin", "manager", "analyst", "operator", "viewer"})


def get_bearer_credentials(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> HTTPAuthorizationCredentials:
    if credentials is None or credentials.scheme.casefold() != "bearer":
        raise unauthorized()
    return credentials


def get_current_inventory_user(
    credentials: HTTPAuthorizationCredentials = Depends(get_bearer_credentials),
    service: InventoryAuthService = Depends(get_inventory_auth_service),
    repository: InventoryUserRepository = Depends(get_inventory_user_repository),
) -> InventoryPrincipal:
    if credentials is None or credentials.scheme.casefold() != "bearer":
        raise unauthorized()
    return service.current_user(repository, credentials.credentials)


def require_roles(user: InventoryPrincipal, *allowed: str) -> InventoryPrincipal:
    if user.role not in ROLES or user.role not in allowed:
        raise HTTPException(status_code=403, detail="Inventory access denied.")
    return user


def require_store_access(user: InventoryPrincipal, *store_ids: str) -> InventoryPrincipal:
    if user.role not in ROLES or not store_ids or any(not isinstance(s, str) or not s or s != s.strip() for s in store_ids):
        raise HTTPException(status_code=403, detail="Inventory access denied.")
    if not user.global_access and any(s not in user.store_ids for s in store_ids):
        raise HTTPException(status_code=403, detail="Inventory access denied.")
    return user


def require_global_access(user: InventoryPrincipal) -> InventoryPrincipal:
    if user.role not in ROLES or not user.global_access:
        raise HTTPException(status_code=403, detail="Inventory access denied.")
    return user


def inventory_user_management_admin(
    user: InventoryPrincipal = Depends(get_current_inventory_user),
) -> InventoryPrincipal:
    """Inventory user management only; admin does not imply global access."""
    require_roles(user, "admin")
    return require_global_access(user)


def roles_required(*allowed: str):
    if not allowed or any(role not in ROLES for role in allowed):
        raise ValueError("Invalid role policy.")

    def dependency(user: InventoryPrincipal = Depends(get_current_inventory_user)):
        return require_roles(user, *allowed)

    return dependency


# Stock movement permissions are Inventory-only, and grant no cross-module access.
STOCK_MOVEMENT_ROLES = {
    "read": ("admin", "manager", "analyst", "operator", "viewer"),
    "recommend": ("admin", "manager", "analyst"),
    "approve": ("admin", "manager"),
    "reject": ("admin", "manager"),
    "cancel": ("admin", "manager"),
    "execute": ("admin", "operator"),
    "explain": ("admin", "manager", "analyst"),
    "summary": ("admin", "manager", "analyst", "operator"),
}


def stock_movement_user(operation: str):
    if operation not in STOCK_MOVEMENT_ROLES:
        raise ValueError("Invalid stock movement policy.")
    return roles_required(*STOCK_MOVEMENT_ROLES[operation])


def require_stock_movement_role(user: InventoryPrincipal, operation: str):
    return require_roles(user, *STOCK_MOVEMENT_ROLES.get(operation, ()))

def inventory_analysis_user():
    """Forecasting/intelligence/decision generation is not available to readers."""
    return roles_required("admin", "manager", "analyst")


def inventory_candidate_reader():
    return roles_required("admin", "manager", "analyst", "operator", "viewer")
