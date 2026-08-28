import 'package:flutter/material.dart';

class ForecastSelectionSummary extends StatelessWidget {
  const ForecastSelectionSummary({
    required this.showroom,
    required this.product,
    required this.forecastType,
    required this.sellingPrice,
    required this.promotion,
    required this.submitting,
    required this.onGenerate,
    this.dateRange,
    super.key,
  });

  final String showroom;
  final String product;
  final String forecastType;
  final String sellingPrice;
  final String promotion;
  final String? dateRange;
  final bool submitting;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE1E6EF)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final details = Wrap(
          spacing: 24,
          runSpacing: 14,
          children: [
            _SummaryValue(label: 'Showroom', value: showroom),
            _SummaryValue(label: 'Product', value: product),
            _SummaryValue(label: 'Forecast', value: forecastType),
            _SummaryValue(label: 'Selling price', value: sellingPrice),
            _SummaryValue(label: 'Promotion', value: promotion),
            if (dateRange != null)
              _SummaryValue(label: 'Date range', value: dateRange!),
          ],
        );
        final button = FilledButton.icon(
          onPressed: submitting ? null : onGenerate,
          icon: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_graph),
          label: Text(
            submitting ? 'Generating forecast…' : 'Generate forecast',
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Review selection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            details,
            const SizedBox(height: 18),
            Align(
              alignment: constraints.maxWidth < 520
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: button,
            ),
          ],
        );
      },
    ),
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
