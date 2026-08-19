import streamlit as st
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Sets the browser tab title, icon, and layout for the dashboard
st.set_page_config(
    page_title="Personalized Marketing Intelligence",
    page_icon="🛍️",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# CSS styles 
from shared.styles import inject_styles
from shared.state  import init_state

inject_styles()
init_state()

#Header - tiles and the subtitles 
st.markdown("""
<div class="dash-header">
    <p class="dash-title">🛍️ Personalized Marketing Intelligence</p>
    <p class="dash-sub">Promotion Performance &nbsp;|&nbsp; AI Recommendations &nbsp;|&nbsp; Poster Generation</p>
</div>
""", unsafe_allow_html=True)

#Components in the dashboard 
from components import hub, upload, promo_performance, promo_recommender, promo_attributes, poster_generator, customer_intelligence

# 7 tabs across the top of the dashboard
t0, t1, t2, t3, t4, t5, t6 = st.tabs([
    "🏠 Hub Overview",
    "📤 Upload Data",
    "👥 Customer Intelligence",
    "📊 Promotion Performance",
    "🤖 Promotion Recommender",
    "⚙️ Promo Attributes",
    "🎨 Poster Generator",
])

#rendering the header
hub.render(t0)
upload.render(t1)
customer_intelligence.render(t2)
promo_performance.render(t3)
promo_recommender.render(t4)
promo_attributes.render(t5)
poster_generator.render(t6)