from pydantic import BaseModel


class PosterRequest(BaseModel):
    gender: str
    age_group: str
    offer_type: str
    discount_value: str
    season: str
    items: list[str]
    palette: str
    style: str
    brand_name: str = "SkyHigh"
    tagline: str = ""  # Free text — campaign dates, wording, or both, shown on the poster itself
    inspiration: str = ""  # Optional free text — a theme/character/vibe to inspire the visual (e.g. "Spiderman")
    # Event details — for in-store events/pop-ups, all optional
    event_date: str = ""
    event_time: str = ""
    event_location: str = ""
    valid_until: str = ""
    hosting_branch: str = ""
    include_terms: bool = False


class EmailPosterRequest(BaseModel):
    recipient_emails: list[str]
    subject: str = "Your SkyHigh Promotion Poster"
    message: str = "Please find the attached promotional poster."
    image_b64: str


class SchedulePosterRequest(BaseModel):
    poster_config: PosterRequest
    image_b64: str
    recipient_emails: list[str]
    subject: str = "Your SkyHigh Promotion Poster"
    message: str = "Please find the attached promotional poster."
    scheduled_date: str  # "YYYY-MM-DD"