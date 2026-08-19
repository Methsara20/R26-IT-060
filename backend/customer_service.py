"""
backend/customer_service.py
Computes customer segmentation, new-vs-returning classification, purchase
intent scoring, and disengagement risk — same logic as the Streamlit
Customer Intelligence tab, exposed here for the Flutter frontend.
"""

import pandas as pd
import firebase_service


def get_customer_intelligence(at_risk_days: int = 60, top_n: int = 10):
    cu = firebase_service.load_latest_csv("customers")
    if cu is None:
        return {"error": "No customer data found. Upload data via the dashboard first."}

    result = {}
    total_customers = len(cu)
    result["total_customers"] = total_customers

    # ── Top KPIs ────────────────────────────────────────────
    if "loyalty_tier" in cu.columns:
        result["gold_platinum_share"] = round(
            float(cu["loyalty_tier"].isin(["Gold", "Platinum"]).mean() * 100), 1
        )
    if "total_spend_lkr" in cu.columns:
        result["avg_spend"] = round(float(cu["total_spend_lkr"].mean()), 0)
    if "visit_frequency" in cu.columns:
        result["avg_visits"] = round(float(cu["visit_frequency"].mean()), 1)

    # ── Segment breakdowns ────────────────────────────────────
    if "loyalty_tier" in cu.columns:
        result["by_loyalty_tier"] = cu["loyalty_tier"].value_counts().to_dict()
    if "age_group" in cu.columns:
        result["by_age_group"] = cu["age_group"].value_counts().sort_index().to_dict()
    if "preferred_category" in cu.columns:
        result["by_category"] = cu["preferred_category"].value_counts().to_dict()

    # ── New vs Returning ──────────────────────────────────────
    has_join = "join_date" in cu.columns
    has_visits = "visit_frequency" in cu.columns
    if has_join or has_visits:
        cu_work = cu.copy()
        if has_join:
            cu_work["join_date"] = pd.to_datetime(cu_work["join_date"], errors="coerce")
            reference_date = cu_work["join_date"].max()
            days_since_join = (reference_date - cu_work["join_date"]).dt.days
            new_by_join = days_since_join <= 90
        else:
            new_by_join = pd.Series(False, index=cu_work.index)

        new_by_visits = cu_work["visit_frequency"] <= 1 if has_visits else pd.Series(False, index=cu_work.index)
        status = (new_by_join | new_by_visits).map({True: "New", False: "Returning"})
        result["new_vs_returning"] = status.value_counts().to_dict()

    # ── Purchase Intent Score (RFM) ────────────────────────────
    intent_inputs = ["days_since_last_purchase", "visit_frequency", "total_spend_lkr"]
    if all(c in cu.columns for c in intent_inputs):
        ci = cu.copy()
        max_days = ci["days_since_last_purchase"].max() or 1
        max_visits = ci["visit_frequency"].max() or 1
        max_spend = ci["total_spend_lkr"].max() or 1

        recency_score = (1 - (ci["days_since_last_purchase"] / max_days)).clip(0, 1) * 100
        frequency_score = (ci["visit_frequency"] / max_visits).clip(0, 1) * 100
        monetary_score = (ci["total_spend_lkr"] / max_spend).clip(0, 1) * 100

        ci["intent_score"] = (recency_score * 0.4 + frequency_score * 0.3 + monetary_score * 0.3).round(1)

        def bucket(score):
            if score >= 66:
                return "High"
            if score >= 33:
                return "Medium"
            return "Low"

        ci["intent_bucket"] = ci["intent_score"].apply(bucket)

        result["avg_intent_score"] = round(float(ci["intent_score"].mean()), 1)
        result["intent_distribution"] = ci["intent_bucket"].value_counts().to_dict()
        result["high_intent_count"] = int((ci["intent_bucket"] == "High").sum())

        top_intent_cols = ["customer_id", "loyalty_tier", "age_group", "intent_score", "intent_bucket"]
        top_intent_cols = [c for c in top_intent_cols if c in ci.columns]
        top_intent = ci.sort_values("intent_score", ascending=False).head(top_n)
        result["top_intent_customers"] = top_intent[top_intent_cols].to_dict(orient="records")

    # ── At-risk / disengagement ────────────────────────────────
    if "days_since_last_purchase" in cu.columns:
        at_risk = cu[cu["days_since_last_purchase"] > at_risk_days]
        result["at_risk_count"] = int(len(at_risk))
        result["at_risk_pct"] = round(float(len(at_risk) / total_customers * 100), 1) if total_customers else 0
        if not at_risk.empty and "loyalty_tier" in at_risk.columns:
            result["at_risk_by_tier"] = at_risk["loyalty_tier"].value_counts().to_dict()

    # ── Top customers by value ──────────────────────────────────
    if "total_spend_lkr" in cu.columns:
        display_cols = ["customer_id", "loyalty_tier", "age_group", "gender", "total_spend_lkr"]
        display_cols = [c for c in display_cols if c in cu.columns]
        if "visit_frequency" in cu.columns:
            display_cols.append("visit_frequency")
        top_customers = cu.sort_values("total_spend_lkr", ascending=False).head(top_n)
        result["top_customers_by_value"] = top_customers[display_cols].to_dict(orient="records")

    return result