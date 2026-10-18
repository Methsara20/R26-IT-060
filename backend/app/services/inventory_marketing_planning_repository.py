"""Inventory planning storage: single-document atomicity, no provisioning.

Pre-provision ordinary collections inventory_forecast_shares and
inventory_campaign_analysis_requests with their standard unique _id ascending
indexes. Do not configure TTL, partial indexes or non-simple collation.
_id is the stable share/request identifier. No other collection is written.
Majority writes and primary majority reconciliation are required. A lost claim
is never reclaimed automatically: operator recovery requires separate approval.
"""
from copy import deepcopy
from datetime import datetime, timezone
from uuid import uuid4
from fastapi import HTTPException
from pymongo import ReadPreference
from pymongo.read_concern import ReadConcern
from pymongo.write_concern import WriteConcern
from pymongo.errors import DuplicateKeyError
from app.services.inventory_marketing_planning_service import PlanningClaim, error, fingerprint

COLLECTIONS = {"forecast-share": "inventory_forecast_shares",
               "campaign-analysis": "inventory_campaign_analysis_requests"}
PROJECTION = {k: 1 for k in ("_id", "fingerprint", "owner_id", "store_id", "state", "lease",
    "request", "result", "result_digest", "review", "rejection_reason", "created_at", "completed_at")}
CAMPAIGN_STATES = frozenset({"PENDING_REVIEW", "PROCESSING", "COMPLETED",
    "UNSUPPORTED_PERIOD", "FAILED", "REJECTED", "COMPLETE"})


class InventoryMarketingPlanningRepository:
    def __init__(self, database):
        if database.name != "smart_retail_db":
            raise error(503, "COMMUNICATION_STORAGE_UNAVAILABLE")
        self.database = database
        self.collections = {}

    def ready(self, namespaces=None):
        requested = tuple(COLLECTIONS) if namespaces is None else tuple(namespaces)
        try:
            if not requested or len(set(requested)) != len(requested) or any(
                    namespace not in COLLECTIONS for namespace in requested):
                raise ValueError()
            for namespace in requested:
                name = COLLECTIONS[namespace]
                metadata = list(self.database.list_collections(filter={"name": name}))
                if len(metadata) != 1 or metadata[0].get("type") != "collection":
                    raise ValueError()
                options = metadata[0].get("options", {})
                if options.get("capped") or options.get("timeseries") or options.get("collation", {}).get("locale", "simple") != "simple":
                    raise ValueError()
                collection = self.database.get_collection(name, read_concern=ReadConcern("majority"),
                    write_concern=WriteConcern(w="majority", wtimeout=15000), read_preference=ReadPreference.PRIMARY)
                indexes = list(collection.list_indexes())
                if not any(list(i.get("key", {}).items()) == [("_id", 1)] and i.get("name") == "_id_" for i in indexes):
                    raise ValueError()
                if any("expireAfterSeconds" in i for i in indexes):
                    raise ValueError()
                self.collections[namespace] = collection
        except Exception:
            self.collections.clear()
            raise error(503, "COMMUNICATION_STORAGE_UNAVAILABLE") from None
        return self

    def _collection(self, namespace):
        if namespace not in COLLECTIONS or namespace not in self.collections:
            raise error(503, "COMMUNICATION_STORAGE_UNAVAILABLE")
        return self.collections[namespace]

    def get(self, namespace, key):
        try:
            row = self._collection(namespace).find_one({"_id": key}, PROJECTION)
            if row is not None:
                self._validate(row)
            return row
        except Exception:
            raise error(503, "COMMUNICATION_STORAGE_UNAVAILABLE") from None

    @staticmethod
    def _validate(row):
        state = row.get("state")
        if (state not in CAMPAIGN_STATES or
                (state in ("PENDING_REVIEW", "PROCESSING") and row.get("result") is not None) or
                not all(isinstance(row.get(k), str) and row[k] for k in ("fingerprint", "owner_id", "store_id", "lease")) or
                (state in ("COMPLETE", "COMPLETED", "UNSUPPORTED_PERIOD", "FAILED") and
                 (not isinstance(row.get("result"), dict) or fingerprint(row["result"]) != row.get("result_digest"))) or
                (state == "REJECTED" and (not isinstance(row.get("review"), dict) or
                 not isinstance(row.get("rejection_reason"), str)))):
            raise ValueError()

    @staticmethod
    def _binding(row, digest, owner, store):
        if (row["fingerprint"], row["owner_id"], row["store_id"]) != (digest, owner, store):
            raise error(409, "REQUEST_CONFLICT")

    def _insert(self, namespace, key, digest, owner, store, payload, result=None):
        collection = self._collection(namespace)
        lease = uuid4().hex
        row = dict(_id=key, fingerprint=digest, owner_id=owner, store_id=store,
            lease=lease, state="COMPLETE" if result is not None else "PROCESSING",
            request=deepcopy(payload), result=deepcopy(result),
            result_digest=fingerprint(result) if result is not None else None,
            created_at=datetime.now(timezone.utc))
        try:
            receipt = collection.insert_one(row)
            if not receipt.acknowledged:
                raise RuntimeError()
            return PlanningClaim(namespace, key, lease, True, deepcopy(result))
        except Exception as exc:
            # No write replay, including unknown commit/write concern outcomes.
            existing = self.get(namespace, key)
            if existing is None:
                raise error(503, "OUTCOME_UNCONFIRMED") from None
            self._binding(existing, digest, owner, store)
            owned = existing["lease"] == lease
            if not isinstance(exc, DuplicateKeyError) and not owned:
                raise error(503, "OUTCOME_UNCONFIRMED") from None
            return PlanningClaim(namespace, key, lease, owned, existing.get("result"))

    def publish(self, key, digest, owner, store, result):
        claim = self._insert("forecast-share", key, digest, owner, store, {}, result)
        if claim.result is None:
            raise error(409, "REQUEST_IN_PROGRESS")
        return claim.result

    def claim(self, namespace, key, fingerprint, owner_id, store_id, payload=None):
        if namespace != "campaign-analysis" or not isinstance(payload, dict):
            raise error(503, "COMMUNICATION_STORAGE_UNAVAILABLE")
        return self._insert(namespace, key, fingerprint, owner_id, store_id, payload)

    def submit_campaign(self, key, digest, owner, store, payload):
        existing = self.get("campaign-analysis", key)
        if existing is not None:
            self._binding(existing, digest, owner, store)
            return self.public_campaign(existing)
        collection = self._collection("campaign-analysis")
        lease = uuid4().hex
        row = dict(_id=key, fingerprint=digest, owner_id=owner, store_id=store,
            lease=lease, state="PENDING_REVIEW", request=deepcopy(payload), result=None,
            result_digest=None, created_at=datetime.now(timezone.utc))
        try:
            receipt = collection.insert_one(row)
            if not receipt.acknowledged:
                raise RuntimeError()
        except Exception as exc:
            existing = self.get("campaign-analysis", key)
            if existing is None:
                raise error(503, "OUTCOME_UNCONFIRMED") from None
            self._binding(existing, digest, owner, store)
            if not isinstance(exc, DuplicateKeyError) and existing.get("lease") != lease:
                raise error(503, "OUTCOME_UNCONFIRMED") from None
            return self.public_campaign(existing)
        return self.public_campaign(row)

    @staticmethod
    def public_campaign(row):
        request = deepcopy(row.get("request")) if isinstance(row.get("request"), dict) else {}
        response = {**request, "request_id": row.get("_id"), "request_status": row.get("state")}
        if isinstance(row.get("result"), dict):
            response["assessment"] = deepcopy(row["result"])
        if isinstance(row.get("review"), dict):
            response["review"] = deepcopy(row["review"])
        if row.get("state") == "REJECTED":
            response["rejection_reason"] = row.get("rejection_reason")
        return response

    def list_campaigns(self, store_ids, skip, limit, owner_id=None):
        if (not isinstance(skip, int) or isinstance(skip, bool) or skip < 0 or
                not isinstance(limit, int) or isinstance(limit, bool) or limit < 1 or limit > 100 or
                (owner_id is not None and (not isinstance(owner_id, str) or not owner_id))):
            raise error(422, "INVALID_PAGINATION")
        query = {}
        if store_ids is not None:
            query["store_id"] = {"$in": list(store_ids)}
        if owner_id is not None:
            query["owner_id"] = owner_id
        try:
            collection = self._collection("campaign-analysis")
            total = collection.count_documents(query)
            rows = list(collection.find(query, PROJECTION).sort("created_at", -1).skip(skip).limit(limit))
            for row in rows:
                self._validate(row)
            return {"items": [self.public_campaign(row) for row in rows], "total": total,
                "skip": skip, "limit": limit}
        except HTTPException:
            raise
        except Exception:
            raise error(503, "COMMUNICATION_STORAGE_UNAVAILABLE") from None

    def begin_review(self, key, review):
        collection = self._collection("campaign-analysis")
        try:
            receipt = collection.update_one({"_id": key, "state": "PENDING_REVIEW"},
                {"$set": {"state": "PROCESSING", "review": deepcopy(review)}})
            if receipt.acknowledged and receipt.matched_count == 1:
                row = self.get("campaign-analysis", key)
                return PlanningClaim("campaign-analysis", key, row["lease"], True,
                    payload=deepcopy(row.get("request")))
        except Exception:
            pass
        row = self.get("campaign-analysis", key)
        if row is None:
            raise error(404, "REQUEST_NOT_FOUND")
        raise error(409, "REQUEST_ALREADY_DECIDED")

    def finish_review(self, claim, state, result):
        if (not claim.acquired or claim.namespace != "campaign-analysis" or
                state not in ("COMPLETED", "UNSUPPORTED_PERIOD", "FAILED")):
            raise error(409, "CLAIM_CONFLICT")
        digest = fingerprint(result)
        try:
            receipt = self._collection(claim.namespace).update_one(
                {"_id": claim.key, "lease": claim.lease, "state": "PROCESSING"},
                {"$set": {"state": state, "result": deepcopy(result), "result_digest": digest,
                    "completed_at": datetime.now(timezone.utc)}})
            if receipt.acknowledged and receipt.matched_count == 1:
                return
        except Exception:
            pass
        existing = self.get(claim.namespace, claim.key)
        if (existing is not None and existing["lease"] == claim.lease and
                existing["state"] == state and existing.get("result_digest") == digest):
            return
        raise error(503, "OUTCOME_UNCONFIRMED")

    def reject_campaign(self, key, reason, review):
        try:
            receipt = self._collection("campaign-analysis").update_one(
                {"_id": key, "state": "PENDING_REVIEW"},
                {"$set": {"state": "REJECTED", "review": deepcopy(review),
                    "rejection_reason": reason, "completed_at": datetime.now(timezone.utc)}})
            if receipt.acknowledged and receipt.matched_count == 1:
                return self.public_campaign(self.get("campaign-analysis", key))
        except Exception:
            pass
        row = self.get("campaign-analysis", key)
        if row is None:
            raise error(404, "REQUEST_NOT_FOUND")
        raise error(409, "REQUEST_ALREADY_DECIDED")

    def complete(self, claim, result):
        if not claim.acquired or claim.namespace != "campaign-analysis":
            raise error(409, "CLAIM_CONFLICT")
        digest = fingerprint(result)
        try:
            receipt = self._collection(claim.namespace).update_one(
                {"_id": claim.key, "lease": claim.lease, "state": "PROCESSING"},
                {"$set": {"state": "COMPLETE", "result": deepcopy(result), "result_digest": digest,
                          "completed_at": datetime.now(timezone.utc)}})
            if receipt.acknowledged and receipt.matched_count == 1:
                return
        except Exception:
            pass
        existing = self.get(claim.namespace, claim.key)
        if (existing is not None and existing["lease"] == claim.lease and
                existing["state"] == "COMPLETE" and existing.get("result_digest") == digest):
            return
        raise error(503, "OUTCOME_UNCONFIRMED")
