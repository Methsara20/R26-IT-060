import '../forecast/short_range_forecast.dart';
import '../optimization/optimization_candidate.dart';
import '../stock_movement/stock_movement.dart';

class DecisionWorkflow {
  const DecisionWorkflow({
    required this.id,
    required this.status,
    required this.nextAction,
    required this.forecastType,
    required this.storeId,
    required this.productId,
    required this.forecast,
    required this.intelligence,
    required this.currentStock,
    required this.reorderLevel,
    required this.maximumStock,
    required this.projectedStock,
    required this.requiredStock,
    required this.safetyStockShortage,
    this.candidate,
    this.movement,
    this.failureStage,
    this.errorMessage,
  });

  factory DecisionWorkflow.fromJson(Map<String, dynamic> json) {
    final id = json['workflow_id']?.toString();
    final status = json['workflow_status']?.toString();
    final storeId = json['store_id']?.toString();
    final productId = json['product_id']?.toString();
    if (id == null || status == null || storeId == null || productId == null) {
      throw const FormatException('Invalid decision workflow identity.');
    }

    final forecastResult = _map(json['forecast_result']);
    final details = _map(forecastResult?['forecast_details']);
    final intelligenceJson = _map(json['inventory_intelligence']);
    final inventory = _map(json['inventory_snapshot']);
    final candidateJson = _map(json['candidate']);
    final movementJson = _map(json['movement']);
    final forecastType = json['forecast_type']?.toString() ?? 'DAILY';

    return DecisionWorkflow(
      id: id,
      status: status,
      nextAction: json['next_action']?.toString() ?? 'NONE',
      forecastType: forecastType,
      storeId: storeId,
      productId: productId,
      forecast: details == null
          ? null
          : ShortRangeForecast.fromJson({
              ...details,
              'forecast_type': switch (forecastType) {
                'SEVEN_DAY' => '7-day',
                'CUSTOM' => 'custom',
                _ => 'daily',
              },
              'store_id': storeId,
              'product_id': productId,
            }),
      intelligence: intelligenceJson == null
          ? null
          : WorkflowInventoryIntelligence.fromJson(intelligenceJson),
      currentStock: _int(inventory?['current_stock']),
      reorderLevel: _int(inventory?['reorder_level']),
      maximumStock: _int(inventory?['max_stock']),
      projectedStock: _double(inventory?['projected_stock_after_demand']),
      requiredStock: _double(inventory?['required_stock_before_demand']),
      safetyStockShortage: _int(inventory?['forecast_shortage_qty']),
      candidate: candidateJson == null
          ? null
          : OptimizationCandidate.fromJson(candidateJson),
      movement: movementJson == null
          ? null
          : StockMovement.fromJson(movementJson),
      failureStage: json['failure_stage']?.toString(),
      errorMessage: json['error_message']?.toString(),
    );
  }

  final String id;
  final String status;
  final String nextAction;
  final String forecastType;
  final String storeId;
  final String productId;
  final ShortRangeForecast? forecast;
  final WorkflowInventoryIntelligence? intelligence;
  final int currentStock;
  final int reorderLevel;
  final int maximumStock;
  final double projectedStock;
  final double requiredStock;
  final int safetyStockShortage;
  final OptimizationCandidate? candidate;
  final StockMovement? movement;
  final String? failureStage;
  final String? errorMessage;

  /// Returns a new workflow snapshot after a backend-confirmed movement
  /// mutation. Other workflow fields remain exactly as originally returned.
  DecisionWorkflow withMovement(StockMovement updatedMovement) =>
      DecisionWorkflow(
        id: id,
        status: status,
        nextAction: nextAction,
        forecastType: forecastType,
        storeId: storeId,
        productId: productId,
        forecast: forecast,
        intelligence: intelligence,
        currentStock: currentStock,
        reorderLevel: reorderLevel,
        maximumStock: maximumStock,
        projectedStock: projectedStock,
        requiredStock: requiredStock,
        safetyStockShortage: safetyStockShortage,
        candidate: candidate,
        movement: updatedMovement,
        failureStage: failureStage,
        errorMessage: errorMessage,
      );
}

class WorkflowInventoryIntelligence {
  const WorkflowInventoryIntelligence({
    required this.forecastDemand,
    required this.currentStock,
    required this.stockHealth,
    required this.daysOnHand,
    required this.stockoutRisk,
    required this.overstockRisk,
    required this.shortageQuantity,
    required this.excessQuantity,
    required this.recommendedAction,
    required this.recommendedQuantity,
    required this.suggestedDiscount,
    required this.reason,
    required this.operationalStatus,
    required this.operationalAction,
    required this.operationalShortageQuantity,
    required this.operationalReason,
    required this.inventoryValue,
    required this.potentialRevenue,
    required this.potentialProfit,
  });

  factory WorkflowInventoryIntelligence.fromJson(Map<String, dynamic> json) =>
      WorkflowInventoryIntelligence(
        forecastDemand: _int(json['forecast_demand']),
        currentStock: _int(json['current_stock']),
        stockHealth: json['stock_health']?.toString() ?? 'Unknown',
        daysOnHand: _double(json['days_on_hand']),
        stockoutRisk: json['stockout_risk']?.toString() ?? 'Unknown',
        overstockRisk: json['overstock_risk']?.toString() ?? 'Unknown',
        shortageQuantity: _int(json['shortage_qty']),
        excessQuantity: _int(json['excess_qty']),
        recommendedAction: json['recommended_action']?.toString() ?? 'MONITOR',
        recommendedQuantity: _int(json['recommended_quantity']),
        suggestedDiscount: _double(json['suggested_discount']),
        reason: json['recommendation_reason']?.toString() ?? '',
        operationalStatus: json['operational_status']?.toString() ?? 'UNKNOWN',
        operationalAction:
            json['operational_action']?.toString() ??
            json['recommended_action']?.toString() ??
            'MONITOR',
        operationalShortageQuantity: _int(json['operational_shortage_qty']),
        operationalReason: json['operational_reason']?.toString() ?? '',
        inventoryValue: _double(json['inventory_value']),
        potentialRevenue: _double(json['potential_revenue']),
        potentialProfit: _double(json['potential_profit']),
      );

  final int forecastDemand;
  final int currentStock;
  final String stockHealth;
  final double daysOnHand;
  final String stockoutRisk;
  final String overstockRisk;
  final int shortageQuantity;
  final int excessQuantity;
  final String recommendedAction;
  final int recommendedQuantity;
  final double suggestedDiscount;
  final String reason;
  final String operationalStatus;
  final String operationalAction;
  final int operationalShortageQuantity;
  final String operationalReason;
  final double inventoryValue;
  final double potentialRevenue;
  final double potentialProfit;
}

Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

double _double(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
