class DashboardSummary {
  const DashboardSummary({
    required this.totalProducts,
    required this.totalStores,
    required this.totalInventoryRecords,
    required this.totalInventoryQuantity,
    required this.totalInventoryValue,
    required this.totalPotentialRevenue,
    required this.totalPotentialProfit,
    required this.lowStockItems,
    required this.overstockItems,
    required this.lastUpdated,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalProducts: _asInt(json, 'total_products'),
      totalStores: _asInt(json, 'total_stores'),
      totalInventoryRecords: _asInt(json, 'total_inventory_records'),
      totalInventoryQuantity: _asInt(json, 'total_inventory_quantity'),
      totalInventoryValue: _asDouble(json, 'total_inventory_value'),
      totalPotentialRevenue: _asDouble(json, 'total_potential_revenue'),
      totalPotentialProfit: _asDouble(json, 'total_potential_profit'),
      lowStockItems: _asInt(json, 'low_stock_items'),
      overstockItems: _asInt(json, 'overstock_items'),
      lastUpdated: DateTime.tryParse(json['last_updated']?.toString() ?? ''),
    );
  }

  final int totalProducts;
  final int totalStores;
  final int totalInventoryRecords;
  final int totalInventoryQuantity;
  final double totalInventoryValue;
  final double totalPotentialRevenue;
  final double totalPotentialProfit;
  final int lowStockItems;
  final int overstockItems;
  final DateTime? lastUpdated;

  static int _asInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toInt();
    throw FormatException('Invalid or missing $key');
  }

  static double _asDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toDouble();
    throw FormatException('Invalid or missing $key');
  }
}
