"""Provisioning tests use injected collections only; never create real users."""
import copy
import importlib.util
import io
import os
import re
import socket
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import Mock, patch

from bson import ObjectId
from pymongo.errors import DuplicateKeyError
from app.services.inventory_auth_service import InventoryAuthService, InventoryJWTSettings

BACKEND = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "isolated_inventory_admin_provisioning", BACKEND / "scripts/provision_inventory_admin.py"
)
provisioning = importlib.util.module_from_spec(spec)
spec.loader.exec_module(provisioning)


class FakeCursor:
    def __init__(self, records):
        self.records = records

    def limit(self, count):
        return self.records[:count]


class FakeCollection:
    name = "inventory_users"

    def __init__(self, database, records):
        self.database = database
        self.records = records
        self.writes = []
        self.reads = []
        self.returned = []
        self.indexes = {"_id_": {"key": [("_id", 1)]}}
        self.fail_insert = False

    def find(self, query, projection):
        # Require explicit inclusion projections, even for apply's Admin read.
        if not projection or any(value not in (0, 1) for value in projection.values()):
            raise AssertionError("Explicit projection required")
        self.reads.append(("find", copy.deepcopy(query), copy.deepcopy(projection)))
        result = []
        for record in self.records:
            if all(record.get(key) == value for key, value in query.items()):
                result.append({
                    key: copy.deepcopy(value) for key, value in record.items()
                    if projection.get(key, 1 if key == "_id" else 0)
                })
        self.returned.extend(copy.deepcopy(result))
        return FakeCursor(result)

    def count_documents(self, query, *, limit):
        self.reads.append(("count", copy.deepcopy(query), limit))
        # Small JSON Schema evaluator for the supported read-only predicate.
        schema = query["$nor"][0]["$jsonSchema"]
        return min(limit, sum(not self._matches_schema(record, schema) for record in self.records))

    @classmethod
    def _matches_schema(cls, value, schema):
        types = {
            "object": lambda v: isinstance(v, dict),
            "objectId": lambda v: isinstance(v, ObjectId),
            "string": lambda v: isinstance(v, str),
            "array": lambda v: isinstance(v, list),
            "bool": lambda v: type(v) is bool,
            "date": lambda v: isinstance(v, datetime),
            "int": lambda v: isinstance(v, int) and not isinstance(v, bool),
            "long": lambda v: isinstance(v, int) and not isinstance(v, bool),
        }
        if "bsonType" in schema:
            allowed = schema["bsonType"] if isinstance(schema["bsonType"], list) else [schema["bsonType"]]
            if not any(types[name](value) for name in allowed):
                return False
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            if not schema.get("minimum", float("-inf")) <= value <= schema.get("maximum", float("inf")):
                return False
        if "enum" in schema and value not in schema["enum"]:
            return False
        if isinstance(value, dict):
            properties = schema.get("properties", {})
            if not set(schema.get("required", [])).issubset(value):
                return False
            if schema.get("additionalProperties") is False and set(value) - set(properties):
                return False
            if any(not cls._matches_schema(item, properties.get(key, {})) for key, item in value.items()):
                return False
        if isinstance(value, str):
            if not schema.get("minLength", 0) <= len(value) <= schema.get("maxLength", float("inf")):
                return False
            if "pattern" in schema and re.search(schema["pattern"], value) is None:
                return False
        if isinstance(value, list) and "items" in schema:
            if any(not cls._matches_schema(item, schema["items"]) for item in value):
                return False
        return True

    def index_information(self):
        self.reads.append(("indexes",))
        return copy.deepcopy(self.indexes)

    def create_index(self, keys, **kwargs):
        self.writes.append(("index", keys, kwargs))
        self.indexes[kwargs["name"]] = {"key": keys, **kwargs}
        return kwargs["name"]

    def insert_one(self, record):
        if self.fail_insert:
            raise DuplicateKeyError("synthetic-private-error")
        if any(r["username_normalized"] == record["username_normalized"] for r in self.records):
            raise DuplicateKeyError("duplicate")
        self.writes.append(("insert", copy.deepcopy(record)))
        self.records.append(copy.deepcopy(record))
        return Mock(inserted_id=record["_id"])


class FakeDatabase:
    name = "smart_retail_db"

    def __init__(self, records=None):
        self.accessed = []
        self.inventory = FakeCollection(self, records or [])
        self.collection_exists = records is not None
        self.metadata_reads = []

    def list_collection_names(self, *, filter):
        self.metadata_reads.append(copy.deepcopy(filter))
        if filter != {"name": "inventory_users"}:
            raise AssertionError("Other collection metadata forbidden")
        return ["inventory_users"] if self.collection_exists else []

    def get_collection(self, name):
        self.accessed.append(name)
        if name != "inventory_users":
            raise AssertionError("Other collection access forbidden")
        return self.inventory


class InventoryAdminProvisioningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.auth = InventoryAuthService(
            InventoryJWTSettings(secret="test-only-provisioning-key-000000-000000-000000")
        )
        cls.password_hash = cls.auth.hash_password("test-only-admin-password")

    def setUp(self):
        for target in ("socket.create_connection", "socket.socket.connect", "pymongo.MongoClient"):
            guard = patch(target, side_effect=AssertionError("Real network/client forbidden"))
            guard.start()
            self.addCleanup(guard.stop)
        self.db = FakeDatabase()
        self.password_reader = Mock(side_effect=["test-only-admin-password", "test-only-admin-password"])

    def record(self, username="inventoryadmin"):
        now = datetime.now(timezone.utc)
        return {
            "_id": ObjectId("0123456789abcdef01234567"),
            "username_normalized": username, "display_name": "Inventory Admin",
            "password_hash": self.password_hash, "role": "admin", "store_ids": [],
            "global_access": True, "is_active": True,
            "created_at": now, "updated_at": now,
        }

    def apply(self, **kwargs):
        options = {
            "dry_run": False, "confirmation": provisioning.CONFIRMATION,
            "password_reader": self.password_reader, "auth_service": self.auth,
        }
        options.update(kwargs)
        return provisioning.provision_admin(self.db, **options)

    def test_optional_management_metadata_is_compatible_without_writes(self):
        record = self.record()
        record.update(auth_version=2, revision=3,
                      created_by="oid:0123456789abcdef01234567",
                      updated_by="oid:0123456789abcdef01234567",
                      password_changed_at=datetime.now(timezone.utc))
        self.db = FakeDatabase([record])
        before = copy.deepcopy(record)
        for dry_run in (True, False):
            self.assertEqual(provisioning.provision_admin(self.db, dry_run=dry_run),
                             "ALREADY_EXISTS_INDEX_MISSING")
        self.assertEqual(self.db.inventory.records, [before])
        self.assertEqual(self.db.inventory.writes, [])

    def test_invalid_optional_metadata_is_rejected(self):
        for field, value in (("auth_version", True), ("revision", -1),
                             ("created_by", "invalid"), ("password_changed_at", "invalid")):
            for dry_run in (True, False):
                with self.subTest(field=field, dry_run=dry_run):
                    record = self.record()
                    record[field] = value
                    self.db = FakeDatabase([record])
                    with self.assertRaises(provisioning.ProvisioningError):
                        provisioning.provision_admin(self.db, dry_run=dry_run)
                    self.assertEqual(self.db.inventory.writes, [])

    def test_dry_run_no_writes_or_password_prompt(self):
        result = provisioning.provision_admin(self.db)
        self.assertEqual(result, "DRY_RUN_CREATE_INDEX_AND_ADMIN")
        self.assertEqual(self.db.inventory.writes, [])
        self.assertEqual(self.db.accessed, ["inventory_users"])
        self.password_reader.assert_not_called()

    def test_dry_run_uses_username_only_and_admin_metadata_projections(self):
        self.db.inventory.records = [self.record(), self.record("other-user")]
        result = provisioning.provision_admin(self.db)
        self.assertEqual(result, "ALREADY_EXISTS_INDEX_MISSING")
        finds = [read for read in self.db.inventory.reads if read[0] == "find"]
        self.assertEqual(finds[0], ("find", {}, {"_id": 0, "username_normalized": 1}))
        self.assertEqual(finds[1][1], {"username_normalized": "inventoryadmin"})
        self.assertEqual(finds[1][2], {"_id": 0, "role": 1, "store_ids": 1, "global_access": 1, "is_active": 1})
        for read in finds:
            self.assertNotIn("password_hash", read[2])
            self.assertTrue(all(v == 1 for k, v in read[2].items() if k != "_id"))
        for record in self.db.inventory.returned:
            self.assertNotIn("password_hash", record)
            if record.get("username_normalized") == "other-user":
                self.assertEqual(set(record), {"username_normalized"})
        counts = [read for read in self.db.inventory.reads if read[0] == "count"]
        self.assertEqual(len(counts), 1)
        self.assertEqual(counts[0][2], 1)
        self.assertEqual(counts[0][1]["$nor"][0]["$jsonSchema"]["properties"]["password_hash"], {})
        self.assertEqual(self.db.inventory.writes, [])

    def test_dry_run_does_not_read_or_validate_hash_contents(self):
        self.db.inventory.records = [{**self.record(), "password_hash": object()}]
        with patch("argon2.extract_parameters", side_effect=AssertionError("Hash read forbidden")):
            self.assertEqual(provisioning.provision_admin(self.db), "ALREADY_EXISTS_INDEX_MISSING")
        self.assertEqual(self.db.inventory.writes, [])

    def test_dry_run_detects_duplicates_including_unicode_casefold(self):
        for names in [("inventoryadmin", " INVENTORYADMIN "), ("Stra\u00dfe", "STRASSE")]:
            self.db.inventory.records = [self.record(name) for name in names]
            with self.assertRaisesRegex(provisioning.ProvisioningError, "Duplicate"):
                provisioning.provision_admin(self.db)
            self.assertEqual(self.db.inventory.writes, [])

    def test_dry_run_rejects_noncanonical_username(self):
        self.db.inventory.records = [self.record(" INVENTORYADMIN ")]
        with self.assertRaises(provisioning.ProvisioningError):
            provisioning.provision_admin(self.db)
        self.assertEqual(self.db.inventory.writes, [])

    def test_dry_run_reports_index_and_admin_states(self):
        for existing in (False, True):
            for indexed in (False, True):
                with self.subTest(existing=existing, indexed=indexed):
                    db = FakeDatabase([self.record()] if existing else [])
                    if indexed:
                        db.inventory.indexes["existing"] = {
                            "key": [("username_normalized", 1)], "unique": True,
                        }
                    expected = (
                        ("ALREADY_EXISTS" if indexed else "ALREADY_EXISTS_INDEX_MISSING")
                        if existing else
                        ("DRY_RUN_CREATE_ADMIN" if indexed else "DRY_RUN_CREATE_INDEX_AND_ADMIN")
                    )
                    self.assertEqual(provisioning.provision_admin(db), expected)
                    self.assertEqual(db.inventory.writes, [])

    def test_dry_run_checks_schema_without_returning_other_users_metadata(self):
        for changes in (
            {"_id": "0123456789abcdef01234567"}, {"is_active": "true"},
            {"global_access": 1}, {"role": "unknown"}, {"display_name": 123},
            {"store_ids": [" CP001"]}, {"store_ids": ["CP001" + chr(10)]},
            {"store_ids": [""]}, {"created_at": "today"}, {"unexpected": "private-value"},
        ):
            with self.subTest(fields=list(changes)):
                self.db.inventory.records = [{**self.record("other-user"), **changes}]
                with self.assertRaises(provisioning.ProvisioningError):
                    provisioning.provision_admin(self.db)
                self.assertEqual(self.db.inventory.writes, [])
        self.assertTrue(all(set(r) == {"username_normalized"} for r in self.db.inventory.returned))

    def test_dry_run_missing_schema_field_fails_closed(self):
        for field in provisioning._ALLOWED_FIELDS:
            record = self.record("other-user")
            del record[field]
            self.db.inventory.records = [record]
            with self.assertRaises(provisioning.ProvisioningError):
                provisioning.provision_admin(self.db)
        self.assertEqual(self.db.inventory.writes, [])

    def test_dry_run_existing_admin_mismatch_fails_without_writes(self):
        for changes in ({"role": "viewer"}, {"is_active": False}, {"global_access": False}, {"store_ids": ["CP001"]}):
            self.db.inventory.records = [{**self.record(), **changes}]
            with self.assertRaises(provisioning.ProvisioningError):
                provisioning.provision_admin(self.db)
        self.assertEqual(self.db.inventory.writes, [])

    def test_collection_existence_query_is_filtered_and_read_only(self):
        for exists in (False, True):
            self.db.collection_exists = exists
            self.assertIs(provisioning._collection_exists(self.db), exists)
        self.assertEqual(self.db.metadata_reads, [{"name": "inventory_users"}] * 2)
        self.assertEqual(self.db.inventory.writes, [])

    def test_apply_retrieves_hash_only_for_initial_admin(self):
        self.db.inventory.records = [self.record(), self.record("other-user")]
        self.assertEqual(self.apply(), "ALREADY_EXISTS_INDEX_MISSING")
        hash_reads = [
            read for read in self.db.inventory.reads
            if read[0] == "find" and "password_hash" in read[2]
        ]
        self.assertEqual(len(hash_reads), 1)
        self.assertEqual(hash_reads[0][1], {"username_normalized": "inventoryadmin"})
        self.assertTrue(all(
            "password_hash" not in record or record["username_normalized"] == "inventoryadmin"
            for record in self.db.inventory.returned
        ))
        self.assertEqual(self.db.inventory.writes, [])

    def test_apply_still_calls_original_admin_hash_validator(self):
        self.db.inventory.records = [self.record()]
        with patch("argon2.extract_parameters", side_effect=ValueError("private-hash")) as validator:
            with self.assertRaises(provisioning.ProvisioningError) as raised:
                self.apply()
        validator.assert_called_once_with(self.password_hash)
        self.assertNotIn("private-hash", str(raised.exception))
        self.assertEqual(self.db.inventory.writes, [])

    def test_apply_rejects_malformed_other_user_hash_without_retrieving_it(self):
        self.db.inventory.records = [{**self.record("other-user"), "password_hash": "plaintext"}]
        with self.assertRaises(provisioning.ProvisioningError):
            self.apply()
        self.assertTrue(all("password_hash" not in record for record in self.db.inventory.returned))
        self.assertEqual(self.db.inventory.writes, [])

    def test_collection_limit_remains_bounded(self):
        self.db.inventory.records = [self.record(str(i)) for i in range(10001)]
        with self.assertRaises(provisioning.ProvisioningError):
            provisioning.provision_admin(self.db)
        self.assertEqual(self.db.inventory.writes, [])

    def test_cli_dry_run_reports_existence_without_credentials_or_writes(self):
        self.db.inventory.records = [self.record(), self.record("other-user")]
        for exists in (False, True):
            self.db.collection_exists = exists
            output = io.StringIO()
            wrapper = Mock(db=self.db)
            self.db.client = wrapper.client
            with patch("dotenv.load_dotenv"), patch.object(
                provisioning, "_validate_environment", return_value="unused-test-uri"
            ), patch("app.mongo_client.MongoFirestoreClient", return_value=wrapper), redirect_stdout(output), redirect_stderr(output):
                self.assertEqual(provisioning.main(["--dry-run"]), 0)
            self.assertEqual(output.getvalue().splitlines(), [
                "COLLECTION_EXISTS" if exists else "COLLECTION_ABSENT",
                "ALREADY_EXISTS_INDEX_MISSING",
            ])
            self.assertNotIn(self.password_hash, output.getvalue())
            self.assertNotIn("test-only-admin-password", output.getvalue())
            self.assertNotIn("other-user", output.getvalue())
            wrapper.client.close.assert_called_once()
        self.assertEqual(self.db.inventory.writes, [])

    def test_apply_output_never_contains_password_or_hash(self):
        output = io.StringIO()
        with redirect_stdout(output), redirect_stderr(output):
            self.apply()
            self.apply()
        self.assertEqual(output.getvalue(), "")

    def test_correct_target_and_objectid_admin(self):
        result = self.apply()
        self.assertEqual(result, "CREATED")
        self.assertEqual(self.db.accessed, ["inventory_users"])
        record = self.db.inventory.records[0]
        self.assertIsInstance(record["_id"], ObjectId)
        self.assertEqual(record["username_normalized"], "inventoryadmin")
        self.assertEqual(record["role"], "admin")
        self.assertIs(record["global_access"], True)
        self.assertIs(record["is_active"], True)
        self.assertEqual(record["store_ids"], [])

    def test_argon2_hash_and_no_plaintext_persistence(self):
        self.apply()
        record = self.db.inventory.records[0]
        self.assertTrue(record["password_hash"].startswith("$argon2id$"))
        self.assertTrue(self.auth.verify_password("test-only-admin-password", record["password_hash"]))
        self.assertNotIn("test-only-admin-password", repr(self.db.inventory.records))
        self.assertEqual(set(record), provisioning._ALLOWED_FIELDS)

    def test_username_normalization_matches_login(self):
        from app.schemas.inventory_auth_schema import InventoryLoginRequest
        for value in [" INVENTORYADMIN ", "InventoryAdmin", " Straße "]:
            self.assertEqual(
                provisioning.normalize_username(value),
                InventoryLoginRequest(username=value, password="test").username,
            )

    def test_unique_index_before_insert(self):
        self.apply()
        writes = self.db.inventory.writes
        self.assertEqual([w[0] for w in writes], ["index", "insert"])
        self.assertEqual(writes[0][1], [("username_normalized", 1)])
        self.assertIs(writes[0][2]["unique"], True)
        self.assertEqual(writes[0][2]["collation"], {"locale": "simple"})

    def test_duplicate_detection_before_index(self):
        self.db.inventory.records = [
            self.record("inventoryadmin"), self.record(" INVENTORYADMIN "),
        ]
        with self.assertRaises(provisioning.ProvisioningError):
            self.apply()
        self.assertEqual(self.db.inventory.writes, [])
        self.password_reader.assert_not_called()

    def test_wrong_database_no_collection_access(self):
        self.db.name = "profiles"
        with self.assertRaises(provisioning.ProvisioningError):
            self.apply()
        self.assertEqual(self.db.accessed, [])
        self.assertEqual(self.db.inventory.writes, [])

    def test_wrong_collection_no_writes(self):
        self.db.inventory.name = "profiles"
        with self.assertRaises(provisioning.ProvisioningError):
            self.apply()
        self.assertEqual(self.db.inventory.writes, [])

    def test_wrong_collection_database_no_writes(self):
        self.db.inventory.database = object()
        with self.assertRaises(provisioning.ProvisioningError):
            self.apply()
        self.assertEqual(self.db.inventory.writes, [])

    def test_repeated_execution_is_noop(self):
        self.apply()
        before = copy.deepcopy(self.db.inventory.records)
        count = len(self.db.inventory.writes)
        self.assertEqual(self.apply(), "ALREADY_EXISTS")
        self.assertEqual(self.db.inventory.records, before)
        self.assertEqual(len(self.db.inventory.writes), count)
        self.assertEqual(self.password_reader.call_count, 2)

    def test_existing_admin_missing_index_is_reported_not_changed(self):
        self.db.inventory.records = [self.record()]
        before = copy.deepcopy(self.db.inventory.records)
        self.assertEqual(self.apply(), "ALREADY_EXISTS_INDEX_MISSING")
        self.assertEqual(self.db.inventory.writes, [])
        self.assertEqual(self.db.inventory.records, before)
        self.password_reader.assert_not_called()

    def test_existing_account_never_promoted_or_replaced(self):
        for changes in ({"role": "viewer"}, {"is_active": False}, {"global_access": False}, {"store_ids": ["CP001"]}):
            self.db.inventory.records = [{**self.record(), **changes}]
            before = copy.deepcopy(self.db.inventory.records)
            with self.assertRaises(provisioning.ProvisioningError):
                self.apply()
            self.assertEqual(self.db.inventory.records, before)
            self.assertEqual(self.db.inventory.writes, [])

    def test_malformed_existing_record_no_writes(self):
        for changes in ({"_id": "0123456789abcdef01234567"}, {"password_hash": "plaintext"}, {"unexpected": "data"}, {"username_normalized": " INVENTORYADMIN "}):
            self.db.inventory.records = [{**self.record(), **changes}]
            with self.assertRaises(provisioning.ProvisioningError):
                self.apply()
            self.assertEqual(self.db.inventory.writes, [])

    def test_index_conflict_no_writes(self):
        self.db.inventory.indexes["bad"] = {"key": [("username_normalized", 1)], "unique": False}
        with self.assertRaises(provisioning.ProvisioningError):
            self.apply()
        self.assertEqual(self.db.inventory.writes, [])

    def test_existing_unique_index_not_recreated(self):
        self.db.inventory.indexes["existing"] = {"key": [("username_normalized", 1)], "unique": True}
        self.assertEqual(self.apply(), "CREATED")
        self.assertEqual([w[0] for w in self.db.inventory.writes], ["insert"])

    def test_confirmation_required_before_password_or_writes(self):
        with self.assertRaises(provisioning.ProvisioningError):
            self.apply(confirmation="wrong")
        self.password_reader.assert_not_called()
        self.assertEqual(self.db.inventory.writes, [])

    def test_password_mismatch_and_length_no_writes(self):
        for passwords in (["short", "short"], ["test-only-admin-password", "different"], ["x"*1025, "x"*1025]):
            with self.assertRaises(provisioning.ProvisioningError):
                self.apply(password_reader=Mock(side_effect=passwords))
            self.assertEqual(self.db.inventory.writes, [])

    def test_hash_failure_no_writes_and_no_leak(self):
        service = Mock()
        service.hash_password.side_effect = RuntimeError("synthetic-private-password")
        with self.assertRaises(provisioning.ProvisioningError) as raised:
            self.apply(auth_service=service)
        self.assertNotIn("synthetic-private-password", str(raised.exception))
        self.assertEqual(self.db.inventory.writes, [])

    def test_race_never_replaces_existing_account(self):
        self.db.inventory.fail_insert = True
        with self.assertRaises(provisioning.ProvisioningError) as raised:
            self.apply()
        self.assertEqual(self.db.inventory.records, [])
        self.assertEqual([w[0] for w in self.db.inventory.writes], ["index"])
        self.assertNotIn("synthetic-private-error", str(raised.exception))

    def test_missing_or_wrong_environment(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(provisioning.ProvisioningError):
                provisioning._validate_environment()
        for uri in ["", "https://invalid", "mongodb://localhost", "mongodb://test:test@localhost/otherdb"]:
            with patch.dict(os.environ, {"DB_TYPE": "mongodb", "MONGODB_URI": uri}, clear=True):
                with self.assertRaises(provisioning.ProvisioningError):
                    provisioning._validate_environment()
        self.assertEqual(self.db.inventory.writes, [])

    def test_password_cli_argument_is_rejected_without_echo(self):
        output = io.StringIO()
        with redirect_stderr(output):
            self.assertEqual(provisioning.main(["--password", "synthetic-private-password"]), 1)
        self.assertNotIn("synthetic-private-password", output.getvalue())

    def test_hidden_password_refuses_noninteractive_input(self):
        with patch.object(sys.stdin, "isatty", return_value=False):
            with self.assertRaises(provisioning.ProvisioningError):
                provisioning._hidden_password("prompt")
        self.assertEqual(self.db.inventory.writes, [])

    def test_apply_declined_does_not_connect(self):
        output = io.StringIO()
        with patch.dict(os.environ, {"DB_TYPE": "mongodb", "MONGODB_URI": "mongodb://test:test@localhost/"}, clear=True), patch("dotenv.load_dotenv"), patch.object(sys.stdin, "isatty", return_value=True), patch("builtins.input", return_value="decline"), redirect_stderr(output):
            self.assertEqual(provisioning.main(["--apply"]), 1)
        self.assertEqual(self.db.inventory.writes, [])

    def test_unexpected_read_failure_is_sanitized(self):
        self.db.inventory.find = Mock(side_effect=RuntimeError("private-connection-uri"))
        with self.assertRaises(provisioning.ProvisioningError) as raised:
            provisioning.provision_admin(self.db)
        self.assertNotIn("private-connection-uri", str(raised.exception))
        self.assertEqual(self.db.inventory.writes, [])


if __name__ == "__main__":
    unittest.main()
