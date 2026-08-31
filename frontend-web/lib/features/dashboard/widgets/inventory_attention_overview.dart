import 'package:flutter/material.dart';

class InventoryAttentionOverview extends StatelessWidget {
  const InventoryAttentionOverview({
    required this.totalRecords,
    required this.lowStock,
    required this.overstock,
    super.key,
  });

  final int totalRecords;
  final int lowStock;
  final int overstock;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory attention profile',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Independent rates across $totalRecords inventory records',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _AttentionRing(
                    label: 'Low stock',
                    value: lowStock,
                    total: totalRecords,
                    color: const Color(0xFFD92D20),
                  ),
                ),
                Container(width: 1, height: 84, color: const Color(0xFFE1E6EF)),
                Expanded(
                  child: _AttentionRing(
                    label: 'Overstock',
                    value: overstock,
                    total: totalRecords,
                    color: const Color(0xFFF79009),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Each percentage is measured separately against all inventory '
            'records. A record may meet more than one attention condition.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _AttentionRing extends StatelessWidget {
  const _AttentionRing({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 82,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: ratio,
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.1),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${(ratio * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
