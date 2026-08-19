"""
backend/poster_service.py
Generates promotional posters via a Colab-hosted Stable Diffusion instance
(same approach as the original Streamlit Poster Generator), exposed here for
the FastAPI backend / Flutter frontend.

SWAPPABLE BY DESIGN: only `generate_poster_image()` talks to the actual image
provider. To switch to Nano Banana (Gemini) or another provider later, replace
just this function's internals — main.py and the Flutter screen don't need
to change, since they just call generate_poster_image() and expect back
(image_b64, error).
"""

import requests
import base64

NGROK_HEADERS = {"ngrok-skip-browser-warning": "true"}


def build_prompt_payload(gender, age_group, offer_type, discount_value, season,
                          items, palette, style, brand_name, steps=30, guidance=8.0):
    """Builds the request payload the Colab Stable Diffusion endpoint expects."""
    return {
        "gender": gender.lower(),
        "age_group": age_group,
        "offer_type": offer_type,
        "discount": discount_value,
        "season": season,
        "items": ", ".join(items) if isinstance(items, list) else items,
        "palette": palette.split("—")[0].strip(),
        "style": style,
        "brand": brand_name,
        "steps": steps,
        "guidance": guidance,
    }


def check_colab_health(api_url: str):
    """Checks whether the Colab endpoint is reachable. Returns (ok, message)."""
    try:
        resp = requests.get(f"{api_url.rstrip('/')}/health", headers=NGROK_HEADERS, timeout=5, verify=False)
        if resp.status_code == 200:
            return True, "Connected"
        return False, f"Reached but /health returned {resp.status_code}"
    except Exception as e:
        return False, f"Could not reach Colab endpoint: {e}"


def generate_poster_image(api_url: str, payload: dict):
    """
    Calls the Colab Stable Diffusion endpoint to generate a poster image.
    Returns (image_b64, error). error is None on success.
    """
    if not api_url:
        return None, "No Colab ngrok URL provided."

    try:
        response = requests.post(
            f"{api_url.rstrip('/')}/generate",
            json=payload,
            headers=NGROK_HEADERS,
            timeout=180,
            verify=False,
        )
        response.raise_for_status()
        image_b64 = response.json().get("image_b64")
        if not image_b64:
            return None, "No image returned by the Colab endpoint."
        return image_b64, None
    except requests.exceptions.Timeout:
        return None, "Request timed out — Colab may be slow or disconnected."
    except requests.exceptions.ConnectionError:
        return None, "Could not connect. Check that your Colab notebook is running and the ngrok URL is current."
    except Exception as e:
        return None, f"Error generating poster: {e}"