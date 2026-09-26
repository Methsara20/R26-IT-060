import 'package:flutter/material.dart';

import '../../models/forecast/forecast_catalog_option.dart';
import '../../models/inventory/inventory_record.dart';
import 'inventory_current_health.dart';

class InventoryAttentionSection extends StatefulWidget {
  const InventoryAttentionSection({
    required this.records,
    required this.products,
    required this.onOpenProduct,
    required this.onViewAll,
    super.key,
  });

  final List<InventoryRecord> records;
  final Map<String, ForecastProductOption> products;
  final ValueChanged<InventoryRecord> onOpenProduct;
  final VoidCallback onViewAll;

  @override
  State<InventoryAttentionSection> createState() =>
      _InventoryAttentionSectionState();
}

class _InventoryAttentionSectionState extends State<InventoryAttentionSection> {
  InventoryCurrentHealth? _filter;

  List<InventoryRecord> get _items {
    final items = widget.records.where((record) {
      final health = inventoryCurrentHealth(record);
      return health != InventoryCurrentHealth.healthy &&
          (_filter == null || health == _filter);
    }).toList();
    items.sort((left, right) {
      final leftHealth = inventoryCurrentHealth(left);
      final rightHealth = inventoryCurrentHealth(right);
      final healthOrder = _priority(
        leftHealth,
      ).compareTo(_priority(rightHealth));
      if (healthOrder != 0) return healthOrder;
      if (leftHealth == InventoryCurrentHealth.lowStock) {
        final leftGap = left.reorderLevel - left.currentStock;
        final rightGap = right.reorderLevel - right.currentStock;
        return rightGap.compareTo(leftGap);
      }
      return left.currentStock.compareTo(right.currentStock);
    });
    return items;
  }

  int _priority(InventoryCurrentHealth health) => switch (health) {
    InventoryCurrentHealth.stockout => 0,
    InventoryCurrentHealth.lowStock => 1,
    InventoryCurrentHealth.overstock => 2,
    InventoryCurrentHealth.healthy => 3,
  };

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Needs attention', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        Text(
          'Highest-priority current inventory exceptions.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
            for (final health in const [
              InventoryCurrentHealth.stockout,
              InventoryCurrentHealth.lowStock,
              InventoryCurrentHealth.overstock,
            ])
              ChoiceChip(
                label: Text(health.label),
                selected: _filter == health,
                onSelected: (_) => setState(() => _filter = health),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const _NoAttentionItems()
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 780 ? 2 : 1;
              const gap = 12.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final record in items.take(8))
                    SizedBox(
                      width: width,
                      child: _AttentionItem(
                        record: record,
                        product: widget.products[record.productId],
                        onTap: () => widget.onOpenProduct(record),
                      ),
                    ),
                ],
              );
            },
          ),
        if (items.length > 8) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: widget.onViewAll,
            icon: const Icon(Icons.arrow_forward),
            label: Text('View all ${items.length} attention items'),
          ),
        ],
      ],
    );
  }
}

class _AttentionItem extends StatelessWidget {
  const _AttentionItem({
    required this.record,
    required this.product,
    required this.onTap,
  });
  final InventoryRecord record;
  final ForecastProductOption? product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final health = inventoryCurrentHealth(record);
    final color = switch (health) {
      InventoryCurrentHealth.stockout => const Color(0xFFD92D20),
      InventoryCurrentHealth.lowStock => const Color(0xFFDC6803),
      InventoryCurrentHealth.overstock => const Color(0xFF7A5AF8),
      InventoryCurrentHealth.healthy => const Color(0xFF17875D),
    };
    final explanation = switch (health) {
      InventoryCurrentHealth.stockout => 'No stock is currently available.',
      InventoryCurrentHealth.lowStock =>
        '${record.reorderLevel - record.currentStock} units below the reorder level.',
      InventoryCurrentHealth.overstock =>
        'Stock has reached the configured overstock threshold.',
      InventoryCurrentHealth.healthy =>
        'Stock is within the configured operating range.',
    };
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product?.name ?? record.productId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      health.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                record.productId,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 22,
                runSpacing: 8,
                children: [
                  _Value('Current stock', '${record.currentStock}'),
                  _Value('Reorder level', '${record.reorderLevel}'),
                  _Value('Maximum stock', '${record.maxStock}'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                explanation,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onTap,
                  child: const Text('View intelligence'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

class _NoAttentionItems extends StatelessWidget {
  const _NoAttentionItems();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FAF5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.check_circle_outline, color: Color(0xFF17875D)),
        SizedBox(width: 10),
        Expanded(
          child: Text('No inventory records match this attention filter.'),
        ),
      ],
    ),
  );
}
