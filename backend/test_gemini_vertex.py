import os
from google import genai

# Using Vertex AI instead of the standard Gemini API
# This uses your Google Cloud Billing credits directly
client = genai.Client(
    vertexai=True,
    project="divine-clone-495811-e4",
    location="us-central1"
)

try:
    print("Testing Gemini via Vertex AI...")
    response = client.models.generate_content(
        model="gemini-1.5-flash",
        contents="Hello"
    )
    print("Success! Response:", response.text)
except Exception as e:
    print("Error:", repr(e))
