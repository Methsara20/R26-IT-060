"""Isolated transaction probe. Import and default dry-run perform no network IO.

Objects for run <32 lowercase hex characters>:
smart_retail_db.inventory_management_tx_probe_<run>_a and ..._<run>_b.
Each receives {_id: "committed", probe_run: <run>, phase: "commit"}.
A separate transaction inserts _id "aborted", phase "rollback" in both,
then explicitly aborts. No production namespaces are accessed.

Cleanup is NOT implemented. Save the printed run ID and exact names. After
separate explicit approval, inspect only those exact namespaces and confirm
all records belong to that run; then approve deletion of those probe objects
(including empty collections). Never use prefix-wide deletion. Failure may
leave collections or committed records; never retry an ambiguous commit.
"""
import argparse
import json
import logging
import re
import secrets
import sys
from pathlib import Path
from pymongo import ReadPreference
from pymongo.read_concern import ReadConcern
from pymongo.write_concern import WriteConcern

DATABASE = "smart_retail_db"
PREFIX = "inventory_management_tx_probe_"


class ProbeError(RuntimeError):
    pass


def plan(run_id):
    if not isinstance(run_id, str) or re.fullmatch(r"[0-9a-f]{32}", run_id) is None:
        raise ProbeError("Invalid probe run identifier.")
    return {"database": DATABASE, "run_id": run_id,
            "collections": [PREFIX + run_id + suffix for suffix in ("_a", "_b")],
            "committed_id": "committed", "aborted_id": "aborted",
            "commit_policy": "One application commit call; PyMongo may internally retry commit. No transaction-body replay; unresolved outcomes fail verification."}


def confirmation(run_id):
    return "VERIFY INVENTORY TRANSACTIONS " + run_id


def connect_existing():
    backend = str(Path(__file__).resolve().parents[1])
    if backend not in sys.path:
        sys.path.insert(0, backend)
    from scripts.provision_inventory_user_management_storage import connect_existing as connect
    return connect()


def verify(db, run_id, *, apply=False, confirmed=None):
    objects = plan(run_id)
    if not apply:
        return {**objects, "status": "DRY_RUN", "verified": False}
    if confirmed != confirmation(run_id):
        raise ProbeError("Exact confirmation required; no writes performed.")
    collections = []
    try:
        if db.name != DATABASE:
            raise ProbeError("Wrong database target.")
        for name in objects["collections"]:
            if db.list_collection_names(filter={"name": name}) != []:
                raise ProbeError("Probe namespace already exists; use a new run after inspecting prior results.")
        for name in objects["collections"]:
            db.create_collection(name, write_concern=WriteConcern("majority", wtimeout=15000))
            collection = db.get_collection(name, read_concern=ReadConcern("majority"),
                                           read_preference=ReadPreference.PRIMARY)
            if collection.name != name or collection.database is not db:
                raise ProbeError("Unexpected probe collection handle.")
            collections.append(collection)
        options = {"read_concern": ReadConcern("snapshot"),
                   "write_concern": WriteConcern("majority", wtimeout=15000),
                   "read_preference": ReadPreference.PRIMARY,
                   "max_commit_time_ms": 15000}
        for phase, identity in (("commit", "committed"), ("rollback", "aborted")):
            with db.client.start_session() as session:
                session.start_transaction(**options)
                try:
                    for collection in collections:
                        result = collection.insert_one({"_id": identity, "probe_run": run_id, "phase": phase}, session=session)
                        if not result.acknowledged:
                            raise ProbeError("Probe write was not acknowledged.")
                    if phase == "rollback":
                        for collection in collections:
                            if collection.count_documents({"_id": identity, "probe_run": run_id}, session=session) != 1:
                                raise ProbeError("Rollback test writes not visible within transaction.")
                        session.abort_transaction()
                    else:
                        # One explicit driver invocation; never replay the body or retry here.
                        # PyMongo may internally retry commit per its transaction specification.
                        try:
                            session.commit_transaction()
                        except Exception:
                            raise ProbeError("Commit failed or outcome unknown. No application retry; retain probe objects for inspection.") from None
                except BaseException:
                    if session.in_transaction:
                        session.abort_transaction()
                    raise
            for collection in collections:
                expected = 1 if phase == "commit" else 0
                if collection.count_documents({"_id": identity, "probe_run": run_id, "phase": phase}) != expected:
                    raise ProbeError("Committed writes or rollback verification failed; retain probe objects.")
        for collection in collections:
            if collection.count_documents({"_id": "committed", "probe_run": run_id, "phase": "commit"}) != 1:
                raise ProbeError("Final committed-write verification failed.")
        return {**objects, "status": "VERIFIED", "verified": True,
                "commit_verified": True, "rollback_verified": True,
                "write_concern": "majority", "cleanup_performed": False}
    except ProbeError:
        raise
    except Exception:
        raise ProbeError("Probe failed; partial test objects may remain. No automatic cleanup or application retry. Sensitive details suppressed.") from None


class SafeParser(argparse.ArgumentParser):
    def error(self, message):
        raise ProbeError("Invalid arguments; use --help.")


def main(argv=None):
    parser = SafeParser(description="Dedicated Inventory transaction verification; no automatic cleanup.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--apply", action="store_true")
    parser.add_argument("--run-id", help="Optional 32-character lowercase hexadecimal run ID.")
    wrapper = None
    previous = logging.root.manager.disable
    try:
        args = parser.parse_args(argv)
        logging.disable(logging.CRITICAL)
        run_id = args.run_id or secrets.token_hex(16)
        objects = plan(run_id)
        print(json.dumps(objects, sort_keys=True))
        if not args.apply:
            print(json.dumps(verify(None, run_id)))
            return 0
        if not sys.stdin.isatty():
            raise ProbeError("Apply requires an interactive terminal.")
        phrase = input("Type " + confirmation(run_id) + " to continue: ")
        if phrase != confirmation(run_id):
            raise ProbeError("Cancelled; no database connection made.")
        wrapper = connect_existing()
        print(json.dumps(verify(wrapper.db, run_id, apply=True, confirmed=phrase), sort_keys=True))
        return 0
    except (KeyboardInterrupt, EOFError):
        print("Cancelled; inspect printed probe objects if writes had begun.", file=sys.stderr)
        return 1
    except ProbeError as error:
        print(str(error), file=sys.stderr)
        return 1
    except Exception:
        print("Probe unavailable; sensitive details suppressed. Inspect printed probe objects before recovery.", file=sys.stderr)
        return 1
    finally:
        if wrapper is not None:
            try:
                wrapper.client.close()
            except Exception:
                pass
        logging.disable(previous)


if __name__ == "__main__":
    raise SystemExit(main())
