from fastapi import APIRouter
from app.models.location import LocationRequest

router = APIRouter()

@router.post("/send-location")
def receive_location(data: LocationRequest):
    return {
        "message": "Location received successfully",
        "latitude": data.latitude,
        "longitude": data.longitude,
        "altitude": data.altitude
    }