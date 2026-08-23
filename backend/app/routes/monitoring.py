import datetime
from fastapi import APIRouter, HTTPException
from firebase_admin import firestore
from app.firebase_config import db
from app.models.monitoring import MonitoringStartRequest, MonitoringUpdateRequest, MonitoringStopRequest, ManualAssistRequest
from app.services.zone_service import is_point_in_zone
from app.services.trajectory_service import calculate_distance, classify_intent

router = APIRouter()


_zones_cache = None
_zones_last_updated = None

def _get_zones():
    global _zones_cache, _zones_last_updated
    now = datetime.datetime.now(datetime.timezone.utc)
    
    if _zones_cache is None or _zones_last_updated is None or (now - _zones_last_updated).total_seconds() > 300:
        docs = db.collection("zones").stream()
        _zones_cache = []
        for doc in docs:
            zone = doc.to_dict()
            zone["id"] = doc.id
            _zones_cache.append(zone)
        _zones_last_updated = now
        
    return _zones_cache

def _resolve_zone(latitude: float, longitude: float, altitude: float):
    zones = _get_zones()
    for zone in zones:
        if is_point_in_zone(latitude, longitude, altitude, zone):
            return zone["id"], zone.get("zone_name", "Unknown Zone")
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

def _get_updated_history(session_data, now_dt):
    history = session_data.get("zone_history", [])
    entry_time = session_data.get("entry_time")
    stored_zone_id = session_data.get("zone_id")
    stored_zone_name = session_data.get("zone_name")

    if not stored_zone_id or not entry_time:
        return history

    if entry_time.tzinfo is None:
        entry_time = entry_time.replace(tzinfo=datetime.timezone.utc)

    dwell_time = (now_dt - entry_time).total_seconds()

    history.append({
        "zone_id": stored_zone_id,
        "zone_name": stored_zone_name,
        "entry_time": entry_time,
        "exit_time": now_dt,
        "dwell_time_seconds": int(dwell_time)
    })
    return history


@router.post("/start")
def start_monitoring(data: MonitoringStartRequest):
    zone_id, zone_name = _resolve_zone(data.latitude, data.longitude, data.altitude)
    if not zone_id:
        zone_id, zone_name = "in_transit", "In Transit"

    # Complete any existing active sessions for this customer to ensure 1 active session per customer
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

    new_session = {
        "customer_id": data.customer_id,
        "customer_name": data.customer_name or data.customer_id,
        "zone_id": zone_id,
        "zone_name": zone_name,
        "entry_time": firestore.SERVER_TIMESTAMP,
        "last_updated": firestore.SERVER_TIMESTAMP,
        "status": "Active",
        "latitude": data.latitude,
        "longitude": data.longitude,
        "altitude": data.altitude,
        "intent": "Transiting" if zone_id == "in_transit" else "Browsing",
        "zone_history": []
    }

    doc_ref = db.collection("customer_monitoring").add(new_session)
    return {"message": "Monitoring started", "monitoring_id": doc_ref[1].id, "zone_name": zone_name}


@router.post("/update")
def update_monitoring(data: MonitoringUpdateRequest):
    active_sessions = list(
        db.collection("customer_monitoring")
        .where(filter=firestore.FieldFilter("customer_id", "==", data.customer_id))
        .where(filter=firestore.FieldFilter("status", "==", "Active"))
        .stream()
    )

    current_zone_id, current_zone_name = _resolve_zone(data.latitude, data.longitude, data.altitude)
    if not current_zone_id:
        current_zone_id, current_zone_name = "in_transit", "In Transit"

    if not active_sessions:
        # No session exists yet — auto-create one
        new_session = {
            "customer_id": data.customer_id,
            "customer_name": data.customer_id,
            "zone_id": current_zone_id,
            "zone_name": current_zone_name,
            "entry_time": firestore.SERVER_TIMESTAMP,
            "last_updated": firestore.SERVER_TIMESTAMP,
            "status": "Active",
            "latitude": data.latitude,
            "longitude": data.longitude,
            "altitude": data.altitude,
            "intent": "Transiting" if current_zone_id == "in_transit" else "Browsing",
            "zone_history": []
        }
        db.collection("customer_monitoring").add(new_session)
        return {"message": "Session auto-created", "zone_name": current_zone_name}

    # Deduplicate: use the first session, mark any extra duplicate active sessions as Completed
    session_doc = active_sessions[0]
    for dup in active_sessions[1:]:
        dup.reference.update({"status": "Completed"})

    session_data = session_doc.to_dict()
    stored_zone_id = session_data.get("zone_id")
    now = datetime.datetime.now(datetime.timezone.utc)

    if current_zone_id != stored_zone_id:
        # Customer moved to a new zone or into transit — append to history, reset timer
        updated_history = _get_updated_history(session_data, now)
        intent = "Transiting" if current_zone_id == "in_transit" else "Browsing"

        session_doc.reference.update({
            "zone_id": current_zone_id,
            "zone_name": current_zone_name,
            "entry_time": firestore.SERVER_TIMESTAMP,
            "last_updated": firestore.SERVER_TIMESTAMP,
            "latitude": data.latitude,
            "longitude": data.longitude,
            "altitude": data.altitude,
            "intent": intent,
            "zone_history": updated_history
        })
        
        # Resolve existing requests since they moved
        _resolve_pending_requests(data.customer_id)

        # PACING DETECTION (A -> B -> A)
        pacing_alert_triggered = False
        if len(updated_history) >= 2:
            prev_zone = updated_history[-1]      # Zone B
            prev_prev_zone = updated_history[-2] # Zone A

            if prev_prev_zone.get("zone_id") == current_zone_id:
                if prev_zone.get("dwell_time_seconds", 0) < 60:
                    pacing_alert_triggered = True
                    customer_name = session_data.get("customer_name", data.customer_id)
                    new_request = {
                        "customer_id": data.customer_id,
                        "customer_name": customer_name,
                        "zone_id": current_zone_id,
                        "zone_name": current_zone_name,
                        "request_time": firestore.SERVER_TIMESTAMP,
                        "last_notification_time": firestore.SERVER_TIMESTAMP,
                        "notification_count": 1,
                        "status": "Pending",
                        "is_pacing": True
                    }
                    db.collection("assistance_requests").add(new_request)
                    db.collection("staff_notifications").add({
                        "staff_id": "broadcast",
                        "customer_id": data.customer_id,
                        "zone_id": current_zone_id,
                        "zone_name": current_zone_name,
                        "sent_time": firestore.SERVER_TIMESTAMP,
                        "status": "Sent",
                        "is_pacing": True
                    })

        msg = "Zone changed (Pacing Alert Triggered)" if pacing_alert_triggered else "Zone changed"
        return {"message": msg, "new_zone": current_zone_name}
    else:
        # Same zone — update coordinates and check dwell time
        prev_lat = session_data.get("latitude")
        prev_lon = session_data.get("longitude")
        last_updated = session_data.get("last_updated")

        distance = 0.0
        intent = "Browsing"
        current_speed = 0.0

        if prev_lat and prev_lon and last_updated:
            distance = calculate_distance(prev_lat, prev_lon, data.latitude, data.longitude)
            
            if last_updated.tzinfo is None:
                last_updated = last_updated.replace(tzinfo=datetime.timezone.utc)
            
            elapsed_since_last = (now - last_updated).total_seconds()
            
            entry_time = session_data.get("entry_time")
            dwell_time = 0.0
            if entry_time:
                if entry_time.tzinfo is None:
                    entry_time = entry_time.replace(tzinfo=datetime.timezone.utc)
                dwell_time = (now - entry_time).total_seconds()

            intent = classify_intent(distance, elapsed_since_last, zone_dwell_time_seconds=dwell_time)
            if elapsed_since_last > 0:
                current_speed = distance / elapsed_since_last

        if current_zone_id == "in_transit" or current_speed > 0.4:
            intent = "Transiting"

        session_doc.reference.update({
            "last_updated": firestore.SERVER_TIMESTAMP,
            "latitude": data.latitude,
            "longitude": data.longitude,
            "altitude": data.altitude,
            "current_speed": current_speed,
            "intent": intent
        })

        entry_time = session_data.get("entry_time")
        if not entry_time:
            return {"message": "Heartbeat updated"}

        elapsed_seconds = (now - entry_time).total_seconds()

        if elapsed_seconds >= 30 and intent == "Browsing":
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
    now = datetime.datetime.now(datetime.timezone.utc)
    for session_doc in active_sessions:
        session_data = session_doc.to_dict()
        updated_history = _get_updated_history(session_data, now)
        session_doc.reference.update({
            "status": "Completed",
            "last_updated": firestore.SERVER_TIMESTAMP,
            "zone_history": updated_history
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
    
    now = datetime.datetime.now(datetime.timezone.utc)
    stale_limit = now - datetime.timedelta(seconds=60)
    
    raw_sessions = []
    for doc in active_sessions:
        data = doc.to_dict()
        
        last_updated = data.get("last_updated")
        if last_updated:
            if last_updated.tzinfo is None:
                last_updated = last_updated.replace(tzinfo=datetime.timezone.utc)
            if last_updated < stale_limit:
                updated_history = _get_updated_history(data, now)
                doc.reference.update({
                    "status": "Completed",
                    "last_updated": firestore.SERVER_TIMESTAMP,
                    "zone_history": updated_history
                })
                _resolve_pending_requests(data.get("customer_id"))
                continue
                
        data["_doc_id"] = doc.id
        data["_doc_ref"] = doc.reference
        data["_last_updated"] = last_updated if last_updated else now
        raw_sessions.append(data)

    # Deduplicate by customer_id: keep latest session, complete older duplicates
    customer_map = {}
    for s in raw_sessions:
        cid = s.get("customer_id")
        if not cid:
            continue
        if cid not in customer_map:
            customer_map[cid] = [s]
        else:
            customer_map[cid].append(s)

    result = []
    for cid, s_list in customer_map.items():
        s_list.sort(key=lambda x: x["_last_updated"], reverse=True)
        latest = s_list[0]
        
        for older in s_list[1:]:
            older["_doc_ref"].update({"status": "Completed"})

        clean_data = {k: v for k, v in latest.items() if not k.startswith("_")}
        clean_data["monitoring_id"] = latest["_doc_id"]
        if "entry_time" in clean_data and clean_data["entry_time"]:
            clean_data["entry_time"] = clean_data["entry_time"].isoformat()
        if "last_updated" in clean_data and clean_data["last_updated"]:
            clean_data["last_updated"] = clean_data["last_updated"].isoformat()
        result.append(clean_data)

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


@router.post("/manual-assist")
def manual_assist(data: ManualAssistRequest):
    active_sessions = list(
        db.collection("customer_monitoring")
        .where(filter=firestore.FieldFilter("customer_id", "==", data.customer_id))
        .where(filter=firestore.FieldFilter("status", "==", "Active"))
        .limit(1)
        .stream()
    )

    if not active_sessions:
        raise HTTPException(status_code=400, detail="No active session found for this customer. Cannot request assistance.")

    session_data = active_sessions[0].to_dict()
    current_zone_id = session_data.get("zone_id", "unknown")
    current_zone_name = session_data.get("zone_name", "Unknown Zone")
    customer_name = session_data.get("customer_name", "Customer")

    # Check if a pending request already exists to avoid duplicates
    pending_requests = list(
        db.collection("assistance_requests")
        .where(filter=firestore.FieldFilter("customer_id", "==", data.customer_id))
        .where(filter=firestore.FieldFilter("status", "==", "Pending"))
        .limit(1)
        .stream()
    )

    if pending_requests:
        return {"message": "Assistance request already pending."}

    new_request = {
        "customer_id": data.customer_id,
        "customer_name": customer_name,
        "zone_id": current_zone_id,
        "zone_name": current_zone_name,
        "request_time": firestore.SERVER_TIMESTAMP,
        "last_notification_time": firestore.SERVER_TIMESTAMP,
        "notification_count": 1,
        "status": "Pending",
        "is_manual": True
    }
    
    db.collection("assistance_requests").add(new_request)
    db.collection("staff_notifications").add({
        "staff_id": "broadcast",
        "customer_id": data.customer_id,
        "zone_id": current_zone_id,
        "zone_name": current_zone_name,
        "sent_time": firestore.SERVER_TIMESTAMP,
        "status": "Sent",
        "is_manual": True
    })
    
    return {"message": "Manual assistance request triggered"}
