# from fastapi import FastAPI
# from app.schemas.prediction_schema import PredictionRequest
# from app.services.predictor import predict_demand
# from app.services.decision_engine import make_decision
# from app.services.explanation_service import generate_explanation
# from app.schemas.chat_schema import ChatRequest
# from app.services.chat_service import handle_chat
# from app.services.data_service import (
#     get_inventory,
#     get_latest_sales,
#     get_weather,
#     get_event
# )
#
#
# app = FastAPI(title="Smart Inventory AI Service")
#
# from fastapi.middleware.cors import CORSMiddleware
#
# app.add_middleware(
#     CORSMiddleware,
#     allow_origins=["*"],  # for dev (later restrict)
#     allow_credentials=True,
#     allow_methods=["*"],
#     allow_headers=["*"],
# )
#
# @app.get("/")
# def home():
#     return {"message": "AI Service Running"}
#
#
# # @app.post("/predict-and-decide")
# # def predict_and_decide(data: PredictionRequest):
# #     payload = data.model_dump()
# #
# #     # 1. prediction
# #     prediction = predict_demand(payload)
# #
# #     # 2. decision
# #     decision = make_decision(
# #         store_id=payload["store_id"],
# #         product_id=payload["product_id"],
# #         predicted_demand=prediction
# #     )
# #
# #     # 3. explanation (NEW)
# #     explanation = generate_explanation(payload, prediction, decision)
# #
# #     return {
# #         "predicted_demand": prediction,
# #         **decision,
# #         "explanation": explanation
# #     }
#
# @app.post("/predict-and-decide")
# def predict_and_decide(data: PredictionRequest):
#     payload = data.model_dump()
#
#     # 1. prediction (UPDATED)
#     prediction, confidence = predict_demand(payload)
#
#     # 2. decision
#     decision = make_decision(
#         store_id=payload["store_id"],
#         product_id=payload["product_id"],
#         predicted_demand=prediction
#     )
#
#     # 3. explanation
#     explanation = generate_explanation(payload, prediction, decision)
#
#     return {
#         "predicted_demand": round(prediction, 2),
#         "confidence": confidence,
#         **decision,
#         "explanation": explanation
#     }
#
#
# @app.post("/chat")
# def chat(data: ChatRequest):
#     reply = handle_chat(data.message, data.context)
#     return {"reply": reply}




from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware


#  Schemas
from app.schemas.prediction_schema import SimplePredictionRequest
from app.schemas.chat_schema import ChatRequest

#  Services
from app.services.predictor import predict_demand
from app.services.decision_engine import make_decision
from app.services.explanation_service import generate_explanation
from app.services.chat_service import handle_chat
from app.services.data_service import (build_payload, get_product_store_info)
from app.services.data_service import enrich_with_forecast

app = FastAPI(title="Smart Inventory AI Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def home():
    return {"message": "AI Service Running"}



@app.get("/dropdown-data")
def dropdown_data():

    return get_product_store_info()


#  PRODUCT + STORE INFO API


@app.get("/product-store-info")
def product_store_info(
    store_id: str,
    product_id: str
):

    return get_product_store_info(
        store_id,
        product_id
    )


@app.post("/predict-and-decide")
def predict_and_decide(data: SimplePredictionRequest):
    try:
        #  Step 1 — Build FULL payload
        payload = build_payload(
            data.store_id,
            data.product_id,
            data.current_stock,
            data.price_lkr,
            data.promotion_percent
        )

        #  Step 2 — Prediction
        prediction, confidence = predict_demand(payload)

        forecast_data = enrich_with_forecast(prediction, payload)

        #  Step 3 — Decision
        decision = make_decision(
            store_id=data.store_id,
            product_id=data.product_id,
            predicted_demand=prediction
        )

        #  Step 4 — Explanation
        explanation = generate_explanation(payload, prediction, decision)

        return {
            "predicted_demand": round(prediction, 2),
            "confidence": confidence,
            **decision,
            **forecast_data,
            "explanation": explanation,
            "payload": payload,
            "current_stock": data.current_stock
        }

    except Exception as e:
        return {"error": str(e)}


@app.post("/chat")
def chat(data: ChatRequest):
    reply = handle_chat(data.message, data.context)
    return {"reply": reply}