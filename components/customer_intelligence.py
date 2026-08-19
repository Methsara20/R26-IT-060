import streamlit as st
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')

CU_REQUIRED = ["customer_id", "age_group", "gender", "loyalty_tier"]


def make_bar(data, color, title, figsize=(6, 3.2), ylabel="", show_labels=True):
    fig, ax = plt.subplots(figsize=figsize)
    fig.patch.set_facecolor('#FFFFFF')
    ax.set_facecolor('#FFFFFF')

    # Keep bars a sensible width even when there's only 1-2 categories
    n = len(data)
    bar_width = 0.5 if n <= 3 else 0.6

    bars = ax.bar(data.index.astype(str), data.values, color=color,
                   edgecolor='white', linewidth=1.5, width=bar_width, zorder=3)

    ax.set_title(title, fontsize=11, fontweight='bold', color='#1A2744', pad=12)
    ax.set_ylabel(ylabel, fontsize=9, color='#888888')
    ax.tick_params(axis='x', rotation=0 if n <= 4 else 25, labelsize=10, colors='#1A2744')
    ax.tick_params(axis='y', labelsize=8, colors='#888888')

    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_visible(False)
    ax.spines['bottom'].set_color('#DDDDDD')

    # Subtle horizontal gridlines behind the bars, helps read values at a glance
    ax.yaxis.grid(True, color='#EDE5D0', linewidth=0.8, zorder=0)
    ax.set_axisbelow(True)

    # Give some headroom above the tallest bar so labels don't get clipped
    ax.set_ylim(0, max(data.values) * 1.18 if len(data) else 1)

    if show_labels:
        for bar, val in zip(bars, data.values):
            ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + max(data.values) * 0.02,
                    f'{val:,.0f}' if float(val).is_integer() else f'{val:,.1f}',
                    ha='center', va='bottom', fontsize=9, fontweight='bold', color='#1A2744')

    if n <= 4:
        plt.xticks(ha='center')
    else:
        plt.xticks(ha='right')
    plt.tight_layout()
    return fig


def render(tab):
    with tab:
        st.markdown('<div class="sec-hdr">👥 Customer Intelligence</div>', unsafe_allow_html=True)
        st.caption("Who your customers are, how they're segmented, and what that means for targeting.")

        cu = st.session_state.df_cu
        ca = st.session_state.df_ca

        if cu is None:
            st.markdown("""
            <div class="error-card">
                <div class="error-card-title">⚠️ No customer data uploaded</div>
                <div class="error-card-body">
                    Please upload your <b>Customers</b> CSV file in the
                    <b>📤 Upload Data</b> tab first, then come back here.
                </div>
            </div>""", unsafe_allow_html=True)
            return

        missing = [c for c in CU_REQUIRED if c not in cu.columns]
        if missing:
            st.warning(f"Missing expected columns in customer data: {', '.join(missing)}")
            return

        # ── Top KPIs ────────────────────────────────────────────
        st.markdown("<br>", unsafe_allow_html=True)
        k1, k2, k3, k4 = st.columns(4)
        total_customers = len(cu)
        top_tier_share = (cu["loyalty_tier"].isin(["Gold", "Platinum"]).mean() * 100) \
            if "loyalty_tier" in cu.columns else None
        avg_spend = cu["total_spend_lkr"].mean() if "total_spend_lkr" in cu.columns else None
        avg_visits = cu["visit_frequency"].mean() if "visit_frequency" in cu.columns else None

        for col, (lbl, val) in zip([k1, k2, k3, k4], [
            ("Total Customers", f"{total_customers:,}"),
            ("Gold/Platinum Share", f"{top_tier_share:.1f}%" if top_tier_share is not None else "—"),
            ("Avg Spend (LKR)", f"{avg_spend:,.0f}" if avg_spend is not None else "—"),
            ("Avg Visit Frequency", f"{avg_visits:.1f}" if avg_visits is not None else "—"),
        ]):
            with col:
                st.markdown(f"""<div class="kpi-card">
                    <div class="kpi-label">{lbl}</div>
                    <div class="kpi-value" style="font-size:1.3rem">{val}</div>
                </div>""", unsafe_allow_html=True)

        st.markdown("<br>", unsafe_allow_html=True)

        # ── New vs Returning classification ─────────────────────
        has_join = "join_date" in cu.columns
        has_visits = "visit_frequency" in cu.columns
        if has_join or has_visits:
            st.markdown('<div class="sec-hdr">🆕 New vs. Returning Customers</div>', unsafe_allow_html=True)

            cu_work = cu.copy()
            if has_join:
                cu_work["join_date"] = pd.to_datetime(cu_work["join_date"], errors="coerce")
                reference_date = cu_work["join_date"].max()
                days_since_join = (reference_date - cu_work["join_date"]).dt.days
                new_by_join = days_since_join <= 90
            else:
                new_by_join = pd.Series(False, index=cu_work.index)

            if has_visits:
                new_by_visits = cu_work["visit_frequency"] <= 1
            else:
                new_by_visits = pd.Series(False, index=cu_work.index)

            cu_work["customer_status"] = (new_by_join | new_by_visits).map({True: "New", False: "Returning"})

            nc1, nc2 = st.columns([1, 2])
            with nc1:
                status_counts = cu_work["customer_status"].value_counts()
                new_pct = status_counts.get("New", 0) / len(cu_work) * 100
                st.markdown(f"""<div class="kpi-card">
                    <div class="kpi-label">New Customers</div>
                    <div class="kpi-value" style="font-size:1.3rem">{status_counts.get('New', 0):,} ({new_pct:.1f}%)</div>
                    <div class="kpi-delta">joined within 90 days or 1 visit</div>
                </div>""", unsafe_allow_html=True)
            with nc2:
                st.pyplot(make_bar(status_counts, "#7AA6C2", "Customer Base: New vs Returning", figsize=(6, 2.6)))

            st.caption("ℹ️ 'New' = joined within the last 90 days, or has only 1 recorded visit so far. Adjust this rule as your definition evolves.")
            st.markdown("<br>", unsafe_allow_html=True)

        # ── Purchase Intent Score ────────────────────────────────
        intent_inputs = ["days_since_last_purchase", "visit_frequency", "total_spend_lkr"]
        if all(c in cu.columns for c in intent_inputs):
            st.markdown('<div class="sec-hdr">🎯 Purchase Intent Score</div>', unsafe_allow_html=True)
            st.caption("A simple recency + frequency + spend score estimating how likely a customer is to purchase soon.")

            ci = cu.copy()
            max_days = ci["days_since_last_purchase"].max() or 1
            max_visits = ci["visit_frequency"].max() or 1
            max_spend = ci["total_spend_lkr"].max() or 1

            recency_score = (1 - (ci["days_since_last_purchase"] / max_days)).clip(0, 1) * 100
            frequency_score = (ci["visit_frequency"] / max_visits).clip(0, 1) * 100
            monetary_score = (ci["total_spend_lkr"] / max_spend).clip(0, 1) * 100

            ci["intent_score"] = (recency_score * 0.4 + frequency_score * 0.3 + monetary_score * 0.3).round(1)

            def bucket(score):
                if score >= 66: return "High"
                if score >= 33: return "Medium"
                return "Low"
            ci["intent_bucket"] = ci["intent_score"].apply(bucket)

            ic1, ic2 = st.columns(2)
            with ic1:
                bucket_counts = ci["intent_bucket"].value_counts().reindex(["High", "Medium", "Low"]).dropna()
                st.pyplot(make_bar(bucket_counts, "#4A7C59", "Customers by Purchase Intent"))
            with ic2:
                avg_intent = ci["intent_score"].mean()
                st.markdown(f"""<div class="kpi-card" style="margin-bottom:10px">
                    <div class="kpi-label">Avg Intent Score</div>
                    <div class="kpi-value" style="font-size:1.5rem">{avg_intent:.1f}/100</div>
                </div>""", unsafe_allow_html=True)
                high_intent_n = (ci["intent_bucket"] == "High").sum()
                st.markdown(f"""<div class="kpi-card">
                    <div class="kpi-label">High-Intent Customers</div>
                    <div class="kpi-value" style="font-size:1.5rem">{high_intent_n:,}</div>
                    <div class="kpi-delta">good targets for active promotion</div>
                </div>""", unsafe_allow_html=True)

            st.markdown("<br>", unsafe_allow_html=True)
            st.markdown("**Top 10 Highest-Intent Customers**")
            top_intent_cols = ["customer_id", "loyalty_tier", "age_group", "intent_score", "intent_bucket"]
            top_intent_cols = [c for c in top_intent_cols if c in ci.columns]
            top_intent = ci.sort_values("intent_score", ascending=False).head(10)
            st.dataframe(top_intent[top_intent_cols], use_container_width=True, hide_index=True)
            st.markdown("<br>", unsafe_allow_html=True)
        st.markdown('<div class="sec-hdr">📋 How Customers Are Segmented</div>', unsafe_allow_html=True)
        st.markdown("""
        <div class="hub-card">
            <div class="hub-title">Loyalty Tier</div>
            <div class="hub-desc">
                Customers are grouped into <b>Bronze, Silver, Gold, and Platinum</b> tiers based on
                cumulative spend and engagement. Higher tiers reflect customers with greater lifetime
                value and are prioritized for retention-focused offers (Loyalty Reward, New Arrival,
                Seasonal Sale).
            </div>
        </div>
        <div class="hub-card">
            <div class="hub-title">Age Group</div>
            <div class="hub-desc">
                Customers fall into four bands: <b>18-25, 26-34, 35-45, 46-60</b>. Younger segments
                respond more to fast, app-driven offers (BOGO, Flash Sale); older segments respond
                more to email/in-store, higher-value offers.
            </div>
        </div>
        <div class="hub-card">
            <div class="hub-title">Engagement Signals</div>
            <div class="hub-desc">
                <b>Visit frequency</b> and <b>days since last purchase</b> are used to gauge how
                active a customer currently is — high frequency + recent purchase = engaged;
                long gap since last purchase = at risk of disengaging.
            </div>
        </div>
        <div class="hub-card">
            <div class="hub-title">New vs. Returning</div>
            <div class="hub-desc">
                Customers who joined in the last 90 days, or have only made one visit so far,
                are classified as <b>New</b>. Everyone else is <b>Returning</b>. This distinction
                matters because new customers typically need onboarding-style offers, while
                returning customers respond better to loyalty-based ones.
            </div>
        </div>
        <div class="hub-card">
            <div class="hub-title">Purchase Intent Score</div>
            <div class="hub-desc">
                A 0-100 score combining <b>recency</b> (how recently they bought), <b>frequency</b>
                (how often they visit), and <b>monetary value</b> (how much they've spent) — the
                classic RFM framework. Higher scores flag customers most likely to respond well
                to an active promotion right now.
            </div>
        </div>
        """, unsafe_allow_html=True)

        st.markdown("<br>", unsafe_allow_html=True)

        # ── Segment breakdown charts ───────────────────────────
        st.markdown('<div class="sec-hdr">Segment Breakdown</div>', unsafe_allow_html=True)
        b1, b2 = st.columns(2)
        with b1:
            st.pyplot(make_bar(
                cu["loyalty_tier"].value_counts(),
                "#1A2744", "Customers by Loyalty Tier"))
        with b2:
            st.pyplot(make_bar(
                cu["age_group"].value_counts().sort_index(),
                "#D4A853", "Customers by Age Group"))

        if "preferred_category" in cu.columns:
            st.pyplot(make_bar(
                cu["preferred_category"].value_counts(),
                "#1A2744", "Customers by Preferred Category", figsize=(10, 3.2)))

        st.markdown("<br>", unsafe_allow_html=True)

        # ── At-risk customers ───────────────────────────────────
        if "days_since_last_purchase" in cu.columns:
            st.markdown('<div class="sec-hdr">⚠️ Disengagement Risk</div>', unsafe_allow_html=True)
            at_risk_threshold = st.slider(
                "Flag customers inactive for more than (days)", 30, 180, 60, step=10)
            at_risk = cu[cu["days_since_last_purchase"] > at_risk_threshold]
            st.warning(f"**{len(at_risk):,} customers** ({len(at_risk)/total_customers*100:.1f}%) "
                       f"haven't purchased in over {at_risk_threshold} days.")

            if not at_risk.empty and "loyalty_tier" in at_risk.columns:
                tier_counts = at_risk["loyalty_tier"].value_counts()
                st.pyplot(make_bar(
                    tier_counts,
                    "#B4543A", f"At-Risk Customers by Loyalty Tier (>{at_risk_threshold} days inactive)"))
                if len(tier_counts) == 1:
                    st.caption(f"ℹ️ All at-risk customers at this threshold belong to the "
                               f"**{tier_counts.index[0]}** tier — worth noting for retention targeting.")

            st.markdown("<br>", unsafe_allow_html=True)

        # ── Top value customers table ───────────────────────────
        if "total_spend_lkr" in cu.columns:
            st.markdown('<div class="sec-hdr">💎 Top Customers by Value</div>', unsafe_allow_html=True)
            display_cols = ["customer_id", "loyalty_tier", "age_group", "gender", "total_spend_lkr"]
            display_cols = [c for c in display_cols if c in cu.columns]
            if "visit_frequency" in cu.columns:
                display_cols.append("visit_frequency")
            top_customers = cu.sort_values("total_spend_lkr", ascending=False).head(15)
            st.dataframe(top_customers[display_cols], use_container_width=True, hide_index=True)
            st.markdown("<br>", unsafe_allow_html=True)

        # ── Segment-to-offer affinity (why the recommender picks what it picks) ──
        if ca is not None and "offer_type" in ca.columns and "redeemed" in ca.columns and "loyalty_tier" in cu.columns:
            st.markdown('<div class="sec-hdr">🎯 Why Segments Get the Offers They Get</div>', unsafe_allow_html=True)
            st.caption("This is the pattern the recommendation model learns from — which segments respond best to which offers.")

            merged = ca.merge(cu[["customer_id", "loyalty_tier"]], on="customer_id", how="left")
            pivot = merged.pivot_table(
                values="redeemed", index="loyalty_tier", columns="offer_type", aggfunc="mean"
            ) * 100

            fig, ax = plt.subplots(figsize=(10, 3.5))
            fig.patch.set_facecolor('#FFFFFF')
            im = ax.imshow(pivot.values, cmap="YlOrBr", aspect="auto")
            ax.set_xticks(range(len(pivot.columns)))
            ax.set_yticks(range(len(pivot.index)))
            ax.set_xticklabels(pivot.columns, rotation=25, ha='right', fontsize=9)
            ax.set_yticklabels(pivot.index, fontsize=9)
            for i in range(len(pivot.index)):
                for j in range(len(pivot.columns)):
                    val = pivot.values[i, j]
                    if not pd.isna(val):
                        ax.text(j, i, f"{val:.0f}%", ha="center", va="center",
                                fontsize=9, color="white" if val > 40 else "#1A2744")
            plt.colorbar(im, ax=ax, label="Redemption Rate %")
            ax.set_title("Redemption Rate % by Loyalty Tier & Offer Type",
                         fontsize=11, fontweight='bold', color='#1A2744', pad=10)
            plt.tight_layout()
            st.pyplot(fig)