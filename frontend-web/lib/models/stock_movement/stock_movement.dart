class StockMovement {
  const StockMovement({
    required this.movementId,
    required this.candidateId,
    required this.productId,
    required this.productName,
    required this.movementType,
    required this.status,
    required this.fromStore,
    required this.toStore,
    required this.recommendedQuantity,
    required this.coveragePercentage,
    required this.confidence,
    required this.priority,
    required this.simulationStatus,
    required this.sourceStockBefore,
    required this.sourceStockAfter,
    required this.targetStockBefore,
    required this.targetStockAfter,
    required this.distanceKm,
    required this.estimatedTimeMinutes,
    required this.estimatedTransferCost,
    required this.recommendationReason,
    required this.aiExplanation,
    required this.transactionId,
    required this.rejectionReason,
    required this.cancelReason,
    required this.createdAt,
    required this.executedAt,
    required this.executionSummary,
    required this.statusHistory,
    required this.evaluatedSources,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    final movementId = (json['movement_id'] ?? json['id'])?.toString();
    if (movementId == null || movementId.isEmpty) {
      throw const FormatException('Movement ID is missing.');
    }


    final history = json['status_history'];
    final sourceItems = json['evaluated_sources'];
    return StockMovement(
      movementId: movementId,
      candidateId: json['candidate_id']?.toString(),
      productId: json['product_id']?.toString() ?? 'Unknown product',
      productName: json['product_name']?.toString() ?? 'Unnamed product',
      movementType: json['movement_type']?.toString() ?? 'UNKNOWN',
      status: json['movement_status']?.toString() ?? 'UNKNOWN',
      fromStore: json['from_store']?.toString() ?? '—',
      toStore: json['to_store']?.toString() ?? '—',
      recommendedQuantity: _asInt(json['recommended_qty']),
      coveragePercentage: _asDouble(json['coverage_percentage']),
      confidence: _asDouble(
        json['recommendation_confidence'] ?? json['decision_confidence'],
      ),
      priority: json['transfer_priority']?.toString() ?? 'UNSPECIFIED',
      simulationStatus: json['simulation_status']?.toString() ?? 'UNKNOWN',
      sourceStockBefore: _asInt(
        json['actual_source_stock_before'] ?? json['source_stock_before'],
      ),
      sourceStockAfter: _asInt(
        json['actual_source_stock_after'] ?? json['source_stock_after'],
      ),
      targetStockBefore: _asInt(
        json['actual_target_stock_before'] ?? json['target_stock_before'],
      ),
      targetStockAfter: _asInt(
        json['actual_target_stock_after'] ?? json['target_stock_after'],
      ),
      distanceKm: _asDouble(json['distance_km']),
      estimatedTimeMinutes: _asInt(json['estimated_time_minutes']),
      estimatedTransferCost: _asDouble(json['estimated_transfer_cost']),
      recommendationReason: json['recommendation_reason']?.toString(),
      aiExplanation: json['ai_explanation']?.toString(),
      transactionId: json['transaction_id']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      cancelReason: json['cancel_reason']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      executedAt: DateTime.tryParse(json['executed_at']?.toString() ?? ''),
      executionSummary: json['ai_execution_summary']?.toString(),
      statusHistory: history is List
          ? history
                .whereType<Map>()
                .map(
                  (item) => MovementStatusEvent.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      evaluatedSources: sourceItems is List
          ? sourceItems
                .whereType<Map>()
                .map(
                  (item) => MovementSourceAlternative.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }

  final String movementId;
  final String? candidateId;
  final String productId;
  final String productName;
  final String movementType;
  final String status;
  final String fromStore;
  final String toStore;
  final int recommendedQuantity;
  final double coveragePercentage;
  final double confidence;
  final String priority;
  final String simulationStatus;
  final int sourceStockBefore;
  final int sourceStockAfter;
  final int targetStockBefore;
  final int targetStockAfter;
  final double distanceKm;
  final int estimatedTimeMinutes;
  final double estimatedTransferCost;
  final String? recommendationReason;
  final String? aiExplanation;
  final String? transactionId;
  final String? rejectionReason;
  final String? cancelReason;
  final DateTime? createdAt;
  final DateTime? executedAt;
  final String? executionSummary;
  final List<MovementStatusEvent> statusHistory;
  final List<MovementSourceAlternative> evaluatedSources;

  // These permissions mirror the status checks enforced by the backend.
  bool get canApprove => status == 'RECOMMENDED';
  bool get canReject => status == 'RECOMMENDED';
  bool get canCancel => status == 'RECOMMENDED' || status == 'APPROVED';
  bool get canExecute => status == 'APPROVED' && movementType == 'TRANSFER';

  static int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  static double _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
}

/// One backend-ranked source option evaluated for a transfer recommendation.
class MovementSourceAlternative {
  const MovementSourceAlternative({
    required this.storeId,
    required this.rank,
    required this.currentStock,
    required this.reorderLevel,
    required this.surplusQuantity,
    required this.safeTransferQuantity,
    required this.remainingBuffer,
    required this.coveragePercentage,
    required this.riskAfterTransfer,
    required this.distanceKm,
    required this.estimatedTimeMinutes,
    required this.estimatedTransferCost,
  });

  factory MovementSourceAlternative.fromJson(
    Map<String, dynamic> json,
  ) => MovementSourceAlternative(
    storeId: json['store_id']?.toString() ?? 'Unknown',
    rank: StockMovement._asInt(json['rank']),
    currentStock: StockMovement._asInt(json['current_stock']),
    reorderLevel: StockMovement._asInt(json['reorder_level']),
    surplusQuantity: StockMovement._asInt(json['surplus_qty']),
    safeTransferQuantity: StockMovement._asInt(json['possible_transfer_qty']),
    remainingBuffer: StockMovement._asInt(json['remaining_buffer']),
    coveragePercentage: StockMovement._asDouble(json['coverage_percentage']),
    riskAfterTransfer: json['risk_after_transfer']?.toString() ?? 'Unknown',
    distanceKm: StockMovement._asDouble(json['distance_km']),
    estimatedTimeMinutes: StockMovement._asInt(json['estimated_time_minutes']),
    estimatedTransferCost: StockMovement._asDouble(
      json['estimated_transfer_cost'],
    ),
  );

  final String storeId;
  final int rank;
  final int currentStock;
  final int reorderLevel;
  final int surplusQuantity;
  final int safeTransferQuantity;
  final int remainingBuffer;
  final double coveragePercentage;
  final String riskAfterTransfer;
  final double distanceKm;
  final int estimatedTimeMinutes;
  final double estimatedTransferCost;
}

class MovementStatusEvent {
  const MovementStatusEvent({required this.status, required this.time});

  factory MovementStatusEvent.fromJson(Map<String, dynamic> json) =>
      MovementStatusEvent(
        status: json['status']?.toString() ?? 'UNKNOWN',
        time: DateTime.tryParse(json['time']?.toString() ?? ''),
      );

  final String status;
  final DateTime? time;
}
