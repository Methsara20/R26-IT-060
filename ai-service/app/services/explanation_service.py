import time
from google import genai

from app.config.settings import GEMINI_API_KEY

client = genai.Client(
    api_key=GEMINI_API_KEY
)

# LOCAL BUSINESS EXPLANATION

def generate_local_explanation(
    payload,
    prediction,
    decision
):

    #  PRODUCT DETAILS
    brand = payload.get(
        "brand",
        "Unknown Brand"
    )

    gender = payload.get(
        "gender",
        ""
    )

    subcategory = payload.get(
        "subcategory",
        ""
    )

    category = payload.get(
        "category",
        ""
    )

    store = payload.get(
        "store_id"
    )

    #  INVENTORY
    stock = decision.get(
        "current_stock",
        0
    )

    action = decision.get(
        "action",
        "MONITOR"
    )

    reasons = []

    #  PROMOTION IMPACT

    if payload.get(
        "is_promotion"
    ) == 1:

        discount = (
            payload.get(
                "discount",
                0
            ) * 100
        )

        reasons.append(
            f"the active {discount:.0f}% promotion is improving customer demand"
        )

    #  PRICE IMPACT

    price = payload.get(
        "price_lkr",
        0
    )

    if price < 2000:

        reasons.append(
            "the lower pricing strategy is encouraging purchases"
        )

    elif price > 5000:

        reasons.append(
            "the premium pricing may slightly slow purchasing behavior"
        )

    #  SALES TREND

    lag_1 = payload.get(
        "lag_1",
        0
    )

    lag_7 = payload.get(
        "lag_7",
        0
    )

    if lag_1 > lag_7:

        reasons.append(
            "recent sales movement shows increasing customer interest"
        )

    elif lag_1 < lag_7:

        reasons.append(
            "recent sales movement indicates slightly declining demand"
        )

    else:

        reasons.append(
            "sales activity remains relatively stable"
        )

    # WEATHER IMPACT

    weather = payload.get(
        "weather_condition",
        ""
    )

    if weather in [
        "Rainy",
        "Storm"
    ]:

        reasons.append(
            "weather conditions may influence store traffic and buying patterns"
        )

    #  FINAL REASON TEXT

    reason_text = ", ".join(
        reasons
    )

    # PRODUCT LABEL

    product_label = (
        f"{brand} "
        f"{gender.lower()} "
        f"{subcategory.lower()}"
    ).strip()

    #  FINAL EXPLANATION

    if prediction > stock:

        return (
            f"Forecasted demand for "
            f"{product_label} products "
            f"in store {store} is expected "
            f"to exceed current inventory levels. "
            f"This is mainly because "
            f"{reason_text}. "
            f"The system recommends "
            f"{action.lower()} action "
            f"to minimize potential stock shortages."
        )

    else:

        return (
            f"Predicted demand for "
            f"{product_label} products "
            f"currently remains within "
            f"available inventory levels. "
            f"This is influenced by "
            f"{reason_text}. "
            f"No immediate inventory adjustment "
            f"is required at this stage."
        )

# HYBRID AI EXPLANATION

def generate_explanation(
    payload,
    prediction,
    decision
):

    # ALWAYS GENERATE LOCAL SAFE VERSION
    base_explanation = (
        generate_local_explanation(
            payload,
            prediction,
            decision
        )
    )

    # GEMINI ENHANCEMENT

    try:

        prompt = f"""
You are an AI-powered retail inventory analyst.

Your task is to rewrite the inventory explanation in a professional and natural business style.

IMPORTANT RULES:
- Use ONLY the provided information
- Do NOT invent fake business insights
- Do NOT mention unavailable data
- Keep explanation realistic and professional
- Keep response concise
- Maximum 3 sentences
- Sound like a real retail operations analyst

PRODUCT INFORMATION:
Brand: {payload.get('brand')}
Gender Segment: {payload.get('gender')}
Subcategory: {payload.get('subcategory')}
Category: {payload.get('category')}

BUSINESS DATA:
Predicted Demand: {prediction}
Current Stock: {decision.get('current_stock')}
Inventory Action: {decision.get('action')}
Weather Condition: {payload.get('weather_condition')}
Promotion Active: {payload.get('is_promotion')}
Price: {payload.get('price_lkr')}

BASE EXPLANATION:
{base_explanation}

Rewrite the explanation naturally.
"""

        response = (
            client.models.generate_content(

                model="gemini-2.0-flash",

                contents=prompt
            )
        )

        enhanced_text = getattr(
            response,
            "text",
            ""
        )

        if enhanced_text:
            return enhanced_text.strip()

        return base_explanation

    except Exception:

        # SAFE FALLBACK
        return base_explanation