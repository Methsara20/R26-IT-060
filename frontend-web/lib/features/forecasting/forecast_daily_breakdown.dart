import 'package:flutter/material.dart';

import '../../models/forecast/short_range_forecast.dart';

/// Progressive daily detail: three rows first, with an explicit expansion.
class ForecastDailyBreakdown extends StatefulWidget {
  const ForecastDailyBreakdown({required this.days, super.key});

  final List<ForecastDayResult> days;

  @override
  State<ForecastDailyBreakdown> createState() => _ForecastDailyBreakdownState();
}


class _ForecastDailyBreakdownState extends State<ForecastDailyBreakdown> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visible = _expanded ? widget.days : widget.days.take(3);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Column(
        children: [
          for (final day in visible) ...[
            _DailyRow(day: day),
            if (day != visible.last) const Divider(height: 1),
          ],
          if (widget.days.length > 3) ...[
            const Divider(height: 1),
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(
                _expanded
                    ? 'Show fewer days'
                    : 'View all ${widget.days.length} days',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({required this.day});

  final ForecastDayResult day;

  @override
  Widget build(BuildContext context) {
    final date = day.date;
    final dateLabel = date == null
        ? 'Day ${day.day}'
        : '${_weekday(date.weekday)}, ${date.day} ${_month(date.month)}';
    final temperature = day.weather.temperature?.toStringAsFixed(1) ?? '--';
    final rainfall = day.weather.rainfall?.toStringAsFixed(1) ?? '--';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 600
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 7,
                    children: _values(temperature, rainfall),
                  ),
                ],
              )
            : Row(
                children: [
                  SizedBox(
                    width: 145,
                    child: Text(
                      dateLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 22,
                      runSpacing: 7,
                      children: _values(temperature, rainfall),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _values(String temperature, String rainfall) => [
    _Value('${day.predictedDemand} units', emphasized: true),
    _Value('${day.confidencePercentage}% confidence'),
    _Value('$temperature C'),
    _Value(day.weather.condition),
    _Value('$rainfall mm rain', secondary: true),
  ];
}

class _Value extends StatelessWidget {
  const _Value(this.text, {this.emphasized = false, this.secondary = false});
  final String text;
  final bool emphasized;
  final bool secondary;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: secondary ? const Color(0xFF667085) : const Color(0xFF344054),
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
    ),
  );
}

String _weekday(int value) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][value - 1];
String _month(int value) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][value - 1];
