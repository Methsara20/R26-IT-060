import 'dart:async';

import 'package:flutter/material.dart';

class SidebarSupportPanel extends StatelessWidget {
  const SidebarSupportPanel({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;


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
                  color: const Color(0xFFD5DEED),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    dark ? 'Dark Mode' : 'Light Mode',
                    style: const TextStyle(
                      color: Color(0xFFD5DEED),
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
          const SizedBox(height: 9),
          const _SidebarSurface(
            child: Row(
              children: [
                Icon(
                  Icons.rocket_launch_outlined,
                  size: 18,
                  color: Color(0xFF7FA6FF),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Optimize. Balance. Grow.',
                    style: TextStyle(
                      color: Color(0xFFD5DEED),
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
        const Icon(Icons.schedule_outlined, size: 18, color: Color(0xFF9FB0C8)),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(_now),
                style: const TextStyle(color: Color(0xFFAAB7CA), fontSize: 10),
              ),
              const SizedBox(height: 2),
              Text(
                _formatTime(_now),
                style: const TextStyle(
                  color: Colors.white,
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
      color: const Color(0xFF1A3155),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF30496E)),
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
