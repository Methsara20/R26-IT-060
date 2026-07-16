# import google.generativeai as genai
#
# genai.configure(api_key="AIzaSyCHHJyYL6f86DXaSD1zQ9yJhMA9DH4xQW8")
#
# model = genai.GenerativeModel("gemini-1.5-flash")
#
# response = model.generate_content("Say hello")
#
# print(response.text)
#
from google import genai

client = genai.Client(api_key="AIzaSyCHHJyYL6f86DXaSD1zQ9yJhMA9DH4xQW8")

response = client.models.generate_content(
    model="gemini-flash-latest",  # ✅ IMPORTANT CHANGE
    contents="Say hello"
)

print(response.text)
# #
# from google import genai
#
# client = genai.Client(api_key="AIzaSyCHHJyYL6f86DXaSD1zQ9yJhMA9DH4xQW8")
#
# for m in client.models.list():
#     print(m.name)