import streamlit as st

def init_state():
    defaults = {
        "api_url":        "",
        "claude_key":     "",
        "steps":          30,
        "guidance":       8.0,
        "df_tx":          None,
        "df_cu":          None,
        "df_ca":          None,
        "df_ve":          None,
        "notifications":  [],
        "xai_open":       None,
        "poster_segment": "",
        "model_loaded":   False,
    }
    for key, val in defaults.items():
        if key not in st.session_state:
            st.session_state[key] = val
