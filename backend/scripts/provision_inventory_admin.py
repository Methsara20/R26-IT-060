"""One-time Inventory-only provisioning. Importing this module performs no IO.

Default: dry-run. Apply requires the exact interactive confirmation phrase.
No startup registration, migrations, account replacement, or other collections.
A successful apply may create the collection implicitly through its index.
Index creation and account insertion are separate operations: a failed insert
can leave the approved unique index in place. Never roll back by deleting data.
"""
import argparse
import getpass
import os
import sys
import warnings
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit

BACKEND = Path(__file__).resolve().parents[1]
DATABASE = "smart_retail_db"
COLLECTION = "inventory_users"
USERNAME = "inventoryadmin"
INDEX_NAME = "inventory_username_normalized_unique"
CONFIRMATION = "PROVISION smart_retail_db.inventory_users inventoryadmin"
_ALLOWED_FIELDS = {
    "_id", "username_normalized", "display_name", "password_hash", "role",
    "store_ids", "global_access", "is_active", "created_at", "updated_at",
}

_OPTIONAL_FIELDS = {"auth_version", "revision", "created_by", "updated_by", "password_changed_at"}


class ProvisioningError(RuntimeError):
    """Only fixed, non-sensitive error messages are allowed."""


def normalize_username(value):
    from app.schemas.inventory_auth_schema import InventoryLoginRequest
    return InventoryLoginRequest.normalize_username(value)


def _validate_record(record):
    from argon2 import Type, extract_parameters
    from app.schemas.inventory_auth_schema import InventoryPrincipal
    from app.services.inventory_user_service import canonical_user_id, object_id_from_subject
    try:
        if not isinstance(record, dict) or not _ALLOWED_FIELDS.issubset(record) or set(record) - (_ALLOWED_FIELDS | _OPTIONAL_FIELDS):
            raise ValueError()
        for name in ("auth_version", "revision"):
            if name in record and (isinstance(record[name], bool) or not isinstance(record[name], int)
                                   or not 0 <= record[name] <= 2**63-1):
                raise ValueError()
        for name in ("created_by", "updated_by"):
            if name in record:
                object_id_from_subject(record[name])
        if "password_changed_at" in record and not isinstance(record["password_changed_at"], datetime):
            raise ValueError()
        username = record["username_normalized"]
        if not isinstance(username, str) or not username or username != normalize_username(username) or len(username) > 128:
            raise ValueError()
        if type(record["is_active"]) is not bool or not isinstance(record["store_ids"], list):
            raise ValueError()
        InventoryPrincipal(
            user_id=canonical_user_id(record["_id"]),
            username_normalized=username, display_name=record["display_name"],
            role=record["role"], store_ids=tuple(record["store_ids"]),
            global_access=record["global_access"],
        )
        if extract_parameters(record["password_hash"]).type is not Type.ID:
            raise ValueError()
        if any(not isinstance(record[name], datetime) for name in ("created_at", "updated_at")):
            raise ValueError()
    except Exception:
        raise ProvisioningError("Unexpected or malformed Inventory user records; no writes performed.") from None


def _admin_matches(record):
    return (
        record["role"] == "admin" and record["global_access"] is True
        and record["store_ids"] == [] and record["is_active"] is True
    )


def _index_present(collection):
    indexes = collection.index_information()
    found = False
    for name, spec in indexes.items():
        key = list(spec.get("key", []))
        if name == INDEX_NAME and key != [("username_normalized", 1)]:
            raise ProvisioningError("Conflicting Inventory index; no writes performed.")
        if key == [("username_normalized", 1)]:
            if (
                spec.get("unique") is not True or spec.get("sparse", False)
                or "partialFilterExpression" in spec
                or spec.get("collation", {}).get("locale", "simple") != "simple"
            ):
                raise ProvisioningError("Conflicting Inventory index; no writes performed.")
            found = True
    return found



# Inclusion projections prevent future credential fields from leaking into reads.
_USERNAME_PROJECTION = {"_id": 0, "username_normalized": 1}
_ADMIN_METADATA_PROJECTION = {
    "_id": 0, "role": 1, "store_ids": 1, "global_access": 1, "is_active": 1,
}


def _collection_exists(database):
    # Filter on the server; never enumerate another component's collections.
    return COLLECTION in database.list_collection_names(filter={"name": COLLECTION})


def _record_schema(*, include_password):
    """Server-side validation returns only a count, never document values.

    Dry-run checks credential field presence only, not its value or validity.
    Apply validates other accounts' Argon2id structure on the server; the
    specific initial Admin still undergoes the original Python validation.
    """
    # Match Python str.strip whitespace, including its extra control characters.
    whitespace = r"\s" + "\u001c-\u001f\u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000"
    properties = {
        "_id": {"bsonType": "objectId"},
        "username_normalized": {"bsonType": "string", "minLength": 1, "maxLength": 128},
        "display_name": {"bsonType": "string"},
        "password_hash": {},
        "role": {"enum": ["admin", "manager", "analyst", "operator", "viewer"]},
        "store_ids": {
            "bsonType": "array",
            "items": {"bsonType": "string", "minLength": 1,
                      "pattern": rf"^[^{whitespace}](?:[\s\S]*[^{whitespace}])?(?![\s\S])"},
        },
        "global_access": {"bsonType": "bool"},
        "is_active": {"bsonType": "bool"},
        "created_at": {"bsonType": "date"},
        "updated_at": {"bsonType": "date"},
    }
    for name in ("auth_version", "revision"):
        properties[name] = {"bsonType": ["int", "long"], "minimum": 0, "maximum": 2**63-1}
    for name in ("created_by", "updated_by"):
        properties[name] = {"bsonType": "string", "pattern": r"^oid:[0-9a-f]{24}$"}
    properties["password_changed_at"] = {"bsonType": "date"}
    if include_password:
        properties["password_hash"] = {
            "bsonType": "string",
            # Accept standard Argon2id encodings, including the legacy
            # version-omitted form, without returning other users' hashes.
            "pattern": (
                r"^\$argon2id\$(?:v=[0-9]+\$)?"
                r"(?=[^$]*m=)(?=[^$]*t=)(?=[^$]*p=)"
                r"(?:[mtp]=[0-9]+,){2}[mtp]=[0-9]+\$[^$]*\$[^$]*$"
            ),
        }
    return {
        "bsonType": "object", "required": sorted(_ALLOWED_FIELDS),
        "additionalProperties": False, "properties": properties,
    }


def _read_existing_admin(collection, *, dry_run):
    # Python casefold exactly matches login normalization; MongoDB $toLower
    # would miss Unicode-equivalent usernames. Only usernames leave MongoDB.
    records = list(collection.find({}, _USERNAME_PROJECTION).limit(10001))
    if len(records) > 10000:
        raise ProvisioningError("Unexpected Inventory collection size; no writes performed.")
    seen = set()
    canonical = True
    for record in records:
        username = record.get("username_normalized") if isinstance(record, dict) else None
        if not isinstance(username, str):
            raise ProvisioningError("Unexpected Inventory user records; no writes performed.")
        normalized = normalize_username(username)
        if normalized in seen:
            raise ProvisioningError("Duplicate Inventory usernames; no writes performed.")
        seen.add(normalized)
        canonical = canonical and username == normalized and len(username) <= 128
    if not canonical or collection.count_documents(
        {"$nor": [{"$jsonSchema": _record_schema(include_password=not dry_run)}]},
        limit=1,
    ):
        raise ProvisioningError("Unexpected or malformed Inventory user records; no writes performed.")
    projection = dict(_ADMIN_METADATA_PROJECTION)
    if not dry_run:
        projection = {field: 1 for field in _ALLOWED_FIELDS | _OPTIONAL_FIELDS}
    admins = list(collection.find(
        {"username_normalized": USERNAME}, projection
    ).limit(2))
    if len(admins) > 1:
        raise ProvisioningError("Duplicate Inventory usernames; no writes performed.")
    if admins:
        if not dry_run:
            _validate_record(admins[0])
        return admins[0]
    return None


def provision_admin(database, *, dry_run=True, confirmation=None, password_reader=None, auth_service=None):
    """Injected database/service allow fake-only testing. No client construction."""
    try:
        if database.name != DATABASE:
            raise ProvisioningError("Wrong database target; no writes performed.")
        collection = database.get_collection(COLLECTION)
        if collection.name != COLLECTION or collection.database is not database:
            raise ProvisioningError("Wrong collection target; no writes performed.")
        existing = _read_existing_admin(collection, dry_run=dry_run)
        has_index = _index_present(collection)
        if existing:
            if not _admin_matches(existing):
                raise ProvisioningError("Existing initial account differs from approved Admin; no overwrite permitted.")
            # Repeated execution is a no-op, including when the index is missing.
            return "ALREADY_EXISTS" if has_index else "ALREADY_EXISTS_INDEX_MISSING"
        if dry_run:
            return "DRY_RUN_CREATE_ADMIN" if has_index else "DRY_RUN_CREATE_INDEX_AND_ADMIN"
        if confirmation != CONFIRMATION:
            raise ProvisioningError("Explicit provisioning confirmation is required; no writes performed.")
        if password_reader is None:
            raise ProvisioningError("Secure password input is required; no writes performed.")
        if auth_service is None:
            from app.services.inventory_auth_service import get_inventory_auth_service
            auth_service = get_inventory_auth_service()
        password = password_reader("Initial Inventory Admin password: ")
        repeat = password_reader("Confirm password: ")
        if not isinstance(password, str) or not 12 <= len(password) <= 1024 or password != repeat:
            raise ProvisioningError("Password confirmation or length is invalid; no writes performed.")
        password_hash = auth_service.hash_password(password)
        del password, repeat
        from bson import ObjectId
        now = datetime.now(timezone.utc)
        document = {
            "_id": ObjectId(), "username_normalized": normalize_username(USERNAME),
            "display_name": "Inventory Admin", "password_hash": password_hash,
            "role": "admin", "store_ids": [], "global_access": True,
            "is_active": True, "created_at": now, "updated_at": now,
        }
        _validate_record(document)
        if not has_index:
            collection.create_index(
                [("username_normalized", 1)], name=INDEX_NAME,
                unique=True, collation={"locale": "simple"},
            )
        # Insert only, never update/upsert/replace. Unique index handles races.
        collection.insert_one(document)
        return "CREATED"
    except ProvisioningError:
        raise
    except Exception:
        raise ProvisioningError(
            "Provisioning failed safely without replacing accounts. An approved index may exist; inspect dry-run before retrying."
        ) from None


def _validate_environment():
    if os.environ.get("DB_TYPE", "").lower() != "mongodb":
        raise ProvisioningError("DB_TYPE must select MongoDB.")
    uri = os.environ.get("MONGODB_URI", "")
    try:
        parsed = urlsplit(uri)
        if (
            parsed.scheme not in ("mongodb", "mongodb+srv")
            or not parsed.hostname or not parsed.username or not parsed.password
            or parsed.path not in ("", "/", "/" + DATABASE)
            or parsed.fragment
        ):
            raise ValueError()
    except Exception:
        raise ProvisioningError("Missing credentials or invalid MongoDB configuration.") from None
    return uri


def _hidden_password(prompt):
    # getpass must never fall back to visible input.
    if not sys.stdin.isatty():
        raise ProvisioningError("Password entry requires an interactive terminal.")
    with warnings.catch_warnings():
        warnings.simplefilter("error", getpass.GetPassWarning)
        return getpass.getpass(prompt)


class SafeArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        raise ProvisioningError("Invalid arguments. Use --dry-run or --apply; passwords are never command-line arguments.")


def main(argv=None):
    parser = SafeArgumentParser(description="Provision only the initial Inventory Admin.")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--dry-run", action="store_true", help="Read-only assessment (default).")
    modes.add_argument("--apply", action="store_true", help="Interactive confirmed provisioning.")
    wrapper = None
    try:
        args = parser.parse_args(argv)
        if str(BACKEND) not in sys.path:
            sys.path.insert(0, str(BACKEND))
        from dotenv import load_dotenv
        load_dotenv(BACKEND / ".env", override=False)
        uri = _validate_environment()
        confirmation = None
        if args.apply:
            if not sys.stdin.isatty():
                raise ProvisioningError("Apply requires an interactive terminal.")
            confirmation = input("Type " + CONFIRMATION + " to continue: ")
            if confirmation != CONFIRMATION:
                raise ProvisioningError("Provisioning not confirmed; no database connection made.")
        from app.mongo_client import MongoFirestoreClient
        wrapper = MongoFirestoreClient(uri)  # Reuse existing TLS/client configuration.
        if wrapper.db.name != DATABASE or wrapper.db.client is not wrapper.client:
            raise ProvisioningError("Wrong MongoDB handle.")
        if not args.apply:
            print("COLLECTION_EXISTS" if _collection_exists(wrapper.db) else "COLLECTION_ABSENT")
        outcome = provision_admin(
            wrapper.db, dry_run=not args.apply, confirmation=confirmation,
            password_reader=_hidden_password if args.apply else None,
        )
        print(outcome)
        return 0
    except (KeyboardInterrupt, EOFError):
        print("Provisioning cancelled.", file=sys.stderr)
        return 1
    except ProvisioningError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    except Exception:
        print("Provisioning unavailable; check approved configuration and dependencies.", file=sys.stderr)
        return 1
    finally:
        if wrapper is not None:
            try:
                wrapper.client.close()
            except Exception:
                pass


if __name__ == "__main__":
    raise SystemExit(main())
