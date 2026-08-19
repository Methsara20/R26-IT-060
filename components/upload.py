import streamlit as st
import pandas as pd
from shared.cleaner import clean_csv
from shared.firebase_client import save_csv_to_firebase, load_latest_csv_from_firebase, get_upload_history
from components.hub import generate_notifications


def render(tab):
    with tab:
        st.markdown('<div class="sec-hdr">Upload CSV Files</div>', unsafe_allow_html=True)
        st.caption("Files are automatically cleaned — duplicates removed, PII anonymized, formats fixed — then saved to Firebase.")

        # ── Auto-load latest saved data on first visit this session ──
        if not st.session_state.get("firebase_autoload_done", False):
            with st.spinner("Checking Firebase for previously saved data..."):
                if st.session_state.df_ca is None:
                    loaded = load_latest_csv_from_firebase("campaigns")
                    if loaded is not None:
                        st.session_state.df_ca = loaded
                if st.session_state.df_cu is None:
                    loaded = load_latest_csv_from_firebase("customers")
                    if loaded is not None:
                        st.session_state.df_cu = loaded
                if st.session_state.df_tx is None:
                    loaded = load_latest_csv_from_firebase("transactions")
                    if loaded is not None:
                        st.session_state.df_tx = loaded
            st.session_state.firebase_autoload_done = True
            if st.session_state.df_ca is not None or st.session_state.df_cu is not None:
                st.success("✅ Restored your most recent data from Firebase.")

        with st.expander("ℹ️ Expected column names per file", expanded=False):
            st.markdown("""
            | File | Required columns |
            |------|-----------------|
            | **Campaigns** *(primary)* | `campaign_id`, `customer_id`, `offer_type`, `channel`, `clicked`, `redeemed`, `treatment`, `revenue_after_lkr`, `discount_pct` |
            | **Customers** *(recommended)* | `customer_id`, `age_group`, `gender`, `loyalty_tier` |
            | **Transactions** *(optional)* | `transaction_id`, `customer_id`, `date`, `product`, `category`, `store_id`, `channel`, `total_amount_lkr` |
            """)

        u1, u2 = st.columns(2)
        with u1:
            st.markdown("**📣 Campaigns** *(primary — required)*")
            ca_file = st.file_uploader("skyhigh_campaigns.csv", type="csv", key="ca")
            if ca_file:
                df_raw = pd.read_csv(ca_file)
                df_clean, report = clean_csv(df_raw, "campaigns")
                st.session_state.df_ca = df_clean
                st.markdown('<div class="clean-report">' + "<br>".join(report) + "</div>", unsafe_allow_html=True)
                st.caption(f"Columns detected: {', '.join(df_clean.columns.tolist())}")
                st.dataframe(df_clean.head(3), use_container_width=True, hide_index=True)
                if save_csv_to_firebase(df_clean, "campaigns"):
                    st.success("☁️ Saved to Firebase")

            st.markdown("**👥 Customers** *(recommended)*")
            cu_file = st.file_uploader("skyhigh_customers.csv", type="csv", key="cu")
            if cu_file:
                df_raw = pd.read_csv(cu_file)
                df_clean, report = clean_csv(df_raw, "customers")
                st.session_state.df_cu = df_clean
                st.markdown('<div class="clean-report">' + "<br>".join(report) + "</div>", unsafe_allow_html=True)
                st.caption(f"Columns detected: {', '.join(df_clean.columns.tolist())}")
                st.dataframe(df_clean.head(3), use_container_width=True, hide_index=True)
                if save_csv_to_firebase(df_clean, "customers"):
                    st.success("☁️ Saved to Firebase")

        with u2:
            st.markdown("**📦 Transactions** *(optional)*")
            tx_file = st.file_uploader("skyhigh_transactions.csv", type="csv", key="tx")
            if tx_file:
                df_raw = pd.read_csv(tx_file)
                df_clean, report = clean_csv(df_raw, "transactions")
                st.session_state.df_tx = df_clean
                st.markdown('<div class="clean-report">' + "<br>".join(report) + "</div>", unsafe_allow_html=True)
                st.caption(f"Columns detected: {', '.join(df_clean.columns.tolist())}")
                st.dataframe(df_clean.head(3), use_container_width=True, hide_index=True)
                if save_csv_to_firebase(df_clean, "transactions"):
                    st.success("☁️ Saved to Firebase")

        if st.session_state.df_ca is not None:
            st.session_state.notifications = generate_notifications(
                st.session_state.df_ca, st.session_state.df_cu)

        # ── Upload history ────────────────────────────────────
        st.markdown("<br>", unsafe_allow_html=True)
        with st.expander("🕓 Upload History (Firebase)", expanded=False):
            history = get_upload_history()
            if not history:
                st.caption("No upload history yet, or Firebase isn't connected.")
            else:
                hist_df = pd.DataFrame(history)
                display_cols = [c for c in ["file_type", "uploaded_at", "row_count"] if c in hist_df.columns]
                st.dataframe(hist_df[display_cols].sort_values("uploaded_at", ascending=False),
                             use_container_width=True, hide_index=True)