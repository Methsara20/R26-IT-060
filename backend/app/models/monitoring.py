from pydantic import BaseModel
from typing import Optional

class MonitoringStartRequest(BaseModel):
    customer_id: str
    customer_name: str
    latitude: float
    longitude: float
    altitude: float

class MonitoringUpdateRequest(BaseModel):
    customer_id: str
    latitude: float
    longitude: float
    altitude: float

class MonitoringStopRequest(BaseModel):
    customer_id: str
