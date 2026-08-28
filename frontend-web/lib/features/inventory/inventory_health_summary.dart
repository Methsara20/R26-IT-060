import 'package:flutter/material.dart';

import '../../models/inventory/inventory_record.dart';
import 'inventory_current_health.dart';

/// Non-overlapping operational health summary based on the current inventory
/// rules. Stockouts are not counted again as low-stock attention records.
class InventoryHealthSummary extends StatelessWidget {
  const InventoryHealthSummary({required this.records, super.key});
  final List<InventoryRecord> records;

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final value in InventoryCurrentHealth.values) value: 0,
    };
    for (final record in records) {
      final health = inventoryCurrentHealth(record);
      counts[health] = counts[health]! + 1;
    }
    final attention = records.length - counts[InventoryCurrentHealth.healthy]!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory health',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          Text(
            '$attention inventory record${attention == 1 ? '' : 's'} currently require attention.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HealthCount(
                health: InventoryCurrentHealth.healthy,
                count: counts[InventoryCurrentHealth.healthy]!,
                color: const Color(0xFF17875D),
              ),
              _HealthCount(
                health: InventoryCurrentHealth.stockout,
                count: counts[InventoryCurrentHealth.stockout]!,
                color: const Color(0xFFD92D20),
              ),
              _HealthCount(
                health: InventoryCurrentHealth.lowStock,
                count: counts[InventoryCurrentHealth.lowStock]!,
                color: const Color(0xFFDC6803),
              ),
              _HealthCount(
                health: InventoryCurrentHealth.overstock,
                count: counts[InventoryCurrentHealth.overstock]!,
                color: const Color(0xFF7A5AF8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthCount extends StatelessWidget {
  const _HealthCount({
    required this.health,
    required this.count,
    required this.color,
  });
  final InventoryCurrentHealth health;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 150),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '${health.label}: ',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          '$count',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
