from fastapi import APIRouter, HTTPException
from firebase_admin import firestore
from app.firebase_config import db
from app.models.zone import ZoneCreateRequest, ZoneIdentifyRequest
from app.services.zone_service import get_zone_boundaries, is_point_in_zone

router = APIRouter()


@router.post("/create")
def create_zone(data: ZoneCreateRequest):
    existing = db.collection("zones").where("zone_name", "==", data.zone_name).stream()

    for _ in existing:
        raise HTTPException(status_code=400, detail="Zone name already exists")

    boundaries = get_zone_boundaries(data.points)

    zone = {
        "zone_name": data.zone_name,
        "points": [point.model_dump() for point in data.points],
        **boundaries,
        "created_at": firestore.SERVER_TIMESTAMP
    }

    doc_ref = db.collection("zones").add(zone)

    return {
        "message": "Zone created successfully",
        "zone_id": doc_ref[1].id,
        "zone": {
            "zone_name": zone["zone_name"],
            "points": zone["points"],
            "min_lat": zone["min_lat"],
            "max_lat": zone["max_lat"],
            "min_lon": zone["min_lon"],
            "max_lon": zone["max_lon"],
            "min_alt": zone["min_alt"],
            "max_alt": zone["max_alt"]
        }
    }


@router.post("/identify")
def identify_zone(data: ZoneIdentifyRequest):
    zones = db.collection("zones").stream()
    matched_zones = []

    for doc in zones:
        zone = doc.to_dict()

        if is_point_in_zone(data.latitude, data.longitude, data.altitude, zone):
            matched_zones.append({
                "zone_id": doc.id,
                "zone_name": zone["zone_name"],
                "zone": zone
            })

    db.collection("zone_identifications").add({
        "latitude": data.latitude,
        "longitude": data.longitude,
        "altitude": data.altitude,
        "matched_zones": [
            {
                "zone_id": item["zone_id"],
                "zone_name": item["zone_name"]
            }
            for item in matched_zones
        ],
        "created_at": firestore.SERVER_TIMESTAMP
    })

    if matched_zones:
        return {
            "message": "Zone identified successfully",
            "zones": matched_zones
        }

    return {
        "message": "No matching zone found"
    }


@router.get("/all")
def get_all_zones():
    docs = db.collection("zones").stream()

    zones = []
    for doc in docs:
        zone = doc.to_dict()
        zone["zone_id"] = doc.id
        zones.append(zone)

    return {"zones": zones}


@router.get("/{zone_id}")
def get_zone_by_id(zone_id: str):
    doc = db.collection("zones").document(zone_id).get()

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Zone not found")

    zone = doc.to_dict()
    zone["zone_id"] = doc.id
    return zone


@router.put("/{zone_id}")
def update_zone(zone_id: str, data: ZoneCreateRequest):
    doc_ref = db.collection("zones").document(zone_id)
    existing_doc = doc_ref.get()

    if not existing_doc.exists:
        raise HTTPException(status_code=404, detail="Zone not found")

    duplicate_docs = db.collection("zones").where("zone_name", "==", data.zone_name).stream()

    for doc in duplicate_docs:
        if doc.id != zone_id:
            raise HTTPException(status_code=400, detail="Zone name already exists")

    boundaries = get_zone_boundaries(data.points)

    updated_data = {
        "zone_name": data.zone_name,
        "points": [point.model_dump() for point in data.points],
        **boundaries,
        "updated_at": firestore.SERVER_TIMESTAMP
    }

    doc_ref.update(updated_data)

    return {
        "message": "Zone updated successfully",
        "zone_id": zone_id
    }


@router.delete("/{zone_id}")
def delete_zone(zone_id: str):
    doc_ref = db.collection("zones").document(zone_id)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Zone not found")

    doc_ref.delete()

    # Mark active monitoring sessions in the deleted zone as Completed
    active_sessions = (
        db.collection("customer_monitoring")
        .where(filter=firestore.FieldFilter("zone_id", "==", zone_id))
        .where(filter=firestore.FieldFilter("status", "==", "Active"))
        .stream()
    )
    for session in active_sessions:
        session.reference.update({
            "status": "Completed",
            "last_updated": firestore.SERVER_TIMESTAMP
        })

    # Resolve pending assistance requests in the deleted zone
    pending_requests = (
        db.collection("assistance_requests")
        .where(filter=firestore.FieldFilter("zone_id", "==", zone_id))
        .where(filter=firestore.FieldFilter("status", "==", "Pending"))
        .stream()
    )
    for req in pending_requests:
        req.reference.update({
            "status": "Resolved",
            "resolved_at": firestore.SERVER_TIMESTAMP
        })

    return {
        "message": "Zone deleted successfully",
        "zone_id": zone_id
    }