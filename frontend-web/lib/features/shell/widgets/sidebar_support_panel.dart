import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/theme/application_design_tokens.dart';

class SidebarSupportPanel extends StatelessWidget {
  const SidebarSupportPanel({
    required this.themeMode,
    required this.onThemeModeChanged,
    this.compact = false,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = themeMode == ThemeMode.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarSurface(
            child: Row(
              children: [
                Icon(
                  dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    dark ? 'Dark Mode' : 'Light Mode',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: dark,
                  onChanged: (value) => onThemeModeChanged(
                    value ? ThemeMode.dark : ThemeMode.light,
                  ),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 9),
            _SidebarSurface(
              child: Row(
                children: [
                  Icon(
                    Icons.rocket_launch_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Optimize. Balance. Grow.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            const SidebarClock(),
          ],
        ],
      ),
    );
  }
}

class SidebarClock extends StatefulWidget {
  const SidebarClock({super.key});

  @override
  State<SidebarClock> createState() => _SidebarClockState();
}

class _SidebarClockState extends State<SidebarClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SidebarSurface(
    child: Row(
      children: [
        Icon(
          Icons.schedule_outlined,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(_now),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatTime(_now),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SidebarSurface extends StatelessWidget {
  const _SidebarSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: ApplicationColors.panelMuted(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ApplicationColors.border(context)),
    ),
    child: child,
  );
}

String _formatDate(DateTime value) {
  const months = [
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
  ];
  return '${value.day.toString().padLeft(2, '0')} '
      '${months[value.month - 1]} ${value.year}';
}

String _formatTime(DateTime value) {
  final period = value.hour >= 12 ? 'PM' : 'AM';
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '${hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')} $period';
}
