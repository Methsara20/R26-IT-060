class InventoryAnalysisAssessment {
  const InventoryAnalysisAssessment({
    this.availableStock,
    this.forecastDemand,
    this.forecastStart,
    this.forecastEnd,
    this.stockSufficiency,
    this.explanation,
    this.status,
  });
  factory InventoryAnalysisAssessment.fromJson(Map<String, dynamic> json) =>
      InventoryAnalysisAssessment(
        availableStock: (json['available_stock'] as num?)?.toDouble(),
        forecastDemand: (json['forecast_demand'] as num?)?.toDouble(),
        forecastStart: json['forecast_start_date']?.toString(),
        forecastEnd: json['forecast_end_date']?.toString(),
        stockSufficiency: json['stock_sufficiency']?.toString(),
        explanation: json['explanation']?.toString(),
        status: json['assessment_status']?.toString(),
      );
  final double? availableStock;
  final double? forecastDemand;
  final String? forecastStart;
  final String? forecastEnd;
  final String? stockSufficiency;
  final String? explanation;
  final String? status;
}

class InventoryAnalysisRequest {
  const InventoryAnalysisRequest({
    required this.requestId,
    required this.status,
    required this.productId,
    required this.storeId,
    required this.campaignName,
    required this.campaignReference,
    required this.campaignStartDate,
    required this.campaignEndDate,
    this.promotionType,
    this.discountPercent,
    this.rejectionReason,
    this.assessment,
  });
  factory InventoryAnalysisRequest.fromJson(Map<String, dynamic> json) {
    final id = json['request_id'];
    final status = json['request_status'];
    final product = json['product_id'];
    final store = json['store_id'];
    final name = json['campaign_name'];
    final reference = json['campaign_reference'];
    final start = json['campaign_start_date'];
    final end = json['campaign_end_date'];
    if (id is! String ||
        status is! String ||
        product is! String ||
        store is! String ||
        name is! String ||
        reference is! String ||
        start is! String ||
        end is! String) {
      throw const FormatException('Invalid campaign analysis response.');
    }
    final normalized = status == 'COMPLETE' ? 'COMPLETED' : status;
    final assessment = json['assessment'];
    return InventoryAnalysisRequest(
      requestId: id,
      status: normalized,
      productId: product,
      storeId: store,
      campaignName: name,
      campaignReference: reference,
      campaignStartDate: start,
      campaignEndDate: end,
      promotionType: json['promotion_type']?.toString(),
      discountPercent: (json['discount_percent'] as num?)?.toDouble(),
      rejectionReason: json['rejection_reason']?.toString(),
      assessment: assessment is Map
          ? InventoryAnalysisAssessment.fromJson(
              Map<String, dynamic>.from(assessment),
            )
          : null,
    );
  }
  final String requestId;
  final String status;
  final String productId;
  final String storeId;
  final String campaignName;
  final String campaignReference;
  final String campaignStartDate;
  final String campaignEndDate;
  final String? promotionType;
  final double? discountPercent;
  final String? rejectionReason;
  final InventoryAnalysisAssessment? assessment;
}

class InventoryAnalysisHistory {
  const InventoryAnalysisHistory({
    required this.items,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory InventoryAnalysisHistory.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final total = json['total'];
    final skip = json['skip'];
    final limit = json['limit'];
    if (items is! List || total is! int || skip is! int || limit is! int) {
      throw const FormatException('Invalid campaign history response.');
    }
    return InventoryAnalysisHistory(
      items: items
          .map(
            (item) => InventoryAnalysisRequest.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      total: total,
      skip: skip,
      limit: limit,
    );
  }

  final List<InventoryAnalysisRequest> items;
  final int total;
  final int skip;
  final int limit;
}

class MarketingCatalogChoice {
  const MarketingCatalogChoice(this.id, this.name);
  final String id;
  final String name;
  String get label => '$name ($id)';
}
