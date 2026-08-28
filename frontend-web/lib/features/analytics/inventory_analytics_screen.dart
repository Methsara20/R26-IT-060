// Final-polish pass: standardizes the page header utility slots and spacing.
// The previous analytics widgets remain temporarily as a verified rollback
// reference while the new decision dashboard is validated end to end.
// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import '../workflow/inventory_decision_workflow_controller.dart';
import '../workflow/active_workflow_banner.dart';

import '../../core/theme/app_theme.dart';
import '../../models/analytics/analytics_overview.dart';
import '../../services/analytics_api_service.dart';
import '../../core/widgets/application_page_layout.dart';
import 'analytics_decision_dashboard.dart';

class InventoryAnalyticsScreen extends StatefulWidget {
  const InventoryAnalyticsScreen({
    required this.workflowController,
    this.onOpenInventoryIntelligence,
    super.key,
  });

  final InventoryDecisionWorkflowController workflowController;
  final VoidCallback? onOpenInventoryIntelligence;

  @override
  State<InventoryAnalyticsScreen> createState() =>
      _InventoryAnalyticsScreenState();
}

class _InventoryAnalyticsScreenState extends State<InventoryAnalyticsScreen> {
  final _api = AnalyticsApiService();
  AnalyticsOverview? _overview;
  String? _error;
  final bool _showWorkflowContext = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _overview = null;
      _error = null;
    });
    try {
      final overview = await _api.getOverview();
      if (mounted) setState(() => _overview = overview);
    } on AnalyticsApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workflow = widget.workflowController.current;
    final movement = workflow?.movement;
    final lastUpdated = _overview?.dashboard.lastUpdated;
    return ApplicationPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ApplicationPageHeader(
            title: 'Analytics',
            subtitle:
                'Analyze inventory performance, stock health and business opportunities',
            updatedText: lastUpdated == null
                ? null
                : 'Updated ${_analyticsUpdatedLabel(lastUpdated)}',
            onRefresh: _overview == null ? null : _load,
            refreshTooltip: 'Refresh analytics',
          ),
          const SizedBox(height: 24),
          // Analytics remains an independent workspace. The workflow stays in
          // the controller solely for global Inventory AI context.
          if (workflow != null && _showWorkflowContext) ...[
            ActiveWorkflowBanner(workflow: workflow),
            if (movement?.status == 'EXECUTED') ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.insights_outlined,
                        color: Color(0xFF039855),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Post-execution analytics context: '
                          '${movement!.productName}, ${movement.fromStore} → '
                          '${movement.toStore}. The analytics below use the '
                          'backend summaries refreshed during execution.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          if (_error != null)
            _ErrorPanel(
              message: 'Analytics data could not be loaded. Please try again.',
              onRetry: _load,
            )
          else if (_overview == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(72),
                child: CircularProgressIndicator(),
              ),
            )
          else
            AnalyticsDecisionDashboard(
              overview: _overview!,
              onOpenInventoryIntelligence: widget.onOpenInventoryIntelligence,
            ),
        ],
      ),
    );
  }
}

String _analyticsUpdatedLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

class _AnalyticsContent extends StatelessWidget {
  const _AnalyticsContent({
    required this.overview,
    required this.breakdown,
    required this.alert,
    required this.onBreakdownChanged,
    required this.onAlertChanged,
  });

  final AnalyticsOverview overview;
  final _BreakdownType breakdown;
  final _AlertType alert;
  final ValueChanged<_BreakdownType> onBreakdownChanged;
  final ValueChanged<_AlertType> onAlertChanged;

  List<AnalyticsBreakdown> get selectedBreakdown => switch (breakdown) {
    _BreakdownType.showrooms => overview.showrooms,
    _BreakdownType.categories => overview.categories,
    _BreakdownType.brands => overview.brands,
    _BreakdownType.genders => overview.genders,
  };

  List<AnalyticsAlertItem> get selectedAlerts => switch (alert) {
    _AlertType.lowStock => overview.lowStockItems,
    _AlertType.overstock => overview.overstockItems,
    _AlertType.highValue => overview.highValueItems,
  };

  @override
  Widget build(BuildContext context) {
    final dashboard = overview.dashboard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KpiGrid(
          values: [
            (
              'Closing inventory',
              _number(dashboard.totalInventoryQuantity),
              Icons.inventory_2_outlined,
              AppTheme.primary,
            ),
            (
              'Closing inventory value',
              _currency(dashboard.totalInventoryValue),
              Icons.account_balance_wallet_outlined,
              const Color(0xFF344054),
            ),
            (
              'Low stock rate',
              _percentage(
                dashboard.lowStockItems,
                dashboard.totalInventoryRecords,
              ),
              Icons.trending_down_rounded,
              const Color(0xFFD92D20),
            ),
            (
              'Overstock rate',
              _percentage(
                dashboard.overstockItems,
                dashboard.totalInventoryRecords,
              ),
              Icons.inventory_outlined,
              const Color(0xFFF79009),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Text(
          'Performance breakdown',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in _BreakdownType.values)
              ChoiceChip(
                label: Text(type.label),
                selected: breakdown == type,
                onSelected: (_) => onBreakdownChanged(type),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final chart = _ProfitChart(items: selectedBreakdown);
            final table = _BreakdownTable(items: selectedBreakdown);
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: chart),
                      const SizedBox(width: 16),
                      Expanded(child: table),
                    ],
                  )
                : Column(children: [chart, const SizedBox(height: 16), table]);
          },
        ),
        const SizedBox(height: 28),
        const Text(
          'Inventory attention',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in _AlertType.values)
              ChoiceChip(
                avatar: Icon(type.icon, size: 17),
                label: Text('${type.label} (${_alertCount(type)})'),
                selected: alert == type,
                onSelected: (_) => onAlertChanged(type),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _AlertList(items: selectedAlerts, type: alert),
      ],
    );
  }

  int _alertCount(_AlertType type) => switch (type) {
    _AlertType.lowStock => overview.lowStockItems.length,
    _AlertType.overstock => overview.overstockItems.length,
    _AlertType.highValue => overview.highValueItems.length,
  };
}

String _percentage(int count, int total) => total <= 0
    ? 'Not available'
    : '${(count / total * 100).toStringAsFixed(1)}%';

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.values});
  final List<(String, String, IconData, Color)> values;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 620 ? 2 : 4;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final value in values)
            SizedBox(
              width: width,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(value.$3, color: value.$4),
                      const SizedBox(height: 12),
                      Text(
                        value.$1,
                        style: const TextStyle(color: Color(0xFF68758C)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _ProfitChart extends StatelessWidget {
  const _ProfitChart({required this.items});
  final List<AnalyticsBreakdown> items;

  @override
  Widget build(BuildContext context) {
    final displayed = items.take(8).toList();
    final maximum = displayed.fold<double>(
      0,
      (current, item) =>
          item.potentialProfit > current ? item.potentialProfit : current,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Potential profit comparison',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            if (displayed.isEmpty)
              const Text('No performance data is available.')
            else
              for (final item in displayed) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 108,
                      child: Text(item.label, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          minHeight: 12,
                          value: maximum == 0
                              ? 0
                              : item.potentialProfit / maximum,
                          backgroundColor: const Color(0xFFE9EDF5),
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 72,
                      child: Text(
                        _compactCurrency(item.potentialProfit),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
          ],
        ),
      ),
    );
  }
}

class _BreakdownTable extends StatelessWidget {
  const _BreakdownTable({required this.items});
  final List<AnalyticsBreakdown> items;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance details',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('No performance data is available.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Stock'), numeric: true),
                  DataColumn(label: Text('Low'), numeric: true),
                  DataColumn(label: Text('Over'), numeric: true),
                  DataColumn(label: Text('Profit'), numeric: true),
                ],
                rows: [
                  for (final item in items.take(8))
                    DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 130,
                            child: Text(
                              item.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(_number(item.totalStock))),
                        DataCell(Text('${item.lowStockItems}')),
                        DataCell(Text('${item.overstockItems}')),
                        DataCell(Text(_compactCurrency(item.potentialProfit))),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.items, required this.type});
  final List<AnalyticsAlertItem> items;
  final _AlertType type;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text('No items are currently in this group.')),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < items.take(12).length; index++) ...[
            _AlertRow(item: items[index], type: type),
            if (index < items.take(12).length - 1) const Divider(height: 1),
          ],
          if (items.length > 12)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Showing 12 of ${items.length} items',
                style: const TextStyle(color: Color(0xFF68758C)),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.item, required this.type});
  final AnalyticsAlertItem item;
  final _AlertType type;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: type.color.withValues(alpha: 0.12),
          foregroundColor: type.color,
          child: Icon(type.icon, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${item.productId} • ${item.storeId} • ${item.brand}',
                style: const TextStyle(color: Color(0xFF68758C), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item.currentStock} units',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Reorder ${item.reorderLevel} • Max ${item.maximumStock}',
              style: const TextStyle(color: Color(0xFF68758C), fontSize: 11),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

enum _BreakdownType { showrooms, categories, brands, genders }

extension on _BreakdownType {
  String get label => switch (this) {
    _BreakdownType.showrooms => 'Showrooms',
    _BreakdownType.categories => 'Categories',
    _BreakdownType.brands => 'Brands',
    _BreakdownType.genders => 'Gender',
  };
}

enum _AlertType { lowStock, overstock, highValue }

extension on _AlertType {
  String get label => switch (this) {
    _AlertType.lowStock => 'Low stock',
    _AlertType.overstock => 'Overstock',
    _AlertType.highValue => 'High value',
  };

  IconData get icon => switch (this) {
    _AlertType.lowStock => Icons.warning_amber,
    _AlertType.overstock => Icons.inventory_outlined,
    _AlertType.highValue => Icons.workspace_premium_outlined,
  };

  Color get color => switch (this) {
    _AlertType.lowStock => Colors.red,
    _AlertType.overstock => Colors.orange,
    _AlertType.highValue => Colors.green,
  };
}

String _number(num value) {
  final digits = value.round().toString();
  return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

String _currency(double value) => 'LKR ${_number(value)}';

String _compactCurrency(double value) {
  if (value >= 1000000000) {
    return 'LKR ${(value / 1000000000).toStringAsFixed(1)}B';
  }
  if (value >= 1000000) return 'LKR ${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return 'LKR ${(value / 1000).toStringAsFixed(1)}K';
  return 'LKR ${value.toStringAsFixed(0)}';
}
