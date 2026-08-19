"""
backend/main.py
FastAPI backend for the SkyHigh Personalized Marketing Intelligence system.
Wraps the existing Python/ML logic (already used in the Streamlit app) as
REST API endpoints, so a Flutter frontend can call the same underlying logic.

Run with:
    uvicorn main:app --reload --port 8000

Then open http://127.0.0.1:8000/docs for interactive API testing (Swagger UI).
"""

from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import pandas as pd
import io

import model_service
import firebase_service
import poster_service
import inventory_service
import customer_service
import cleaner_service

app = FastAPI(
    title="SkyHigh Marketing Intelligence API",
    description="Backend API for customer segmentation, promotion recommendation, and campaign KPIs.",
    version="1.0.0",
)

# Allow the Flutter app (running on a different port/device) to call this API.
# Tighten allow_origins to your actual Flutter app's origin before production use.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Health check ─────────────────────────────────────────────
@app.get("/health")
def health_check():
    return {"status": "ok"}


# ── Model info ───────────────────────────────────────────────
@app.get("/model/info")
def model_info():
    try:
        return model_service.get_model_info()
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ── Recommendation ───────────────────────────────────────────
class CustomerProfile(BaseModel):
    age_group: str
    gender: str
    loyalty_tier: str
    channel: str
    preferred_category: str
    visit_frequency: float
    total_spend_lkr: float
    avg_basket_value_lkr: float
    days_since_last_purchase: float
    customer_past_redemption_rate: float = 0.0
    discount_pct: Optional[float] = 20.0
    is_seasonal_window: int = 0
    is_salary_cycle: int = 0
    is_school_holiday: int = 0


@app.post("/recommend")
def recommend(profile: CustomerProfile):
    try:
        profile_dict = profile.model_dump()
        discount_pct = profile_dict.pop("discount_pct", 20.0)
        ranked = model_service.rank_offers(profile_dict, discount_pct=discount_pct)
        return {
            "top_recommendation": ranked[0],
            "all_offers_ranked": ranked,
        }
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# ── Executive KPIs (Hub screen) ──────────────────────────────
@app.get("/kpis")
def get_kpis():
    ca = firebase_service.load_latest_csv("campaigns")
    cu = firebase_service.load_latest_csv("customers")

    if ca is None:
        raise HTTPException(status_code=404, detail="No campaign data found. Upload data via the dashboard first.")

    kpis = {}

    if "redeemed" in ca.columns:
        kpis["redemption_rate"] = round(float(ca["redeemed"].mean()) * 100, 1)

    if all(c in ca.columns for c in ["treatment", "redeemed"]):
        treat_rate = ca[ca["treatment"] == 1]["redeemed"].mean()
        control_rate = ca[ca["treatment"] == 0]["redeemed"].mean()
        kpis["revenue_uplift_vs_control_pct"] = round(float((treat_rate - control_rate) * 100), 1)

    if all(c in ca.columns for c in ["offer_type", "redeemed"]):
        grp = ca.groupby("offer_type")["redeemed"].mean()
        kpis["best_offer_type"] = grp.idxmax()
        kpis["best_offer_redemption_rate"] = round(float(grp.max()) * 100, 1)

    if all(c in ca.columns for c in ["channel", "clicked"]):
        grp = ca.groupby("channel")["clicked"].mean()
        kpis["best_channel"] = grp.idxmax()
        kpis["best_channel_ctr"] = round(float(grp.max()) * 100, 1)

    kpis["total_campaigns"] = int(len(ca))
    kpis["total_customers"] = int(len(cu)) if cu is not None else None

    try:
        model_info = model_service.get_model_info()
        kpis["model_accuracy"] = round(model_info["accuracy"] * 100, 1) if model_info.get("accuracy") else None
    except FileNotFoundError:
        kpis["model_accuracy"] = None

    return kpis


# ── Upload history ────────────────────────────────────────────
@app.get("/upload-history")
def upload_history(limit: int = 20):
    return firebase_service.get_upload_history(limit=limit)


# ── Poster Generation (Colab / Stable Diffusion) ──────────────
class PosterRequest(BaseModel):
    api_url: str  # Colab ngrok URL, e.g. https://xxxx.ngrok-free.app
    gender: str
    age_group: str
    offer_type: str
    discount_value: str
    season: str
    items: list[str]
    palette: str
    style: str
    brand_name: str = "SkyHigh"


@app.get("/poster/health")
def poster_health(api_url: str):
    ok, message = poster_service.check_colab_health(api_url)
    return {"connected": ok, "message": message}


@app.post("/poster/generate")
def generate_poster(req: PosterRequest):
    payload = poster_service.build_prompt_payload(
        gender=req.gender,
        age_group=req.age_group,
        offer_type=req.offer_type,
        discount_value=req.discount_value,
        season=req.season,
        items=req.items,
        palette=req.palette,
        style=req.style,
        brand_name=req.brand_name,
    )
    image_b64, error = poster_service.generate_poster_image(req.api_url, payload)
    if error:
        raise HTTPException(status_code=502, detail=error)
    return {"image_b64": image_b64}


# ── Inventory preview (read-only, teammate's Firestore collections) ──────
@app.get("/inventory/collections")
def inventory_collections():
    """Lists all top-level collection names in the shared Firestore project."""
    return inventory_service.list_collections()


@app.get("/inventory/preview")
def inventory_preview(collection: str, limit: int = 5):
    """Read-only preview of a given collection's documents, to inspect real structure."""
    return inventory_service.preview_collection(collection, limit=limit)


@app.get("/inventory/overstock-suggestions")
def overstock_suggestions(category: str = None, limit: int = 10):
    """
    Returns overstocked products (read-only, from the inventory component's
    precomputed alert), optionally filtered by category — e.g. a 'Women'
    category filter suggests overstocked women's items worth promoting.
    """
    return inventory_service.get_overstock_suggestions(category=category, limit=limit)


# ── Promotion Calendar ─────────────────────────────────────────
class CalendarNote(BaseModel):
    date: str  # YYYY-MM-DD
    text: str


@app.get("/calendar/campaigns")
def calendar_campaigns(year: int, month: int):
    """Returns {day: count} of campaigns sent in the given month."""
    return firebase_service.get_campaign_counts_by_day(year, month)


@app.get("/calendar/campaigns/year")
def calendar_campaigns_year(year: int):
    """Returns {month: {day: count}} for the whole year, in one call."""
    return firebase_service.get_campaign_counts_by_year(year)


@app.get("/calendar/notes")
def calendar_notes(year: int, month: int):
    return firebase_service.get_calendar_notes(year, month)


@app.get("/calendar/notes/year")
def calendar_notes_year(year: int):
    """Returns all notes for the given year, no month filter."""
    return firebase_service.get_calendar_notes_year(year)


@app.post("/calendar/notes")
def add_calendar_note(note: CalendarNote):
    note_id = firebase_service.add_calendar_note(note.date, note.text)
    if note_id is None:
        raise HTTPException(status_code=500, detail="Could not save note")
    return {"id": note_id, "date": note.date, "text": note.text}


@app.delete("/calendar/notes/{note_id}")
def delete_calendar_note(note_id: str):
    success = firebase_service.delete_calendar_note(note_id)
    if not success:
        raise HTTPException(status_code=500, detail="Could not delete note")
    return {"deleted": True}


# ── Customer Intelligence ───────────────────────────────────────
@app.get("/customer-intelligence")
def customer_intelligence(at_risk_days: int = 60, top_n: int = 10):
    result = customer_service.get_customer_intelligence(at_risk_days=at_risk_days, top_n=top_n)
    if "error" in result:
        raise HTTPException(status_code=404, detail=result["error"])
    return result


# ── Data Upload ──────────────────────────────────────────────
ALLOWED_FILE_TYPES = ["campaigns", "customers", "transactions"]


@app.post("/upload")
async def upload_csv(file: UploadFile = File(...), file_type: str = Form(...)):
    if file_type not in ALLOWED_FILE_TYPES:
        raise HTTPException(status_code=400, detail=f"file_type must be one of {ALLOWED_FILE_TYPES}")

    try:
        contents = await file.read()
        df_raw = pd.read_csv(io.BytesIO(contents))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Could not read CSV: {e}")

    df_clean, report = cleaner_service.clean_csv(df_raw, file_type)

    success, error = firebase_service.save_csv_to_firebase(df_clean, file_type)
    if not success:
        raise HTTPException(status_code=500, detail=f"Cleaned successfully but could not save to Firebase: {error}")

    columns_detected = list(df_clean.columns)
    preview = df_clean.head(3).to_dict(orient="records")

    return {
        "file_type": file_type,
        "row_count": len(df_clean),
        "cleaning_report": report,
        "columns_detected": columns_detected,
        "preview": preview,
        "saved_to_firebase": True,
    }