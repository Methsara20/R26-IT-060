"""No network: transaction snapshots, outcomes and acknowledgements are fake."""
import copy
import importlib.util
import io
import unittest
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from pymongo.errors import OperationFailure

spec = importlib.util.spec_from_file_location("transaction_probe", Path(__file__).resolve().parents[2] / "scripts/verify_inventory_management_transactions.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
RUN = "a" * 32


class Collection:
    def __init__(self, db, name): self.database, self.name = db, name
    def insert_one(self, document, *, session):
        assert session.in_transaction
        self.database.data[self.name].append(copy.deepcopy(document))
        return SimpleNamespace(acknowledged=self.database.ack)
    def count_documents(self, query, session=None):
        if self.database.hide_commit and query["_id"] == "committed": return 0
        return sum(all(row.get(k) == v for k, v in query.items()) for row in self.database.data[self.name])


class Session:
    def __init__(self, db): self.db, self.in_transaction = db, False
    def __enter__(self): return self
    def __exit__(self, *args):
        if self.in_transaction: self.abort_transaction()
    def start_transaction(self, **options):
        assert options["write_concern"].document["w"] == "majority"
        assert options["read_concern"].document == {"level": "snapshot"}
        self.db.options.append(options)
        self.before = copy.deepcopy(self.db.data)
        self.in_transaction = True
    def commit_transaction(self):
        self.db.commits += 1
        if self.db.fail_commit == "unknown":
            self.in_transaction = False
            raise OperationFailure("secret-marker", details={"errorLabels": ["UnknownTransactionCommitResult"]})
        if self.db.fail_commit:
            raise OperationFailure("secret-marker")
        self.in_transaction = False
    def abort_transaction(self):
        self.db.aborts += 1
        if not self.db.bad_rollback: self.db.data = self.before
        self.in_transaction = False


class Database:
    name = probe.DATABASE
    def __init__(self):
        self.client = self
        self.data, self.options = {}, []
        self.commits = self.aborts = 0
        self.ack = True
        self.fail_commit = None
        self.hide_commit = self.bad_rollback = False
    def list_collection_names(self, *, filter):
        assert filter["name"] in probe.plan(RUN)["collections"]
        return [filter["name"]] if filter["name"] in self.data else []
    def create_collection(self, name, *, write_concern):
        assert name in probe.plan(RUN)["collections"]
        assert write_concern.document["w"] == "majority"
        assert name not in self.data
        self.data[name] = []
    def get_collection(self, name, *, read_concern, read_preference):
        assert name in probe.plan(RUN)["collections"]
        assert read_concern.document == {"level": "majority"}
        return Collection(self, name)
    def start_session(self): return Session(self)


class TransactionProbeTests(unittest.TestCase):
    def setUp(self):
        for target in ("pymongo.MongoClient", "socket.create_connection"):
            guard = patch(target, side_effect=AssertionError("Live IO forbidden"))
            guard.start(); self.addCleanup(guard.stop)
        self.db = Database()
    def apply(self):
        return probe.verify(self.db, RUN, apply=True, confirmed=probe.confirmation(RUN))
    def cli(self, args):
        output = io.StringIO()
        with redirect_stdout(output), redirect_stderr(output): code = probe.main(args)
        self.assertNotIn("secret-marker", output.getvalue())
        return code
    def test_default_dry_run_no_connection_or_writes(self):
        with patch.object(probe, "connect_existing") as connect:
            self.assertEqual(self.cli([]), 0)
            self.assertEqual(self.cli(["--dry-run"]), 0)
            connect.assert_not_called()
        self.assertFalse(probe.verify(None, RUN)["verified"])
    def test_confirmation_cancellation(self):
        with patch.object(probe.sys.stdin, "isatty", return_value=True), patch("builtins.input", return_value="cancel"), patch.object(probe, "connect_existing") as connect:
            self.assertEqual(self.cli(["--apply"]), 1)
            connect.assert_not_called()
        with self.assertRaises(probe.ProbeError): probe.verify(self.db, RUN, apply=True)
        self.assertEqual(self.db.data, {})
    def test_success_commit_and_rollback_majority(self):
        result = self.apply()
        self.assertTrue(result["verified"])
        self.assertEqual(self.db.commits, 1)
        self.assertEqual(self.db.aborts, 1)
        self.assertEqual(len(self.db.options), 2)
        for rows in self.db.data.values():
            self.assertEqual(rows, [{"_id": "committed", "probe_run": RUN, "phase": "commit"}])
    def test_failed_commit_not_retried_or_cleaned(self):
        self.db.fail_commit = "failed"
        with self.assertRaises(probe.ProbeError) as error: self.apply()
        self.assertNotIn("secret-marker", str(error.exception))
        self.assertEqual(self.db.commits, 1)
        self.assertEqual(len(self.db.data), 2)
    def test_unknown_commit_not_retried_or_cleaned(self):
        self.db.fail_commit = "unknown"
        with self.assertRaises(probe.ProbeError) as error: self.apply()
        self.assertIn("unknown", str(error.exception))
        self.assertEqual(self.db.commits, 1)
        self.assertTrue(all(len(rows) == 1 for rows in self.db.data.values()))
    def test_failed_rollback_not_reported_as_success(self):
        self.db.bad_rollback = True
        with self.assertRaises(probe.ProbeError): self.apply()
        self.assertEqual(len(self.db.data), 2)
        self.assertTrue(all(len(rows) == 2 for rows in self.db.data.values()))
    def test_committed_write_readback_required(self):
        self.db.hide_commit = True
        with self.assertRaises(probe.ProbeError): self.apply()
        self.assertEqual(self.db.commits, 1)
    def test_unacknowledged_write_fails(self):
        self.db.ack = False
        with self.assertRaises(probe.ProbeError): self.apply()
        self.assertEqual(self.db.commits, 0)
    def test_existing_namespace_never_reused(self):
        name = probe.plan(RUN)["collections"][0]
        self.db.data[name] = [{"sentinel": True}]
        before = copy.deepcopy(self.db.data)
        with self.assertRaises(probe.ProbeError): self.apply()
        self.assertEqual(self.db.data, before)
    def test_wrong_database_and_invalid_identifier(self):
        self.db.name = "wrong"
        with self.assertRaises(probe.ProbeError): self.apply()
        for value in ("inventory_users", "../stores", "A"*32, "", None):
            with self.assertRaises(probe.ProbeError): probe.plan(value)
        self.assertEqual(self.db.data, {})
    def test_production_namespaces_not_accessed_or_modified(self):
        for name in ("inventory_users", "stores", "inventory_user_management_state", "inventory_user_audit"):
            self.db.data[name] = [{"sentinel": True}]
        before = copy.deepcopy(self.db.data)
        self.apply()
        for name, rows in before.items(): self.assertEqual(self.db.data[name], rows)
    def test_connection_failure_no_secret_disclosure(self):
        with patch.object(probe.sys.stdin, "isatty", return_value=True), patch("builtins.input", return_value=probe.confirmation(RUN)), patch.object(probe, "connect_existing", side_effect=RuntimeError("secret-marker")):
            self.assertEqual(self.cli(["--apply", "--run-id", RUN]), 1)


if __name__ == "__main__": unittest.main()
