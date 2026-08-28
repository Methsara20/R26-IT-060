import unittest
from unittest.mock import patch

from fastapi import HTTPException

from app.routes import decision_workflow_routes as routes
from app.schemas.decision_workflow_schema import DecisionWorkflowRequest
from app.services.decision_workflow_service import (
    DecisionWorkflowNotFoundError,
    DecisionWorkflowValidationError,
)


class DecisionWorkflowRouteTests(unittest.TestCase):
    def test_analyze_maps_business_validation_to_400(self):
        request = DecisionWorkflowRequest(
            forecast_type="DAILY",
            store_id="CP001",
            product_id="P0001",
            selling_price=2500,
            idempotency_key="route-test-key",
        )
        with patch.object(
            routes,
            "analyze_decision_workflow",
            side_effect=DecisionWorkflowValidationError("Invalid request."),
        ):
            with self.assertRaises(HTTPException) as raised:
                routes.analyze_workflow(request)

        self.assertEqual(raised.exception.status_code, 400)
        self.assertEqual(raised.exception.detail, "Invalid request.")

    def test_history_passes_bounded_limit_to_service(self):
        with patch.object(
            routes,
            "list_decision_workflows",
            return_value=[],
        ) as list_workflows:
            result = routes.workflow_history(limit=20)

        self.assertEqual(result, [])
        list_workflows.assert_called_once_with(limit=20)

    def test_missing_workflow_maps_to_404(self):
        with patch.object(
            routes,
            "get_decision_workflow",
            side_effect=DecisionWorkflowNotFoundError("Not found."),
        ):
            with self.assertRaises(HTTPException) as raised:
                routes.workflow_by_id("WF-MISSING")

        self.assertEqual(raised.exception.status_code, 404)

    def test_response_models_document_stable_nested_names(self):
        fields = routes.DecisionWorkflowResponse.model_fields

        self.assertIn("candidate", fields)
        self.assertIn("movement", fields)
        self.assertIn("forecast_result", fields)
        self.assertIn("next_action", fields)


if __name__ == "__main__":
    unittest.main()
