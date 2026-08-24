import os
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from google import genai

from app.services.llm_manager import llm_manager

from app.firebase_config import db
from app.services.rag_service import retrieve_relevant_products
from app.services.body_measurement_service import predict_body_measurements
from app.services.profile_service import get_size

router = APIRouter()

class StylistChatRequest(BaseModel):
    customer_id: str
    message: str

@router.post("/chat")
def stylist_chat(data: StylistChatRequest):
    from app.services.cache_service import profiles_cache
    
    # 1. Fetch the user's profile to get their measurements
    user_data = profiles_cache.get(data.customer_id)
    if not user_data:
        user_doc = db.collection("profiles").document(data.customer_id).get()
        if user_doc.exists:
            user_data = user_doc.to_dict()
            profiles_cache.set(data.customer_id, user_data)
        else:
            user_data = {}
    
    predicted_measurements = {}
    predicted_size = "Unknown"
    
    if user_data:
        height = user_data.get("height")
        weight = user_data.get("weight")
        gender = user_data.get("gender", "Unisex")
        
        if height and weight:
            # We use the existing ML service to get the body context
            try:
                measurements = predict_body_measurements(height, weight, gender)
                predicted_measurements = {
                    "shoulder_width": f"{measurements[0]:.1f} cm",
                    "waist_circumference": f"{measurements[1]:.1f} cm",
                    "leg_length": f"{measurements[2]:.1f} cm"
                }
                predicted_size = get_size(height, weight)
            except Exception as e:
                print(f"Failed to get ML measurements for RAG: {e}")

    # 2. Retrieve relevant products from ChromaDB using LangChain
    relevant_products = retrieve_relevant_products(data.message, top_k=3)
    
    if not relevant_products:
        return {"response": "I couldn't find any items matching your request in our catalog."}

    # 3. Construct the prompt for the LLM
    product_context = "\n\n".join([
        f"Product Name: {p['product_name']}\nBrand: {p['brand']}\nPrice: LKR {float(p['price']):.2f}\nDetails: {p['description']}"
        for p in relevant_products
    ])
    
    system_prompt = f"""
    You are an expert Virtual Stylist for an Omni-Retail clothing brand. 
    You are talking to a customer who has asked a question.
    
    Here is the customer's predicted physical profile:
    - Recommended Base Size: {predicted_size}
    - Measurements: {predicted_measurements}
    
    Here are the top products from our catalog that match their query:
    {product_context}
    
    Your goal: Answer the customer's question thoughtfully. Use the product descriptions (like fabric type and fit) 
    and cross-reference them with the customer's measurements to give personalized advice on sizing and styling. 
    When recommending a specific product, ALWAYS mention its price. Format the price exactly like this: "LKR 1374.37".
    Keep your response friendly, concise, and helpful. Do not mention that you are an AI or using a database.
    
    IMPORTANT: Provide your response in plain text ONLY. Do NOT use any Markdown formatting, bold text (**), asterisks (*), or hashtags (#). Use natural paragraphs and spacing instead.
    """
    
    try:
        # 4. Generate response using load-balanced Gemini client
        prompt = f"{system_prompt}\n\nUSER QUESTION: {data.message}"
        response_text = llm_manager.generate_content_with_fallback(prompt)

        return {
            "response": response_text,
            "relevant_products": relevant_products,
            "used_size": predicted_size
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"LLM generation failed: {str(e)}")
