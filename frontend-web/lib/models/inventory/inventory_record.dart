/// Current inventory values returned by `/inventory/store/{store_id}`.
class InventoryRecord {
  const InventoryRecord({
    required this.inventoryId,
    required this.storeId,
    required this.productId,
    required this.currentStock,
    required this.reorderLevel,
    required this.maxStock,
    required this.supplierLeadTime,
    this.lastUpdated,
  });


  factory InventoryRecord.fromJson(Map<String, dynamic> json) {
    final inventoryId = (json['inventory_id'] ?? json['id'])?.toString();
    final storeId = json['store_id']?.toString();
    final productId = json['product_id']?.toString();
    final currentStock = json['current_stock'];
    final reorderLevel = json['reorder_level'];
    final maxStock = json['max_stock'];
    final leadTime = json['supplier_lead_time'];
    if (inventoryId == null ||
        storeId == null ||
        productId == null ||
        currentStock is! num ||
        reorderLevel is! num ||
        maxStock is! num ||
        leadTime is! num) {
      throw const FormatException('Invalid inventory record');
    }
    return InventoryRecord(
      inventoryId: inventoryId,
      storeId: storeId,
      productId: productId,
      currentStock: currentStock.toInt(),
      reorderLevel: reorderLevel.toInt(),
      maxStock: maxStock.toInt(),
      supplierLeadTime: leadTime.toInt(),
      lastUpdated: json['last_updated']?.toString(),
    );
  }

  final String inventoryId;
  final String storeId;
  final String productId;
  final int currentStock;
  final int reorderLevel;
  final int maxStock;
  final int supplierLeadTime;
  final String? lastUpdated;
}
