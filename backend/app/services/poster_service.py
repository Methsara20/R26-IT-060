import os
import base64
from io import BytesIO
from google import genai
from google.genai import types
from dotenv import load_dotenv
from PIL import Image

load_dotenv()

GEMINI_API_KEY2 = os.getenv("GEMINI_API_KEY2")
LOGO_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "skyhigh_logo.png")

def _get_db():
    import os
    from app.mongo_client import MongoFirestoreClient
    return MongoFirestoreClient(os.getenv("MONGODB_URI"))


_client = None


def _get_client():
    global _client
    if _client is None:
        if not GEMINI_API_KEY2:
            raise ValueError("GEMINI_API_KEY2 not set in .env")
        _client = genai.Client(api_key=GEMINI_API_KEY2)
    return _client


def build_event_detail_lines(
    event_date: str = "",
    event_time: str = "",
    event_location: str = "",
    valid_until: str = "",
    hosting_branch: str = "",
) -> list[str]:
    """Build the event-detail lines that are overlaid after image generation."""
    lines = []
    if event_date.strip():
        lines.append(f"Date: {event_date.strip()}")
    if event_time.strip():
        lines.append(f"Time: {event_time.strip()}")
    if event_location.strip():
        lines.append(f"Location: {event_location.strip()}")
    if valid_until.strip():
        lines.append(f"Valid until: {valid_until.strip()}")
    if hosting_branch.strip():
        lines.append(f"Venue: {hosting_branch.strip()}")
    return lines


def build_prompt_payload(
    gender: str,
    age_group: str,
    offer_type: str,
    discount_value: str,
    season: str,
    items: list[str],
    palette: str,
    style: str,
    brand_name: str = "SkyHigh",
    tagline: str = "",
    inspiration: str = "",
    event_date: str = "",
    event_time: str = "",
    event_location: str = "",
    valid_until: str = "",
    hosting_branch: str = "",
    include_terms: bool = False,
) -> str:
    """
    Builds a single text prompt describing the poster to generate.
    Kept as a plain string (not a dict payload) since Gemini takes a text prompt directly.
    """
    items_str = ", ".join(items)
    prompt = (
        f"Create a {style.lower()} promotional retail poster for a fashion brand called '{brand_name}'. "
        f"The poster artwork should fill the entire image edge-to-edge, with no wall, frame, border, "
        f"binder clips, or background scene around it -- just the flat poster design itself, full-bleed. "
    )

    if offer_type.strip().lower() != "not applicable":
        prompt += f"The poster advertises a '{offer_type}' campaign for the '{season}' collection, "
    else:
        prompt += f"The poster showcases the '{season}' collection (general promotion, no specific offer type), "

    prompt += f"featuring: {items_str}. "

    if discount_value.strip().lower() != "not applicable":
        prompt += f"Prominently display the discount/offer text: '{discount_value}'. "

    prompt += (
        f"Target audience: {gender.lower()}, age group {age_group}. "
        f"Use a color palette of {palette.lower()}. "
        f"The poster should look professional, eye-catching, and suitable for social media and in-store display. "
        f"Include the brand name '{brand_name}' clearly on the poster. "
        f"Leave the bottom 12% of the image as a clean, uncluttered plain-color footer band with no text "
        f"or graphics in it, reserved for a logo to be added separately."
    )

    if inspiration.strip():
        prompt += (
            f" Draw visual inspiration from '{inspiration.strip()}' as a theme -- incorporate its style, "
            f"color mood, or iconic visual motifs into the poster design, while keeping the brand name, "
            f"offer details, and footer band exactly as specified above."
        )
    if tagline.strip():
        prompt += f" Also include this promotional tagline prominently on the poster: '{tagline.strip()}'."

    # ── Event details (for in-store events/pop-ups) ──────────
    event_lines = build_event_detail_lines(event_date, event_time, event_location, valid_until, hosting_branch)

    if event_lines:
        prompt += (
            f" Leave a clean, uncluttered horizontal strip near the bottom of the poster "
            f"(just above the footer band), with no text or graphics in it -- this space "
            f"is reserved for event details to be added separately."
        )

    if include_terms:
        prompt += " Leave a small clear area near the bottom for a short disclaimer text to be added separately."
    return prompt


def check_gemini_health() -> tuple[bool, str]:
    """
    Quick check that the Gemini API key is configured and reachable.
    """
    if not GEMINI_API_KEY2:
        return False, "GEMINI_API_KEY2 not set on the server."
    try:
        _get_client()
        return True, "Gemini API key is configured."
    except Exception as e:
        return False, f"Gemini connection failed: {str(e)}"


def _add_event_details_overlay(image_bytes: bytes, lines: list[str]) -> bytes:
    """Draw event details onto a dedicated band above the logo footer."""
    if not lines:
        return image_bytes

    try:
        from PIL import ImageDraw, ImageFont

        poster = Image.open(BytesIO(image_bytes)).convert("RGBA")
        width, height = poster.width, poster.height
        band_height = int(height * 0.10)
        band_top = height - int(height * 0.12) - band_height

        overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        draw = ImageDraw.Draw(overlay)
        draw.rectangle([(0, band_top), (width, band_top + band_height)], fill=(13, 23, 38, 235))

        font_size = max(14, int(height * 0.022))

        def load_font(size: int):
            try:
                return ImageFont.truetype("arialbd.ttf", size)
            except Exception:
                try:
                    return ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", size)
                except Exception:
                    return ImageFont.load_default()

        font = load_font(font_size)
        text = "   |   ".join(lines)
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]

        while text_width > width * 0.94 and font_size > 10:
            font_size -= 1
            font = load_font(font_size)
            bbox = draw.textbbox((0, 0), text, font=font)
            text_width = bbox[2] - bbox[0]
            text_height = bbox[3] - bbox[1]

        draw.text(
            ((width - text_width) // 2, band_top + (band_height - text_height) // 2),
            text,
            font=font,
            fill=(255, 255, 255, 255),
        )
        output = BytesIO()
        Image.alpha_composite(poster, overlay).convert("RGB").save(output, format="PNG")
        return output.getvalue()
    except Exception as e:
        print(f"Event details overlay failed, returning image without it: {e}")
        return image_bytes


def _add_logo_watermark(image_bytes: bytes) -> bytes:
    """
    Overlays the SkyHigh logo at the bottom-center of the poster.
    If the logo file is missing, returns the original image unchanged.
    """
    if not os.path.exists(LOGO_PATH):
        return image_bytes

    try:
        poster = Image.open(BytesIO(image_bytes)).convert("RGBA")
        logo = Image.open(LOGO_PATH).convert("RGBA")

        # Size the logo relative to poster width — keeps it proportionate
        # across different poster dimensions.
        logo_width = int(poster.width * 0.12)
        logo_ratio = logo_width / logo.width
        logo_height = int(logo.height * logo_ratio)
        logo_resized = logo.resize((logo_width, logo_height), Image.LANCZOS)

        margin_bottom = int(poster.height * 0.015)
        x = (poster.width - logo_width) // 2
        y = poster.height - logo_height - margin_bottom

        poster.paste(logo_resized, (x, y), logo_resized)

        output = BytesIO()
        poster.convert("RGB").save(output, format="PNG")
        return output.getvalue()

    except Exception as e:
        print(f"Logo watermark failed, returning original image: {e}")
        return image_bytes


def generate_poster_image(
    prompt: str,
    event_details: list[str] = None,
    include_terms: bool = False,
) -> tuple[str | None, str | None]:
    """
    Calls Gemini 2.5 Flash Image to generate a poster image from the prompt,
    then overlays event details and the brand logo before returning it.
    Returns (image_b64, error) - one of which will be None.
    """
    try:
        client = _get_client()
        response = client.models.generate_content(
            model="gemini-2.5-flash-image",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_modalities=["Text", "Image"],
            ),
        )

        for part in response.candidates[0].content.parts:
            if part.inline_data is not None:
                image_bytes = part.inline_data.data
                overlay_lines = list(event_details) if event_details else []
                if include_terms:
                    overlay_lines.append("Terms and Conditions Applied")
                if overlay_lines:
                    image_bytes = _add_event_details_overlay(image_bytes, overlay_lines)
                image_bytes = _add_logo_watermark(image_bytes)
                image_b64 = base64.b64encode(image_bytes).decode("utf-8")
                return image_b64, None

        return None, "Gemini did not return an image. The prompt may have been blocked by safety filters."

    except Exception as e:
        return None, f"Image generation failed: {str(e)}"


# ── Generated Posts history (lightweight — config only, no image bytes) ──
GENERATED_POSTERS_COLLECTION = "skyhigh_generated_posters"
SCHEDULED_POSTERS_COLLECTION = "skyhigh_scheduled_posters"


def save_generation_to_history(config: dict) -> str | None:
    """
    Saves the CONFIGURATION used for a generation (not the image itself,
    to stay well within Firestore's 1MB per-document limit and keep
    quota usage light). Returns the new document ID, or None on failure.
    """
    from datetime import datetime

    db = _get_db()
    if not db:
        return None
    try:
        doc_ref = db.collection(GENERATED_POSTERS_COLLECTION).document()
        doc_ref.set({
            **config,
            "generated_at": datetime.utcnow().isoformat(),
        })
        return doc_ref.id
    except Exception as e:
        print(f"Could not save generation history: {e}")
        return None


def get_generation_history(limit: int = 50) -> list[dict]:
    db = _get_db()
    if not db:
        return []
    try:
        docs = (
            db.collection(GENERATED_POSTERS_COLLECTION)
            .order_by("generated_at", direction="DESCENDING")
            .limit(limit)
            .stream()
        )
        return [{"id": d.id, **d.to_dict()} for d in docs]
    except Exception as e:
        print(f"Could not load generation history: {e}")
        return []


def save_scheduled_post(
    poster_config: dict,
    image_b64: str,
    recipient_emails: list[str],
    subject: str,
    message: str,
    scheduled_date: str,
) -> str | None:
    """
    Saves a poster (config + already-generated image) to be sent later.
    Status starts as 'pending' — sending itself is manual (triggered from
    the Scheduled Posts list), since there's no always-on backend to fire
    this automatically at the exact scheduled time.
    """
    from datetime import datetime

    db = _get_db()
    if not db:
        return None
    try:
        doc_ref = db.collection(SCHEDULED_POSTERS_COLLECTION).document()
        doc_ref.set({
            "poster_config": poster_config,
            "image_b64": image_b64,
            "recipient_emails": recipient_emails,
            "subject": subject,
            "message": message,
            "scheduled_date": scheduled_date,
            "status": "pending",
            "created_at": datetime.utcnow().isoformat(),
        })
        return doc_ref.id
    except Exception as e:
        print(f"Could not save scheduled post: {e}")
        return None


def get_scheduled_posts(status: str = None) -> list[dict]:
    """
    Returns scheduled posts, optionally filtered by status ('pending' or
    'sent'). Does NOT include image_b64 in the list response (kept light
    for the list view) — use get_scheduled_post_by_id for the full record
    including the image, when actually sending.
    """
    db = _get_db()
    if not db:
        return []
    try:
        docs = db.collection(SCHEDULED_POSTERS_COLLECTION).stream()
        results = []
        for d in docs:
            data = d.to_dict()
            if status and data.get("status") != status:
                continue
            results.append({
                "id": d.id,
                "poster_config": data.get("poster_config"),
                "recipient_emails": data.get("recipient_emails"),
                "subject": data.get("subject"),
                "scheduled_date": data.get("scheduled_date"),
                "status": data.get("status"),
                "created_at": data.get("created_at"),
            })
        results.sort(key=lambda r: r.get("scheduled_date") or "")
        return results
    except Exception as e:
        print(f"Could not load scheduled posts: {e}")
        return []


def get_scheduled_post_by_id(post_id: str) -> dict | None:
    db = _get_db()
    if not db:
        return None
    try:
        doc = db.collection(SCHEDULED_POSTERS_COLLECTION).document(post_id).get()
        if not doc.exists:
            return None
        return {"id": doc.id, **doc.to_dict()}
    except Exception as e:
        print(f"Could not load scheduled post {post_id}: {e}")
        return None


def mark_scheduled_post_sent(post_id: str) -> bool:
    from datetime import datetime

    db = _get_db()
    if not db:
        return False
    try:
        db.collection(SCHEDULED_POSTERS_COLLECTION).document(post_id).update({
            "status": "sent",
            "sent_at": datetime.utcnow().isoformat(),
        })
        return True
    except Exception as e:
        print(f"Could not update scheduled post {post_id}: {e}")
        return False
