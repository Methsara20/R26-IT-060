import streamlit as st
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')
from shared.helpers import missing_cols_error, get_xai_reasoning

CA_REQUIRED = ["offer_type", "clicked", "redeemed", "channel", "discount_pct"]

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
    plt.xticks(ha='right')
    plt.tight_layout()
    return fig

def render(tab):
    with tab:
        st.markdown('<div class="sec-hdr">Promotion Attribute Engine</div>', unsafe_allow_html=True)
        ca = st.session_state.df_ca
        cu = st.session_state.df_cu

        if missing_cols_error(ca, CA_REQUIRED, "Campaigns", "promo_attr"):
            return

        # ── Filters ───────────────────────────────────────────
        st.markdown("**🔍 Filters**")
        f1, f2 = st.columns(2)
        with f1:
            offer_filter = st.multiselect("Offer Type",
                options=ca["offer_type"].unique().tolist(),
                default=ca["offer_type"].unique().tolist(),
                key="attr_offer")
        with f2:
            channel_filter = st.multiselect("Channel",
                options=ca["channel"].unique().tolist(),
                default=ca["channel"].unique().tolist(),
                key="attr_channel")

        filtered = ca[
            (ca["offer_type"].isin(offer_filter)) &
            (ca["channel"].isin(channel_filter))
        ].copy()

        if filtered.empty:
            st.warning("No data matches the selected filters.")
            return

        st.markdown("<br>", unsafe_allow_html=True)

        # ── Optimal Discount Analysis ─────────────────────────
        st.markdown('<div class="sec-hdr">Optimal Discount Level Analysis</div>', unsafe_allow_html=True)
        d1, d2 = st.columns(2)
        with d1:
            st.pyplot(make_bar(
                filtered.groupby("discount_pct")["redeemed"].mean()*100,
                "#1A2744", "Redemption Rate by Discount Level (%)", ylabel="%"))
        with d2:
            st.pyplot(make_bar(
                filtered.groupby("discount_pct")["clicked"].mean()*100,
                "#D4A853", "CTR by Discount Level (%)", ylabel="%"))

        st.markdown("<br>", unsafe_allow_html=True)

        # ── Offer Type Attributes ─────────────────────────────
        st.markdown('<div class="sec-hdr">Offer Type Performance Attributes</div>', unsafe_allow_html=True)

        offer_stats = filtered.groupby("offer_type").agg(
            campaigns=("redeemed", "count"),
            avg_ctr=("clicked", "mean"),
            avg_redemption=("redeemed", "mean"),
            avg_revenue=("revenue_after_lkr", "mean") if "revenue_after_lkr" in filtered.columns else ("redeemed", "mean"),
            avg_discount=("discount_pct", "mean")
        ).round(3).reset_index()

        avg_ctr_pct       = (avg_stats := offer_stats.copy())["avg_ctr"] * 100
        offer_stats["avg_ctr_%"]        = (offer_stats["avg_ctr"] * 100).round(1)
        offer_stats["avg_redemption_%"] = (offer_stats["avg_redemption"] * 100).round(1)
        offer_stats["avg_discount_%"]   = offer_stats["avg_discount"].round(1)

        display_cols = ["offer_type", "campaigns", "avg_ctr_%", "avg_redemption_%", "avg_discount_%"]
        if "revenue_after_lkr" in filtered.columns:
            offer_stats["avg_revenue_lkr"] = offer_stats["avg_revenue"].round(0)
            display_cols.append("avg_revenue_lkr")

        st.dataframe(offer_stats[display_cols], use_container_width=True, hide_index=True)

        st.markdown("<br>", unsafe_allow_html=True)

        # ── Channel + Offer Heatmap ───────────────────────────
        st.markdown('<div class="sec-hdr">Channel × Offer Redemption Matrix</div>', unsafe_allow_html=True)
        pivot = filtered.pivot_table(
            values="redeemed", index="channel",
            columns="offer_type", aggfunc="mean"
        ) * 100

        fig, ax = plt.subplots(figsize=(10, 3.5))
        fig.patch.set_facecolor('#FFFFFF')
        im = ax.imshow(pivot.values, cmap="YlOrBr", aspect="auto")
        ax.set_xticks(range(len(pivot.columns)))
        ax.set_yticks(range(len(pivot.index)))
        ax.set_xticklabels(pivot.columns, rotation=35, ha='right', fontsize=9)
        ax.set_yticklabels(pivot.index, fontsize=9)
        for i in range(len(pivot.index)):
            for j in range(len(pivot.columns)):
                val = pivot.values[i, j]
                ax.text(j, i, f"{val:.1f}%", ha="center", va="center",
                        fontsize=9, color="white" if val > 50 else "#1A2744")
        plt.colorbar(im, ax=ax, label="Redemption Rate %")
        ax.set_title("Redemption Rate % by Channel & Offer Type",
                     fontsize=11, fontweight='bold', color='#1A2744', pad=10)
        plt.tight_layout()
        st.pyplot(fig)

        st.markdown("<br>", unsafe_allow_html=True)

        # ── Segment Attributes if customers loaded ────────────
        if cu is not None and all(c in cu.columns for c in ["customer_id", "age_group", "gender", "loyalty_tier"]):
            st.markdown('<div class="sec-hdr">Segment Promotion Preferences</div>', unsafe_allow_html=True)

            merged = filtered.merge(
                cu[["customer_id", "age_group", "gender", "loyalty_tier"]],
                on="customer_id", how="left"
            ).dropna(subset=["age_group", "gender"])

            seg_f1, seg_f2 = st.columns(2)
            with seg_f1:
                age_sel = st.selectbox("Select Age Group", merged["age_group"].dropna().unique(), key="attr_age_sel")
            with seg_f2:
                gen_sel = st.selectbox("Select Gender", merged["gender"].unique(), key="attr_gen_sel")

            seg_data = merged[(merged["age_group"] == age_sel) & (merged["gender"] == gen_sel)]

            if not seg_data.empty:
                sa1, sa2 = st.columns(2)
                with sa1:
                    st.pyplot(make_bar(
                        seg_data.groupby("offer_type")["redeemed"].mean()*100,
                        "#1A2744",
                        f"Best Offers for {gen_sel} | {age_sel} (%)", ylabel="%"))
                with sa2:
                    st.pyplot(make_bar(
                        seg_data.groupby("channel")["redeemed"].mean()*100,
                        "#D4A853",
                        f"Best Channels for {gen_sel} | {age_sel} (%)", ylabel="%"))

        # ── XAI ───────────────────────────────────────────────
        st.markdown("<br>", unsafe_allow_html=True)
        best_discount = filtered.groupby("discount_pct")["redeemed"].mean().idxmax()
        best_offer    = filtered.groupby("offer_type")["redeemed"].mean().idxmax()

        col_ev, col_btn = st.columns([3, 1])
        with col_ev:
            st.markdown(f"""<div class="hub-card">
                <div class="hub-title">📊 Attribute Summary</div>
                <div class="hub-desc">
                    Best offer type: <b>{best_offer}</b><br>
                    Optimal discount level: <b>{best_discount}% OFF</b><br>
                    Total campaigns analysed: <b>{len(filtered):,}</b>
                </div></div>""", unsafe_allow_html=True)
        with col_btn:
            if st.button("🤖 AI Insight", use_container_width=True, key="xai_attr"):
                st.session_state.xai_open = "promo_attr"

        if st.session_state.xai_open == "promo_attr":
            evidence = (f"Best offer type is {best_offer}. "
                        f"Optimal discount level is {best_discount}%. "
                        f"Analysis based on {len(filtered)} campaigns.")
            with st.spinner("Generating insight..."):
                reasoning = get_xai_reasoning("Promotion attributes", evidence, st.session_state.claude_key)
            st.markdown(f"""<div class="xai-panel">
                <div style="font-weight:700;color:#1A2744;margin-bottom:8px">🤖 AI Insight</div>
                <div style="color:#444;font-size:13px;line-height:1.6">{reasoning}</div>
            </div>""", unsafe_allow_html=True)
