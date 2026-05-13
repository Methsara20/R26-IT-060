import os
from dotenv import load_dotenv
from google import genai

load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")
client = genai.Client(api_key=api_key)

try:
    print("Testing Imagen...")
    response = client.models.generate_image(
        model="imagen-3.0-generate-001",
        prompt="A person wearing a blue t-shirt",
    )
    print("Success! Image generated.")
except Exception as e:
    print("Error:", repr(e))
