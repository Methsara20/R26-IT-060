import 'package:flutter/material.dart';

import '../../models/forecast/short_range_forecast.dart';

/// Compact, responsive headline metrics for a generated forecast.
class ForecastResultSummary extends StatelessWidget {
  const ForecastResultSummary({required this.result, super.key});

  final ShortRangeForecast result;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE1E7F0)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 560;
        final metrics = [
          _Metric(
            value: '${result.totalPredictedDemand} units',
            label: result.days.length == 1
                ? 'Forecast demand'
                : 'Total forecast demand',
            icon: Icons.inventory_2_outlined,
          ),
          _Metric(
            value: '${result.averageConfidencePercentage}%',
            label: 'Average confidence',
            icon: Icons.verified_outlined,
          ),
          _Metric(
            value: result.weatherSource ?? 'Weather integrated',
            label: 'Weather source',
            icon: Icons.cloud_outlined,
          ),
        ];
        return Flex(
          direction: vertical ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < metrics.length; index++) ...[
              if (index > 0)
                vertical
                    ? const Divider(height: 24)
                    : const SizedBox(
                        height: 52,
                        child: VerticalDivider(width: 32),
                      ),
              if (vertical) metrics[index] else Expanded(child: metrics[index]),
            ],
          ],
        );
      },
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary, size: 21),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}
