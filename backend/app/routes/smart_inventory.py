from fastapi import APIRouter, HTTPException
from app.schemas.prediction_schema import SimplePredictionRequest
from app.schemas.chat_schema import ChatRequest
from app.services.smart_inventory_data_service import build_payload, enrich_with_forecast, get_product_store_info
from app.services.smart_inventory_predictor import predict_demand
from app.services.smart_inventory_decision_engine import make_decision
from app.services.smart_inventory_explanation_service import generate_explanation
from app.services.smart_inventory_chat_service import handle_chat

router = APIRouter(
    tags=["Smart Inventory"]
)


@router.post("/predict-and-decide")
def predict_and_decide(data: SimplePredictionRequest):
    try:
        # 1. Build prediction payload (features)
        payload = build_payload(
            store_id=data.store_id,
            product_id=data.product_id,
            current_stock=data.current_stock,
            price_lkr=data.price_lkr,
            promotion_percent=data.promotion_percent
        )

        # 2. Predict demand and retrieve confidence
        predicted_demand, confidence = predict_demand(payload)

        # 3. Enrich with 7-day forecast
        forecast_enrichment = enrich_with_forecast(predicted_demand, payload)

        # 4. Make reordering/transfer decision
        decision = make_decision(
            store_id=data.store_id,
            product_id=data.product_id,
            predicted_demand=predicted_demand
        )

        if "error" in decision:
            raise HTTPException(status_code=400, detail=decision["error"])

        # 5. Generate AI Hybrid explanation report
        explanation = generate_explanation(
            payload=payload,
            prediction=predicted_demand,
            decision=decision
        )

        # 6. Build consolidated response
        return {
            "predicted_demand": round(predicted_demand, 2),
            "confidence": confidence,
            "status": decision.get("status"),
            "action": decision.get("action"),
            "current_stock": decision.get("current_stock"),
            "from_store": decision.get("from_store"),
            "transfer_qty": decision.get("transfer_qty"),
            "forecast_7_days": forecast_enrichment.get("forecast_7_days"),
            "forecast_7_days_list": forecast_enrichment.get("forecast_7_days_list"),
            "trend": forecast_enrichment.get("trend"),
            "payload": payload,
            "explanation": explanation
        }

    except ValueError as val_err:
        raise HTTPException(status_code=404, detail=str(val_err))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/dropdown-data")
def dropdown_data():
    try:
        return get_product_store_info()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/product-store-info")
def product_store_info(store_id: str, product_id: str):
    try:
        return get_product_store_info(store_id=store_id, product_id=product_id)
    except ValueError as val_err:
        raise HTTPException(status_code=404, detail=str(val_err))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/chat")
def chat(data: ChatRequest):
    try:
        reply = handle_chat(message=data.message, context=data.context)
        return {"reply": reply}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
