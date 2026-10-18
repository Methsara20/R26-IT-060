import 'package:flutter/material.dart';
import '../../../core/theme/application_design_tokens.dart';
import '../../../core/widgets/application_ui_components.dart';

/// Dashboard-specific visual treatment; all values and actions are supplied.
class ExecutiveInventoryOverview extends StatelessWidget {
  const ExecutiveInventoryOverview({
    required this.lowStockCount,
    required this.overstockCount,
    required this.onViewInventory,
    required this.onReviewOptimization,
    super.key,
  });
  final int lowStockCount, overstockCount;
  final VoidCallback onViewInventory, onReviewOptimization;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark
        ? ApplicationColors.darkText
        : ApplicationColors.lightText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              ApplicationColors.coreAccent.withValues(alpha: dark ? .18 : .08),
              ApplicationColors.panel(context),
            ),
            Color.alphaBlend(
              ApplicationColors.indigo.withValues(alpha: dark ? .12 : .03),
              ApplicationColors.panel(context),
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(ApplicationRadii.largeSurface),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .18),
        ),
        boxShadow: ApplicationElevation.forBrightness(
          Theme.of(context).brightness,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.auto_graph_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              Text(
                'INVENTORY DECISION OVERVIEW',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '$lowStockCount low-stock records require attention',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$overstockCount records are above the configured overstock threshold.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
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
          ),
        ],
      ),
    );
  }
}

class PremiumDashboardMetric extends StatelessWidget {
  const PremiumDashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
    super.key,
  });
  final String label, value;
  final String? caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => ApplicationSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Tooltip(
          message: value,
          child: Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(caption ?? '', style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class DashboardAttentionProfile extends StatelessWidget {
  const DashboardAttentionProfile({
    required this.totalRecords,
    required this.lowStock,
    required this.overstock,
    super.key,
  });
  final int totalRecords, lowStock, overstock;

  @override
  Widget build(BuildContext context) => ApplicationSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inventory attention profile',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Independent rates across $totalRecords inventory records',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final rings = [
              _Ring(
                label: 'Low stock',
                value: lowStock,
                total: totalRecords,
                tone: ApplicationStatusColor.danger,
              ),
              _Ring(
                label: 'Overstock',
                value: overstock,
                total: totalRecords,
                tone: ApplicationStatusColor.warning,
              ),
            ];
            return Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                for (final ring in rings)
                  SizedBox(
                    width: constraints.maxWidth < 260
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 24) / 2,
                    child: ring,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Each percentage is measured separately against all inventory records. A record may meet more than one attention condition.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.label,
    required this.value,
    required this.total,
    required this.tone,
  });
  final String label;
  final int value, total;
  final ApplicationStatusColor tone;
  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    final color = ApplicationColors.status(context, tone);
    return Column(
      children: [
        Semantics(
          label:
              '$label: $value records, ${(ratio * 100).toStringAsFixed(1)} percent',
          child: SizedBox.square(
            dimension: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: color.withValues(alpha: .12),
                  ),
                ),
                Text(
                  '${(ratio * 100).toStringAsFixed(1)}%',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text('$value records', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
