"""Isolated authentication; no database connections, Firebase, AI, or dotenv."""
import os
import time
from collections.abc import Mapping
from copy import deepcopy
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from hashlib import sha256
from threading import BoundedSemaphore, Lock
from typing import Any
from uuid import uuid4

import jwt
from argon2 import PasswordHasher, Type
from argon2.exceptions import VerificationError, InvalidHashError
from fastapi import HTTPException
from pydantic import PrivateAttr, ValidationError

from app.schemas.inventory_auth_schema import InventoryPrincipal
from app.services.inventory_user_service import (
    InvalidInventoryUser, InventoryUserRepository, canonical_user_id,
    object_id_from_subject,
)

ALLOWED_ALGORITHMS = ("HS256",)
TOKEN_PURPOSE = "inventory_access"
ACCESS_TOKEN_SECONDS = 900


def unauthorized() -> HTTPException:
    return HTTPException(
        status_code=401, detail="Invalid authentication credentials.",
        headers={"WWW-Authenticate": "Bearer"},
    )


def throttled() -> HTTPException:
    return HTTPException(
        status_code=429, detail="Too many authentication attempts. Try again later.",
        headers={"Retry-After": "60"},
    )


class LoginThrottle:
    """Development-only, thread-safe fixed-window admission control.

    Five failed/in-flight attempts per normalized username per minute, 100 total
    admissions/minute, at most 1024 account keys. Saturation rejects new keys
    rather than evicting active limits. State expires using monotonic time.
    NOT sufficient for multi-worker production: each process has independent
    counters and restarts erase them. No IP/proxy headers or external services.
    """
    def __init__(self, clock=time.monotonic):
        self.clock = clock
        self._lock = Lock()
        self._accounts: dict[str, tuple[float, int]] = {}
        self._window_start = clock()
        self._total = 0

    def begin(self, username: str) -> tuple[str, float]:
        key = sha256(username.encode("utf-8")).hexdigest()
        with self._lock:
            now = self.clock()
            self._accounts = {
                k: v for k, v in self._accounts.items() if now - v[0] < 60
            }
            if now - self._window_start >= 60:
                self._window_start, self._total = now, 0
            start, attempts = self._accounts.get(key, (now, 0))
            if (
                attempts >= 5 or self._total >= 100
                or (key not in self._accounts and len(self._accounts) >= 1024)
            ):
                raise throttled()
            self._accounts[key] = (start, attempts + 1)
            self._total += 1
            return key, start

    def succeeded(self, reservation: tuple[str, float]):
        # Remove only this successful admission; never clear concurrent failures.
        key, start = reservation
        with self._lock:
            current = self._accounts.get(key)
            if current and current[0] == start:
                self._accounts[key] = (start, max(0, current[1] - 1))


@dataclass(frozen=True)
class InventoryJWTSettings:
    secret: str = field(repr=False)
    issuer: str = "smart-inventory"
    audience: str = "inventory-api"

    def __post_init__(self):
        if len(self.secret.encode("utf-8")) < 32 or not self.issuer or not self.audience:
            raise ValueError("Invalid Inventory JWT configuration.")

    @classmethod
    def from_environment(cls):
        return cls(
            secret=os.environ.get("INVENTORY_JWT_SECRET", ""),
            issuer=os.environ.get("INVENTORY_JWT_ISSUER", "smart-inventory"),
            audience=os.environ.get("INVENTORY_JWT_AUDIENCE", "inventory-api"),
        )


def _account_version(record: Mapping[str, Any]) -> int:
    """Legacy accounts read as version zero; never backfill during authentication.

    Future account writers MUST atomically increment auth_version with password,
    role, scope or status updates (including reactivation). Never reset/remove it.
    BSON Int64 is accepted; bool, coercible strings and malformed values are not.
    """
    value = record.get("auth_version", 0)
    if isinstance(value, bool) or not isinstance(value, int) or not 0 <= value <= 2**63 - 1:
        raise unauthorized()
    return int(value)


class _InventoryAccountPrincipal(InventoryPrincipal):
    """Internal snapshot metadata, excluded from schema, repr and serialization.

    Password verification and token issuance must use the same account snapshot.
    A plain public principal cannot be used to invent a version for issuance.
    """
    _auth_version: int | None = PrivateAttr(default=None)


class InventoryAuthService:
    def __init__(self, settings: InventoryJWTSettings, throttle: LoginThrottle | None = None):
        self.settings = settings
        self.hasher = PasswordHasher(
            time_cost=2, memory_cost=19456, parallelism=1, type=Type.ID,
        )
        self._dummy_hash = self.hasher.hash("inventory-invalid-account-placeholder")
        self.throttle = throttle if throttle is not None else LoginThrottle()
        self._verification_slots = BoundedSemaphore(2)

    def hash_password(self, password: str) -> str:
        if not isinstance(password, str) or not password or len(password) > 1024:
            raise ValueError("Invalid password length.")
        return self.hasher.hash(password)

    def verify_password(self, password: str, encoded: Any) -> bool:
        if not self._verification_slots.acquire(blocking=False):
            raise throttled()
        try:
            valid_format = isinstance(encoded, str) and encoded.startswith("$argon2id$")
            candidate = encoded if valid_format else self._dummy_hash
            try:
                matches = self.hasher.verify(candidate, password)
                return bool(matches and valid_format)
            except (VerificationError, InvalidHashError):
                return False
            except Exception:
                raise HTTPException(
                    status_code=503, detail="Inventory authentication is unavailable.",
                ) from None
        finally:
            self._verification_slots.release()

    @staticmethod
    def principal(record: Mapping[str, Any]) -> InventoryPrincipal:
        if not isinstance(record, Mapping):
            raise unauthorized()
        if record.get("is_active") is not True:
            raise unauthorized()
        try:
            store_ids = record.get("store_ids")
            if not isinstance(store_ids, (list, tuple)):
                raise ValueError("Invalid store scope.")
            username = record["username_normalized"]
            if (
                not isinstance(username, str) or not username
                or username != username.strip().casefold() or len(username) > 128
            ):
                raise ValueError("Invalid normalized username.")
            principal = _InventoryAccountPrincipal(
                user_id=canonical_user_id(record.get("_id")),
                username_normalized=username,
                display_name=record["display_name"], role=record["role"],
                store_ids=tuple(store_ids),
                global_access=record.get("global_access", False),
            )
            principal._auth_version = _account_version(record)
            return principal
        except (ValidationError, KeyError, ValueError, TypeError):
            raise HTTPException(status_code=403, detail="Inventory access denied.") from None

    @staticmethod
    def lookup(repository: InventoryUserRepository, method: str, value: str):
        try:
            record = getattr(repository, method)(value)
            if record is not None and not isinstance(record, Mapping):
                raise InvalidInventoryUser("Invalid Inventory account.")
            # MongoDB reads already return detached documents; copying also
            # protects against mutable injected repositories during verification.
            return deepcopy(record)
        except InvalidInventoryUser:
            raise unauthorized() from None
        except Exception:
            raise HTTPException(
                status_code=503, detail="Inventory authentication is unavailable.",
            ) from None

    def authenticate(self, repository: InventoryUserRepository, username: str, password: str):
        username = username.strip().casefold()
        reservation = self.throttle.begin(username)
        record = self.lookup(repository, "find_by_username", username)
        encoded = record.get("password_hash") if record else None
        valid_password = self.verify_password(password, encoded)
        if not record or not valid_password or record.get("username_normalized") != username:
            raise unauthorized()
        try:
            user = self.principal(record)
        except HTTPException:
            raise unauthorized() from None
        self.throttle.succeeded(reservation)
        return user

    def create_token(self, principal: InventoryPrincipal) -> str:
        object_id_from_subject(principal.user_id)
        if not isinstance(principal, _InventoryAccountPrincipal):
            raise unauthorized()
        version = _account_version({"auth_version": principal._auth_version})
        now = datetime.now(timezone.utc)
        return jwt.encode(
            {
                "sub": principal.user_id, "iss": self.settings.issuer,
                "aud": self.settings.audience, "purpose": TOKEN_PURPOSE,
                "iat": now, "nbf": now,
                "exp": now + timedelta(seconds=ACCESS_TOKEN_SECONDS),
                "jti": uuid4().hex, "auth_version": version,
            },
            self.settings.secret, algorithm=ALLOWED_ALGORITHMS[0],
        )

    def verify_token(self, token: str) -> str:
        """Validate token structure; current_user also checks live account version."""
        return self._verified_claims(token)["sub"]

    def _verified_claims(self, token: str) -> dict[str, Any]:
        try:
            claims = jwt.decode(
                token, self.settings.secret, algorithms=list(ALLOWED_ALGORITHMS),
                issuer=self.settings.issuer, audience=self.settings.audience,
                options={"require": ["sub", "iss", "aud", "purpose", "iat", "nbf", "exp", "jti", "auth_version"],
                         "strict_aud": True},
            )
            if claims["purpose"] != TOKEN_PURPOSE:
                raise ValueError("Wrong token purpose.")
            object_id_from_subject(claims["sub"])
            if not isinstance(claims["jti"], str) or not claims["jti"]:
                raise ValueError("Invalid token ID.")
            if any(type(claims[name]) is not int for name in ("iat", "nbf", "exp")):
                raise ValueError("Invalid token times.")
            if not 0 < claims["exp"] - claims["iat"] <= ACCESS_TOKEN_SECONDS:
                raise ValueError("Invalid token lifetime.")
            if claims["nbf"] != claims["iat"]:
                raise ValueError("Invalid activation time.")
            # Old tokens without a version fail closed; sign in again.
            if type(claims["auth_version"]) is not int:
                raise ValueError("Invalid account version.")
            _account_version(claims)
            return claims
        except (jwt.InvalidTokenError, ValueError, TypeError, KeyError):
            raise unauthorized() from None

    def current_user(self, repository: InventoryUserRepository, token: str):
        claims = self._verified_claims(token)
        user_id = claims["sub"]
        record = self.lookup(repository, "find_by_id", user_id)
        if not record:
            raise unauthorized()
        try:
            if canonical_user_id(record.get("_id")) != user_id:
                raise unauthorized()
        except InvalidInventoryUser:
            raise unauthorized() from None
        if _account_version(record) != claims["auth_version"]:
            raise unauthorized()
        return self.principal(record)


_service_lock = Lock()


@lru_cache(maxsize=1)
def _cached_inventory_auth_service() -> InventoryAuthService:
    # Environment changes require process restart; no secrets used as cache keys.
    return InventoryAuthService(InventoryJWTSettings.from_environment())


def get_inventory_auth_service() -> InventoryAuthService:
    try:
        # Serialize first construction so the dummy hash is calculated once.
        with _service_lock:
            return _cached_inventory_auth_service()
    except Exception:
        raise HTTPException(
            status_code=503, detail="Inventory authentication is unavailable.",
        ) from None
