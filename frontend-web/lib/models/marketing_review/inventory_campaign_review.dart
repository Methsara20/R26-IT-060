class InventoryCampaignReview {
  const InventoryCampaignReview({
    required this.requestId,
    required this.campaignReference,
    required this.campaignName,
    required this.productId,
    required this.storeId,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.promotionType,
    this.discountPercent,
    this.assessment,
    this.review,
    this.rejectionReason,
  });

  factory InventoryCampaignReview.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty || value != value.trim()) {
        throw FormatException('Invalid campaign review $key.');
      }
      return value;
    }

    final status = requiredString('request_status');
    const statuses = {
      'PENDING_REVIEW',
      'PROCESSING',
      'COMPLETED',
      'COMPLETE',
      'REJECTED',
      'FAILED',
      'UNSUPPORTED_PERIOD',
    };
    if (!statuses.contains(status)) {
      throw const FormatException('Invalid campaign review status.');
    }
    final discount = json['discount_percent'];
    if (discount != null && discount is! num) {
      throw const FormatException('Invalid campaign discount.');
    }
    return InventoryCampaignReview(
      requestId: requiredString('request_id'),
      campaignReference: requiredString('campaign_reference'),
      campaignName: requiredString('campaign_name'),
      productId: requiredString('product_id'),
      storeId: requiredString('store_id'),
      startDate: DateTime.parse(requiredString('campaign_start_date')),
      endDate: DateTime.parse(requiredString('campaign_end_date')),
      status: status == 'COMPLETE' ? 'COMPLETED' : status,
      promotionType: json['promotion_type'] as String?,
      discountPercent: (discount as num?)?.toDouble(),
      assessment: json['assessment'] is Map<String, dynamic>
          ? CampaignAssessment.fromJson(json['assessment'])
          : null,
      review: json['review'] is Map<String, dynamic>
          ? CampaignReviewer.fromJson(json['review'])
          : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  final String requestId, campaignReference, campaignName, productId, storeId;
  final DateTime startDate, endDate;
  final String status;
  final String? promotionType, rejectionReason;
  final double? discountPercent;
  final CampaignAssessment? assessment;
  final CampaignReviewer? review;
  bool get pending => status == 'PENDING_REVIEW';
}

class CampaignAssessment {
  const CampaignAssessment({
    this.availableStock,
    this.forecastDemand,
    this.forecastStartDate,
    this.forecastEndDate,
    this.stockSufficiency,
    this.assessmentStatus,
    this.explanation,
    this.forecastBasis,
    required this.promotionAdjusted,
  });
  factory CampaignAssessment.fromJson(Map<String, dynamic> json) =>
      CampaignAssessment(
        availableStock: (json['available_stock'] as num?)?.toDouble(),
        forecastDemand: (json['forecast_demand'] as num?)?.toDouble(),
        forecastStartDate: json['forecast_start_date'] as String?,
        forecastEndDate: json['forecast_end_date'] as String?,
        stockSufficiency: json['stock_sufficiency'] as String?,
        assessmentStatus: json['assessment_status'] as String?,
        explanation: json['explanation'] as String?,
        forecastBasis: json['forecast_basis'] as String?,
        promotionAdjusted: json['promotion_adjusted'] == true,
      );
  final double? availableStock, forecastDemand;
  final String? forecastStartDate,
      forecastEndDate,
      stockSufficiency,
      assessmentStatus,
      explanation,
      forecastBasis;
  final bool promotionAdjusted;
}

class CampaignReviewer {
  const CampaignReviewer(this.name, this.role, this.decision, this.decidedAt);
  factory CampaignReviewer.fromJson(Map<String, dynamic> json) {
    final display = json['reviewer_display_name_snapshot'];
    final username = json['reviewer_username_snapshot'];
    return CampaignReviewer(
      display is String && display.isNotEmpty
          ? display
          : username is String && username.isNotEmpty
          ? username
          : 'Reviewer unavailable',
      json['reviewer_role_snapshot'] as String?,
      json['decision'] as String?,
      json['decided_at'] as String?,
    );
  }
  final String name;
  final String? role, decision, decidedAt;
}

class InventoryCampaignReviewPage {
  const InventoryCampaignReviewPage(
    this.items,
    this.total,
    this.skip,
    this.limit,
  );
  factory InventoryCampaignReviewPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List ||
        json['total'] is! int ||
        json['skip'] is! int ||
        json['limit'] is! int) {
      throw const FormatException('Invalid campaign review page.');
    }
    return InventoryCampaignReviewPage(
      items
          .map(
            (item) => InventoryCampaignReview.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      json['total'],
      json['skip'],
      json['limit'],
    );
  }
  final List<InventoryCampaignReview> items;
  final int total, skip, limit;
}
