import 'analytics_overview.dart';
import 'dashboard_summary.dart';

/// Data used by the dashboard command center.
///
/// The summary is required, while alert lists are optional secondary data so
/// a missing alert document never hides the overall inventory position.
class DashboardCommandCenter {
  const DashboardCommandCenter({
    required this.summary,
    required this.lowStockItems,
    required this.overstockItems,
  });


  final DashboardSummary summary;
  final List<AnalyticsAlertItem> lowStockItems;
  final List<AnalyticsAlertItem> overstockItems;
}
