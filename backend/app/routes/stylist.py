import os
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services.llm_manager import llm_manager
from app.firebase_config import db
from app.services.rag_service import retrieve_relevant_products
from app.services.body_measurement_service import predict_body_measurements
from app.services.profile_service import get_size

router = APIRouter()

class StylistChatRequest(BaseModel):
    customer_id: str
    message: str

def safe_float(val, default=0.0) -> float:
    if val is None:
        return default
    try:
        return float(val)
    except (TypeError, ValueError):
        return default

@router.post("/chat")
def stylist_chat(data: StylistChatRequest):
    print(f"\n[STYLIST] New chat request from customer '{data.customer_id}'")
    print(f"[STYLIST] Message: '{data.message}'")
    
    # 1. Fetch the user's profile to get their measurements
    predicted_measurements = {}
    predicted_size = "M"
    
    try:
        email = data.customer_id.strip()
        email_lower = email.lower()
        profiles_ref = db.collection("profiles")
        docs = list(profiles_ref.where("email", "in", [email, email_lower]).limit(1).stream())
        
        if docs:
            user_data = docs[0].to_dict()
            height = user_data.get("height")
            weight = user_data.get("weight")
            gender = user_data.get("gender", "Unisex")
            
            if height and weight:
                try:
                    measurements = predict_body_measurements(float(height), float(weight), gender)
                    predicted_measurements = {
                        "shoulder_width": f"{measurements[0]:.1f} cm",
                        "waist_circumference": f"{measurements[1]:.1f} cm",
                        "leg_length": f"{measurements[2]:.1f} cm"
                    }
                    predicted_size = get_size(float(height), float(weight))
                    print(f"[STYLIST] Profile matched! Size: {predicted_size}")
                except Exception as e:
                    print(f"[STYLIST] ML prediction error: {e}")
        else:
            print("[STYLIST] No body profile found for this email.")
    except Exception as e:
        print(f"[STYLIST] Profile lookup warning: {e}")

    # 2. Retrieve relevant products from ChromaDB / RAG
    print("[STYLIST] Searching Vector Database for relevant products...")
    relevant_products = retrieve_relevant_products(data.message, top_k=3)
    
    if not relevant_products:
        return {
            "response": "I'm your Personal AI Stylist! For the best look, I recommend pairing classic denim jackets or tailored tops with versatile fitted bottoms.",
            "relevant_products": [],
            "used_size": predicted_size
        }
        
    print(f"[STYLIST] Found {len(relevant_products)} relevant products.")

    # 3. Construct prompt for LLM
    product_lines = []
    for p in relevant_products:
        p_name = p.get('product_name') or 'Fashion Item'
        p_brand = p.get('brand') or 'NexaRetail'
        p_price = safe_float(p.get('price'))
        p_desc = p.get('description') or 'Quality apparel'
        product_lines.append(
            f"Product Name: {p_name}\nBrand: {p_brand}\nPrice: LKR {p_price:.2f}\nDetails: {p_desc}"
        )

    product_context = "\n\n".join(product_lines)
    
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
    
    # 4. Generate response using load-balanced Gemini client
    try:
        print("[STYLIST] Calling Gemini AI...")
        prompt = f"{system_prompt}\n\nUSER QUESTION: {data.message}"
        response_text = llm_manager.generate_content_with_fallback(prompt)
        
        # Cleanup any leftover markdown symbols
        response_text = response_text.replace('**', '').replace('###', '').replace('##', '')
        
        print("[STYLIST] Gemini AI responded successfully!")
        return {
            "response": response_text,
            "relevant_products": relevant_products,
            "used_size": predicted_size
        }
    except Exception as e:
        print(f"[STYLIST] LLM call notice: {e}. Generating formatted stylist recommendation...")
        
        # Create an intelligent fallback styling recommendation using retrieved products!
        top_item = relevant_products[0]
        item_name = top_item.get('product_name') or 'denim jacket'
        item_price = safe_float(top_item.get('price'))
        
        recommendation = (
            f"To style your look effortlessly, pair a classic {item_name} (LKR {item_price:.2f}) with neutral-toned slim-fit pants or layer it over a clean graphic tee. "
            f"Based on your profile, size {predicted_size} provides the ideal balance of comfort and modern silhouette."
        )
        
        return {
            "response": recommendation,
            "relevant_products": relevant_products,
            "used_size": predicted_size
        }
