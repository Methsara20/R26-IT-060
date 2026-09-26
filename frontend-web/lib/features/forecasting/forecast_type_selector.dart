import 'package:flutter/material.dart';

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
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final option in _options)
            SizedBox(
              width: width,
              child: _ForecastTypeOption(
                title: option.$2,
                description: option.$3,
                icon: option.$4,
                selected: option.$1 == selectedMode,
                onTap: () => onChanged(option.$1),
              ),
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
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? const Color(0xFFEDF4FF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primary : const Color(0xFFE1E6EF),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? primary : const Color(0xFF667085)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              if (selected) Icon(Icons.check_circle, color: primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
