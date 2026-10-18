"""Lazy Inventory-only dependencies. Importing this module performs no IO."""
from fastapi import Depends
from app.security.inventory_permissions import inventory_user_management_admin, get_current_inventory_user
from app.services.inventory_auth_dependencies import get_existing_inventory_mongo_wrapper
from app.services.inventory_auth_service import get_inventory_auth_service
from app.services.inventory_user_management_repository import MongoInventoryManagementRepository, unavailable
from app.services.inventory_user_management_service import InventoryUserManagementService


def get_management_repository(_admin=Depends(inventory_user_management_admin)):
    # Resolve the existing wrapper only AFTER the admin dependency succeeds.
    try:
        wrapper = get_existing_inventory_mongo_wrapper()
        if wrapper.db.client is not wrapper.client:
            raise unavailable()
        return MongoInventoryManagementRepository(wrapper.db)
    except Exception:
        raise unavailable() from None


def get_management_service(repository=Depends(get_management_repository),
                           auth=Depends(get_inventory_auth_service)):
    return InventoryUserManagementService(repository, auth)


def get_profile_repository(_user=Depends(get_current_inventory_user)):
    """Separate all-role entry point; existing Admin dependency remains intact."""
    try:
        wrapper = get_existing_inventory_mongo_wrapper()
        if wrapper.db.client is not wrapper.client:
            raise unavailable()
        return MongoInventoryManagementRepository(wrapper.db)
    except Exception:
        raise unavailable() from None


def get_profile_service(repository=Depends(get_profile_repository),
                        auth=Depends(get_inventory_auth_service)):
    from app.services.inventory_profile_service import InventoryProfileService
    return InventoryProfileService(repository, auth)
