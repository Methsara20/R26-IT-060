"""Fake-only storage provisioning tests. No live clients or shared app imports."""
import copy
import importlib.util
import io
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from pymongo.errors import DuplicateKeyError, OperationFailure

spec = importlib.util.spec_from_file_location("storage_provisioning", Path(__file__).resolve().parents[2] / "scripts/provision_inventory_user_management_storage.py")
script = importlib.util.module_from_spec(spec)
spec.loader.exec_module(script)


class Collection:
    def __init__(self, db, name):
        self.database, self.name = db, name

    def find_one(self, query, projection):
        assert query == {"_id": script.GUARD}
        assert projection == {"_id": 1, "revision": 1}
        for row in self.database.data[self.name]:
            if row.get("_id") == script.GUARD:
                return {k: v for k, v in row.items() if k in projection}

    def count_documents(self, query, limit):
        rows = self.database.data[self.name]
        if not query:
            return min(len(rows), limit)
        assert query["$jsonSchema"]["additionalProperties"] is False
        return min(sum(set(row) == {"_id", "revision"} and row["_id"] == script.GUARD
                       and type(row["revision"]) is int and 0 <= row["revision"] < 2**63-1
                       for row in rows), limit)

    def insert_one(self, row):
        self.database.writes.append(("insert", self.name))
        if self.database.duplicate:
            raise DuplicateKeyError("private-credential-marker")
        assert self.name == script.STATE and row == {"_id": script.GUARD, "revision": 0}
        self.database.data[self.name].append(copy.deepcopy(row))
        return SimpleNamespace(acknowledged=True)


class Database:
    name = script.DATABASE

    def __init__(self, data=None):
        self.data = copy.deepcopy(data or {})
        self.writes = []
        self.duplicate = False

    def list_collection_names(self, *, filter):
        assert filter in ({"name": script.STATE}, {"name": script.AUDIT})
        return [filter["name"]] if filter["name"] in self.data else []

    def get_collection(self, name, **kwargs):
        assert name in (script.STATE, script.AUDIT)
        if kwargs:
            assert kwargs["write_concern"].document == {"w": "majority"}
        return Collection(self, name)

    def create_collection(self, name, *, write_concern):
        assert name in (script.STATE, script.AUDIT)
        assert write_concern.document == {"w": "majority"}
        if name in self.data:
            raise OperationFailure("private-credential-marker")
        self.writes.append(("create", name))
        self.data[name] = []


class StorageProvisioningTests(unittest.TestCase):
    def setUp(self):
        for target in ("pymongo.MongoClient", "socket.create_connection"):
            guard = patch(target, side_effect=AssertionError("Live IO forbidden"))
            guard.start()
            self.addCleanup(guard.stop)

    def ready(self, revision=0):
        return Database({script.STATE: [{"_id": script.GUARD, "revision": revision}], script.AUDIT: []})

    def apply(self, db):
        return script.provision_storage(db, apply=True, confirmation=script.CONFIRMATION)

    def cli(self, args, **kwargs):
        output = io.StringIO()
        with redirect_stdout(output), redirect_stderr(output):
            code = script.main(args)
        self.assertNotIn("private-credential-marker", output.getvalue())
        return code, output.getvalue()

    def test_empty_default_dry_run_no_writes(self):
        db = Database()
        result = script.provision_storage(db)
        self.assertEqual(result["status"], "EMPTY")
        self.assertEqual(result["would_create"], [script.STATE, script.AUDIT, "guard:" + script.GUARD])
        self.assertEqual(db.data, {})
        self.assertEqual(db.writes, [])

    def test_apply_empty_and_verify_final_state(self):
        db = Database()
        self.assertEqual(self.apply(db)["status"], "READY")
        self.assertEqual(db.writes, [("create", script.STATE), ("create", script.AUDIT), ("insert", script.STATE)])
        self.assertEqual(db.data[script.STATE], [{"_id": script.GUARD, "revision": 0}])

    def test_valid_existing_guard_revision_never_reset_or_recreated(self):
        db = self.ready(72)
        before = copy.deepcopy(db.data)
        self.assertEqual(self.apply(db)["status"], "READY")
        self.assertEqual(self.apply(db)["status"], "READY")
        self.assertEqual(db.data, before)
        self.assertEqual(db.writes, [])

    def test_partial_and_missing_guard_require_recovery(self):
        for data in ({script.STATE: []}, {script.AUDIT: []},
                     {script.STATE: [], script.AUDIT: []},
                     {script.STATE: [{"_id": script.GUARD, "revision": 0}]}):
            with self.subTest(data=data):
                db = Database(data)
                report = script.provision_storage(db)
                self.assertEqual(report["status"], "BLOCKED")
                self.assertEqual(report["would_create"], [])
                with self.assertRaises(script.ProvisioningError): self.apply(db)
                self.assertEqual(db.data, data)
                self.assertEqual(db.writes, [])

    def test_malformed_guard_or_extra_state_document_fails_closed(self):
        for row in ({"_id": script.GUARD}, {"_id": "wrong", "revision": 0},
                    {"_id": script.GUARD, "revision": 0, "secret": "private-credential-marker"},
                    *[{"_id": script.GUARD, "revision": v} for v in (True, None, -1, "0", 2**63-1)]):
            db = Database({script.STATE: [row], script.AUDIT: []})
            report = script.provision_storage(db)
            self.assertFalse(report["guard_valid"])
            self.assertNotIn("private-credential-marker", str(report))
            with self.assertRaises(script.ProvisioningError): self.apply(db)
            self.assertEqual(db.writes, [])
        db = self.ready()
        db.data[script.STATE].append({"_id": "unexpected"})
        with self.assertRaises(script.ProvisioningError): self.apply(db)

    def test_duplicate_conflict_no_retry_no_deletion(self):
        db = Database()
        db.duplicate = True
        with self.assertRaises(script.ProvisioningError) as error: self.apply(db)
        self.assertNotIn("private-credential-marker", str(error.exception))
        self.assertEqual(len(db.writes), 3)
        self.assertEqual(script.provision_storage(db)["status"], "BLOCKED")
        with self.assertRaises(script.ProvisioningError): self.apply(db)
        self.assertEqual(len(db.writes), 3)

    def test_confirmation_cancellation_never_connects(self):
        with patch.object(script, "connect_existing") as connect, patch.object(script.sys.stdin, "isatty", return_value=True), patch("builtins.input", return_value="cancel"):
            self.assertEqual(self.cli(["--apply"])[0], 1)
            connect.assert_not_called()
        db = Database()
        with self.assertRaises(script.ProvisioningError): script.provision_storage(db, apply=True)
        self.assertEqual(db.writes, [])

    def test_noninteractive_apply_rejected(self):
        with patch.object(script, "connect_existing") as connect, patch.object(script.sys.stdin, "isatty", return_value=False):
            self.assertEqual(self.cli(["--apply"])[0], 1)
            connect.assert_not_called()

    def test_connection_failure_is_sanitized(self):
        with patch.object(script, "connect_existing", side_effect=RuntimeError("private-credential-marker")):
            self.assertEqual(self.cli([])[0], 1)

    def test_metadata_and_unexpected_errors_no_writes(self):
        db = Database()
        with patch.object(db, "list_collection_names", side_effect=OperationFailure("private-credential-marker")):
            with self.assertRaises(script.ProvisioningError) as error: self.apply(db)
        self.assertNotIn("private-credential-marker", str(error.exception))
        self.assertEqual(db.writes, [])

    def test_wrong_database_rejected(self):
        db = Database()
        db.name = "wrong"
        with self.assertRaises(script.ProvisioningError): self.apply(db)
        self.assertEqual(db.writes, [])

    def test_unrelated_collections_unchanged(self):
        db = Database({"inventory_users": [{"sentinel": True}], "stores": [{"sentinel": True}]})
        before = copy.deepcopy(db.data)
        self.apply(db)
        for name, rows in before.items(): self.assertEqual(db.data[name], rows)

    def test_cli_default_dry_run_and_client_closed(self):
        from unittest.mock import Mock
        db = Database()
        wrapper = SimpleNamespace(db=db, client=Mock())
        with patch.object(script, "connect_existing", return_value=wrapper):
            self.assertEqual(self.cli([])[0], 0)
        wrapper.client.close.assert_called_once()
        self.assertEqual(db.writes, [])

    def test_transaction_probe_disabled_even_when_explicitly_requested(self):
        with patch.object(script, "connect_existing") as connect:
            code, output = self.cli(["--check-transactions"])
            self.assertEqual(code, 1)
            self.assertIn("disabled", output)
            connect.assert_not_called()


if __name__ == "__main__":
    unittest.main()
