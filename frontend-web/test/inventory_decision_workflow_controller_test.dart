import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/workflow/inventory_decision_workflow_controller.dart';
import 'package:smart_inventory_web/models/stock_movement/stock_movement.dart';
import 'package:smart_inventory_web/models/workflow/decision_workflow.dart';

void main() {
  group('connected inventory decision workflow', () {
    test('maps reorder-buffer shortage fields without relabeling demand', () {
      final workflow = DecisionWorkflow.fromJson(_workflowJson());

      expect(workflow.currentStock, 50);
      expect(workflow.reorderLevel, 135);
      expect(workflow.requiredStock, 181);
      expect(workflow.safetyStockShortage, 131);
      expect(workflow.intelligence?.operationalAction, 'TRANSFER_OR_REPLENISH');
    });

    test(
      'derives review, execution, and completed stages from confirmed movement',
      () {
        final controller = InventoryDecisionWorkflowController();
        controller.setCurrent(
          DecisionWorkflow.fromJson(
            _workflowJson(movementStatus: 'RECOMMENDED'),
          ),
        );

        expect(controller.currentStage, WorkflowStage.review);

        controller.updateMovement(_movement('APPROVED'));
        expect(controller.currentStage, WorkflowStage.execution);
        expect(controller.current?.movement?.status, 'APPROVED');

        controller.updateMovement(_movement('EXECUTED'));
        expect(controller.currentStage, WorkflowStage.completed);
        expect(controller.current?.movement?.transactionId, 'TX-MOV-001');
      },
    );

    test(
      'ignores movement updates that do not belong to the active workflow',
      () {
        final controller = InventoryDecisionWorkflowController();
        controller.setCurrent(
          DecisionWorkflow.fromJson(
            _workflowJson(movementStatus: 'RECOMMENDED'),
          ),
        );

        controller.updateMovement(_movement('EXECUTED', id: 'MOV-OTHER'));

        expect(controller.current?.movement?.status, 'RECOMMENDED');
        expect(controller.currentStage, WorkflowStage.review);
      },
    );
  });
}

Map<String, dynamic> _workflowJson({String? movementStatus}) => {
  'workflow_id': 'WF-TEST-001',
  'workflow_status': movementStatus == null
      ? 'CANDIDATE_ANALYZED'
      : 'MOVEMENT_RECOMMENDED',
  'next_action': 'REVIEW_MOVEMENT',
  'forecast_type': 'SEVEN_DAY',
  'store_id': 'CP001',
  'product_id': 'P0001',
  'inventory_snapshot': {
    'current_stock': 50,
    'reorder_level': 135,
    'max_stock': 400,
    'projected_stock_after_demand': 4,
    'required_stock_before_demand': 181,
    'forecast_shortage_qty': 131,
  },
  'inventory_intelligence': {
    'forecast_demand': 46,
    'current_stock': 50,
    'stock_health': 'HEALTHY',
    'days_on_hand': 32.0,
    'stockout_risk': 'LOW',
    'overstock_risk': 'LOW',
    'shortage_qty': 0,
    'excess_qty': 0,
    'recommended_action': 'MONITOR',
    'recommended_quantity': 0,
    'suggested_discount': 0,
    'recommendation_reason': 'Standalone intelligence result.',
    'operational_status': 'BELOW_REORDER_BUFFER',
    'operational_action': 'TRANSFER_OR_REPLENISH',
    'operational_shortage_qty': 131,
    'operational_reason': 'Reorder buffer is not covered.',
    'inventory_value': 1000,
    'potential_revenue': 1500,
    'potential_profit': 500,
  },
  if (movementStatus != null)
    'movement': _movementJson(movementStatus, id: 'MOV-001'),
};

StockMovement _movement(String status, {String id = 'MOV-001'}) =>
    StockMovement.fromJson(_movementJson(status, id: id));

Map<String, dynamic> _movementJson(String status, {required String id}) => {
  'movement_id': id,
  'movement_status': status,
  'movement_type': 'TRANSFER',
  'product_id': 'P0001',
  'product_name': 'Test Product',
  'from_store': 'CP002',
  'to_store': 'CP001',
  'recommended_qty': 131,
  'coverage_percentage': 100,
  'recommendation_confidence': 90,
  'transfer_priority': 'HIGH',
  'simulation_status': 'SAFE',
  'source_stock_before': 300,
  'source_stock_after': 169,
  'target_stock_before': 50,
  'target_stock_after': 181,
  if (status == 'EXECUTED') ...{
    'actual_source_stock_before': 300,
    'actual_source_stock_after': 169,
    'actual_target_stock_before': 50,
    'actual_target_stock_after': 181,
    'transaction_id': 'TX-MOV-001',
    'executed_at': '2026-08-24T10:00:00Z',
  },
};
