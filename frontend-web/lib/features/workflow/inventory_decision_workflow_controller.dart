import 'package:flutter/foundation.dart';

import '../../models/workflow/decision_workflow.dart';
import '../../models/stock_movement/stock_movement.dart';

/// Keeps the active decision chain available while managers move between
/// forecasting, optimization, movement review, and contextual assistance.
class InventoryDecisionWorkflowController extends ChangeNotifier {
  DecisionWorkflow? _current;
  String? _assistantSessionId;

  DecisionWorkflow? get current => _current;
  String? get workflowId => _current?.id;
  String? get candidateId => _current?.candidate?.id;
  String? get movementId => _current?.movement?.movementId;
  String? get storeId => _current?.storeId;
  String? get productId => _current?.productId;
  WorkflowStage get currentStage => WorkflowStage.fromWorkflow(_current);
  bool get hasActiveWorkflow => _current != null;
  String? get assistantSessionId => _assistantSessionId;

  void setCurrent(DecisionWorkflow workflow) {
    _current = workflow;
    notifyListeners();
  }


  /// Synchronizes only a response confirmed by the stock-movement backend.
  void updateMovement(StockMovement movement) {
    final current = _current;
    if (current == null ||
        current.movement?.movementId != movement.movementId) {
      return;
    }
    _current = current.withMovement(movement);
    notifyListeners();
  }

  /// Replaces a rejected workflow movement with a newly generated version.
  ///
  /// A candidate identity check prevents a recommendation from an unrelated
  /// workflow from becoming the active manager review.
  bool replaceMovementVersion(StockMovement movement) {
    final current = _current;
    final candidateId = current?.candidate?.id;
    if (current == null ||
        candidateId == null ||
        movement.candidateId != candidateId) {
      return false;
    }

    _current = current.withMovement(movement);
    notifyListeners();
    return true;
  }

  void setAssistantSession(String sessionId) {
    _assistantSessionId = sessionId;
  }

  /// Removes only the in-memory workflow context.
  ///
  /// Backend workflow and Firestore records are deliberately unaffected, and
  /// the assistant session remains available as normal chat history.
  void clearActiveWorkflow() {
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  void clear() {
    _current = null;
    _assistantSessionId = null;
    notifyListeners();
  }
}

/// Manager-facing lifecycle stages derived only from backend-confirmed state.
enum WorkflowStage {
  forecast,
  intelligence,
  optimization,
  review,
  execution,
  completed;

  static WorkflowStage fromWorkflow(DecisionWorkflow? workflow) {
    if (workflow == null) return WorkflowStage.forecast;

    final movementStatus = workflow.movement?.status;
    if (movementStatus == 'EXECUTED') return WorkflowStage.completed;
    if (movementStatus == 'APPROVED') return WorkflowStage.execution;
    if (workflow.movement != null) return WorkflowStage.review;
    if (workflow.candidate != null) return WorkflowStage.optimization;
    return WorkflowStage.intelligence;
  }
}
