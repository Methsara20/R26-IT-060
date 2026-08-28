import 'dashboard_summary.dart';

class AnalyticsOverview {
  const AnalyticsOverview({
    required this.dashboard,
    required this.showrooms,
    required this.categories,
    required this.brands,
    required this.genders,
    required this.lowStockItems,
    required this.overstockItems,
    required this.highValueItems,
  });

  final DashboardSummary dashboard;
  final List<AnalyticsBreakdown> showrooms;
  final List<AnalyticsBreakdown> categories;
  final List<AnalyticsBreakdown> brands;
  final List<AnalyticsBreakdown> genders;
  final List<AnalyticsAlertItem> lowStockItems;
  final List<AnalyticsAlertItem> overstockItems;
  final List<AnalyticsAlertItem> highValueItems;
}

class AnalyticsBreakdown {
  const AnalyticsBreakdown({
    required this.id,
    required this.label,
    required this.totalStock,
    required this.inventoryValue,
    required this.potentialRevenue,
    required this.potentialProfit,
    required this.lowStockItems,
    required this.overstockItems,
    this.secondaryLabel,
  });

  factory AnalyticsBreakdown.fromJson(
    Map<String, dynamic> json, {
    required String labelKey,
    String? secondaryKey,
  }) {
    final id = json['id']?.toString() ?? json[labelKey]?.toString();
    final label = json[labelKey]?.toString() ?? id;
    if (id == null || label == null) {
      throw FormatException('Missing analytics label: $labelKey');
    }
    return AnalyticsBreakdown(
      id: id,
      label: label,
      secondaryLabel: secondaryKey == null
          ? null
          : json[secondaryKey]?.toString(),
      totalStock: _int(json['total_stock']),
      inventoryValue: _double(json['inventory_value']),
      potentialRevenue: _double(json['potential_revenue']),
      potentialProfit: _double(json['potential_profit']),
      lowStockItems: _int(json['low_stock_items']),
      overstockItems: _int(json['overstock_items']),
    );
  }

  final String id;
  final String label;
  final String? secondaryLabel;
  final int totalStock;
  final double inventoryValue;
  final double potentialRevenue;
  final double potentialProfit;
  final int lowStockItems;
  final int overstockItems;
}

class AnalyticsAlertItem {
  const AnalyticsAlertItem({
    required this.inventoryId,
    required this.productId,
    required this.productName,
    required this.storeId,
    required this.category,
    required this.brand,
    required this.currentStock,
    required this.reorderLevel,
    required this.maximumStock,
  });

  factory AnalyticsAlertItem.fromJson(Map<String, dynamic> json) {
    return AnalyticsAlertItem(
      inventoryId: (json['inventory_id'] ?? json['id'])?.toString() ?? '—',
      productId: json['product_id']?.toString() ?? '—',
      productName: json['product_name']?.toString() ?? 'Unnamed product',
      storeId: json['store_id']?.toString() ?? '—',
      category: json['category']?.toString() ?? 'Unspecified',
      brand: json['brand']?.toString() ?? 'Unspecified',
      currentStock: _int(json['current_stock']),
      reorderLevel: _int(json['reorder_level']),
      maximumStock: _int(json['max_stock']),
    );
  }

  final String inventoryId;
  final String productId;
  final String productName;
  final String storeId;
  final String category;
  final String brand;
  final int currentStock;
  final int reorderLevel;
  final int maximumStock;
}

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

double _double(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
