from fastapi import APIRouter, HTTPException
from app.schemas.calendar import CalendarNote
from app.services import firebase_service

router = APIRouter(prefix="/calendar", tags=["Calendar"])


@router.get("/campaigns")
def calendar_campaigns(year: int, month: int):
    """Returns {day: count} of campaigns sent in the given month."""
    return firebase_service.get_campaign_counts_by_day(year, month)


@router.get("/campaigns/year")
def calendar_campaigns_year(year: int):
    """Returns {month: {day: count}} for the whole year, in one call."""
    return firebase_service.get_campaign_counts_by_year(year)


@router.get("/notes")
def calendar_notes(year: int, month: int):
    return firebase_service.get_calendar_notes(year, month)


@router.get("/notes/year")
def calendar_notes_year(year: int):
    """Returns all notes for the given year, no month filter."""
    return firebase_service.get_calendar_notes_year(year)


@router.post("/notes")
def add_calendar_note(note: CalendarNote):
    note_id = firebase_service.add_calendar_note(note.date, note.text, note.category)
    if note_id is None:
        raise HTTPException(status_code=500, detail="Could not save note")
    return {"id": note_id, "date": note.date, "text": note.text, "category": note.category}


@router.delete("/notes/{note_id}")
def delete_calendar_note(note_id: str):
    success = firebase_service.delete_calendar_note(note_id)
    if not success:
        raise HTTPException(status_code=500, detail="Could not delete note")
    return {"deleted": True}