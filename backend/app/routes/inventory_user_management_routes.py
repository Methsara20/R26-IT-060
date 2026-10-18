"""Isolated management router; deliberately not registered in the shared app."""
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute
from app.schemas.inventory_user_management_schema import (
    CreateInventoryUser, UpdateInventoryUser, SetInventoryUserStatus,
    ResetInventoryUserPassword, InventoryUserView, InventoryUserPage, InventoryUserQuery,
)
from app.security.inventory_permissions import inventory_user_management_admin, get_bearer_credentials
from app.services.inventory_user_management_dependencies import get_management_service


class ManagementRoute(APIRoute):
    def get_route_handler(self):
        handler = super().get_route_handler()
        async def safe(request):
            headers = {"Cache-Control": "no-store"}
            try:
                response = await handler(request)
                response.headers.update(headers)
                return response
            except RequestValidationError:
                return JSONResponse(status_code=422, content={"detail": "Invalid Inventory user request. Check the supplied fields."}, headers=headers)
            except HTTPException as error:
                messages = {
                    401: "Invalid authentication credentials.", 403: "Inventory access denied.",
                    404: "Inventory account not found.",
                    409: "Account conflict or protected Admin operation. Reload before making another change.",
                    422: "Invalid Inventory user request. Check the supplied fields.",
                    429: "Too many password operations. Try again later.",
                    503: "Inventory user management is unavailable. A submitted change may have an unknown outcome; reload before any further action.",
                }
                status = error.status_code if error.status_code in messages else 503
                if status == 401:
                    headers["WWW-Authenticate"] = "Bearer"
                if status == 429:
                    headers["Retry-After"] = "60"
                return JSONResponse(status_code=status, content={"detail": messages[status]}, headers=headers)
            except Exception:
                return JSONResponse(status_code=503, content={"detail": "Inventory user management is unavailable."}, headers=headers)
        return safe


router = APIRouter(prefix="/inventory-users", tags=["Inventory User Management"],
                   route_class=ManagementRoute, dependencies=[Depends(inventory_user_management_admin)])


@router.get("", response_model=InventoryUserPage)
def list_users(query: InventoryUserQuery = Depends(), service=Depends(get_management_service),
               credentials=Depends(get_bearer_credentials)):
    return service.list(credentials.credentials, query)


@router.get("/{user_id}", response_model=InventoryUserView)
def get_user(user_id: str, service=Depends(get_management_service), credentials=Depends(get_bearer_credentials)):
    return service.get(credentials.credentials, user_id)


@router.post("", response_model=InventoryUserView, status_code=201)
def create_user(data: CreateInventoryUser, service=Depends(get_management_service), credentials=Depends(get_bearer_credentials)):
    return service.mutate(credentials.credentials, "create", data)


@router.patch("/{user_id}", response_model=InventoryUserView)
def update_user(user_id: str, data: UpdateInventoryUser, service=Depends(get_management_service), credentials=Depends(get_bearer_credentials)):
    return service.mutate(credentials.credentials, "update", data, user_id)


@router.patch("/{user_id}/status", response_model=InventoryUserView)
def set_status(user_id: str, data: SetInventoryUserStatus, service=Depends(get_management_service), credentials=Depends(get_bearer_credentials)):
    return service.mutate(credentials.credentials, "status", data, user_id)


@router.post("/{user_id}/reset-password", response_model=InventoryUserView)
def reset_password(user_id: str, data: ResetInventoryUserPassword, service=Depends(get_management_service), credentials=Depends(get_bearer_credentials)):
    return service.mutate(credentials.credentials, "reset_password", data, user_id)
