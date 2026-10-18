class MarketingOpportunityRequest {
  const MarketingOpportunityRequest({
    required this.workflowId,
    required this.productId,
    required this.productName,
    required this.storeId,
    required this.currentStock,
    required this.forecastDemand,
    required this.requiredStock,
    required this.excessQuantity,
    required this.stockHealth,
    required this.recommendedAction,
    this.category,
    this.subcategory,
    this.brand,
    this.gender,
    this.sellingPrice,
    this.promotionPercent,
  });

  final String workflowId;
  final String productId;
  final String productName;
  final String storeId;
  final String? category;
  final String? subcategory;
  final String? brand;
  final String? gender;
  final int currentStock;
  final int forecastDemand;
  final int requiredStock;
  final int excessQuantity;
  final double? sellingPrice;
  final double? promotionPercent;
  final String stockHealth;
  final String recommendedAction;

  Map<String, dynamic> toJson() => {
    'workflow_id': workflowId,
    'product_id': productId,
    'product_name': productName,
    'store_id': storeId,
    'category': category,
    'subcategory': subcategory,
    'brand': brand,
    'gender': gender,
    'current_stock': currentStock,
    'forecast_demand': forecastDemand,
    'required_stock': requiredStock,
    'excess_quantity': excessQuantity,
    'selling_price': sellingPrice,
    if (promotionPercent != null) 'promotion_percent': promotionPercent,
    'stock_health': stockHealth,
    'recommended_action': recommendedAction,
  };
}

class MarketingOpportunityResponse {
  const MarketingOpportunityResponse({
    required this.opportunityId,
    required this.workflowId,
    required this.status,
    required this.message,
  });

  factory MarketingOpportunityResponse.fromJson(Map<String, dynamic> json) {
    final opportunityId = json['opportunity_id'];
    final workflowId = json['workflow_id'];
    final status = json['status'];
    final message = json['message'];
    if (opportunityId is! String ||
        opportunityId.isEmpty ||
        workflowId is! String ||
        workflowId.isEmpty ||
        status is! String ||
        status.isEmpty ||
        message is! String ||
        message.isEmpty) {
      throw const FormatException('Invalid marketing opportunity response.');
    }
    return MarketingOpportunityResponse(
      opportunityId: opportunityId,
      workflowId: workflowId,
      status: status,
      message: message,
    );
  }

  final String opportunityId;
  final String workflowId;
  final String status;
  final String message;
}
