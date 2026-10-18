import 'package:flutter/material.dart';

import '../../../models/analytics/analytics_overview.dart';

class AttentionRequiredPanel extends StatelessWidget {
  const AttentionRequiredPanel({
    required this.lowStockItems,
    required this.overstockItems,
    required this.onViewAll,
    required this.onReview,
    super.key,
  });

  final List<AnalyticsAlertItem> lowStockItems;
  final List<AnalyticsAlertItem> overstockItems;
  final VoidCallback onViewAll;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final entries = <({AnalyticsAlertItem item, bool lowStock})>[
      ...lowStockItems.map((item) => (item: item, lowStock: true)),
      ...overstockItems.map((item) => (item: item, lowStock: false)),
    ].take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Attention required',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(onPressed: onViewAll, child: const Text('View all')),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Priority inventory records requiring manager investigation',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            if (entries.isEmpty)
              const _EmptyAttentionState()
            else
              for (var index = 0; index < entries.length; index++) ...[
                _AttentionRow(entry: entries[index], onReview: onReview),
                if (index != entries.length - 1) const SizedBox(height: 9),
              ],
          ],
        ),
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.entry, required this.onReview});
  final ({AnalyticsAlertItem item, bool lowStock}) entry;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final color = entry.lowStock
        ? const Color(0xFFD92D20)
        : const Color(0xFFF79009);
    final issue = entry.lowStock ? 'Low stock' : 'Overstock';
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                entry.lowStock
                    ? Icons.trending_down_rounded
                    : Icons.inventory_outlined,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${item.productId} • ${item.storeId}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          issue.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.currentStock} units',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  entry.lowStock
                      ? 'Reorder ${item.reorderLevel}'
                      : 'Maximum ${item.maximumStock}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (constraints.maxWidth >= 560) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onReview,
                child: const Text('Review →'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyAttentionState extends StatelessWidget {
  const _EmptyAttentionState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 34),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 34,
          ),
          const SizedBox(height: 10),
          const Text('No alert records currently require attention.'),
        ],
      ),
    ),
  );
}
