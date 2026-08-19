import streamlit as st
import requests

# ── Safe column helpers ───────────────────────────────────────

def safe_col(df, col):
    """Return True if column exists in dataframe."""
    return df is not None and col in df.columns


def get_val(df, col, agg="mean", fallback="—"):
    """Safely compute an aggregation on a column."""
    if not safe_col(df, col):
        return fallback
    try:
        if agg == "mean":   return df[col].mean()
        if agg == "sum":    return df[col].sum()
        if agg == "max":    return df[col].max()
        if agg == "idxmax": return df[col].value_counts().idxmax()
    except Exception:
        return fallback


def missing_cols_error(df, required_cols, file_label, tab_name):
    """
    Show a styled error card + back button when required columns are missing.
    Returns True if there IS a problem (caller should stop rendering).
    """
    if df is None:
        st.markdown(f"""
        <div class="error-card">
            <div class="error-card-title">⚠️ No {file_label} data uploaded</div>
            <div class="error-card-body">
                Please upload your <b>{file_label}</b> CSV file in the
                <b>📤 Upload Data</b> tab first, then come back here.
            </div>
        </div>""", unsafe_allow_html=True)
        if st.button("← Go to Upload Data", key=f"back_none_{tab_name}"):
            st.info("👆 Click the **📤 Upload Data** tab above to upload your files.")
        return True

    missing = [c for c in required_cols if c not in df.columns]
    if not missing:
        return False

    found_cols = "".join(f'<span class="col-pill">{c}</span>' for c in df.columns.tolist())
    need_cols  = "".join(f'<span class="col-pill">{c}</span>' for c in missing)

    st.markdown(f"""
    <div class="error-card">
        <div class="error-card-title">❌ Column mismatch in your {file_label} file</div>
        <div class="error-card-body">
            The dashboard expected these columns but could not find them:<br>
            {need_cols}<br><br>
            <b>Columns found in your uploaded file:</b><br>
            {found_cols}<br><br>
            Please go back to <b>📤 Upload Data</b>, remove the current file,
            and re-upload a corrected CSV with the correct column names.
        </div>
    </div>""", unsafe_allow_html=True)
    if st.button("← Back to Upload Data", key=f"back_err_{tab_name}"):
        st.info("👆 Click the **📤 Upload Data** tab above to re-upload your file.")
    return True


# ── XAI Reasoning via Gemini ──────────────────────────────────

def get_xai_reasoning(segment, evidence, gemini_key):
    if not gemini_key:
        return "Add your Gemini API key in the 🎨 Poster Generator tab to get AI-generated reasoning."
    try:
        prompt = (
            f"You are a retail analytics AI. Explain in 3-4 clear sentences why this customer segment "
            f"is predicted to respond well to promotions. Use the evidence provided. Be specific with numbers. No bullet points.\n\n"
            f"Segment: {segment}\nEvidence: {evidence}"
        )
        response = requests.post(
            f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={gemini_key}",
            headers={"Content-Type": "application/json"},
            json={"contents": [{"parts": [{"text": prompt}]}]},
            timeout=30,
            verify=False
        )
        return response.json()["candidates"][0]["content"]["parts"][0]["text"]
    except Exception as e:
        return f"Could not generate AI summary: {str(e)}"
