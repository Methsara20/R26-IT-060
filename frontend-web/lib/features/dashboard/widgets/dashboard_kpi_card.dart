// Final-polish pass: dashboard metrics delegate to the shared stat-card system.
import 'package:flutter/material.dart';

import '../../../core/widgets/application_ui_components.dart';

class DashboardKpiCard extends StatelessWidget {
  const DashboardKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) => ApplicationStatCard(
    label: label,
    value: value,
    icon: icon,
    accentColor: color,
    supportingText: caption,
  );
}
