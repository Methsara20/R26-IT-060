"""Inventory-only wiring, with no import-time database initialization.

Call configure_inventory_auth_dependencies(app) explicitly during a later,
approved registration phase. The existing shared MongoDB wrapper must already
be initialized; this module will never initialize it or create a MongoClient.
"""
import sys

from fastapi import Depends, HTTPException

from app.services.inventory_user_service import (
    MongoInventoryUserRepository, get_inventory_user_repository,
)


def unavailable() -> HTTPException:
    return HTTPException(
        status_code=503, detail="Inventory authentication is unavailable.",
    )


def get_existing_inventory_mongo_wrapper():
    """Read the already-loaded shared configuration without importing it.

    Importing app.firebase_config when absent would initialize Firebase and a
    MongoClient. Refuse that path instead. Normal shared-app startup already
    loads this configuration through its existing routers.
    """
    try:
        configuration = sys.modules.get("app.firebase_config")
        if configuration is None or getattr(configuration, "db_type", None) != "mongodb":
            raise unavailable()
        wrapper = getattr(configuration, "db", None)
        from app.mongo_client import MongoFirestoreClient
        if not isinstance(wrapper, MongoFirestoreClient):
            raise unavailable()
        return wrapper
    except Exception:
        raise unavailable() from None


def get_inventory_mongo_repository(
    wrapper=Depends(get_existing_inventory_mongo_wrapper),
) -> MongoInventoryUserRepository:
    """Select only the Inventory collection from the existing native handle.

    Handle selection performs no network query or provisioning. Availability
    errors encountered by subsequent reads are sanitized by the auth service.
    No fallback to Firestore, profiles, or a new database/client is allowed.
    """
    try:
        from app.mongo_client import MongoFirestoreClient
        if not isinstance(wrapper, MongoFirestoreClient):
            raise unavailable()
        database = wrapper.db
        if (
            database.name != "smart_retail_db"
            or database.client is not wrapper.client
        ):
            raise unavailable()
        collection = database.get_collection("inventory_users")
        if collection.name != "inventory_users" or collection.database is not database:
            raise unavailable()
        return MongoInventoryUserRepository(collection)
    except Exception:
        raise unavailable() from None


def configure_inventory_auth_dependencies(app) -> None:
    """Install only the Inventory repository dependency; never register routes.

    Safe to call repeatedly; refuse to overwrite an unrelated/custom override.
    This operates on the supplied application only and resolves no database.
    """
    existing = app.dependency_overrides.get(get_inventory_user_repository)
    if existing is not None and existing is not get_inventory_mongo_repository:
        raise RuntimeError("Inventory repository dependency is already configured.")
    app.dependency_overrides[get_inventory_user_repository] = get_inventory_mongo_repository
