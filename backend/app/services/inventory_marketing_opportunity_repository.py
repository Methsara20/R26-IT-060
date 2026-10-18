"""Inventory-owned, fail-closed persistence for existing Marketing opportunities."""
from copy import deepcopy

from fastapi import HTTPException
from pymongo import ReadPreference
from pymongo.errors import DuplicateKeyError
from pymongo.read_concern import ReadConcern
from pymongo.write_concern import WriteConcern


COLLECTION = "marketing_opportunities"
INDEX_NAME = "uq_inventory_marketing_publication_key"
INDEX_KEY = [("publication_key", 1)]
INDEX_FILTER = {"publication_key": {"$type": "string"}}
LEGACY_FIELDS = (
    "workflow_id", "source_component", "product_id", "product_name", "store_id",
    "category", "subcategory", "brand", "gender", "current_stock",
    "forecast_demand", "required_stock", "excess_quantity", "selling_price",
    "stock_health", "recommended_action", "status",
)


def unavailable():
    return HTTPException(503, detail="Marketing opportunity storage is unavailable.")


class InventoryMarketingOpportunityRepository:
    def __init__(self, database):
        if database.name != "smart_retail_db":
            raise unavailable()
        self.database = database
        self.workflows = database.get_collection(
            "decision_workflows", read_concern=ReadConcern("majority"),
            read_preference=ReadPreference.PRIMARY,
        )
        self.products = database.get_collection(
            "products", read_concern=ReadConcern("majority"),
            read_preference=ReadPreference.PRIMARY,
        )
        self.opportunities = database.get_collection(
            COLLECTION, read_concern=ReadConcern("majority"),
            write_concern=WriteConcern(w="majority", wtimeout=15000),
            read_preference=ReadPreference.PRIMARY,
        )

    def require_ready(self):
        try:
            for name in ("decision_workflows", "products", COLLECTION):
                metadata = list(self.database.list_collections(filter={"name": name}))
                if len(metadata) != 1 or metadata[0].get("type") != "collection":
                    raise ValueError()
            indexes = list(self.opportunities.list_indexes())
            if not any(
                index.get("name") == INDEX_NAME
                and list(index.get("key", {}).items()) == INDEX_KEY
                and index.get("unique") is True
                and not index.get("sparse")
                and index.get("partialFilterExpression") == INDEX_FILTER
                and "expireAfterSeconds" not in index
                and index.get("collation", {}).get("locale", "simple") == "simple"
                for index in indexes
            ):
                raise ValueError()
            return self
        except HTTPException:
            raise
        except Exception:
            raise unavailable() from None

    def workflow(self, workflow_id):
        try:
            return self.workflows.find_one(
                {"_id": workflow_id},
                {
                    "_id": 1, "workflow_id": 1, "workflow_status": 1,
                    "product_id": 1, "store_id": 1, "selling_price": 1,
                    "promotion_percent": 1, "forecast_result": 1,
                    "inventory_snapshot": 1, "inventory_intelligence": 1,
                },
            )
        except Exception:
            raise unavailable() from None

    def product(self, product_id):
        try:
            return self.products.find_one(
                {"_id": product_id},
                {
                    "_id": 1, "product_id": 1, "product_name": 1,
                    "category": 1, "subcategory": 1, "brand": 1, "gender": 1,
                },
            )
        except Exception:
            raise unavailable() from None

    @staticmethod
    def _same(document, payload, fingerprint):
        if document.get("publication_fingerprint") is not None:
            return document.get("publication_fingerprint") == fingerprint
        return all(field in document and document.get(field) == payload.get(field)
                   for field in LEGACY_FIELDS)

    def _by_key(self, key):
        return self.opportunities.find_one(
            {"publication_key": key}, {"_id": 1, "opportunity_id": 1,
             "workflow_id": 1, "product_id": 1, "store_id": 1,
             "publication_fingerprint": 1, "status": 1},
        )

    def publish(self, document, publication_key, fingerprint):
        payload = {k: deepcopy(v) for k, v in document.items()
                   if k not in {"_id", "opportunity_id", "created_at",
                                "publication_key", "publication_fingerprint"}}
        try:
            existing = self._by_key(publication_key)
            if existing is not None:
                if not self._same(existing, payload, fingerprint):
                    raise HTTPException(409, detail="Marketing opportunity publication conflicts with an existing record.")
                return existing

            legacy_query = {
                "workflow_id": document["workflow_id"],
                "product_id": document["product_id"],
                "store_id": document["store_id"],
                "source_component": "SMART_INVENTORY",
                "publication_key": {"$exists": False},
            }
            projection = {field: 1 for field in (
                "_id", "opportunity_id", "workflow_id", "source_component",
                "product_id", "product_name", "store_id", "category",
                "subcategory", "brand", "gender", "current_stock",
                "forecast_demand", "required_stock", "excess_quantity",
                "selling_price", "promotion_percent", "stock_health",
                "recommended_action", "status",
            )}
            legacy = list(self.opportunities.find(legacy_query, projection).limit(2))
            if len(legacy) > 1:
                raise HTTPException(409, detail="Historical Marketing opportunities are ambiguous.")
            if legacy:
                if not self._same(legacy[0], payload, fingerprint):
                    raise HTTPException(409, detail="Marketing opportunity publication conflicts with a historical record.")
                return legacy[0]

            receipt = self.opportunities.insert_one(deepcopy(document))
            if not receipt.acknowledged:
                raise RuntimeError()
            return document
        except HTTPException:
            raise
        except Exception as exc:
            # Never replay a write. Reconcile both duplicate-key and uncertain outcomes.
            try:
                existing = self._by_key(publication_key)
            except Exception:
                raise unavailable() from None
            if existing is not None and self._same(existing, payload, fingerprint):
                return existing
            if isinstance(exc, DuplicateKeyError) and existing is not None:
                raise HTTPException(409, detail="Marketing opportunity publication conflicts with an existing record.") from None
            raise unavailable() from None
