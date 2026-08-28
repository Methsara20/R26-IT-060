import 'package:flutter/material.dart';

import '../../models/analytics/dashboard_summary.dart';
import '../../services/analytics_api_service.dart';

class DashboardOverviewScreen extends StatefulWidget {
  const DashboardOverviewScreen({super.key});

  @override
  State<DashboardOverviewScreen> createState() =>
      _DashboardOverviewScreenState();
}


class _DashboardOverviewScreenState extends State<DashboardOverviewScreen> {
  final AnalyticsApiService _service = AnalyticsApiService();
  late Future<DashboardSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _service.getDashboardSummary();
  }

  void _retry() {
    setState(() => _summaryFuture = _service.getDashboardSummary());
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Live inventory position and retail opportunity overview',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _retry,
                  tooltip: 'Refresh dashboard',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 28),
            FutureBuilder<DashboardSummary>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _DashboardLoadingState();
                }
                if (snapshot.hasError) {
                  return _DashboardErrorState(
                    message: snapshot.error.toString(),
                    onRetry: _retry,
                  );
                }
                final summary = snapshot.data;
                if (summary == null) {
                  return _DashboardErrorState(
                    message: 'No dashboard summary is available.',
                    onRetry: _retry,
                  );
                }
                return _DashboardContent(summary: summary);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricData(
        'Products',
        _number(summary.totalProducts),
        Icons.sell_outlined,
        const Color(0xFF155EEF),
      ),
      _MetricData(
        'Showrooms',
        _number(summary.totalStores),
        Icons.storefront_outlined,
        const Color(0xFF7A5AF8),
      ),
      _MetricData(
        'Closing inventory',
        _number(summary.totalInventoryQuantity),
        Icons.inventory_2_outlined,
        const Color(0xFF0E9384),
      ),
      _MetricData(
        'Inventory records',
        _number(summary.totalInventoryRecords),
        Icons.dataset_outlined,
        const Color(0xFF475467),
      ),
      _MetricData(
        'Closing inventory value',
        _money(summary.totalInventoryValue),
        Icons.account_balance_wallet_outlined,
        const Color(0xFF155EEF),
      ),
      _MetricData(
        'Potential revenue',
        _money(summary.totalPotentialRevenue),
        Icons.trending_up,
        const Color(0xFF0E9384),
      ),
      _MetricData(
        'Potential profit',
        _money(summary.totalPotentialProfit),
        Icons.payments_outlined,
        const Color(0xFF039855),
      ),
      _MetricData(
        'Low-stock items',
        _number(summary.lowStockItems),
        Icons.warning_amber_rounded,
        const Color(0xFFD92D20),
      ),
      _MetricData(
        'Overstock items',
        _number(summary.overstockItems),
        Icons.inventory_outlined,
        const Color(0xFFF79009),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 3
                : constraints.maxWidth >= 620
                ? 2
                : 1;
            const spacing = 16.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: width,
                    child: _DashboardMetricCard(data: card),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Icon(Icons.schedule, size: 16, color: Color(0xFF667085)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _updatedLabel(summary.lastUpdated),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _number(num value) {
    final digits = value.round().toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  static String _money(double value) => 'LKR ${_number(value)}';

  static String _updatedLabel(DateTime? value) {
    if (value == null) return 'Last update time unavailable';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return 'Last updated ${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({required this.data});
  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: data.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.value,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 72),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading dashboard summary…'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 52),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Dashboard unavailable',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}
