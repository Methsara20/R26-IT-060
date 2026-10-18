"""Isolated security and persistence tests for Inventory opportunity publishing."""
import copy
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pymongo.errors import DuplicateKeyError

from app.routes.marketing_opportunity_routes import router
from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.schemas.marketing_opportunity_schema import MarketingOpportunityRequest
from app.security.inventory_permissions import get_current_inventory_user
from app.services.inventory_marketing_opportunity_dependencies import (
    get_inventory_marketing_opportunity_repository,
)
from app.services.inventory_marketing_opportunity_repository import (
    INDEX_FILTER, INDEX_NAME, InventoryMarketingOpportunityRepository,
)
from app.services.marketing_opportunity_service import create_marketing_opportunity


def principal(role="manager", stores=("CP004",), global_access=False):
    return InventoryPrincipal(user_id="oid:0123456789abcdef01234567",
        username_normalized="fixture", display_name="Fixture", role=role,
        store_ids=stores, global_access=global_access)


def request(**changes):
    values = dict(workflow_id="WF-1", product_id="P001", product_name="Product",
        store_id="CP004", category="Apparel", subcategory="Tops", brand="Brand",
        gender="Unisex", current_stock=100, forecast_demand=20, required_stock=30,
        excess_quantity=70, selling_price=1200, promotion_percent=10,
        stock_health="OVERSTOCK", recommended_action="PROMOTE")
    values.update(changes)
    return MarketingOpportunityRequest(**values)


class ServiceRepository:
    def __init__(self):
        self.workflow_record = {"_id":"WF-1", "workflow_id":"WF-1",
            "workflow_status":"COMPLETED", "product_id":"P001", "store_id":"CP004",
            "selling_price":1200, "promotion_percent":10,
            "forecast_result":{"forecast_total_demand":20},
            "inventory_snapshot":{"current_stock":100,"required_stock_before_demand":30},
            "inventory_intelligence":{"forecast_demand":20,"excess_qty":70,
                "stock_health":"OVERSTOCK","recommended_action":"PROMOTE"}}
        self.product_record = {"_id":"P001","product_id":"P001","product_name":"Product",
            "category":"Apparel","subcategory":"Tops","brand":"Brand","gender":"Unisex"}
        self.saved = None
        self.calls = 0
    def workflow(self, value): return copy.deepcopy(self.workflow_record) if value == "WF-1" else None
    def product(self, value): return copy.deepcopy(self.product_record) if value == "P001" else None
    def publish(self, document, key, fingerprint):
        self.calls += 1
        if self.saved is None: self.saved = copy.deepcopy(document)
        return copy.deepcopy(self.saved)


class Cursor(list):
    def limit(self, count): return Cursor(self[:count])


class Collection:
    def __init__(self, db, name): self.db, self.name, self.rows = db, name, []
    def list_indexes(self):
        if self.name != "marketing_opportunities": return [{"name":"_id_","key":{"_id":1}}]
        return copy.deepcopy(self.db.indexes)
    def find_one(self, query, projection):
        with self.db.lock:
            row = next((r for r in self.rows if match(r, query)), None)
            return project(row, projection)
    def find(self, query, projection):
        with self.db.lock: return Cursor([project(r, projection) for r in self.rows if match(r, query)])
    def insert_one(self, document):
        with self.db.lock:
            if any(r.get("publication_key") == document.get("publication_key") for r in self.rows):
                raise DuplicateKeyError("duplicate fixture")
            self.rows.append(copy.deepcopy(document)); self.db.writes += 1
            return SimpleNamespace(acknowledged=True)


def match(row, query):
    for key, value in query.items():
        if isinstance(value, dict) and "$exists" in value:
            if (key in row) != value["$exists"]: return False
        elif row.get(key) != value: return False
    return True


def project(row, projection):
    if row is None: return None
    return {key: copy.deepcopy(value) for key, value in row.items() if projection.get(key)}


class Database:
    name = "smart_retail_db"
    def __init__(self):
        self.lock, self.writes = threading.RLock(), 0
        self.indexes = [{"name":INDEX_NAME,"key":{"publication_key":1},"unique":True,
            "partialFilterExpression":copy.deepcopy(INDEX_FILTER)}]
        self.collections = {name:Collection(self,name) for name in
            ("decision_workflows","products","marketing_opportunities")}
    def get_collection(self, name, **options): return self.collections[name]
    def list_collections(self, filter): return [{"name":filter["name"],"type":"collection"}]


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.network = patch("socket.create_connection", side_effect=AssertionError("network forbidden"))
        self.mongo = patch("pymongo.MongoClient", side_effect=AssertionError("Mongo forbidden"))
        self.network.start(); self.mongo.start()
        self.addCleanup(self.network.stop); self.addCleanup(self.mongo.stop)

    def test_roles_scope_and_authoritative_mapping(self):
        for role in ("admin","manager","analyst"):
            repo=ServiceRepository(); response=create_marketing_opportunity(request(),principal(role),repo)
            self.assertEqual(response["status"],"PENDING_MARKETING")
            self.assertEqual(repo.saved["current_stock"],100)
            self.assertEqual(repo.saved["source_component"],"SMART_INVENTORY")
        for role in ("operator","viewer"):
            with self.assertRaises(HTTPException) as error:
                create_marketing_opportunity(request(),principal(role),ServiceRepository())
            self.assertEqual(error.exception.status_code,403)
        for user in (principal("admin",()), principal("manager",("OTHER",))):
            with self.assertRaises(HTTPException) as error:
                create_marketing_opportunity(request(),user,ServiceRepository())
            self.assertEqual(error.exception.status_code,403)
        create_marketing_opportunity(request(),principal("admin",(),True),ServiceRepository())

    def test_forged_assertions_and_invalid_workflow_fail_before_write(self):
        for changes in ({"store_id":"OTHER"},{"current_stock":99},{"forecast_demand":21},
                        {"product_name":"Forged"},{"promotion_percent":11}):
            repo=ServiceRepository()
            with self.assertRaises(HTTPException) as error:
                create_marketing_opportunity(request(**changes),principal(),repo)
            self.assertEqual(error.exception.status_code,409); self.assertEqual(repo.calls,0)
        repo=ServiceRepository(); repo.workflow_record["inventory_intelligence"]["recommended_action"]="REORDER"
        with self.assertRaises(HTTPException): create_marketing_opportunity(request(),principal(),repo)
        self.assertEqual(repo.calls,0)

    def prepared_repository(self):
        db=Database(); repo=InventoryMarketingOpportunityRepository(db).require_ready()
        service=ServiceRepository(); db.collections["decision_workflows"].rows=[service.workflow_record]
        db.collections["products"].rows=[service.product_record]
        return db,repo

    def test_exact_duplicate_is_atomic_and_conflict_is_rejected(self):
        db,repo=self.prepared_repository()
        def publish(_): return create_marketing_opportunity(request(),principal(),repo)
        with ThreadPoolExecutor(max_workers=8) as pool: results=list(pool.map(publish,range(16)))
        self.assertEqual(db.writes,1); self.assertEqual(len({r["opportunity_id"] for r in results}),1)
        db.collections["marketing_opportunities"].rows[0]["publication_fingerprint"]="conflict"
        with self.assertRaises(HTTPException) as error: publish(0)
        self.assertEqual(error.exception.status_code,409)

    def test_legacy_exact_reused_unchanged_and_ambiguity_fails(self):
        db,repo=self.prepared_repository(); service_repo=ServiceRepository()
        create_marketing_opportunity(request(),principal(),service_repo)
        legacy={k:v for k,v in service_repo.saved.items() if k not in
            ("publication_key","publication_fingerprint","opportunity_type")}
        original=copy.deepcopy(legacy); db.collections["marketing_opportunities"].rows=[legacy]
        result=create_marketing_opportunity(request(),principal(),repo)
        self.assertEqual(result["opportunity_id"],legacy["opportunity_id"])
        self.assertEqual(legacy,original); self.assertEqual(db.writes,0)
        db.collections["marketing_opportunities"].rows.append(copy.deepcopy(legacy))
        with self.assertRaises(HTTPException) as error:
            create_marketing_opportunity(request(),principal(),repo)
        self.assertEqual(error.exception.status_code,409)

    def test_missing_or_incompatible_index_fails_closed(self):
        for indexes in ([], [{"name":INDEX_NAME,"key":{"publication_key":1},"unique":False,
                              "partialFilterExpression":copy.deepcopy(INDEX_FILTER)}]):
            db=Database(); db.indexes=indexes
            with self.assertRaises(HTTPException) as error:
                InventoryMarketingOpportunityRepository(db).require_ready()
            self.assertEqual(error.exception.status_code,503); self.assertEqual(db.writes,0)

    def test_route_requires_inventory_identity_and_preserves_contract(self):
        repo=ServiceRepository(); app=FastAPI(); app.include_router(router)
        client=TestClient(app); self.addCleanup(client.close)
        payload=request().model_dump()
        self.assertEqual(client.post("/marketing-opportunities/",json=payload).status_code,401)
        app.dependency_overrides[get_current_inventory_user]=lambda:principal()
        app.dependency_overrides[get_inventory_marketing_opportunity_repository]=lambda:repo
        response=client.post("/marketing-opportunities/",json=payload)
        self.assertEqual(response.status_code,200,response.text)
        self.assertEqual(set(response.json()),{"opportunity_id","workflow_id","status","message"})


if __name__ == "__main__": unittest.main()
