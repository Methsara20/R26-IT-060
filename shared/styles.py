import streamlit as st

def inject_styles():
    st.markdown("""
<style>
    html, body, [class*="css"] { font-family: 'Georgia', serif; }
    .stApp { background-color: #F5F0E8; }
    .dash-header {
        background: #1A2744; padding: 1.4rem 2rem;
        border-radius: 12px; margin-bottom: 1.2rem;
        border: 1px solid #D4A853;
    }
    .dash-title { color: #D4A853; font-size: 1.7rem; font-weight: 700; margin: 0; letter-spacing: 1px; }
    .dash-sub   { color: #C4A882; font-size: 0.82rem; margin: 2px 0 0; }
    .stTabs [data-baseweb="tab-list"] { background: #EDE5D0; border-radius: 10px; padding: 4px; gap: 4px; }
    .stTabs [data-baseweb="tab"] { background: transparent; border-radius: 8px; color: #1A2744; font-weight: 500; font-size: 13px; padding: 8px 14px; }
    .stTabs [aria-selected="true"] { background: #1A2744 !important; color: #D4A853 !important; }
    .stTabs [data-baseweb="tab-border"] { display: none; }
    .sec-hdr { background: #1A2744; color: #D4A853; padding: 7px 14px; border-radius: 8px; font-size: 13px; font-weight: 600; letter-spacing: 1px; margin-bottom: 12px; text-transform: uppercase; }
    .kpi-card { background: white; border: 1px solid #D4C4A0; border-radius: 10px; padding: 1rem; text-align: center; }
    .kpi-label { font-size: 11px; color: #8B6914; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 4px; }
    .kpi-value { font-size: 1.8rem; font-weight: 700; color: #1A2744; }
    .kpi-delta { font-size: 11px; color: #4A7C59; margin-top: 2px; }
    .hub-card { background: white; border: 1px solid #D4C4A0; border-radius: 12px; padding: 1rem 1.2rem; margin-bottom: 10px; }
    .hub-title { color: #1A2744; font-weight: 700; font-size: 14px; margin-bottom: 4px; }
    .hub-desc  { color: #6B5B3E; font-size: 12px; }
    .notif-card { background: #FFF8E7; border: 2px solid #D4A853; border-radius: 10px; padding: 12px 16px; margin-bottom: 10px; }
    .notif-title { color: #1A2744; font-weight: 700; font-size: 14px; }
    .notif-desc { color: #6B5B3E; font-size: 12px; margin-top: 4px; }
    .clean-report { background: #F0F7F0; border: 1px solid #4A7C59; border-radius: 10px; padding: 12px 16px; margin-bottom: 12px; }
    .xai-panel { background: white; border: 2px solid #D4A853; border-radius: 12px; padding: 1.2rem; margin-top: 12px; }
    .stButton > button { background: #1A2744; color: #D4A853; border: 1px solid #D4A853; border-radius: 8px; font-weight: 600; }
    .stButton > button:hover { background: #D4A853; color: #1A2744; }
    .gauge-wrap { background: white; border: 1px solid #D4C4A0; border-radius: 10px; padding: 1rem; text-align: center; }
    .gauge-val { font-size: 2rem; font-weight: 700; color: #1A2744; }
    .gauge-lbl { font-size: 11px; color: #8B6914; text-transform: uppercase; letter-spacing: 1px; }
    .ngrok-box { background: #1A2744; border: 2px solid #D4A853; border-radius: 10px; padding: 12px 14px; margin-bottom: 8px; }
    .ngrok-status-ok  { color: #4A7C59; font-size: 12px; font-weight: 600; margin-top: 6px; }
    .ngrok-status-off { color: #C8952A; font-size: 12px; font-weight: 600; margin-top: 6px; }
    .error-card { background: #FFF0F0; border: 2px solid #C0392B; border-radius: 12px; padding: 16px 20px; margin-bottom: 16px; }
    .error-card-title { color: #C0392B; font-weight: 700; font-size: 15px; margin-bottom: 8px; }
    .error-card-body  { color: #5D2D2D; font-size: 13px; line-height: 1.7; }
    .col-pill { display: inline-block; background: #F5F0E8; border: 1px solid #D4A853; border-radius: 6px; padding: 2px 8px; margin: 2px 3px; font-family: monospace; font-size: 12px; color: #1A2744; }
</style>
""", unsafe_allow_html=True)
