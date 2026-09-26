from pydantic import BaseModel


class CalendarNote(BaseModel):
    date: str  # YYYY-MM-DD
    text: str
    category: str = "General"  # One of: Reminder, Campaign Idea, Urgent, General