"""Dedicated server-to-server verifier. No token issuance or browser credentials.

Configuration (unset => disabled): INVENTORY_PLANNING_VERIFY_KEY (RSA PUBLIC PEM),
INVENTORY_PLANNING_STORE_IDS (JSON array), INVENTORY_PLANNING_GLOBAL_ACCESS
(literal true/false). Scope is server-owned, never taken from JWT claims.
Pinned issuer/sub: marketing-service; audience: inventory-marketing-planning;
purpose: campaign_planning; permission: planning:access; RS256 only.
"""
from app.security.inventory_marketing_service_auth import MarketingServiceSettings
from app.services.inventory_marketing_planning_service import MarketingPlanningCaller
import json
import os
import time
import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer


def feedback_error(status, code):
    return HTTPException(status_code=status, detail={"code": code})


def get_marketing_service_settings():
    try:
        global_value = os.environ.get("INVENTORY_PLANNING_GLOBAL_ACCESS", "false")
        if global_value not in ("true", "false"):
            raise ValueError()
        stores = json.loads(os.environ.get("INVENTORY_PLANNING_STORE_IDS", "[]"))
        if not isinstance(stores, list):
            raise ValueError()
        return MarketingServiceSettings(os.environ["INVENTORY_PLANNING_VERIFY_KEY"],
                                        tuple(stores), global_value == "true")
    except Exception:
        raise feedback_error(503, "PLANNING_AUTHORIZATION_UNAVAILABLE") from None


_bearer = HTTPBearer(auto_error=False)


def require_marketing_service(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    settings: MarketingServiceSettings = Depends(get_marketing_service_settings),
):
    try:
        if credentials is None or credentials.scheme.lower() != "bearer" or len(credentials.credentials) > 16384:
            raise ValueError()
        claims = jwt.decode(credentials.credentials, settings.verification_key, algorithms=["RS256"],
                            issuer="marketing-service", audience="inventory-marketing-planning",
                            options={"require": ["sub", "iss", "aud", "purpose", "iat", "nbf", "exp", "jti", "permissions"],
                                     "strict_aud": True})
        if claims["sub"] != "marketing-service" or claims["purpose"] != "campaign_planning":
            raise ValueError()
        if not isinstance(claims["permissions"], list) or "planning:access" not in claims["permissions"]:
            raise ValueError()
        if any(type(claims[k]) is not int for k in ("iat", "nbf", "exp")):
            raise ValueError()
        if not 0 < claims["exp"] - claims["iat"] <= 300 or not claims["iat"] <= claims["nbf"] < claims["exp"]:
            raise ValueError()
        if claims["iat"] > time.time() or not isinstance(claims["jti"], str) or not 1 <= len(claims["jti"]) <= 128:
            raise ValueError()
        return MarketingPlanningCaller("marketing-service", settings.store_ids, settings.global_access)
    except Exception:
        raise feedback_error(401, "INVALID_SERVICE_IDENTITY") from None
