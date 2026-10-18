"""Dedicated server-to-server verifier. No token issuance or browser credentials.

Configuration (unset => disabled): INVENTORY_MARKETING_VERIFY_KEY (RSA PUBLIC PEM),
INVENTORY_MARKETING_STORE_IDS (JSON array), INVENTORY_MARKETING_GLOBAL_ACCESS
(literal true/false). Scope is server-owned, never taken from JWT claims.
Pinned issuer/sub: marketing-service; audience: inventory-campaign-feedback;
purpose: campaign_feedback; permission: campaign-feedback:write; RS256 only.
"""
import json
import os
import time
from dataclasses import dataclass, field
import jwt
from cryptography.hazmat.primitives.serialization import load_pem_public_key
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicKey
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer


def feedback_error(status, code):
    return HTTPException(status_code=status, detail={"code": code})


@dataclass(frozen=True)
class MarketingServiceIdentity:
    producer_id: str
    store_ids: tuple[str, ...]
    global_access: bool = False

    def authorize(self, store_id):
        if not self.global_access and store_id not in self.store_ids:
            raise feedback_error(403, "SCOPE_DENIED")


@dataclass(frozen=True)
class MarketingServiceSettings:
    verification_key: str = field(repr=False)
    store_ids: tuple[str, ...] = ()
    global_access: bool = False

    def __post_init__(self):
        key = load_pem_public_key(self.verification_key.encode())
        if not isinstance(key, RSAPublicKey) or key.key_size < 2048:
            raise ValueError("Invalid service verification key")
        if type(self.global_access) is not bool or not isinstance(self.store_ids, tuple):
            raise ValueError("Invalid service scope")
        if any(not isinstance(s, str) or not s or s != s.strip() or not s.isprintable() for s in self.store_ids):
            raise ValueError("Invalid service scope")
        if not self.global_access and not self.store_ids:
            raise ValueError("Missing service scope")


def get_marketing_service_settings():
    try:
        global_value = os.environ.get("INVENTORY_MARKETING_GLOBAL_ACCESS", "false")
        if global_value not in ("true", "false"):
            raise ValueError()
        stores = json.loads(os.environ.get("INVENTORY_MARKETING_STORE_IDS", "[]"))
        if not isinstance(stores, list):
            raise ValueError()
        return MarketingServiceSettings(os.environ["INVENTORY_MARKETING_VERIFY_KEY"],
                                        tuple(stores), global_value == "true")
    except Exception:
        raise feedback_error(503, "FEEDBACK_UNAVAILABLE") from None


_bearer = HTTPBearer(auto_error=False)


def require_marketing_service(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    settings: MarketingServiceSettings = Depends(get_marketing_service_settings),
):
    try:
        if credentials is None or credentials.scheme.lower() != "bearer" or len(credentials.credentials) > 16384:
            raise ValueError()
        claims = jwt.decode(credentials.credentials, settings.verification_key, algorithms=["RS256"],
                            issuer="marketing-service", audience="inventory-campaign-feedback",
                            options={"require": ["sub", "iss", "aud", "purpose", "iat", "nbf", "exp", "jti", "permissions"],
                                     "strict_aud": True})
        if claims["sub"] != "marketing-service" or claims["purpose"] != "campaign_feedback":
            raise ValueError()
        if not isinstance(claims["permissions"], list) or "campaign-feedback:write" not in claims["permissions"]:
            raise ValueError()
        if any(type(claims[k]) is not int for k in ("iat", "nbf", "exp")):
            raise ValueError()
        if not 0 < claims["exp"] - claims["iat"] <= 300 or not claims["iat"] <= claims["nbf"] < claims["exp"]:
            raise ValueError()
        if claims["iat"] > time.time() or not isinstance(claims["jti"], str) or not 1 <= len(claims["jti"]) <= 128:
            raise ValueError()
        return MarketingServiceIdentity("marketing-service", settings.store_ids, settings.global_access)
    except Exception:
        raise feedback_error(401, "INVALID_SERVICE_IDENTITY") from None
