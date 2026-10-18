"""Standalone Inventory storage provisioning; import performs no IO.

Partial storage requires a separately approved recovery plan, never repair.
DDL and guard insertion are not atomic. On failure, inspect dry-run; do not
retry apply blindly. Run provisioning exclusively, with management stopped.

Transaction probe design (NOT implemented/authorized here): separately approve
 two dedicated Inventory test collections, insert one nonce-tagged record in
 each within one snapshot/primary transaction with majority write concern,
 commit once, and verify both using majority reads. A failed/ambiguous commit
 must not be replayed. Cleanup needs separate approval and exact nonce/_id
 filters, never collection drops. This scope permits only production state
 and audit collections, so no disposable probe writes are enabled.
"""
import argparse
import json
import logging
import os
import sys
from pathlib import Path
from urllib.parse import urlsplit

BACKEND = Path(__file__).resolve().parents[1]
DATABASE = "smart_retail_db"
STATE = "inventory_user_management_state"
AUDIT = "inventory_user_audit"
GUARD = "user_management"
CONFIRMATION = "PROVISION smart_retail_db INVENTORY MANAGEMENT STORAGE"


class ProvisioningError(RuntimeError):
    pass


def inspect_storage(db):
    """Only approved namespaces; guard values/unknown fields never returned."""
    if db.name != DATABASE:
        raise ProvisioningError("Wrong database target.")
    exists = {}
    for name in (STATE, AUDIT):
        names = db.list_collection_names(filter={"name": name})
        if names not in ([], [name]):
            raise ProvisioningError("Unexpected collection metadata.")
        exists[name] = names == [name]
    present = valid = False
    if exists[STATE]:
        collection = db.get_collection(STATE)
        if collection.name != STATE or collection.database is not db:
            raise ProvisioningError("Wrong collection handle.")
        guard = collection.find_one({"_id": GUARD}, {"_id": 1, "revision": 1})
        present = guard is not None
        revision = guard.get("revision") if present else None
        # Server-side schema count catches extra fields without retrieving them.
        schema = {"bsonType": "object", "required": ["_id", "revision"],
                  "additionalProperties": False, "properties": {
                      "_id": {"enum": [GUARD]},
                      "revision": {"bsonType": ["int", "long"], "minimum": 0,
                                   "maximum": 2**63-2}}}
        valid = (present and not isinstance(revision, bool) and isinstance(revision, int)
                 and 0 <= revision < 2**63-1
                 and collection.count_documents({"_id": GUARD, "$jsonSchema": schema}, limit=1) == 1)
        # The state namespace is reserved for the singleton, not test records.
        valid = valid and collection.count_documents({}, limit=2) == 1
    empty = not any(exists.values())
    ready = all(exists.values()) and valid
    return {"database": DATABASE, "collections": exists, "guard_exists": present,
            "guard_valid": bool(valid), "status": "READY" if ready else "EMPTY" if empty else "BLOCKED",
            "would_create": [STATE, AUDIT, "guard:" + GUARD] if empty else [],
            "safe_to_apply": empty or ready}


def provision_storage(db, *, apply=False, confirmation=None):
    try:
        report = inspect_storage(db)
        if not apply:
            return report
        if confirmation != CONFIRMATION:
            raise ProvisioningError("Apply confirmation required; no writes performed.")
        if report["status"] == "READY":
            return report
        if report["status"] != "EMPTY":
            raise ProvisioningError("Partial or malformed storage; deliberate recovery approval required. No writes performed.")
        # Explicit create fails on races; never implicitly create via upsert.
        from pymongo.write_concern import WriteConcern
        for name in (STATE, AUDIT):
            db.create_collection(name, write_concern=WriteConcern("majority"))
        state = db.get_collection(STATE, write_concern=WriteConcern("majority"))
        if state.name != STATE or state.database is not db:
            raise ProvisioningError("Wrong collection handle; inspect partial storage before recovery.")
        result = state.insert_one({"_id": GUARD, "revision": 0})
        if not result.acknowledged:
            raise ProvisioningError("Guard write not acknowledged; inspect storage before recovery.")
        final = inspect_storage(db)
        if final["status"] != "READY":
            raise ProvisioningError("Final verification failed; inspect storage before recovery.")
        return final
    except ProvisioningError:
        raise
    except Exception:
        raise ProvisioningError("Storage operation failed. Partial objects may remain; use dry-run and obtain recovery approval. No automatic retry.") from None


def connect_existing():
    # Same .env precedence and MongoFirestoreClient/TLS conventions as Admin provisioning.
    from dotenv import dotenv_values
    config = {**dotenv_values(BACKEND / ".env"), **os.environ}
    uri = config.get("MONGODB_URI", "")
    try:
        parsed = urlsplit(uri)
        if (config.get("DB_TYPE", "").lower() != "mongodb"
                or parsed.scheme not in ("mongodb", "mongodb+srv")
                or not parsed.hostname or not parsed.username or not parsed.password
                or parsed.path not in ("", "/", "/" + DATABASE) or parsed.fragment):
            raise ValueError()
    except Exception:
        raise ProvisioningError("Missing or invalid approved MongoDB configuration.") from None
    if str(BACKEND) not in sys.path:
        sys.path.insert(0, str(BACKEND))
    from app.mongo_client import MongoFirestoreClient
    wrapper = MongoFirestoreClient(uri)
    if wrapper.db.name != DATABASE or wrapper.db.client is not wrapper.client:
        wrapper.client.close()
        raise ProvisioningError("Wrong MongoDB handle.")
    return wrapper


class SafeParser(argparse.ArgumentParser):
    def error(self, message):
        raise ProvisioningError("Invalid arguments; use --help.")


def main(argv=None):
    parser = SafeParser(description="Provision only Inventory management storage.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="Read-only assessment (default).")
    mode.add_argument("--apply", action="store_true", help="Requires interactive confirmation.")
    mode.add_argument("--check-transactions", action="store_true", help="Disabled: dedicated probe storage requires separate approval.")
    wrapper = None
    old_logging = logging.root.manager.disable
    try:
        args = parser.parse_args(argv)
        logging.disable(logging.CRITICAL)
        if args.check_transactions:
            raise ProvisioningError("Transaction-write probe disabled. Dedicated test storage and cleanup require separate approval.")
        confirmation = None
        if args.apply:
            if not sys.stdin.isatty():
                raise ProvisioningError("Apply requires an interactive terminal.")
            confirmation = input("Type " + CONFIRMATION + " to continue: ")
            if confirmation != CONFIRMATION:
                raise ProvisioningError("Cancelled; no connection or writes performed.")
        wrapper = connect_existing()
        report = provision_storage(wrapper.db, apply=args.apply, confirmation=confirmation)
        print(json.dumps(report, sort_keys=True))
        return 0 if report["safe_to_apply"] else 1
    except (KeyboardInterrupt, EOFError):
        print("Cancelled.", file=sys.stderr)
        return 1
    except ProvisioningError as error:
        print(str(error), file=sys.stderr)
        return 1
    except Exception:
        print("Storage connection or operation unavailable; sensitive details suppressed.", file=sys.stderr)
        return 1
    finally:
        if wrapper is not None:
            try:
                wrapper.client.close()
            except Exception:
                pass
        logging.disable(old_logging)


if __name__ == "__main__":
    raise SystemExit(main())
