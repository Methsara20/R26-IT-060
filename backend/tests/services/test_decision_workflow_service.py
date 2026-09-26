import unittest
from datetime import date, timedelta
from unittest.mock import patch

from app.schemas.forecast_schema import CustomForecastRequest, DailyForecastRequest
from app.schemas.decision_workflow_schema import DecisionWorkflowRequest
from app.services import decision_workflow_service as service


class DecisionWorkflowServiceTests(unittest.TestCase):
    def request(self, **overrides):
        values = {
            "forecast_type": "DAILY",
            "store_id": "CP001",
            "product_id": "P0001",
            "selling_price": 2500,
            "promotion_percent": 0,
            "idempotency_key": "workflow-test-key",
        }
        values.update(overrides)
        return DecisionWorkflowRequest(**values)

    def test_custom_range_over_fourteen_days_is_rejected(self):
        start = date.today() + timedelta(days=1)
        request = self.request(
            forecast_type="CUSTOM",
            start_date=start,
            end_date=start + timedelta(days=14),
        )

        with self.assertRaises(service.DecisionWorkflowValidationError):
            service.analyze_decision_workflow(request)

    def test_daily_payload_matches_established_forecast_defaults(self):
        request = self.request()
        payload = service._forecast_payload(request)
        established = DailyForecastRequest(
            store_id=request.store_id,
            product_id=request.product_id,
            price_lkr=request.selling_price,
            promotion_percent=request.promotion_percent,
            month=payload["month"],
            day=payload["day"],
            day_of_week_num=payload["day_of_week_num"],
        ).model_dump()

        self.assertEqual(payload, established)
        self.assertEqual(payload["lag_1"], 0)
        self.assertEqual(payload["lag_7"], 0)
        self.assertEqual(payload["rolling_mean_7"], 0)

    def test_custom_payload_matches_established_forecast_defaults(self):
        start = date.today() + timedelta(days=1)
        request = self.request(
            forecast_type="CUSTOM",
            start_date=start,
            end_date=start,
        )
        payload = service._forecast_payload(request)
        established = CustomForecastRequest(
            store_id=request.store_id,
            product_id=request.product_id,
            price_lkr=request.selling_price,
            promotion_percent=request.promotion_percent,
            start_date=start,
            end_date=start,
        ).model_dump(exclude={"start_date", "end_date"})

        self.assertEqual(payload, established)

    @patch.object(service, "predict_next_day")
    def test_daily_forecast_details_are_retained(self, predict_next_day):
        raw = {
            "forecast_date": "2026-08-23",
            "predicted_demand": 8,
            "confidence_percentage": 91,
            "weather": {
                "temperature": 29,
                "humidity": 80,
                "rainfall": 2,
                "weather_condition": "Rainy",
            },
        }
        predict_next_day.return_value = raw

        result = service._run_forecast(self.request(), {})

        self.assertEqual(result["forecast_details"]["predicted_demand"], 8)
        self.assertEqual(result["forecast_details"]["weather"], raw["weather"])
        self.assertEqual(result["forecast_details"]["weather_source"], "Open-Meteo")

    @patch.object(service, "generate_7_day_forecast")
    def test_seven_day_forecast_details_are_retained(self, generate_forecast):
        raw = {
            "forecast_days": 7,
            "start_date": "2026-08-23",
            "end_date": "2026-08-29",
            "total_predicted_demand": 14,
            "average_confidence_percentage": 92,
            "weather_source": "Open-Meteo",
            "forecast": [
                {
                    "date": "2026-08-23",
                    "predicted_demand": 2,
                    "confidence_percentage": 92,
                    "weather": {"temperature": 29},
                }
            ],
        }
        generate_forecast.return_value = raw

        result = service._run_forecast(
            self.request(forecast_type="SEVEN_DAY"),
            {},
        )

        self.assertEqual(result["forecast_details"], raw)

    @patch.object(service, "generate_custom_forecast")
    def test_custom_forecast_details_are_retained(self, generate_forecast):
        start = date.today() + timedelta(days=1)
        raw = {
            "forecast_days": 1,
            "start_date": start.isoformat(),
            "end_date": start.isoformat(),
            "total_predicted_demand": 3,
            "average_confidence_percentage": 88,
            "weather_source": "Open-Meteo",
            "forecast": [
                {
                    "date": start.isoformat(),
                    "predicted_demand": 3,
                    "confidence_percentage": 88,
                    "weather": {"rainfall": 0},
                }
            ],
        }
        generate_forecast.return_value = raw
        request = self.request(
            forecast_type="CUSTOM",
            start_date=start,
            end_date=start,
        )

        result = service._run_forecast(request, {})

        self.assertEqual(result["forecast_details"], raw)

    @patch.object(service, "get_document_by_id")
    def test_reused_idempotency_key_with_different_inputs_is_rejected(
        self,
        get_document,
    ):
        request = self.request(product_id="P0002")
        get_document.return_value = {
            **service._request_identity(self.request(product_id="P0001")),
            "workflow_id": service._workflow_id(request.idempotency_key),
            "workflow_status": "NO_ACTION_REQUIRED",
        }

        with self.assertRaisesRegex(
            service.DecisionWorkflowValidationError,
            "different request data",
        ):
            service._claim_workflow(request)

    @patch.object(service, "_save_workflow")
    @patch.object(service, "generate_inventory_intelligence")
    @patch.object(service, "_run_forecast")
    @patch.object(service, "_find_inventory")
    @patch.object(service, "get_product_by_id")
    @patch.object(service, "get_store_by_id")
    @patch.object(service, "_claim_workflow")
    def test_no_action_workflow_does_not_create_candidate(
        self,
        claim_workflow,
        get_store,
        get_product,
        find_inventory,
        run_forecast,
        intelligence,
        save_workflow,
    ):
        request = self.request()
        workflow_id = service._workflow_id(request.idempotency_key)
        workflow = {
            "workflow_id": workflow_id,
            "workflow_status": "PROCESSING",
            "candidate_id": None,
            "movement_id": None,
        }
        claim_workflow.return_value = (workflow, True)
        get_store.return_value = {"store_id": "CP001"}
        get_product.return_value = {"product_id": "P0001", "cost_price": 1000}
        find_inventory.return_value = {
            "inventory_id": "INV-1",
            "store_id": "CP001",
            "product_id": "P0001",
            "current_stock": 100,
            "reorder_level": 10,
            "max_stock": 150,
        }
        run_forecast.return_value = {
            "forecast_horizon_days": 1,
            "forecast_total_demand": 5,
            "forecast_average_confidence": 90,
            "forecast_start_date": "2026-08-23",
            "forecast_end_date": "2026-08-23",
        }
        intelligence.return_value = {"stock_health": "Healthy"}
        save_workflow.side_effect = lambda _, item: item

        with patch.object(service, "create_or_update_document") as save_document:
            result = service.analyze_decision_workflow(request)

        self.assertEqual(result["workflow_status"], "NO_ACTION_REQUIRED")
        self.assertIsNone(result["candidate_id"])
        save_document.assert_not_called()

    @patch.object(service, "_hydrate_workflow")
    @patch.object(service, "_claim_workflow")
    def test_existing_idempotent_workflow_returns_without_reanalysis(
        self,
        claim_workflow,
        hydrate_workflow,
    ):
        request = self.request()
        existing = {
            "workflow_id": service._workflow_id(request.idempotency_key),
            "workflow_status": "MOVEMENT_RECOMMENDED",
            "movement_id": "MOV-1",
        }
        claim_workflow.return_value = (existing, False)
        hydrate_workflow.return_value = existing

        with patch.object(service, "_run_forecast") as run_forecast:
            result = service.analyze_decision_workflow(request)

        self.assertEqual(result, existing)
        run_forecast.assert_not_called()

    @patch.object(service, "_save_workflow")
    @patch.object(service, "recommend_transfer")
    @patch.object(service, "analyze_candidate")
    @patch.object(service, "create_or_update_document")
    @patch.object(service, "generate_inventory_intelligence")
    @patch.object(service, "_run_forecast")
    @patch.object(service, "_find_inventory")
    @patch.object(service, "get_product_by_id")
    @patch.object(service, "get_store_by_id")
    @patch.object(service, "_claim_workflow")
    def test_actionable_shortage_creates_unique_candidate_and_one_movement(
        self,
        claim_workflow,
        get_store,
        get_product,
        find_inventory,
        run_forecast,
        intelligence,
        save_document,
        analyze_candidate,
        recommend_transfer,
        save_workflow,
    ):
        request = self.request(idempotency_key="movement-test-key")
        workflow_id = service._workflow_id(request.idempotency_key)
        workflow = {
            "workflow_id": workflow_id,
            "workflow_status": "PROCESSING",
            "candidate_id": None,
            "movement_id": None,
        }
        claim_workflow.return_value = (workflow, True)
        get_store.return_value = {"store_id": "CP001"}
        get_product.return_value = {
            "product_id": "P0001",
            "product_name": "Test Product",
            "cost_price": 1000,
        }
        find_inventory.return_value = {
            "inventory_id": "INV-1",
            "store_id": "CP001",
            "product_id": "P0001",
            "current_stock": 2,
            "reorder_level": 5,
            "max_stock": 50,
        }
        run_forecast.return_value = {
            "forecast_horizon_days": 1,
            "forecast_total_demand": 10,
            "forecast_average_confidence": 90,
            "forecast_start_date": "2026-08-23",
            "forecast_end_date": "2026-08-23",
        }
        intelligence.return_value = {"stock_health": "Critical"}
        candidate_id = service._candidate_id(workflow_id)
        analyzed_candidate = {
            "candidate_id": candidate_id,
            "recommended_action": "TRANSFER",
            "transfer_ready": True,
        }
        analyze_candidate.return_value = {
            "decision": {"recommended_action": "TRANSFER"},
            "candidate": analyzed_candidate,
        }
        recommend_transfer.return_value = {
            "movement_id": "MOV-1",
            "movement_status": "RECOMMENDED",
        }
        save_workflow.side_effect = lambda _, item: service._with_next_action(item)

        result = service.analyze_decision_workflow(request)

        self.assertEqual(candidate_id, f"FW-{workflow_id}")
        self.assertEqual(result["workflow_status"], "MOVEMENT_RECOMMENDED")
        self.assertEqual(result["movement_id"], "MOV-1")
        recommend_transfer.assert_called_once_with(candidate_id)
        saved_candidate = save_document.call_args.args[2]
        self.assertEqual(saved_candidate["candidate_origin"], "FORECAST_WORKFLOW")
        self.assertEqual(saved_candidate["workflow_id"], workflow_id)
        self.assertIn(saved_candidate["priority"], {"LOW", "MEDIUM", "HIGH"})
        self.assertEqual(result["next_action"], "MANAGER_REVIEW")


if __name__ == "__main__":
    unittest.main()
