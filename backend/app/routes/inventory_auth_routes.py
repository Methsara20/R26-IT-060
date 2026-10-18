"""Isolated router, with auth-only response sanitization; not registered in main."""
from fastapi import APIRouter, Depends, HTTPException
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute

from app.schemas.inventory_auth_schema import InventoryLoginRequest, InventoryLoginResponse, InventoryPrincipal
from app.security.inventory_permissions import get_current_inventory_user
from app.services.inventory_auth_service import ACCESS_TOKEN_SECONDS, InventoryAuthService, get_inventory_auth_service
from app.services.inventory_user_service import InventoryUserRepository, get_inventory_user_repository


class InventoryAuthRoute(APIRoute):
    """Contain auth errors, including dependency/serialization failures.

    Never return validation input, custom exception details, headers, or traces.
    Other routers keep their existing validation/exception behavior.
    """
    def get_route_handler(self):
        original = super().get_route_handler()

        async def safe_handler(request):
            try:
                response = await original(request)
                response.headers["Cache-Control"] = "no-store"
                return response
            except RequestValidationError:
                return JSONResponse(
                    status_code=422,
                    content={"detail": "Invalid authentication request. Check username and password fields."},
                    headers={"Cache-Control": "no-store"},
                )
            except HTTPException as exc:
                messages = {
                    401: "Invalid authentication credentials.",
                    403: "Inventory access denied.",
                    429: "Too many authentication attempts. Try again later.",
                }
                status = exc.status_code if exc.status_code in messages else 503
                headers = {"Cache-Control": "no-store"}
                if status == 401:
                    headers["WWW-Authenticate"] = "Bearer"
                if status == 429:
                    headers["Retry-After"] = "60"
                return JSONResponse(
                    status_code=status,
                    content={"detail": messages.get(status, "Inventory authentication is unavailable.")},
                    headers=headers,
                )
            except Exception:
                return JSONResponse(
                    status_code=503,
                    content={"detail": "Inventory authentication is unavailable."},
                    headers={"Cache-Control": "no-store"},
                )
        return safe_handler


router = APIRouter(
    prefix="/inventory-auth", tags=["Inventory Authentication"],
    route_class=InventoryAuthRoute,
)


@router.post("/login", response_model=InventoryLoginResponse)
def login(
    data: InventoryLoginRequest,
    service: InventoryAuthService = Depends(get_inventory_auth_service),
    repository: InventoryUserRepository = Depends(get_inventory_user_repository),
):
    # authenticate returns a detached, verified account snapshot with private
    # version metadata. Never re-read a newer version between verification and
    # signing: a concurrent reset must make this token stale, not upgrade it.
    user = service.authenticate(repository, data.username, data.password)
    return InventoryLoginResponse(
        access_token=service.create_token(user), expires_in=ACCESS_TOKEN_SECONDS, user=user,
    )


@router.get("/me", response_model=InventoryPrincipal)
def me(user: InventoryPrincipal = Depends(get_current_inventory_user)):
    return user
