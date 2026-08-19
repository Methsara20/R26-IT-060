import streamlit as st
import json
import os
from shared.helpers import safe_col

MODEL_META_PATH = "model/columns.json"


def load_model_accuracy():
    """Reads accuracy from the trained model's metadata, if it exists."""
    if not os.path.exists(MODEL_META_PATH):
        return None
    try:
        with open(MODEL_META_PATH, "r") as f:
            meta = json.load(f)
        return meta.get("accuracy")
    except Exception:
        return None


def render_executive_kpis(ca, cu):
    """Top-level exec summary row: the numbers a supervisor/client would want in 5 seconds."""
    st.markdown('<div class="sec-hdr">📌 Executive Summary</div>', unsafe_allow_html=True)

    has_ca = ca is not None
    has_treatment = has_ca and all(c in ca.columns for c in ["treatment", "redeemed"])
    has_revenue = has_ca and "revenue_after_lkr" in ca.columns

    # Revenue uplift vs control — the strongest number, since it shows causal impact
    if has_treatment:
        treat_rate = ca[ca["treatment"] == 1]["redeemed"].mean()
        control_rate = ca[ca["treatment"] == 0]["redeemed"].mean()
        uplift_pct = (treat_rate - control_rate) * 100
        uplift_val = f"{uplift_pct:+.1f}%"
    else:
        uplift_val = "—"

    redemption_val = f"{ca['redeemed'].mean()*100:.1f}%" if safe_col(ca, "redeemed") else "—"

    if safe_col(ca, "offer_type") and safe_col(ca, "redeemed"):
        best_offer = ca.groupby("offer_type")["redeemed"].mean().idxmax()
        best_offer_rate = ca.groupby("offer_type")["redeemed"].mean().max()
        best_offer_val = f"{best_offer} ({best_offer_rate*100:.0f}%)"
    else:
        best_offer_val = "—"

    if safe_col(ca, "channel") and safe_col(ca, "clicked"):
        best_channel = ca.groupby("channel")["clicked"].mean().idxmax()
        best_ctr = ca.groupby("channel")["clicked"].mean().max()
        best_channel_val = f"{best_channel} ({best_ctr*100:.0f}%)"
    else:
        best_channel_val = "—"

    total_customers_val = f"{len(cu):,}" if cu is not None else "—"

    accuracy = load_model_accuracy()
    accuracy_val = f"{accuracy*100:.1f}%" if accuracy is not None else "—"

    kpis = [
        ("💰 Revenue Uplift vs Control", uplift_val, "treatment vs control"),
        ("🎯 Redemption Rate", redemption_val, "overall"),
        ("🏆 Best Offer Type", best_offer_val, "by redemption"),
        ("📣 Best Channel", best_channel_val, "by CTR"),
        ("👥 Total Customers", total_customers_val, "in database"),
        ("🤖 Model Accuracy", accuracy_val, "recommender confidence"),
    ]

    cols = st.columns(6)
    for col, (label, value, sub) in zip(cols, kpis):
        with col:
            st.markdown(f"""<div class="kpi-card">
                <div class="kpi-label">{label}</div>
                <div class="kpi-value" style="font-size:1.15rem">{value}</div>
                <div class="kpi-delta">{sub}</div>
            </div>""", unsafe_allow_html=True)

    if not has_ca:
        st.caption("⚠️ Upload campaign data to populate these metrics.")

    st.markdown("<br>", unsafe_allow_html=True)


def generate_notifications(df_ca, df_cu):
    notifs = []
    try:
        if df_ca is not None and all(c in df_ca.columns for c in ["offer_type", "redeemed"]):
            best_offer = df_ca.groupby("offer_type")["redeemed"].mean().idxmax()
            best_rate  = df_ca.groupby("offer_type")["redeemed"].mean().max()
            notifs.append({
                "title": "🏆 Top Performing Promotion",
                "desc":  f"'{best_offer}' has {best_rate*100:.1f}% redemption rate — scale this campaign!",
                "action": "View Performance"
            })
    except Exception:
        pass
    try:
        if df_ca is not None and all(c in df_ca.columns for c in ["channel", "clicked"]):
            best_ch   = df_ca.groupby("channel")["clicked"].mean().idxmax()
            best_ctr  = df_ca.groupby("channel")["clicked"].mean().max()
            notifs.append({
                "title": "📣 Best Performing Channel",
                "desc":  f"'{best_ch}' leads with {best_ctr*100:.1f}% CTR — prioritize this channel.",
                "action": "View Channel"
            })
    except Exception:
        pass
    try:
        if df_ca is not None and df_cu is not None:
            if all(c in df_ca.columns for c in ["customer_id","redeemed"]) and \
               all(c in df_cu.columns for c in ["customer_id","age_group","gender"]):
                merged = df_ca.merge(df_cu[["customer_id","age_group","gender"]], on="customer_id", how="left")
                seg = merged.groupby(["age_group","gender"])["redeemed"].mean()
                best = seg.idxmax()
                notifs.append({
                    "title": "🎯 Highest Responding Segment",
                    "desc":  f"{best[1].title()} aged {best[0]} — {seg.max()*100:.1f}% redemption. Recommend a poster!",
                    "action": "Generate Poster"
                })
    except Exception:
        pass
    return notifs


def render(tab):
    with tab:
        st.markdown('<div class="dash-header-inner"><p class="dash-title">Personalized Marketing Intelligence — System Status</p></div>', unsafe_allow_html=True)

        render_executive_kpis(st.session_state.df_ca, st.session_state.df_cu)

        if st.session_state.notifications:
            st.markdown('<div class="sec-hdr">🔔 Smart Notifications</div>', unsafe_allow_html=True)
            for notif in st.session_state.notifications:
                st.markdown(f"""<div class="notif-card">
                    <div class="notif-title">{notif['title']}</div>
                    <div class="notif-desc">{notif['desc']}</div>
                </div>""", unsafe_allow_html=True)
            st.markdown("<br>", unsafe_allow_html=True)
        else:
            st.info("📤 Upload your CSV files in the **Upload Data** tab to activate smart notifications.")

        has_ca = st.session_state.df_ca is not None
        has_cu = st.session_state.df_cu is not None
        has_model = st.session_state.model_loaded

        c1, c2, c3 = st.columns(3)
        with c1:
            st.markdown(f"""<div class="hub-card">
                <div class="hub-title">📊 Promotion Performance Engine</div>
                <div class="hub-desc">Analyzes CTR, redemption rates and revenue lift across offer types and channels.</div>
                <div style="margin-top:8px;font-size:12px;color:{'#4A7C59' if has_ca else '#C8952A'};font-weight:600">
                    {'✅ Active — Campaign data loaded' if has_ca else '⚠️ Upload campaign data to activate'}
                </div></div>""", unsafe_allow_html=True)
            st.markdown(f"""<div class="hub-card">
                <div class="hub-title">⚙️ Promo Attribute Engine</div>
                <div class="hub-desc">Determines optimal discount level, target audience and promotion timing.</div>
                <div style="margin-top:8px;font-size:12px;color:{'#4A7C59' if has_ca else '#C8952A'};font-weight:600">
                    {'✅ Active — Ready for analysis' if has_ca else '⚠️ Upload campaign data to activate'}
                </div></div>""", unsafe_allow_html=True)
        with c2:
            st.markdown("""
            <div style="background:#1A2744;border-radius:50%;width:180px;height:180px;
                        margin:0 auto;display:flex;align-items:center;justify-content:center;
                        border:3px solid #D4A853;text-align:center;">
                <div>
                    <div style="color:#D4A853;font-size:13px;font-weight:700;letter-spacing:1px">PROMO</div>
                    <div style="color:white;font-size:11px;margin-top:4px">INTELLIGENCE</div>
                    <div style="color:#D4A853;font-size:13px;font-weight:700">HUB</div>
                </div>
            </div>
            <div style="text-align:center;margin-top:12px;font-size:12px;color:#6B5B3E">6 components active</div>""", unsafe_allow_html=True)
        with c3:
            st.markdown(f"""<div class="hub-card">
                <div class="hub-title">🤖 XGBoost Promotion Recommender</div>
                <div class="hub-desc">Predicts best promotion type per customer segment using machine learning.</div>
                <div style="margin-top:8px;font-size:12px;color:{'#4A7C59' if has_model else '#C8952A'};font-weight:600">
                    {'✅ Model loaded — Ready to predict' if has_model else '⚠️ Run train_model.py to activate'}
                </div></div>""", unsafe_allow_html=True)
            st.markdown(f"""<div class="hub-card">
                <div class="hub-title">🎨 Emotion-Aware Poster Generator</div>
                <div class="hub-desc">Generates tailored promotional posters via Nano Banana based on segment.</div>
                <div style="margin-top:8px;font-size:12px;color:{'#4A7C59' if st.session_state.claude_key else '#C8952A'};font-weight:600">
                    {'✅ Connected — Gemini API key set' if st.session_state.claude_key else '⚠️ Set Gemini API key in Poster Generator tab'}
                </div></div>""", unsafe_allow_html=True)

        # ── KPIs ──────────────────────────────────────────────
        st.markdown("<br>", unsafe_allow_html=True)
        st.markdown('<div class="sec-hdr">Promotion KPIs</div>', unsafe_allow_html=True)
        ca = st.session_state.df_ca
        cu = st.session_state.df_cu
        m1, m2, m3, m4, m5 = st.columns(5)

        total_camp  = f"{len(ca):,}"                                        if ca is not None else "—"
        ctr_val     = f"{ca['clicked'].mean()*100:.1f}%"                    if safe_col(ca, "clicked")          else "—"
        red_val     = f"{ca['redeemed'].mean()*100:.1f}%"                   if safe_col(ca, "redeemed")         else "—"
        best_offer  = ca.groupby("offer_type")["redeemed"].mean().idxmax()  if safe_col(ca, "offer_type")       else "—"
        cu_count    = f"{len(cu):,}"                                        if cu is not None else "—"

        for col, (lbl, val, dlt) in zip([m1, m2, m3, m4, m5], [
            ("Total Campaigns",  total_camp,  "campaigns run"),
            ("Avg CTR",          ctr_val,     "clicked / sent"),
            ("Redemption Rate",  red_val,     "redeemed / sent"),
            ("Best Offer Type",  best_offer,  "highest redemption"),
            ("Total Customers",  cu_count,    "in database"),
        ]):
            with col:
                st.markdown(f"""<div class="kpi-card">
                    <div class="kpi-label">{lbl}</div>
                    <div class="kpi-value" style="font-size:1.3rem">{val}</div>
                    <div class="kpi-delta">{dlt}</div>
                </div>""", unsafe_allow_html=True)