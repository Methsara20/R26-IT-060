import os
from dotenv import load_dotenv

# Load variables from .env
load_dotenv()


# ==========================================================
# FIREBASE
# ==========================================================

FIREBASE_KEY_PATH = os.getenv(
    "FIREBASE_KEY_PATH",
    "app/config/firebase_key.json",
)


# ==========================================================
# GEMINI
# ==========================================================

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")


# ==========================================================
# APP
# ==========================================================

APP_NAME = os.getenv(
    "APP_NAME",
    "Smart Inventory AI Service",
)

APP_VERSION = os.getenv(
    "APP_VERSION",
    "2.0.0",
)


# ==========================================================
# PRODUCT IMAGES
# ==========================================================

PRODUCT_IMAGE_BASE_URL = os.getenv(
    "PRODUCT_IMAGE_BASE_URL",
    "https://Methsara20.github.io/R26-IT-060/product_images",
)


# ==========================================================
# GROQ - Manager Chatbot
# ==========================================================

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

GROQ_MODEL = os.getenv(
    "GROQ_MODEL",
    "qwen/qwen3.6-27b",
)

GROQ_FALLBACK_MODEL_1 = os.getenv(
    "GROQ_FALLBACK_MODEL_1",
    "openai/gpt-oss-20b",
)

GROQ_FALLBACK_MODEL_2 = os.getenv(
    "GROQ_FALLBACK_MODEL_2",
    "openai/gpt-oss-120b",
)

GROQ_MODELS = [
    GROQ_MODEL,
    GROQ_FALLBACK_MODEL_1,
    GROQ_FALLBACK_MODEL_2,
]


# ==========================================================
# CONFIGURATION VALIDATION
# ==========================================================

if not GEMINI_API_KEY:
    raise RuntimeError("GEMINI_API_KEY is not configured.")

if not GROQ_API_KEY:
    raise RuntimeError("GROQ_API_KEY is not configured.")