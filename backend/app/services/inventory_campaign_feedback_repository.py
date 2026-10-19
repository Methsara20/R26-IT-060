"""Native MongoDB feedback adapter; no provisioning, shared wrapper edits or retries.

Pre-provision both collections. Events require full, non-sparse, non-partial unique
indexes (producer_id,event_id) and (opportunity_id,revision), with simple collation.
State uses its standard unique _id index. Never expire event receipts automatically.
Only state/events are written; marketing_opportunities is projected read-only.
"""
from contextlib import contextmanager
from datetime import datetime, timezone
from pymongo import ReadPreference
from pymongo.read_concern import ReadConcern
from pymongo.write_concern import WriteConcern
from pymongo.errors import PyMongoError
from app.security.inventory_marketing_service_auth import feedback_error

STATE = "inventory_campaign_feedback_state"
EVENTS = "inventory_campaign_feedback_events"

class UnknownFeedbackCommit(Exception):
    pass

class InventoryCampaignFeedbackRepository:
    def __init__(self, database):
        if database.name != "smart_retail_db":
            raise feedback_error(503, "FEEDBACK_UNAVAILABLE")
        self.db = database
        self.state = database.get_collection(STATE)
        self.events = database.get_collection(EVENTS)
        self.opportunities = database.get_collection("marketing_opportunities")

    def require_ready(self):
        for name, collection in ((STATE, self.state), (EVENTS, self.events)):
            if self.db.list_collection_names(filter={"name": name}) != [name]:
                raise feedback_error(503, "FEEDBACK_UNAVAILABLE")
            indexes = list(collection.list_indexes())
            if any("expireAfterSeconds" in index for index in indexes):
                raise feedback_error(503, "FEEDBACK_UNAVAILABLE")
            required = [[("_id", 1)]] if name == STATE else [
                [("producer_id", 1), ("event_id", 1)], [("opportunity_id", 1), ("revision", 1)]]
            for fields in required:
                if not any(list(i.get("key", {}).items()) == fields
                           and (i.get("unique") is True or fields == [("_id", 1)])
                           and not i.get("sparse") and "partialFilterExpression" not in i
                           and "expireAfterSeconds" not in i
                           and i.get("collation", {}).get("locale", "simple") == "simple"
                           for i in indexes):
                    raise feedback_error(503, "FEEDBACK_UNAVAILABLE")

    @contextmanager
    def transaction(self):
        with self.db.client.start_session() as session:
            session.start_transaction(read_concern=ReadConcern("snapshot"),
                                      write_concern=WriteConcern("majority", wtimeout=15000),
                                      read_preference=ReadPreference.PRIMARY, max_commit_time_ms=15000)
            try:
                yield session
            except BaseException:
                if session.in_transaction:
                    try:
                        session.abort_transaction()
                    except PyMongoError:
                        pass
                raise
            else:
                try:
                    # One application commit call; driver may retry commit internally.
                    session.commit_transaction()
                except PyMongoError:
                    raise UnknownFeedbackCommit() from None

    def opportunity(self, opportunity_id, session):
        return self.opportunities.find_one({"_id": opportunity_id},
            {"_id": 0, "opportunity_id": 1, "product_id": 1, "store_id": 1}, session=session)

    def current(self, opportunity_id, session=None):
        collection = self.state if session is not None else self.state.with_options(
            read_concern=ReadConcern("majority"), read_preference=ReadPreference.PRIMARY)
        return collection.find_one({"_id": opportunity_id}, {"_id": 0, "producer_id": 1, "snapshot": 1, "revision": 1}, session=session)

    def receipt(self, producer, event_id, session=None):
        collection = self.events if session is not None else self.events.with_options(
            read_concern=ReadConcern("majority"), read_preference=ReadPreference.PRIMARY)
        return collection.find_one({"producer_id": producer, "event_id": event_id},
            {"_id": 0, "producer_id": 1, "event_id": 1, "digest": 1, "opportunity_id": 1, "revision": 1}, session=session)

    def save(self, producer, event, digest, snapshot, previous_revision, session):
        document = {"producer_id": producer, "revision": event.revision, "snapshot": snapshot,
                    "updated_at": datetime.now(timezone.utc)}
        if previous_revision == 0:
            result = self.state.insert_one({"_id": event.opportunity_id, **document}, session=session)
        else:
            result = self.state.update_one({"_id": event.opportunity_id, "producer_id": producer,
                                            "revision": previous_revision}, {"$set": document}, session=session, upsert=False)
            if result.matched_count != 1:
                raise feedback_error(409, "REVISION_CONFLICT")
        if not result.acknowledged:
            raise feedback_error(503, "FEEDBACK_UNAVAILABLE")
        result = self.events.insert_one({"producer_id": producer, "event_id": event.event_id,
            "opportunity_id": event.opportunity_id, "revision": event.revision, "digest": digest,
            "received_at": datetime.now(timezone.utc)}, session=session)
        if not result.acknowledged:
            raise feedback_error(503, "FEEDBACK_UNAVAILABLE")
