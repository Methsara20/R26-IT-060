import 'package:flutter/material.dart';

import '../../models/inventory/inventory_record.dart';

/// Current-snapshot KPIs derived from the showroom inventory response already
/// loaded by the parent screen. This widget performs no network requests.
class ShowroomInventoryKpiSummary extends StatelessWidget {
  const ShowroomInventoryKpiSummary({required this.records, super.key});

  final List<InventoryRecord> records;

  @override
  Widget build(BuildContext context) {
    final units = records.fold<int>(0, (sum, item) => sum + item.currentStock);
    final stockouts = records.where((item) => item.currentStock <= 0).length;
    final lowStock = records
        .where((item) => item.currentStock <= item.reorderLevel)
        .length;
    final overstock = records
        .where(
          (item) =>
              item.maxStock > 0 && item.currentStock >= item.maxStock * 0.85,
        )
        .length;
    final values = [
      _Kpi(
        'Inventory records',
        '${records.length}',
        'Showroom-product records',
        Icons.dataset_outlined,
        const Color(0xFF475467),
      ),
      _Kpi(
        'Closing inventory',
        '$units units',
        'Current snapshot',
        Icons.inventory_2_outlined,
        const Color(0xFF0E9384),
      ),
      _Kpi(
        'Stockout records',
        '$stockouts',
        'Current stock is zero',
        Icons.remove_shopping_cart_outlined,
        const Color(0xFFD92D20),
      ),
      _Kpi(
        'Low-stock records',
        '$lowStock',
        'Includes stockouts',
        Icons.trending_down_rounded,
        const Color(0xFFDC6803),
      ),
      _Kpi(
        'Overstock records',
        '$overstock',
        'At least 85% of maximum',
        Icons.inventory_outlined,
        const Color(0xFF7A5AF8),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current inventory KPIs',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 5),
        Text(
          'Operational position for the selected showroom at the latest available snapshot.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 940
                ? 5
                : constraints.maxWidth >= 620
                ? 3
                : constraints.maxWidth >= 360
                ? 2
                : 1;
            const gap = 12.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final value in values)
                  SizedBox(
                    width: width,
                    child: _KpiTile(data: value),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.caption, this.icon, this.color);
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.data});
  final _Kpi data;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: data.color, size: 21),
          const SizedBox(height: 12),
          Text(data.value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(data.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(data.caption, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}
