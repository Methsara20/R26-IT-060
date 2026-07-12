import datetime
from fastapi import APIRouter, HTTPException
from firebase_admin import firestore
from app.firebase_config import db
from app.models.monitoring import MonitoringStartRequest, MonitoringUpdateRequest, MonitoringStopRequest
from app.services.zone_service import is_point_in_zone

router = APIRouter()


def _resolve_zone(latitude: float, longitude: float, altitude: float):
    zones = db.collection("zones").stream()
    for doc in zones:
        zone = doc.to_dict()
        if is_point_in_zone(latitude, longitude, altitude, zone):
            return doc.id, zone.get("zone_name", "Unknown Zone")
    return None, None


def _resolve_pending_requests(customer_id: str):
    pending_requests = (
        db.collection("assistance_requests")
        .where(filter=firestore.FieldFilter("customer_id", "==", customer_id))
        .where(filter=firestore.FieldFilter("status", "==", "Pending"))
        .stream()
    )
    for req_doc in pending_requests:
        req_doc.reference.update({
            "status": "Resolved",
            "resolved_at": firestore.SERVER_TIMESTAMP
        })


@router.post("/start")
def start_monitoring(data: MonitoringStartRequest):
    zone_id, zone_name = _resolve_zone(data.latitude, data.longitude, data.altitude)

    # Complete any existing active sessions for this customer
    active_sessions = (
        db.collection("customer_monitoring")
        .where(filter=firestore.FieldFilter("customer_id", "==", data.customer_id))
        .where(filter=firestore.FieldFilter("status", "==", "Active"))
        .stream()
    )
    for session_doc in active_sessions:
        session_doc.reference.update({"status": "Completed"})

    # Resolve any stale assistance requests
    _resolve_pending_requests(data.customer_id)

    if not zone_id:
        return {"message": "Customer is not in any predefined zone", "monitoring_id": None}

    new_session = {
        "customer_id": data.customer_id,
        "customer_name": data.customer_name,
        "zone_id": zone_id,
        "zone_name": zone_name,
        "entry_time": firestore.SERVER_TIMESTAMP,
        "last_updated": firestore.SERVER_TIMESTAMP,
        "status": "Active",
        "latitude": data.latitude,
        "longitude": data.longitude,
        "altitude": data.altitude
    }

    doc_ref = db.collection("customer_monitoring").add(new_session)
    return {"message": "Monitoring started", "monitoring_id": doc_ref[1].id, "zone_name": zone_name}


@router.post("/update")
def update_monitoring(data: MonitoringUpdateRequest):
    active_sessions = list(
        db.collection("customer_monitoring")
        .where(filter=firestore.FieldFilter("customer_id", "==", data.customer_id))
        .where(filter=firestore.FieldFilter("status", "==", "Active"))
        .limit(1)
        .stream()
    )

    if not active_sessions:
        # No session exists yet — auto-create one if in a zone
        zone_id, zone_name = _resolve_zone(data.latitude, data.longitude, data.altitude)
        if zone_id:
            new_session = {
                "customer_id": data.customer_id,
                "customer_name": data.customer_id,
                "zone_id": zone_id,
                "zone_name": zone_name,
                "entry_time": firestore.SERVER_TIMESTAMP,
                "last_updated": firestore.SERVER_TIMESTAMP,
                "status": "Active",
                "latitude": data.latitude,
                "longitude": data.longitude,
                "altitude": data.altitude
            }
            db.collection("customer_monitoring").add(new_session)
            return {"message": "Session auto-created", "zone_name": zone_name}
        return {"message": "No active monitoring session found."}

    session_doc = active_sessions[0]
    session_data = session_doc.to_dict()

    current_zone_id, current_zone_name = _resolve_zone(data.latitude, data.longitude, data.altitude)

    if not current_zone_id:
        session_doc.reference.update({
            "last_updated": firestore.SERVER_TIMESTAMP,
            "latitude": data.latitude,
            "longitude": data.longitude,
            "altitude": data.altitude
        })
        return {"message": "Customer not in any zone, tracking paused."}

    stored_zone_id = session_data.get("zone_id")
    now = datetime.datetime.now(datetime.timezone.utc)

    if current_zone_id != stored_zone_id:
        # Customer moved to a new zone — reset timer
        session_doc.reference.update({
            "zone_id": current_zone_id,
            "zone_name": current_zone_name,
            "entry_time": firestore.SERVER_TIMESTAMP,
            "last_updated": firestore.SERVER_TIMESTAMP,
            "latitude": data.latitude,
            "longitude": data.longitude,
            "altitude": data.altitude
        })
        _resolve_pending_requests(data.customer_id)
        return {"message": "Zone changed", "new_zone": current_zone_name}
    else:
        # Same zone — update coordinates and check dwell time
        session_doc.reference.update({
            "last_updated": firestore.SERVER_TIMESTAMP,
            "latitude": data.latitude,
            "longitude": data.longitude,
            "altitude": data.altitude
        })

        entry_time = session_data.get("entry_time")
        if not entry_time:
            return {"message": "Heartbeat updated"}

        elapsed_seconds = (now - entry_time).total_seconds()

        if elapsed_seconds >= 30:
            pending_requests = list(
                db.collection("assistance_requests")
                .where(filter=firestore.FieldFilter("customer_id", "==", data.customer_id))
                .where(filter=firestore.FieldFilter("status", "==", "Pending"))
                .limit(1)
                .stream()
            )

            if not pending_requests:
                new_request = {
                    "customer_id": data.customer_id,
                    "customer_name": session_data.get("customer_name"),
                    "zone_id": current_zone_id,
                    "zone_name": current_zone_name,
                    "request_time": firestore.SERVER_TIMESTAMP,
                    "last_notification_time": firestore.SERVER_TIMESTAMP,
                    "notification_count": 1,
                    "status": "Pending"
                }
                db.collection("assistance_requests").add(new_request)
                db.collection("staff_notifications").add({
                    "staff_id": "broadcast",
                    "customer_id": data.customer_id,
                    "zone_id": current_zone_id,
                    "zone_name": current_zone_name,
                    "sent_time": firestore.SERVER_TIMESTAMP,
                    "status": "Sent"
                })
                return {"message": "Assistance request triggered"}
            else:
                req_doc = pending_requests[0]
                req_data = req_doc.to_dict()
                last_notify = req_data.get("last_notification_time", now)
                notify_elapsed = (now - last_notify).total_seconds()

                if notify_elapsed >= 30:
                    new_count = req_data.get("notification_count", 0) + 1
                    req_doc.reference.update({
                        "notification_count": new_count,
                        "last_notification_time": firestore.SERVER_TIMESTAMP
                    })
                    db.collection("staff_notifications").add({
                        "staff_id": "broadcast",
                        "customer_id": data.customer_id,
                        "zone_id": current_zone_id,
                        "zone_name": current_zone_name,
                        "sent_time": firestore.SERVER_TIMESTAMP,
                        "status": "Sent",
                        "is_reminder": True
                    })
                    return {"message": "Assistance reminder triggered", "count": new_count}

        return {"message": "Heartbeat updated", "zone": current_zone_name, "elapsed_seconds": int(elapsed_seconds)}


@router.post("/stop")
def stop_monitoring(data: MonitoringStopRequest):
    active_sessions = (
        db.collection("customer_monitoring")
        .where(filter=firestore.FieldFilter("customer_id", "==", data.customer_id))
        .where(filter=firestore.FieldFilter("status", "==", "Active"))
        .stream()
    )
    for session_doc in active_sessions:
        session_doc.reference.update({
            "status": "Completed",
            "last_updated": firestore.SERVER_TIMESTAMP
        })

    _resolve_pending_requests(data.customer_id)
    return {"message": "Monitoring stopped"}


@router.get("/active")
def get_active_sessions():
    active_sessions = (
        db.collection("customer_monitoring")
        .where(filter=firestore.FieldFilter("status", "==", "Active"))
        .stream()
    )
    result = []
    for doc in active_sessions:
        data = doc.to_dict()
        data["monitoring_id"] = doc.id
        if "entry_time" in data and data["entry_time"]:
            data["entry_time"] = data["entry_time"].isoformat()
        if "last_updated" in data and data["last_updated"]:
            data["last_updated"] = data["last_updated"].isoformat()
        result.append(data)
    return result


@router.get("/requests")
def get_active_requests():
    requests = (
        db.collection("assistance_requests")
        .where(filter=firestore.FieldFilter("status", "==", "Pending"))
        .stream()
    )
    result = []
    for doc in requests:
        data = doc.to_dict()
        data["request_id"] = doc.id
        if "request_time" in data and data["request_time"]:
            data["request_time"] = data["request_time"].isoformat()
        if "last_notification_time" in data and data["last_notification_time"]:
            data["last_notification_time"] = data["last_notification_time"].isoformat()
        result.append(data)
    return result


@router.post("/resolve/{request_id}")
def resolve_request(request_id: str):
    doc_ref = db.collection("assistance_requests").document(request_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Request not found")

    doc_ref.update({
        "status": "Resolved",
        "resolved_at": firestore.SERVER_TIMESTAMP
    })
    return {"message": "Request marked as Resolved"}
