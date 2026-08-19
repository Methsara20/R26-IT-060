import streamlit as st
import requests
import base64
import io
import os
from PIL import Image
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ── Nano Banana (Gemini image generation) config ──────────────
# Model options:
#   "gemini-3.1-flash-image"       -> Nano Banana 2 (best all-round quality/speed/cost)
#   "gemini-3.1-flash-lite-image"  -> Nano Banana 2 Lite (fastest/cheapest, 1K only)
#   "gemini-3-pro-image"           -> Nano Banana Pro (highest quality, 4K, slower)
NANO_BANANA_MODEL = "gemini-3.1-flash-image"
INTERACTIONS_URL = "https://generativelanguage.googleapis.com/v1beta/interactions"


def generate_poster_image(api_key, prompt, aspect_ratio="1:1", image_size="1K"):
    """
    Calls the Gemini Interactions API (Nano Banana) to generate a poster image.
    Returns (PIL.Image, error_message). error_message is None on success.
    """
    if not api_key:
        return None, "No Gemini API key provided."

    try:
        response = requests.post(
            INTERACTIONS_URL,
            headers={
                "x-goog-api-key": api_key,
                "Content-Type": "application/json",
            },
            json={
                "model": NANO_BANANA_MODEL,
                "input": [{"type": "text", "text": prompt}],
                "response_format": {
                    "type": "image",
                    "aspect_ratio": aspect_ratio,
                    "image_size": image_size,
                },
            },
            timeout=90,
            verify=False,
        )
        response.raise_for_status()
        data = response.json()

        # The convenience field is `output_image`; fall back to manual
        # step-scanning if it's missing (e.g. interleaved responses).
        image_b64 = None
        if data.get("output_image"):
            image_b64 = data["output_image"].get("data")
        else:
            for step in data.get("steps", []):
                if step.get("type") == "model_output":
                    for block in step.get("content", []):
                        if block.get("type") == "image":
                            image_b64 = block.get("data")
                            break

        if not image_b64:
            return None, "No image returned by the model. Try rephrasing the prompt."

        img = Image.open(io.BytesIO(base64.b64decode(image_b64)))
        return img, None

    except requests.exceptions.HTTPError as e:
        status = e.response.status_code if e.response is not None else None
        detail = ""
        try:
            detail = e.response.json().get("error", {}).get("message", "")
        except Exception:
            pass

        if status == 429:
            return None, (
                "🚫 Rate limit / quota hit. Either your free daily quota for image "
                "generation ran out, or you're sending requests too fast. Check your "
                "quota at aistudio.google.com, or wait and try again."
            )
        if status in (402, 403) or "billing" in detail.lower() or "quota" in detail.lower():
            return None, (
                "💳 This looks like a billing/quota issue — your Gemini API key may need "
                "billing enabled for image generation, or your free tier doesn't cover this "
                "model. Check aistudio.google.com → your project → Billing."
            )
        if status == 400:
            return None, f"⚠️ Bad request — the prompt or settings may be invalid: {detail or str(e)}"
        if status == 401:
            return None, "🔑 Invalid API key — double check the key in secrets.toml or the input box."

        return None, f"API error ({status}): {detail or str(e)}"
    except requests.exceptions.Timeout:
        return None, "⏱️ Request timed out. The model may be under heavy load — try again."
    except Exception as e:
        return None, f"Error: {str(e)}"


def build_prompt(gender, age_group, offer_type, discount_value, season, items,
                  palette, style, brand_name):
    """Builds a descriptive text-to-image prompt from the segment/offer inputs."""
    items_str = ", ".join(items) if items else "assorted clothing items"
    return (
        f"Create a {style.lower()} retail promotional poster for a fashion brand called "
        f"'{brand_name}'. The poster advertises a '{offer_type}' offer with '{discount_value}' "
        f"prominently displayed, for the '{season}' campaign. It should visually target "
        f"{gender.lower()} customers aged {age_group}. Feature these items: {items_str}. "
        f"Use a color palette of {palette.lower()}. The brand name '{brand_name}' should "
        f"appear clearly on the poster in bold, legible text along with the discount value. "
        f"Poster layout, professional marketing design, eye-catching composition."
    )


def get_api_key():
    """
    Looks for the Gemini key in this order:
    1. .streamlit/secrets.toml -> GEMINI_API_KEY
    2. Environment variable    -> GEMINI_API_KEY
    3. Manual entry in the UI  (fallback only)
    """
    key = ""
    try:
        key = st.secrets.get("GEMINI_API_KEY", "")
    except Exception:
        # No secrets.toml file exists at all — that's fine, just fall through.
        key = ""
    if not key:
        key = os.environ.get("GEMINI_API_KEY", "")
    return key


def render(tab):
    with tab:
        st.markdown('<div class="sec-hdr">Emotion-Aware Visual Marketing Generator</div>', unsafe_allow_html=True)

        secret_key = get_api_key()

        if secret_key:
            api_key = secret_key
            st.success("✅ Gemini API key loaded automatically — ready to generate posters with Nano Banana")
        else:
            with st.expander("🔑 Gemini API Key (Nano Banana)", expanded=st.session_state.claude_key == ""):
                st.markdown("""
                <div style="background:#FFF8E7;border:1px solid #D4A853;border-radius:8px;padding:10px 12px;font-size:12px;color:#6B5B3E;margin-bottom:10px">
                    <b>No key found in secrets.toml.</b> You can either:<br>
                    1. Add <code>GEMINI_API_KEY = "..."</code> to <code>.streamlit/secrets.toml</code> and restart the app, or<br>
                    2. Paste it below just for this session.
                </div>
                """, unsafe_allow_html=True)
                new_key = st.text_input("Gemini API Key", value=st.session_state.claude_key,
                                         type="password", placeholder="AIza...")
                if new_key != st.session_state.claude_key:
                    st.session_state.claude_key = new_key
            api_key = st.session_state.claude_key
            if not api_key:
                st.warning("⚠️ Add a secrets.toml key or paste one above to enable poster generation.")

        # ── Pre-fill from notification ────────────────────────
        preset_segment = st.session_state.get("poster_segment", "")
        preset_gender  = "Female"
        preset_age     = "35-45"
        if preset_segment:
            parts = preset_segment.split(" ")
            if len(parts) == 2:
                preset_age    = parts[0]
                preset_gender = parts[1].title()

        col_form, col_prev = st.columns([1.2, 1], gap="large")
        with col_form:
            st.markdown("**👤 Customer Segment**")
            g1, g2 = st.columns(2)
            with g1:
                gender = st.selectbox("Gender", ["Female", "Male", "Non-binary"],
                    index=["Female","Male","Non-binary"].index(preset_gender) if preset_gender in ["Female","Male","Non-binary"] else 0)
            with g2:
                age_group = st.selectbox("Age group", ["18-25","26-34","35-45","46-60","60+"],
                    index=["18-25","26-34","35-45","46-60","60+"].index(preset_age) if preset_age in ["18-25","26-34","35-45","46-60","60+"] else 0)

            st.markdown("**🏷️ Offer Details**")
            o1, o2 = st.columns(2)
            with o1:
                offer_type = st.selectbox("Offer type", ["Seasonal Sale","Discount","Buy One Get One Free","Loyalty Reward","New Arrival","Flash Sale","Members Only"])
            with o2:
                discount_value = st.selectbox("Discount", ["10% OFF","20% OFF","30% OFF","40% OFF","50% OFF","60% OFF","BOGO FREE","Free Shipping"])

            season = st.selectbox("Season / Campaign", ["Summer 2026","Winter 2026","Spring 2026","Autumn 2026","Year Round","Holiday Special","Back to School","Black Friday"])

            st.markdown("**👗 Items for Sale**")
            items = st.multiselect("Select items",
                ["Dresses","Handbags","Shoes","Accessories","Jewellery","Tops & Blouses",
                 "Trousers","Coats & Jackets","Sportswear","Swimwear","Watches",
                 "Sunglasses","Perfume","Umbrellas","Suits"],
                default=["Dresses","Handbags"])

            st.markdown("**🎨 Visual Style**")
            s1, s2 = st.columns(2)
            with s1:
                palette = st.selectbox("Colour palette", ["Pastel Pink & Gold","Bold Red & Black","Ocean Blue & White","Earthy Beige & Brown","Vibrant Yellow & Purple","Midnight Navy & Gold"])
            with s2:
                style = st.selectbox("Illustration style", ["Illustrated cartoon","Watercolour illustration","Bold graphic / pop art","Flat vector design","Fashion magazine editorial","Vintage retro poster"])

            a1, a2 = st.columns(2)
            with a1:
                aspect_ratio = st.selectbox("Aspect ratio", ["1:1", "4:5", "3:4", "9:16", "16:9"], index=0)
            with a2:
                image_size = st.selectbox("Resolution", ["1K", "2K", "4K"], index=0)

            brand_name = st.text_input("Brand name", value="SkyHigh")
            generate   = st.button("✨ Generate Poster", use_container_width=True)

        with col_prev:
            st.markdown("**👁️ Preview**")
            st.markdown(f"""<div class="hub-card" style="text-align:center">
                <h3 style="color:#1A2744;margin:0 0 4px">{brand_name}</h3>
                <p style="font-size:1.5rem;font-weight:700;color:#D4A853;margin:0">{discount_value}</p>
                <p style="margin:4px 0;color:#555">{offer_type} · {season}</p>
                <hr style="border-color:#D4C4A0">
                <p style="margin:4px 0"><b>For:</b> {age_group} {gender}</p>
                <p style="margin:4px 0"><b>Items:</b> {", ".join(items) if items else "None"}</p>
                <p style="margin:4px 0"><b>Palette:</b> {palette}</p>
            </div>""", unsafe_allow_html=True)

            cu = st.session_state.df_cu
            count = 0
            if cu is not None and "age_group" in cu.columns and "gender" in cu.columns:
                count = len(cu[(cu["age_group"] == age_group) & (cu["gender"].str.lower() == gender.lower())])
                if count > 0:
                    st.info(f"📧 {count} customers in this segment will receive this poster")

            if generate:
                if not api_key:
                    st.error("❌ No Gemini API key. Paste your key in the panel above first.")
                elif not items:
                    st.error("Select at least one item.")
                else:
                    prompt = build_prompt(gender, age_group, offer_type, discount_value,
                                           season, items, palette, style, brand_name)
                    with st.spinner("Generating with Nano Banana... (5–30 seconds)"):
                        img, error = generate_poster_image(api_key, prompt, aspect_ratio, image_size)

                    if error:
                        st.error(error)
                    else:
                        st.success("✅ Poster generated!")
                        st.image(img, use_column_width=True)
                        buf = io.BytesIO()
                        img.save(buf, format="PNG")
                        st.download_button("⬇️ Download Poster", buf.getvalue(),
                                           f"poster_{gender}_{age_group}.png", "image/png")
                        if count > 0:
                            st.warning(f"📧 Ready to send to {count} customers — email feature coming soon!")

        # ── Batch generation ──────────────────────────────────
        st.divider()
        st.markdown('<div class="sec-hdr">Batch — Auto-Generate All Segments</div>', unsafe_allow_html=True)
        SEGMENTS = [
            {"gender": "Female", "age_group": "35-45", "offer_type": "Loyalty Reward", "discount_value": "30% OFF"},
            {"gender": "Male",   "age_group": "18-25", "offer_type": "New Arrival",    "discount_value": "BOGO FREE"},
            {"gender": "Female", "age_group": "26-34", "offer_type": "Seasonal Sale",  "discount_value": "50% OFF"},
            {"gender": "Male",   "age_group": "46-60", "offer_type": "Members Only",   "discount_value": "40% OFF"},
        ]
        if st.button("🚀 Generate All 4 Segments", use_container_width=True):
            if not api_key:
                st.error("❌ No Gemini API key. Paste your key in the panel above first.")
            else:
                bcols = st.columns(4)
                for i, seg in enumerate(SEGMENTS):
                    with bcols[i]:
                        st.markdown(f"**{seg['age_group']} {seg['gender']}**")
                        st.caption(f"{seg['offer_type']} · {seg['discount_value']}")
                        with st.spinner("Generating..."):
                            seg_prompt = build_prompt(
                                seg["gender"], seg["age_group"], seg["offer_type"],
                                seg["discount_value"], season,
                                items if items else ["clothing"], palette, style, brand_name
                            )
                            img, error = generate_poster_image(api_key, seg_prompt, aspect_ratio, image_size)
                        if error:
                            st.error(error)
                        else:
                            st.image(img, use_column_width=True)
                            buf = io.BytesIO()
                            img.save(buf, format="PNG")
                            st.download_button("⬇️ Download", buf.getvalue(),
                                               f"poster_{seg['gender']}_{seg['age_group']}.png",
                                               "image/png", key=f"dl_{i}")