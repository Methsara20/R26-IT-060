import 'package:flutter/material.dart';

import '../../core/theme/application_design_tokens.dart';

enum ForecastMode { daily, sevenDay, custom, monthly, quarterly }

class ForecastTypeSelector extends StatelessWidget {
  const ForecastTypeSelector({
    required this.selectedMode,
    required this.onChanged,
    super.key,
  });

  final ForecastMode selectedMode;
  final ValueChanged<ForecastMode> onChanged;

  static const _options = [
    (ForecastMode.daily, 'Daily', 'Tomorrow’s demand', Icons.today_outlined),
    (
      ForecastMode.sevenDay,
      '7-Day',
      'Short-term weekly outlook',
      Icons.date_range_outlined,
    ),
    (
      ForecastMode.custom,
      'Custom',
      'Choose your own date range',
      Icons.edit_calendar_outlined,
    ),
    (
      ForecastMode.monthly,
      'Monthly',
      'Strategic monthly planning',
      Icons.calendar_month_outlined,
    ),
    (
      ForecastMode.quarterly,
      'Quarterly',
      'Long-term inventory outlook',
      Icons.view_week_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1060
          ? 5
          : constraints.maxWidth >= 650
          ? 3
          : constraints.maxWidth >= 400
          ? 2
          : 1;
      const spacing = 10.0;
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose forecast horizon',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Operational forecasts support connected decisions. Strategic forecasts support longer-range planning.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (var index = 0; index < _options.length; index++)
                SizedBox(
                  width: width,
                  child: _ForecastTypeOption(
                    title: _options[index].$2,
                    description: _options[index].$3,
                    icon: _options[index].$4,
                    category: index < 3 ? 'OPERATIONAL' : 'STRATEGIC',
                    selected: _options[index].$1 == selectedMode,
                    onTap: () => onChanged(_options[index].$1),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}

class _ForecastTypeOption extends StatelessWidget {
  const _ForecastTypeOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String description;
  final IconData icon;
  final String category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '$title $category forecast',
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: .09)
            : ApplicationColors.panel(context),
        borderRadius: BorderRadius.circular(ApplicationRadii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ApplicationRadii.card),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ApplicationRadii.card),
              border: Border.all(
                color: selected ? primary : ApplicationColors.border(context),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: selected ? .14 : .07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? primary : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected ? primary : scheme.onSurfaceVariant,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 2,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: primary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
