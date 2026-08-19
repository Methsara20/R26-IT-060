import streamlit as st
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')
from shared.helpers import missing_cols_error, get_xai_reasoning

CA_REQUIRED = ["offer_type", "clicked", "redeemed", "channel", "revenue_after_lkr", "treatment", "discount_pct"]

def make_bar(data, color, title, figsize=(6, 3.5), ylabel=""):
    fig, ax = plt.subplots(figsize=figsize)
    fig.patch.set_facecolor('#FFFFFF')
    ax.set_facecolor('#FFFFFF')
    ax.bar(data.index.astype(str), data.values, color=color, edgecolor='none', width=0.6)
    ax.set_title(title, fontsize=11, fontweight='bold', color='#1A2744', pad=10)
    ax.set_ylabel(ylabel, fontsize=9, color='#888888')
    ax.tick_params(axis='x', rotation=35, labelsize=9, colors='#444444')
    ax.tick_params(axis='y', labelsize=8, colors='#888888')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color('#DDDDDD')
    ax.spines['bottom'].set_color('#DDDDDD')
    plt.xticks(ha='right')
    plt.tight_layout()
    return fig

def render(tab):
    with tab:
        st.markdown('<div class="sec-hdr">Promotion Performance Analytics</div>', unsafe_allow_html=True)
        ca = st.session_state.df_ca
        cu = st.session_state.df_cu

        if missing_cols_error(ca, CA_REQUIRED, "Campaigns", "promo_perf"):
            return

        # ── Filters ───────────────────────────────────────────
        st.markdown("**🔍 Filters**")
        f1, f2, f3 = st.columns(3)
        with f1:
            offer_filter = st.multiselect("Offer Type",
                options=ca["offer_type"].unique().tolist(),
                default=ca["offer_type"].unique().tolist(),
                key="perf_offer")
        with f2:
            channel_filter = st.multiselect("Channel",
                options=ca["channel"].unique().tolist(),
                default=ca["channel"].unique().tolist(),
                key="perf_channel")
        with f3:
            treatment_filter = st.selectbox("Group",
                options=["All", "Treatment", "Control"],
                key="perf_treatment")

        # Apply filters
        filtered = ca[
            (ca["offer_type"].isin(offer_filter)) &
            (ca["channel"].isin(channel_filter))
        ].copy()
        if treatment_filter == "Treatment":
            filtered = filtered[filtered["treatment"] == 1]
        elif treatment_filter == "Control":
            filtered = filtered[filtered["treatment"] == 0]

        if filtered.empty:
            st.warning("No data matches the selected filters.")
            return

        st.markdown("<br>", unsafe_allow_html=True)

        # ── KPIs ──────────────────────────────────────────────
        k1, k2, k3, k4 = st.columns(4)
        for col, (lbl, val) in zip([k1, k2, k3, k4], [
            ("Total Campaigns",  f"{len(filtered):,}"),
            ("Avg CTR",          f"{filtered['clicked'].mean()*100:.1f}%"),
            ("Redemption Rate",  f"{filtered['redeemed'].mean()*100:.1f}%"),
            ("Avg Revenue Lift", f"LKR {filtered['revenue_after_lkr'].mean():,.0f}"),
        ]):
            with col:
                st.markdown(f"""<div class="kpi-card">
                    <div class="kpi-label">{lbl}</div>
                    <div class="kpi-value" style="font-size:1.3rem">{val}</div>
                </div>""", unsafe_allow_html=True)

        st.markdown("<br>", unsafe_allow_html=True)

        # ── Charts Row 1 ──────────────────────────────────────
        p1, p2 = st.columns(2)
        with p1:
            st.pyplot(make_bar(
                filtered.groupby("offer_type")["redeemed"].mean()*100,
                "#1A2744", "Redemption Rate by Offer Type (%)", ylabel="%"))
        with p2:
            st.pyplot(make_bar(
                filtered.groupby("channel")["clicked"].mean()*100,
                "#D4A853", "CTR by Channel (%)", ylabel="%"))

        st.markdown("<br>", unsafe_allow_html=True)

        # ── Charts Row 2 ──────────────────────────────────────
        p3, p4 = st.columns(2)
        with p3:
            st.pyplot(make_bar(
                filtered.groupby("offer_type")["revenue_after_lkr"].mean(),
                "#1A2744", "Avg Revenue After Campaign by Offer", ylabel="LKR"))
        with p4:
            st.pyplot(make_bar(
                filtered.groupby("discount_pct")["redeemed"].mean()*100,
                "#D4A853", "Redemption Rate by Discount Level (%)", ylabel="%"))

        st.markdown("<br>", unsafe_allow_html=True)

        # ── Segment breakdown if customers loaded ─────────────
        if cu is not None and all(c in cu.columns for c in ["customer_id", "age_group", "gender"]):
            st.markdown('<div class="sec-hdr">Segment-Level Promotion Response</div>', unsafe_allow_html=True)

            seg_f1, seg_f2 = st.columns(2)
            with seg_f1:
                seg_filter_age = st.multiselect("Age Group",
                    options=cu["age_group"].dropna().unique().tolist(),
                    default=cu["age_group"].dropna().unique().tolist(),
                    key="perf_age")
            with seg_f2:
                seg_filter_gen = st.multiselect("Gender",
                    options=cu["gender"].unique().tolist(),
                    default=cu["gender"].unique().tolist(),
                    key="perf_gender")

            merged = filtered.merge(
                cu[["customer_id", "age_group", "gender", "loyalty_tier"]],
                on="customer_id", how="left"
            )
            merged = merged[
                (merged["age_group"].isin(seg_filter_age)) &
                (merged["gender"].isin(seg_filter_gen))
            ]

            if not merged.empty:
                s1, s2 = st.columns(2)
                with s1:
                    st.pyplot(make_bar(
                        merged.groupby("age_group")["redeemed"].mean()*100,
                        "#1A2744", "Redemption Rate by Age Group (%)", ylabel="%"))
                with s2:
                    st.pyplot(make_bar(
                        merged.groupby("gender")["redeemed"].mean()*100,
                        "#D4A853", "Redemption Rate by Gender (%)", ylabel="%"))

                s3, s4 = st.columns(2)
                with s3:
                    st.pyplot(make_bar(
                        merged.groupby("loyalty_tier")["redeemed"].mean()*100,
                        "#1A2744", "Redemption Rate by Loyalty Tier (%)", ylabel="%"))
                with s4:
                    st.pyplot(make_bar(
                        merged.groupby("offer_type")["revenue_after_lkr"].mean(),
                        "#D4A853", "Avg Revenue by Offer Type", ylabel="LKR"))

        st.markdown("<br>", unsafe_allow_html=True)

        # ── Treatment vs Control ──────────────────────────────
        st.markdown('<div class="sec-hdr">Treatment vs Control Analysis</div>', unsafe_allow_html=True)
        t1, t2 = st.columns(2)
        with t1:
            treat_data = filtered.groupby("treatment")["redeemed"].mean()*100
            treat_data.index = treat_data.index.map({0: "Control", 1: "Treatment"})
            st.pyplot(make_bar(treat_data, "#1A2744", "Redemption: Treatment vs Control (%)", ylabel="%"))
        with t2:
            treat_rev = filtered.groupby("treatment")["revenue_after_lkr"].mean()
            treat_rev.index = treat_rev.index.map({0: "Control", 1: "Treatment"})
            st.pyplot(make_bar(treat_rev, "#D4A853", "Revenue: Treatment vs Control (LKR)", ylabel="LKR"))

        # ── XAI ───────────────────────────────────────────────
        st.markdown("<br>", unsafe_allow_html=True)
        best_offer      = filtered.groupby("offer_type")["redeemed"].mean().idxmax()
        best_offer_rate = filtered.groupby("offer_type")["redeemed"].mean().max()
        best_channel    = filtered.groupby("channel")["clicked"].mean().idxmax()

        col_ev, col_btn = st.columns([3, 1])
        with col_ev:
            st.markdown(f"""<div class="hub-card">
                <div class="hub-title">📊 Key Findings</div>
                <div class="hub-desc">
                    Best offer type: <b>{best_offer}</b> ({best_offer_rate*100:.1f}% redemption)<br>
                    Best channel: <b>{best_channel}</b><br>
                    Treatment uplift: <b>{(filtered[filtered.treatment==1]['redeemed'].mean() - filtered[filtered.treatment==0]['redeemed'].mean())*100:.1f}%</b> vs control<br>
                    Total campaigns analysed: <b>{len(filtered):,}</b>
                </div></div>""", unsafe_allow_html=True)
      
    
