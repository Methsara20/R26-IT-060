from pydantic import BaseModel, field_validator
from typing import List


class Point(BaseModel):
    latitude: float
    longitude: float
    altitude: float


class ZoneCreateRequest(BaseModel):
    zone_name: str
    points: List[Point]

    @field_validator("points")
    @classmethod
    def validate_points(cls, value):
        if len(value) != 4:
            raise ValueError("A zone must contain exactly 4 points")
        return value


class ZoneIdentifyRequest(BaseModel):
    latitude: float
    longitude: float
    altitude: float