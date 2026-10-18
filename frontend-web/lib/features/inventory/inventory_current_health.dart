import '../../models/inventory/inventory_record.dart';

/// Frontend presentation of the existing current-inventory thresholds.
/// Stockout is evaluated before low stock because zero stock is already a
/// subset of the backend's `current_stock <= reorder_level` low-stock rule.
enum InventoryCurrentHealth { healthy, stockout, lowStock, overstock }

InventoryCurrentHealth inventoryCurrentHealth(InventoryRecord record) {
  if (record.currentStock <= 0) return InventoryCurrentHealth.stockout;
  if (record.currentStock <= record.reorderLevel) {
    return InventoryCurrentHealth.lowStock;
  }
  if (record.maxStock > 0 && record.currentStock >= record.maxStock * 0.85) {
    return InventoryCurrentHealth.overstock;
  }
  return InventoryCurrentHealth.healthy;
}

extension InventoryCurrentHealthLabel on InventoryCurrentHealth {
  String get label => switch (this) {
    InventoryCurrentHealth.healthy => 'Healthy',
    InventoryCurrentHealth.stockout => 'Stockout',
    InventoryCurrentHealth.lowStock => 'Low Stock',
    InventoryCurrentHealth.overstock => 'Overstock',
  };
}
