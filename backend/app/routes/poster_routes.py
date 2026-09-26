from fastapi import APIRouter, HTTPException
from app.schemas.poster import PosterRequest, EmailPosterRequest, SchedulePosterRequest
from app.services import poster_service, email_service, firebase_service
import base64

router = APIRouter(prefix="/poster", tags=["Poster Generation"])


@router.get("/health")
def poster_health():
    ok, message = poster_service.check_gemini_health()
    return {"connected": ok, "message": message}


@router.post("/generate")
def generate_poster(req: PosterRequest):
    prompt = poster_service.build_prompt_payload(
        gender=req.gender,
        age_group=req.age_group,
        offer_type=req.offer_type,
        discount_value=req.discount_value,
        season=req.season,
        items=req.items,
        palette=req.palette,
        style=req.style,
        brand_name=req.brand_name,
        tagline=req.tagline,
        inspiration=req.inspiration,
        event_date=req.event_date,
        event_time=req.event_time,
        event_location=req.event_location,
        valid_until=req.valid_until,
        hosting_branch=req.hosting_branch,
        include_terms=req.include_terms,
    )
    event_lines = poster_service.build_event_detail_lines(
        event_date=req.event_date,
        event_time=req.event_time,
        event_location=req.event_location,
        valid_until=req.valid_until,
        hosting_branch=req.hosting_branch,
    )
    print(f"DEBUG: event_lines = {event_lines}, include_terms = {req.include_terms}")

    image_b64, error = poster_service.generate_poster_image(
        prompt,
        event_details=event_lines,
        include_terms=req.include_terms,
    )
    if error:
        raise HTTPException(status_code=502, detail=error)

    # Save the configuration (not the image) to the generation history log
    poster_service.save_generation_to_history(req.model_dump())

    return {"image_b64": image_b64}


@router.get("/history")
def poster_history(limit: int = 50):
    """Returns the most recent poster generations (config only, no images)."""
    return {"history": poster_service.get_generation_history(limit=limit)}


@router.post("/send-email")
def send_poster_email(req: EmailPosterRequest):
    try:
        image_bytes = base64.b64decode(req.image_b64)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image data.")

    result = email_service.send_poster_email(
        recipient_emails=req.recipient_emails,
        subject=req.subject,
        message_body=req.message,
        image_bytes=image_bytes,
        image_filename="skyhigh_poster.png",
    )

    if not result["success"]:
        raise HTTPException(status_code=502, detail=result["error"])

    return {"message": result["message"]}


@router.post("/schedule")
def schedule_poster(req: SchedulePosterRequest):
    """
    Saves a poster (already generated) to be sent later, and adds a
    calendar reminder note for the scheduled date. Sending itself is
    manual — trigger it from the Scheduled Posts list via /poster/send-scheduled.
    """
    post_id = poster_service.save_scheduled_post(
        poster_config=req.poster_config.model_dump(),
        image_b64=req.image_b64,
        recipient_emails=req.recipient_emails,
        subject=req.subject,
        message=req.message,
        scheduled_date=req.scheduled_date,
    )
    if post_id is None:
        raise HTTPException(status_code=500, detail="Could not save scheduled post.")

    # Add a calendar reminder for the scheduled date, so it shows up in
    # the Calendar tab and (if tomorrow) the Hub's "Tomorrow" card.
    recipients_preview = ", ".join(req.recipient_emails[:2])
    if len(req.recipient_emails) > 2:
        recipients_preview += f" +{len(req.recipient_emails) - 2} more"
    note_text = f"Send scheduled poster ({req.poster_config.offer_type}) to {recipients_preview}"
    firebase_service.add_calendar_note(date=req.scheduled_date, text=note_text, category="Campaign Idea")

    return {"id": post_id, "message": "Poster scheduled and calendar reminder added."}


@router.get("/scheduled")
def list_scheduled_posts(status: str = None):
    """Returns scheduled posts, optionally filtered by status ('pending' or 'sent')."""
    return {"scheduled": poster_service.get_scheduled_posts(status=status)}


@router.post("/send-scheduled/{post_id}")
def send_scheduled_poster(post_id: str):
    """Manually sends a previously-scheduled poster, then marks it as sent."""
    post = poster_service.get_scheduled_post_by_id(post_id)
    if post is None:
        raise HTTPException(status_code=404, detail="Scheduled post not found.")
    if post.get("status") == "sent":
        raise HTTPException(status_code=400, detail="This post has already been sent.")

    try:
        image_bytes = base64.b64decode(post["image_b64"])
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image data on this scheduled post.")

    result = email_service.send_poster_email(
        recipient_emails=post["recipient_emails"],
        subject=post.get("subject", "Your SkyHigh Promotion Poster"),
        message_body=post.get("message", "Please find the attached promotional poster."),
        image_bytes=image_bytes,
        image_filename="skyhigh_poster.png",
    )

    if not result["success"]:
        raise HTTPException(status_code=502, detail=result["error"])

    poster_service.mark_scheduled_post_sent(post_id)
    return {"message": result["message"]}