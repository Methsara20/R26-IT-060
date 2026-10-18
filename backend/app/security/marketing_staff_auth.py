"""Marketing-only staff sessions backed exclusively by server configuration."""
import json
import os
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from threading import BoundedSemaphore
from uuid import uuid4
import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from argon2.low_level import Type
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

SESSION_SECONDS = 600


def auth_error(status=401, code="INVALID_MARKETING_CREDENTIALS"):
    return HTTPException(status_code=status, detail={"code": code})


@dataclass(frozen=True)
class MarketingStaffSettings:
    username: str
    password_hash: str = field(repr=False)
    session_secret: str = field(repr=False)
    store_ids: tuple[str, ...] = ()
    global_access: bool = False

    def __post_init__(self):
        if (not self.username or self.username != self.username.strip().casefold()
                or not self.password_hash.startswith("$argon2id$")
                or len(self.session_secret.encode()) < 32
                or type(self.global_access) is not bool
                or not isinstance(self.store_ids, tuple)
                or any(not isinstance(store, str) or not store or store != store.strip()
                       or not store.isprintable() for store in self.store_ids)
                or (not self.global_access and not self.store_ids)):
            raise ValueError("Invalid Marketing staff configuration.")

    @classmethod
    def from_environment(cls):
        try:
            global_value = os.environ.get("MARKETING_STAFF_GLOBAL_ACCESS", "false")
            stores = json.loads(os.environ.get("MARKETING_STAFF_STORE_IDS", "[]"))
            if global_value not in ("true", "false") or not isinstance(stores, list):
                raise ValueError()
            return cls(os.environ["MARKETING_STAFF_USERNAME"].strip().casefold(),
                       os.environ["MARKETING_STAFF_PASSWORD_HASH"],
                       os.environ["MARKETING_SESSION_SECRET"], tuple(stores),
                       global_value == "true")
        except Exception:
            raise auth_error(503, "MARKETING_AUTH_UNAVAILABLE") from None


@dataclass(frozen=True)
class MarketingStaffPrincipal:
    subject: str
    username: str
    store_ids: tuple[str, ...]
    global_access: bool

    def authorize_store(self, store_id):
        if not self.global_access and store_id not in self.store_ids:
            raise auth_error(403, "MARKETING_STORE_ACCESS_DENIED")


class MarketingStaffAuth:
    def __init__(self, settings):
        self.settings = settings
        self.hasher = PasswordHasher(time_cost=2, memory_cost=19456,
                                     parallelism=1, type=Type.ID)
        self._slots = BoundedSemaphore(2)

    def login(self, username, password):
        normalized = username.strip().casefold()
        if not self._slots.acquire(blocking=False):
            raise auth_error(429, "MARKETING_LOGIN_BUSY")
        try:
            try:
                valid = self.hasher.verify(self.settings.password_hash, password)
            except (VerificationError, InvalidHashError):
                valid = False
            if normalized != self.settings.username or not valid:
                raise auth_error()
        finally:
            self._slots.release()
        now = datetime.now(timezone.utc)
        token = jwt.encode({"sub": "marketing-staff", "iss": "smart-marketing",
            "aud": "marketing-backend", "purpose": "marketing_staff_session",
            "iat": now, "nbf": now, "exp": now + timedelta(seconds=SESSION_SECONDS),
            "jti": uuid4().hex}, self.settings.session_secret, algorithm="HS256")
        return token

    def current(self, token):
        try:
            claims = jwt.decode(token, self.settings.session_secret, algorithms=["HS256"],
                issuer="smart-marketing", audience="marketing-backend",
                options={"require": ["sub", "iss", "aud", "purpose", "iat", "nbf", "exp", "jti"],
                         "strict_aud": True})
            if claims["sub"] != "marketing-staff" or claims["purpose"] != "marketing_staff_session":
                raise ValueError()
            if any(type(claims[key]) is not int for key in ("iat", "nbf", "exp")):
                raise ValueError()
            if not 0 < claims["exp"] - claims["iat"] <= SESSION_SECONDS or claims["nbf"] != claims["iat"]:
                raise ValueError()
            if not isinstance(claims["jti"], str) or not claims["jti"]:
                raise ValueError()
            return MarketingStaffPrincipal(claims["sub"], self.settings.username,
                self.settings.store_ids, self.settings.global_access)
        except (jwt.InvalidTokenError, ValueError, KeyError, TypeError):
            raise auth_error() from None


def get_marketing_staff_settings():
    return MarketingStaffSettings.from_environment()


def get_marketing_staff_auth(settings=Depends(get_marketing_staff_settings)):
    return MarketingStaffAuth(settings)


_bearer = HTTPBearer(auto_error=False)


def require_marketing_staff(credentials: HTTPAuthorizationCredentials = Depends(_bearer),
                            auth: MarketingStaffAuth = Depends(get_marketing_staff_auth)):
    if credentials is None or credentials.scheme.lower() != "bearer" or len(credentials.credentials) > 16384:
        raise auth_error()
    return auth.current(credentials.credentials)
