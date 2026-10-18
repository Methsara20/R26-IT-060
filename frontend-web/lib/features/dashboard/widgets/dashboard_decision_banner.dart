import 'package:flutter/material.dart';

/// High-level deterministic inventory decision summary.
class DashboardDecisionBanner extends StatelessWidget {
  const DashboardDecisionBanner({
    required this.lowStockCount,
    required this.overstockCount,
    required this.onViewInventory,
    required this.onReviewOptimization,
    super.key,
  });

  final int lowStockCount;
  final int overstockCount;
  final VoidCallback onViewInventory;
  final VoidCallback onReviewOptimization;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF182B4B) : const Color(0xFFEDF4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? const Color(0xFF35578C) : const Color(0xFFBFD2FF),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A155EEF),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF155EEF),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.auto_graph_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'INVENTORY DECISION OVERVIEW',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: dark
                          ? const Color(0xFF8FB1FF)
                          : const Color(0xFF1849A9),
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '$lowStockCount low-stock records require attention',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 5),
              Text(
                '$overstockCount records are above the configured overstock threshold.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onViewInventory,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('View inventory'),
              ),
              OutlinedButton.icon(
                onPressed: onReviewOptimization,
                icon: const Icon(Icons.hub_outlined),
                label: const Text('Review optimization'),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 20), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 24),
              actions,
            ],
          );
        },
      ),
    );
  }
}
