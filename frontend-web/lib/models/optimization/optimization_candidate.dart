/// Summary counters returned by the optimization candidate service.
class OptimizationSummary {
  const OptimizationSummary({
    required this.total,
    required this.highPriority,
    required this.mediumPriority,
    required this.lowStock,
    required this.overstock,
    required this.pending,
    required this.recommended,
  });
  factory OptimizationSummary.fromJson(Map<String, dynamic> json) =>
      OptimizationSummary(
        total: _int(json, 'total_candidates'),
        highPriority: _int(json, 'high_priority'),
        mediumPriority: _int(json, 'medium_priority'),
        lowStock: _int(json, 'low_stock'),
        overstock: _int(json, 'overstock'),
        pending: _int(json, 'pending'),
        recommended: _int(json, 'recommended'),
      );
  final int total;
  final int highPriority;
  final int mediumPriority;
  final int lowStock;
  final int overstock;
  final int pending;
  final int recommended;
  static int _int(Map<String, dynamic> json, String key) =>
      (json[key] as num?)?.toInt() ?? 0;
}

/// One safe source-store option returned by the decision engine.
class QualifiedSourceStore {
  const QualifiedSourceStore({
    required this.storeId,
    required this.currentStock,
    required this.reorderLevel,
    required this.surplusQuantity,
    required this.possibleTransferQuantity,
    required this.stockAfterTransfer,
  });
  factory QualifiedSourceStore.fromJson(Map<String, dynamic> json) =>
      QualifiedSourceStore(
        storeId: json['store_id']?.toString() ?? 'Unknown',
        currentStock: (json['current_stock'] as num?)?.toInt() ?? 0,
        reorderLevel: (json['reorder_level'] as num?)?.toInt() ?? 0,
        surplusQuantity: (json['surplus_qty'] as num?)?.toInt() ?? 0,
        possibleTransferQuantity:
            (json['possible_transfer_qty'] as num?)?.toInt() ?? 0,
        stockAfterTransfer:
            (json['stock_after_transfer'] as num?)?.toInt() ?? 0,
      );
  final String storeId;
  final int currentStock;
  final int reorderLevel;
  final int surplusQuantity;
  final int possibleTransferQuantity;
  final int stockAfterTransfer;
}

/// Candidate and optional decision fields stored by the optimization engine.
class OptimizationCandidate {
  const OptimizationCandidate({
    required this.id,
    required this.productId,
    required this.productName,
    required this.storeId,
    required this.category,
    required this.brand,
    required this.currentStock,
    required this.reorderLevel,
    required this.maxStock,
    required this.shortageQuantity,
    required this.surplusQuantity,
    required this.stockHealth,
    required this.type,
    required this.priority,
    required this.status,
    required this.recommendedAction,
    required this.decisionReason,
    required this.sources,
    this.decisionConfidence,
    this.coverageRatio,
    this.transferFeasibility,
    this.transferReady,
  });

  factory OptimizationCandidate.fromJson(Map<String, dynamic> json) {
    final id = (json['candidate_id'] ?? json['id'])?.toString();
    final productId = json['product_id']?.toString();
    final storeId = json['store_id']?.toString();
    if (id == null || productId == null || storeId == null) {
      throw const FormatException('Invalid optimization candidate');
    }
    final sourceItems = json['qualified_source_details'];
    return OptimizationCandidate(
      id: id,
      productId: productId,
      productName: json['product_name']?.toString() ?? productId,
      storeId: storeId,
      category: json['category']?.toString() ?? 'Unknown',
      brand: json['brand']?.toString() ?? 'Unknown',
      currentStock: _int(json, 'current_stock'),
      reorderLevel: _int(json, 'reorder_level'),
      maxStock: _int(json, 'max_stock'),
      shortageQuantity: _int(json, 'shortage_qty'),
      surplusQuantity: _int(json, 'surplus_qty'),
      stockHealth: json['stock_health']?.toString() ?? 'Unknown',
      type: json['candidate_type']?.toString() ?? 'UNKNOWN',
      priority: json['priority']?.toString() ?? 'LOW',
      status: json['status']?.toString() ?? 'PENDING',
      recommendedAction: json['recommended_action']?.toString() ?? 'PENDING',
      decisionReason: json['decision_reason']?.toString() ?? '',
      decisionConfidence: (json['decision_confidence'] as num?)?.toInt(),
      coverageRatio: (json['coverage_ratio'] as num?)?.toDouble(),
      transferFeasibility: json['transfer_feasibility']?.toString(),
      transferReady: json['transfer_ready'] as bool?,
      sources: sourceItems is List
          ? sourceItems
                .map(
                  (item) => QualifiedSourceStore.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList()
          : const [],
    );
  }

  final String id;
  final String productId;
  final String productName;
  final String storeId;
  final String category;
  final String brand;
  final int currentStock;
  final int reorderLevel;
  final int maxStock;
  final int shortageQuantity;
  final int surplusQuantity;
  final String stockHealth;
  final String type;
  final String priority;
  final String status;
  final String recommendedAction;
  final String decisionReason;
  final int? decisionConfidence;
  final double? coverageRatio;
  final String? transferFeasibility;
  final bool? transferReady;
  final List<QualifiedSourceStore> sources;

  /// A transfer is actionable only when the backend confirms a real shortage,
  /// transfer readiness, and at least one positive transfer quantity.
  bool get hasActionableTransfer =>
      recommendedAction == 'TRANSFER' &&
      shortageQuantity > 0 &&
      transferReady == true &&
      sources.any((source) => source.possibleTransferQuantity > 0);

  bool get hasInconsistentTransferDecision =>
      recommendedAction == 'TRANSFER' && !hasActionableTransfer;

  List<QualifiedSourceStore> get actionableSources =>
      sources.where((source) => source.possibleTransferQuantity > 0).toList();

  static int _int(Map<String, dynamic> json, String key) =>
      (json[key] as num?)?.toInt() ?? 0;
}

class OptimizationOverview {
  const OptimizationOverview({required this.summary, required this.candidates});
  final OptimizationSummary summary;
  final List<OptimizationCandidate> candidates;
}
