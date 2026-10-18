"""Unregistered Inventory self-service write routes. Existing GET /me is untouched."""
from fastapi import APIRouter, Depends, HTTPException
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute
from app.schemas.inventory_profile_schema import (
    UpdateInventoryProfile, ChangeInventoryPassword, InventoryProfileUpdated, InventoryPasswordChanged,
)
from app.security.inventory_permissions import get_current_inventory_user, get_bearer_credentials
from app.services.inventory_user_management_dependencies import get_profile_service


class InventoryProfileRoute(APIRoute):
    def get_route_handler(self):
        handler = super().get_route_handler()
        async def safe(request):
            headers = {"Cache-Control": "no-store"}
            try:
                response = await handler(request)
                response.headers.update(headers)
                return response
            except RequestValidationError:
                return JSONResponse(status_code=422, content={"detail": "Invalid profile request. Check the supplied fields and password confirmation."}, headers=headers)
            except HTTPException as error:
                messages = {
                    400: "Current password could not be verified.",
                    401: "Invalid authentication credentials.",
                    403: "Inventory access denied.",
                    409: "Your account changed. Reload before trying again.",
                    422: "Invalid profile request. Check the fields and choose a different new password.",
                    429: "Too many authentication attempts. Try again later.",
                    503: "Profile service unavailable. A submitted change may have an unknown outcome; sign in again before any further action.",
                }
                status = error.status_code if error.status_code in messages else 503
                if status == 401: headers["WWW-Authenticate"] = "Bearer"
                if status == 429: headers["Retry-After"] = "60"
                return JSONResponse(status_code=status, content={"detail": messages[status]}, headers=headers)
            except Exception:
                return JSONResponse(status_code=503, content={"detail": "Inventory profile service is unavailable."}, headers=headers)
        return safe


router = APIRouter(prefix="/inventory-auth", tags=["Inventory My Profile"],
                   dependencies=[Depends(get_current_inventory_user)], route_class=InventoryProfileRoute)


@router.patch("/me", response_model=InventoryProfileUpdated)
def update_my_profile(data: UpdateInventoryProfile, service=Depends(get_profile_service),
                      credentials=Depends(get_bearer_credentials)):
    return service.update_display_name(credentials.credentials, data)


@router.post("/change-password", response_model=InventoryPasswordChanged)
def change_my_password(data: ChangeInventoryPassword, service=Depends(get_profile_service),
                       credentials=Depends(get_bearer_credentials)):
    return service.change_password(credentials.credentials, data)
