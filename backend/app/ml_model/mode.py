from google import genai

client = genai.Client(
    api_key="AIzaSyAQ.Ab8RN6KXQUr_ZiGEnVoaYCV7zlmI7Mnub0wDr19w-w5Z_ZWeZw"
)

response = client.models.generate_content(
    model="gemini-1.5-flash",
    contents="Hello"
)

print(response.text)