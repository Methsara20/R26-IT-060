from fastapi import APIRouter, HTTPException
from app.services import firebase_service, model_service
import pandas as pd

router = APIRouter(tags=["KPIs"])


def compute_kpis(ca: pd.DataFrame, cu: pd.DataFrame, start_date: str = None, end_date: str = None) -> dict:
    """
    Computes the full KPI set from a campaigns dataframe (and optionally a
    customers dataframe), optionally filtered to a date range (inclusive)
    based on sent_date. Shared by /kpis (dashboard) and /reports/generate
    (PDF export) so both always show identical numbers for the same range.
    """
    if "sent_date" in ca.columns and (start_date or end_date):
        ca = ca.copy()
        ca["sent_date"] = pd.to_datetime(ca["sent_date"], errors="coerce")
        if start_date:
            ca = ca[ca["sent_date"] >= pd.to_datetime(start_date)]
        if end_date:
            ca = ca[ca["sent_date"] <= pd.to_datetime(end_date)]

    kpis = {}

    if len(ca) == 0:
        kpis["no_data_in_range"] = True
        kpis["total_campaigns"] = 0
        kpis["total_customers"] = int(len(cu)) if cu is not None else None
        return kpis

    if "redeemed" in ca.columns:
        kpis["redemption_rate"] = round(float(ca["redeemed"].mean()) * 100, 1)

    if all(c in ca.columns for c in ["treatment", "redeemed"]):
        treat_rate = ca[ca["treatment"] == 1]["redeemed"].mean()
        control_rate = ca[ca["treatment"] == 0]["redeemed"].mean()
        uplift = (treat_rate - control_rate) * 100
        kpis["revenue_uplift_vs_control_pct"] = round(float(uplift), 1) if pd.notna(uplift) else None

    if all(c in ca.columns for c in ["offer_type", "redeemed"]):
        grp = ca.groupby("offer_type")["redeemed"].mean()
        kpis["best_offer_type"] = grp.idxmax()
        kpis["best_offer_redemption_rate"] = round(float(grp.max()) * 100, 1)
        kpis["offer_type_breakdown"] = {k: round(float(v) * 100, 1) for k, v in grp.to_dict().items()}

    if all(c in ca.columns for c in ["channel", "clicked"]):
        grp = ca.groupby("channel")["clicked"].mean()
        kpis["best_channel"] = grp.idxmax()
        kpis["best_channel_ctr"] = round(float(grp.max()) * 100, 1)
        kpis["channel_breakdown"] = {k: round(float(v) * 100, 1) for k, v in grp.to_dict().items()}

    kpis["total_campaigns"] = int(len(ca))
    kpis["total_customers"] = int(len(cu)) if cu is not None else None

    if all(c in ca.columns for c in ["sent_date", "redeemed", "revenue_after_lkr"]):
        try:
            redeemed_ca = ca[ca["redeemed"] == 1].copy()
            redeemed_ca["sent_date"] = pd.to_datetime(redeemed_ca["sent_date"], errors="coerce")
            redeemed_ca = redeemed_ca.dropna(subset=["sent_date"])
            redeemed_ca["year_month"] = redeemed_ca["sent_date"].dt.to_period("M")

            monthly_revenue = redeemed_ca.groupby("year_month")["revenue_after_lkr"].sum().sort_index()

            top_offer_by_month = {}
            if "offer_type" in redeemed_ca.columns:
                for period, group in redeemed_ca.groupby("year_month"):
                    if len(group) > 0:
                        top_offer_by_month[str(period)] = group["offer_type"].mode().iloc[0]

            kpis["revenue_over_time"] = {
                "labels": [str(period) for period in monthly_revenue.index],
                "values": [round(float(v), 2) for v in monthly_revenue.values],
                "top_offer_type": [top_offer_by_month.get(str(period)) for period in monthly_revenue.index],
            }
            kpis["total_revenue"] = round(float(redeemed_ca["revenue_after_lkr"].sum()), 2)
        except Exception as e:
            print(f"Could not compute revenue_over_time: {e}")
            kpis["revenue_over_time"] = None

    try:
        model_info = model_service.get_model_info()
        kpis["model_accuracy"] = round(model_info["accuracy"] * 100, 1) if model_info.get("accuracy") else None
    except FileNotFoundError:
        kpis["model_accuracy"] = None

    return kpis


@router.get("/kpis")
def get_kpis(start_date: str = None, end_date: str = None):
    """
    Returns the full KPI set. Optionally filtered to a date range
    (YYYY-MM-DD, inclusive) via start_date/end_date — used by the
    dashboard's Today/This Month/Last Month/This Year/Last Year/Custom
    filter. With no params, returns all-time KPIs as before.
    """
    ca = firebase_service.load_latest_csv("campaigns")
    cu = firebase_service.load_latest_csv("customers")

    if ca is None:
        raise HTTPException(status_code=404, detail="No campaign data found. Upload data via the dashboard first.")

    return compute_kpis(ca, cu, start_date=start_date, end_date=end_date)


@router.get("/kpis/available-periods")
def get_available_periods():
    """
    Returns the real years, months, and quarters actually present in the
    campaigns data — so the report-generation UI only ever offers periods
    that genuinely have data, never guessed/hardcoded ones.
    """
    ca = firebase_service.load_latest_csv("campaigns")
    if ca is None or "sent_date" not in ca.columns:
        return {"years": [], "months": [], "quarters": []}

    dates = pd.to_datetime(ca["sent_date"], errors="coerce").dropna()

    years = sorted(dates.dt.year.unique().tolist())

    months_set = set(dates.dt.to_period("M").astype(str))
    months = sorted(months_set)

    quarters_set = set(dates.dt.to_period("Q").astype(str))  # e.g. "2025Q1"
    quarters = sorted(quarters_set)

    return {
        "years": [str(y) for y in years],
        "months": months,
        "quarters": quarters,
    }