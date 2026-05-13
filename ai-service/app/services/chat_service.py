import time
import re

from google import genai

from app.config.settings import GEMINI_API_KEY
from app.services.explanation_service import generate_explanation

# Gemini Client
client = genai.Client(api_key=GEMINI_API_KEY)

# GEMINI CALL

def call_model(prompt):
    for attempt in range(3):
        try:
            response = client.models.generate_content(
                model="gemini-flash-latest",
                contents=prompt
            )

            return getattr(response, "text", str(response))

        except Exception as e:
            if "503" in str(e) or "UNAVAILABLE" in str(e):
                time.sleep(2)
            else:
                break

    # 🔥 Fallback model
    try:
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=prompt
        )

        return getattr(response, "text", str(response))

    except Exception:
        return "AI service is temporarily busy. Please try again."


# MAIN CHAT HANDLER

def handle_chat(message: str, context: dict):

    try:

        # NO CONTEXT

        if not context:
            return (
                "Please generate a demand forecast first so I can assist you with inventory insights."
            )
        message_lower = message.lower()

        # EXTRACT CONTEXT

        payload = context.get("payload", {})
        prediction = context.get("predicted_demand")
        confidence = context.get("confidence")

        forecast = context.get(
            "forecast_7_days_list", []
        )

        trend = context.get("trend")

        decision = {
            "current_stock":
                context.get("current_stock"),
            "status":
                context.get("status"),
            "action":
                context.get("action"),
            "from_store":
                context.get("from_store"),
            "transfer_qty":
                context.get("transfer_qty"),
        }

        explanation = generate_explanation(
            payload,
            prediction,
            decision
        )


        # STRICT LOCAL HANDLERS

        # DAY QUESTIONS

        day_match = re.search(
            r"day\s*(\d+)",
            message_lower
        )

        if day_match:
            day = int(
                day_match.group(1)
            )

            if 1 <= day <= 7:

                if len(forecast) >= day:

                    value = forecast[day - 1]

                    return (
                        f"The projected demand for Day {day} "
                        f"is approximately {value} units."
                    )

                else:

                    return (
                        f"Forecast data for Day {day} "
                        f"is not available."
                    )


        #  PEAK DEMAND

        if (
            "highest" in message_lower
            or "peak" in message_lower
            or "maximum" in message_lower
        ):

            if forecast:

                peak_day = (
                    forecast.index(
                        max(forecast)
                    ) + 1
                )

                peak_value = max(forecast)

                return (
                    f"The highest projected demand "
                    f"occurs on Day {peak_day} "
                    f"with approximately "
                    f"{peak_value} units."
                )


        # LOWEST DEMAND


        if (
            "lowest" in message_lower
            or "minimum" in message_lower
        ):

            if forecast:

                low_day = (
                    forecast.index(
                        min(forecast)
                    ) + 1
                )

                low_value = min(forecast)

                return (
                    f"The lowest projected demand "
                    f"occurs on Day {low_day} "
                    f"with approximately "
                    f"{low_value} units."
                )


        # 🔥 GEMINI BUSINESS REASONING


        prompt = f"""
You are an AI-powered fashion retail inventory consultant.

You help fashion retail managers understand:
- demand forecasting
- stock risks
- promotion impact
- pricing strategy
- inventory movement
- retail business decisions

IMPORTANT RULES:
- Use ONLY the provided system context
- NEVER invent fake forecast values
- NEVER mention unavailable data
- If data is missing, clearly say it is unavailable
- Give realistic business-oriented answers
- Sound like a professional fashion retail analyst
- Keep responses concise (2-4 sentences)
- Avoid robotic wording
- Provide practical recommendations when appropriate

SYSTEM CONTEXT:

Product ID:
{payload.get('product_id')}

Store ID:
{payload.get('store_id')}

Category:
{payload.get('category')}

Brand:
{payload.get('brand')}

Gender:
{payload.get('gender')}

Subcategory:
{payload.get('subcategory')}

Current Price:
{payload.get('price_lkr')} LKR

Promotion Active:
{payload.get('is_promotion')}

Discount:
{payload.get('discount')}

Current Stock:
{decision.get('current_stock')}

Predicted Demand (Day 1):
{prediction}

7-Day Forecast:
{forecast}

Forecast Trend:
{trend}

Prediction Confidence:
{confidence}

Inventory Status:
{decision.get('status')}

Recommended Action:
{decision.get('action')}

Transfer From Store:
{decision.get('from_store')}

Transfer Quantity:
{decision.get('transfer_qty')}

Weather Condition:
{payload.get('weather_condition')}

Temperature:
{payload.get('temperature')}

AI Explanation:
{explanation}

USER QUESTION:
{message}

Now provide a realistic retail business response.
"""

        return call_model(prompt)

    except Exception as e:

        return f"Error: {str(e)}"