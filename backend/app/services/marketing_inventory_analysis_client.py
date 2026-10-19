"""Restricted server-side client for the existing Inventory planning API."""
import hashlib
import json
import os
import time
from dataclasses import dataclass, field
from urllib.parse import quote, urlsplit
from uuid import uuid4
import httpx
import jwt
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey
from cryptography.hazmat.primitives.serialization import load_pem_private_key
from fastapi import HTTPException
from app.schemas.inventory_marketing_planning_schema import CampaignAnalysisRequest


def client_error(status, code):
    return HTTPException(status_code=status, detail={"code": code})


@dataclass(frozen=True)
class MarketingInventoryClientSettings:
    base_url: str
    signing_key: str = field(repr=False)

    def validate(self):
        parsed = urlsplit(self.base_url)
        clean_key = self.signing_key.replace("\\n", "\n").strip("\"'")
        object.__setattr__(self, "signing_key", clean_key)
        key = load_pem_private_key(clean_key.encode(), password=None)
        if (parsed.scheme not in ("http", "https") or not parsed.hostname
                or parsed.username or parsed.password or parsed.query or parsed.fragment
                or parsed.path not in ("", "/") or not isinstance(key, RSAPrivateKey)
                or key.key_size < 2048):
            raise ValueError("Invalid Inventory planning client configuration.")
        return key

    @classmethod
    def from_environment(cls):
        try:
            value = cls(os.environ["MARKETING_INVENTORY_PLANNING_BASE_URL"],
                        os.environ["MARKETING_INVENTORY_PLANNING_PRIVATE_KEY"])
            value.validate()
            return value
        except Exception:
            raise client_error(503, "INVENTORY_PLANNING_CLIENT_UNAVAILABLE") from None


class MarketingInventoryAnalysisClient:
    def __init__(self, settings, transport=None):
        self.settings = settings
        self.key = settings.validate()
        self.transport = transport

    @staticmethod
    def request_id(principal, request):
        identity = "\x1f".join(("v1", principal.subject, request.campaign_reference))
        return "MKT-" + hashlib.sha256(identity.encode()).hexdigest()[:40]

    def _service_token(self):
        now = int(time.time())
        return jwt.encode({"iss": "marketing-service", "sub": "marketing-service",
            "aud": "inventory-marketing-planning", "purpose": "campaign_planning",
            "permissions": ["planning:access"], "iat": now, "nbf": now,
            "exp": now + 120, "jti": uuid4().hex}, self.key, algorithm="RS256")

    def _send(self, method, path, body=None):
        if method not in ("GET", "POST") or not (path == "/inventory-marketing/campaign-analysis"
                or (method == "GET" and path.startswith("/inventory-marketing/campaign-analysis?")
                    and path.count("/") == 2)
                or (method == "GET" and path.startswith("/inventory-marketing/campaign-analysis/")
                    and path.count("/") == 3)):
            raise client_error(503, "INVENTORY_PLANNING_CLIENT_UNAVAILABLE")
        url = self.settings.base_url.rstrip("/") + path
        headers = {"Authorization": "Bearer " + self._service_token(),
                   "Accept": "application/json"}
        if body is not None:
            headers["Content-Type"] = "application/json"
        try:
            if self.transport is not None:
                response = self.transport(method=method, url=url, headers=headers,
                    content=None if body is None else json.dumps(body, separators=(",", ":")),
                    timeout=10, follow_redirects=False)
            else:
                with httpx.Client(follow_redirects=False, timeout=10) as client:
                    response = client.request(method, url, headers=headers, json=body)
        except Exception:
            raise client_error(503, "INVENTORY_PLANNING_OUTCOME_UNCONFIRMED") from None
        if response.status_code == 409:
            raise client_error(409, "CAMPAIGN_REQUEST_CONFLICT")
        if response.status_code in (401, 403):
            raise client_error(503, "INVENTORY_PLANNING_AUTHORIZATION_FAILED")
        if response.status_code < 200 or response.status_code >= 300:
            raise client_error(response.status_code if response.status_code in (404, 422) else 503,
                               "INVENTORY_PLANNING_REQUEST_FAILED")
        try:
            result = response.json()
            if not isinstance(result, dict):
                raise ValueError()
            return result
        except Exception:
            raise client_error(503, "INVALID_INVENTORY_PLANNING_RESPONSE") from None

    def submit(self, principal, request):
        principal.authorize_store(request.store_id)
        request_id = self.request_id(principal, request)
        inventory_request = CampaignAnalysisRequest(request_id=request_id,
            **request.model_dump())
        result = self._send("POST", "/inventory-marketing/campaign-analysis",
                            inventory_request.model_dump(mode="json"))
        if (result.get("request_id") != request_id or result.get("store_id") != request.store_id
                or result.get("product_id") != request.product_id):
            raise client_error(503, "INVALID_INVENTORY_PLANNING_RESPONSE")
        return result

    def status(self, principal, request_id):
        if (not isinstance(request_id, str)
                or not request_id.startswith("MKT-") or len(request_id) != 44
                or any(char not in "0123456789abcdef" for char in request_id[4:])):
            raise client_error(422, "INVALID_REQUEST_ID")
        result = self._send("GET", "/inventory-marketing/campaign-analysis/" + quote(request_id, safe=""))
        if result.get("request_id") != request_id or not isinstance(result.get("store_id"), str):
            raise client_error(503, "INVALID_INVENTORY_PLANNING_RESPONSE")
        principal.authorize_store(result["store_id"])
        return result

    def list(self, principal, skip=0, limit=50):
        if (not isinstance(skip, int) or isinstance(skip, bool) or skip < 0 or
                not isinstance(limit, int) or isinstance(limit, bool) or limit < 1 or limit > 100):
            raise client_error(422, "INVALID_PAGINATION")
        result = self._send("GET", f"/inventory-marketing/campaign-analysis?skip={skip}&limit={limit}")
        if (not isinstance(result.get("items"), list) or type(result.get("total")) is not int
                or result.get("skip") != skip or result.get("limit") != limit):
            raise client_error(503, "INVALID_INVENTORY_PLANNING_RESPONSE")
        for item in result["items"]:
            if not isinstance(item, dict) or not isinstance(item.get("store_id"), str):
                raise client_error(503, "INVALID_INVENTORY_PLANNING_RESPONSE")
            principal.authorize_store(item["store_id"])
        return result
