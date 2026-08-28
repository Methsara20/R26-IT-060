// Final-polish pass: standardizes analytics filters, KPI cards, and headings.
import 'package:flutter/material.dart';

import '../../models/analytics/analytics_overview.dart';
import '../../core/widgets/application_page_layout.dart';
import '../../core/widgets/application_ui_components.dart';

enum AnalyticsBreakdownDimension { showrooms, categories, brands, genders }

enum AnalyticsMetric {
  inventoryValue,
  potentialProfit,
  stock,
  lowStock,
  overstock,
}



class AnalyticsDecisionDashboard extends StatefulWidget {
  const AnalyticsDecisionDashboard({
    required this.overview,
    this.onOpenInventoryIntelligence,
    super.key,
  });

  final AnalyticsOverview overview;
  final VoidCallback? onOpenInventoryIntelligence;

  @override
  State<AnalyticsDecisionDashboard> createState() =>
      _AnalyticsDecisionDashboardState();
}

class _AnalyticsDecisionDashboardState
    extends State<AnalyticsDecisionDashboard> {
  AnalyticsBreakdownDimension _dimension =
      AnalyticsBreakdownDimension.showrooms;
  AnalyticsMetric _metric = AnalyticsMetric.potentialProfit;
  String _showroom = 'ALL';
  String _category = 'ALL';
  String _brand = 'ALL';
  bool _showComparison = false;
  int _sortColumn = 4;
  bool _sortAscending = false;

  AnalyticsOverview get overview => widget.overview;

  List<AnalyticsBreakdown> get _breakdownItems => switch (_dimension) {
    AnalyticsBreakdownDimension.showrooms => overview.showrooms,
    AnalyticsBreakdownDimension.categories => overview.categories,
    AnalyticsBreakdownDimension.brands => overview.brands,
    AnalyticsBreakdownDimension.genders => overview.genders,
  };

  List<AnalyticsAlertItem> _filterItems(List<AnalyticsAlertItem> items) => items
      .where(
        (item) =>
            (_showroom == 'ALL' || item.storeId == _showroom) &&
            (_category == 'ALL' || item.category == _category) &&
            (_brand == 'ALL' || item.brand == _brand),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final dashboard = overview.dashboard;
    final lowStock = _filterItems(overview.lowStockItems);
    final overstock = _filterItems(overview.overstockItems);
    final highValue = _filterItems(overview.highValueItems);
    final priorityItems = [...lowStock, ...overstock]
      ..sort((a, b) {
        final aShortage = a.reorderLevel - a.currentStock;
        final bShortage = b.reorderLevel - b.currentStock;
        return bShortage.compareTo(aShortage);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnalyticsFilters(
          overview: overview,
          showroom: _showroom,
          category: _category,
          brand: _brand,
          onShowroomChanged: (value) => setState(() => _showroom = value),
          onCategoryChanged: (value) => setState(() => _category = value),
          onBrandChanged: (value) => setState(() => _brand = value),
          onClear: () => setState(() {
            _showroom = 'ALL';
            _category = 'ALL';
            _brand = 'ALL';
          }),
        ),
        const SizedBox(height: 22),
        const _SectionHeading(
          title: 'Performance overview',
          subtitle: 'Network totals from the current analytics snapshot',
        ),
        const SizedBox(height: 12),
        _KpiGrid(
          cards: [
            _KpiData(
              'Closing inventory',
              _number(dashboard.totalInventoryQuantity),
              'Across ${dashboard.totalStores} showrooms',
              Icons.inventory_2_outlined,
              const Color(0xFF2563EB),
            ),
            _KpiData(
              'Inventory value',
              _currency(dashboard.totalInventoryValue),
              'Current stock value',
              Icons.account_balance_wallet_outlined,
              const Color(0xFF475467),
            ),
            _KpiData(
              'Low stock rate',
              _rate(dashboard.lowStockItems, dashboard.totalInventoryRecords),
              '${_number(dashboard.lowStockItems)} of ${_number(dashboard.totalInventoryRecords)} records',
              Icons.trending_down,
              const Color(0xFFD92D20),
            ),
            _KpiData(
              'Overstock rate',
              _rate(dashboard.overstockItems, dashboard.totalInventoryRecords),
              '${_number(dashboard.overstockItems)} of ${_number(dashboard.totalInventoryRecords)} records',
              Icons.inventory_outlined,
              const Color(0xFFF79009),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _AttentionExposure(
          lowCount: dashboard.lowStockItems,
          overCount: dashboard.overstockItems,
          total: dashboard.totalInventoryRecords,
        ),
        const SizedBox(height: 24),
        _PerformanceBreakdown(
          items: _breakdownItems,
          dimension: _dimension,
          metric: _metric,
          showComparison: _showComparison,
          sortColumn: _sortColumn,
          sortAscending: _sortAscending,
          onDimensionChanged: (value) => setState(() => _dimension = value),
          onMetricChanged: (value) => setState(() => _metric = value),
          onToggleComparison: () =>
              setState(() => _showComparison = !_showComparison),
          onSort: (column, ascending) => setState(() {
            _sortColumn = column;
            _sortAscending = ascending;
          }),
          onInspect: _showBreakdownDetails,
        ),
        const SizedBox(height: 24),
        _AttentionShowrooms(
          showrooms: overview.showrooms,
          onReview: _showBreakdownDetails,
        ),
        const SizedBox(height: 24),
        _AttentionSummary(
          lowStock: lowStock,
          overstock: overstock,
          highValue: highValue,
        ),
        const SizedBox(height: 24),
        _PriorityItems(
          items: priorityItems.take(8).toList(),
          totalCount: priorityItems.length,
          onViewAll: widget.onOpenInventoryIntelligence,
        ),
        const SizedBox(height: 24),
        _FinancialOpportunity(
          inventoryValue: dashboard.totalInventoryValue,
          potentialRevenue: dashboard.totalPotentialRevenue,
          potentialProfit: dashboard.totalPotentialProfit,
        ),
      ],
    );
  }

  void _showBreakdownDetails(AnalyticsBreakdown item) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (item.secondaryLabel != null) Text(item.secondaryLabel!),
                const SizedBox(height: 20),
                _DetailGrid(item: item),
                if (widget.onOpenInventoryIntelligence != null) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenInventoryIntelligence!();
                      },
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Open Inventory Intelligence'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsFilters extends StatelessWidget {
  const _AnalyticsFilters({
    required this.overview,
    required this.showroom,
    required this.category,
    required this.brand,
    required this.onShowroomChanged,
    required this.onCategoryChanged,
    required this.onBrandChanged,
    required this.onClear,
  });
  final AnalyticsOverview overview;
  final String showroom;
  final String category;
  final String brand;
  final ValueChanged<String> onShowroomChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onBrandChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => ApplicationFilterBar(
    children: [
      _FilterField(
        label: 'Scope / showroom',
        value: showroom,
        values: ['ALL', ...overview.showrooms.map((item) => item.id)],
        labels: {for (final item in overview.showrooms) item.id: item.label},
        onChanged: onShowroomChanged,
      ),
      _FilterField(
        label: 'Category',
        value: category,
        values: ['ALL', ...overview.categories.map((item) => item.id)],
        onChanged: onCategoryChanged,
      ),
      _FilterField(
        label: 'Brand',
        value: brand,
        values: ['ALL', ...overview.brands.map((item) => item.id)],
        onChanged: onBrandChanged,
      ),
      TextButton.icon(
        onPressed: onClear,
        icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
        label: const Text('Clear filters'),
      ),
    ],
  );
}

class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.labels = const {},
  });
  final String label;
  final String value;
  final List<String> values;
  final Map<String, String> labels;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ApplicationFilterDropdown(
    label: label,
    value: value,
    items: {
      for (final item in values.toSet())
        item: item == 'ALL' ? 'All' : labels[item] ?? item,
    },
    onChanged: onChanged,
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) =>
      ApplicationSectionHeader(title: title, subtitle: subtitle);
}

class _KpiData {
  const _KpiData(this.label, this.value, this.support, this.icon, this.color);
  final String label;
  final String value;
  final String support;
  final IconData icon;
  final Color color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.cards});
  final List<_KpiData> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 4
          : constraints.maxWidth >= 560
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final card in cards)
            SizedBox(
              width: width,
              child: ApplicationStatCard(
                label: card.label,
                value: card.value,
                icon: card.icon,
                accentColor: card.color,
                supportingText: card.support,
                showAccentBar: false,
              ),
            ),
        ],
      );
    },
  );
}

class _AttentionExposure extends StatelessWidget {
  const _AttentionExposure({
    required this.lowCount,
    required this.overCount,
    required this.total,
  });
  final int lowCount;
  final int overCount;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: _panel(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'Inventory attention',
          subtitle:
              'Independent exposure rates; classifications are not treated as mutually exclusive',
        ),
        const SizedBox(height: 18),
        _ExposureLine(
          label: 'Low-stock exposure',
          count: lowCount,
          total: total,
          color: const Color(0xFFD92D20),
        ),
        const SizedBox(height: 17),
        _ExposureLine(
          label: 'Overstock exposure',
          count: overCount,
          total: total,
          color: const Color(0xFFF79009),
        ),
      ],
    ),
  );
}

class _ExposureLine extends StatelessWidget {
  const _ExposureLine({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = total <= 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${_number(count)} records',
              style: const TextStyle(color: Color(0xFF68758D)),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 52,
              child: Text(
                _rate(count, total),
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 9,
            color: color,
            backgroundColor: const Color(0xFFE9EDF5),
          ),
        ),
      ],
    );
  }
}

class _PerformanceBreakdown extends StatelessWidget {
  const _PerformanceBreakdown({
    required this.items,
    required this.dimension,
    required this.metric,
    required this.showComparison,
    required this.sortColumn,
    required this.sortAscending,
    required this.onDimensionChanged,
    required this.onMetricChanged,
    required this.onToggleComparison,
    required this.onSort,
    required this.onInspect,
  });
  final List<AnalyticsBreakdown> items;
  final AnalyticsBreakdownDimension dimension;
  final AnalyticsMetric metric;
  final bool showComparison;
  final int sortColumn;
  final bool sortAscending;
  final ValueChanged<AnalyticsBreakdownDimension> onDimensionChanged;
  final ValueChanged<AnalyticsMetric> onMetricChanged;
  final VoidCallback onToggleComparison;
  final void Function(int, bool) onSort;
  final ValueChanged<AnalyticsBreakdown> onInspect;

  @override
  Widget build(BuildContext context) {
    final ranked = [...items]
      ..sort(
        (a, b) => _metricValue(b, metric).compareTo(_metricValue(a, metric)),
      );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Performance breakdown',
            subtitle:
                'Compare operational and financial performance by business dimension',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in AnalyticsBreakdownDimension.values)
                ChoiceChip(
                  label: Text(_dimensionLabel(value)),
                  selected: dimension == value,
                  onSelected: (_) => onDimensionChanged(value),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<AnalyticsMetric>(
              initialValue: metric,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Comparison metric',
                isDense: true,
              ),
              items: [
                for (final value in AnalyticsMetric.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(_metricLabel(value)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onMetricChanged(value);
              },
            ),
          ),
          const SizedBox(height: 20),
          if (ranked.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No analytics data is available for this breakdown.'),
            )
          else
            for (final item in ranked.take(10))
              _RankingBar(
                item: item,
                metric: metric,
                maximum: _metricValue(ranked.first, metric),
                onTap: () => onInspect(item),
              ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onToggleComparison,
            icon: Icon(
              showComparison ? Icons.expand_less : Icons.table_rows_outlined,
            ),
            label: Text(
              showComparison
                  ? 'Hide detailed comparison'
                  : 'View detailed comparison',
            ),
          ),
          if (showComparison) ...[
            const Divider(height: 24),
            _ComparisonTable(
              items: items,
              sortColumn: sortColumn,
              ascending: sortAscending,
              onSort: onSort,
            ),
          ],
        ],
      ),
    );
  }
}

class _RankingBar extends StatelessWidget {
  const _RankingBar({
    required this.item,
    required this.metric,
    required this.maximum,
    required this.onTap,
  });
  final AnalyticsBreakdown item;
  final AnalyticsMetric metric;
  final double maximum;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final value = _metricValue(item, metric);
            return Row(
              children: [
                SizedBox(
                  width: constraints.maxWidth < 650 ? 110 : 190,
                  child: Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: maximum <= 0 ? 0 : value / maximum,
                      minHeight: 12,
                      color: const Color(0xFF2563EB),
                      backgroundColor: const Color(0xFFE9EDF5),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: Text(
                    _metricFormat(value, metric),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({
    required this.items,
    required this.sortColumn,
    required this.ascending,
    required this.onSort,
  });
  final List<AnalyticsBreakdown> items;
  final int sortColumn;
  final bool ascending;
  final void Function(int, bool) onSort;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]
      ..sort((a, b) {
        final comparison = switch (sortColumn) {
          0 => a.label.compareTo(b.label),
          1 => a.totalStock.compareTo(b.totalStock),
          2 => a.lowStockItems.compareTo(b.lowStockItems),
          3 => a.overstockItems.compareTo(b.overstockItems),
          _ => a.potentialProfit.compareTo(b.potentialProfit),
        };
        return ascending ? comparison : -comparison;
      });
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: sortColumn,
        sortAscending: ascending,
        columns: [
          DataColumn(label: const Text('Name'), onSort: onSort),
          DataColumn(
            label: const Text('Inventory'),
            numeric: true,
            onSort: onSort,
          ),
          DataColumn(
            label: const Text('Low stock'),
            numeric: true,
            onSort: onSort,
          ),
          DataColumn(
            label: const Text('Overstock'),
            numeric: true,
            onSort: onSort,
          ),
          DataColumn(
            label: const Text('Potential profit'),
            numeric: true,
            onSort: onSort,
          ),
        ],
        rows: [
          for (final item in sorted)
            DataRow(
              cells: [
                DataCell(SizedBox(width: 180, child: Text(item.label))),
                DataCell(Text(_number(item.totalStock))),
                DataCell(Text(_number(item.lowStockItems))),
                DataCell(Text(_number(item.overstockItems))),
                DataCell(Text(_compactCurrency(item.potentialProfit))),
              ],
            ),
        ],
      ),
    );
  }
}

class _AttentionShowrooms extends StatelessWidget {
  const _AttentionShowrooms({required this.showrooms, required this.onReview});
  final List<AnalyticsBreakdown> showrooms;
  final ValueChanged<AnalyticsBreakdown> onReview;

  @override
  Widget build(BuildContext context) {
    final ranked = [...showrooms]
      ..sort(
        (a, b) => (b.lowStockItems + b.overstockItems).compareTo(
          a.lowStockItems + a.overstockItems,
        ),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'Showrooms requiring attention',
          subtitle:
              'Ranked transparently by total low-stock and overstock records',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in ranked.take(5))
                  SizedBox(
                    width: width,
                    child: _AttentionShowroomCard(
                      item: item,
                      onReview: () => onReview(item),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AttentionShowroomCard extends StatelessWidget {
  const _AttentionShowroomCard({required this.item, required this.onReview});
  final AnalyticsBreakdown item;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _panel(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          maxLines: 2,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          '${item.lowStockItems} low stock',
          style: const TextStyle(color: Color(0xFFD92D20)),
        ),
        Text(
          '${item.overstockItems} overstock',
          style: const TextStyle(color: Color(0xFFF79009)),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onReview, child: const Text('Review →')),
        ),
      ],
    ),
  );
}

class _AttentionSummary extends StatelessWidget {
  const _AttentionSummary({
    required this.lowStock,
    required this.overstock,
    required this.highValue,
  });
  final List<AnalyticsAlertItem> lowStock;
  final List<AnalyticsAlertItem> overstock;
  final List<AnalyticsAlertItem> highValue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeading(
        title: 'Inventory attention summary',
        subtitle: 'Focused item counts for the selected filters',
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 3 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: width,
                child: _SummaryCard(
                  label: 'Low stock',
                  count: lowStock.length,
                  icon: Icons.warning_amber,
                  color: const Color(0xFFD92D20),
                ),
              ),
              SizedBox(
                width: width,
                child: _SummaryCard(
                  label: 'Overstock',
                  count: overstock.length,
                  icon: Icons.inventory_outlined,
                  color: const Color(0xFFF79009),
                ),
              ),
              SizedBox(
                width: width,
                child: _SummaryCard(
                  label: 'High value',
                  count: highValue.length,
                  icon: Icons.workspace_premium_outlined,
                  color: const Color(0xFF16A36A),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _panel(context),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${_number(count)} records',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PriorityItems extends StatelessWidget {
  const _PriorityItems({
    required this.items,
    required this.totalCount,
    required this.onViewAll,
  });
  final List<AnalyticsAlertItem> items;
  final int totalCount;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: _SectionHeading(
              title: 'Items requiring attention',
              subtitle: 'Highest reorder shortfalls among the selected records',
            ),
          ),
          if (onViewAll != null)
            TextButton(onPressed: onViewAll, child: const Text('View all')),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        decoration: _panel(context),
        clipBehavior: Clip.antiAlias,
        child: items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(36),
                child: Center(
                  child: Text(
                    'No analytics data is available for the selected filters.',
                  ),
                ),
              )
            : Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    _PriorityRow(item: items[index]),
                    if (index != items.length - 1) const Divider(height: 1),
                  ],
                  if (totalCount > items.length)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Showing ${items.length} of $totalCount attention records',
                        style: const TextStyle(color: Color(0xFF68758D)),
                      ),
                    ),
                ],
              ),
      ),
    ],
  );
}

class _PriorityRow extends StatelessWidget {
  const _PriorityRow({required this.item});
  final AnalyticsAlertItem item;

  @override
  Widget build(BuildContext context) {
    final status = item.currentStock <= 0
        ? 'STOCKOUT'
        : item.currentStock < item.reorderLevel
        ? 'LOW'
        : 'OVERSTOCK';
    final color = status == 'STOCKOUT'
        ? const Color(0xFFD92D20)
        : status == 'LOW'
        ? const Color(0xFFF04438)
        : const Color(0xFFF79009);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                item.productId,
                style: const TextStyle(fontSize: 12, color: Color(0xFF68758D)),
              ),
            ],
          );
          final statusPill = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 8),
                    statusPill,
                  ],
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    Text(item.storeId),
                    Text('${item.currentStock} units'),
                    Text('Reorder ${item.reorderLevel}'),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: identity),
              Expanded(child: Text(item.storeId)),
              Expanded(child: Text('${item.currentStock} units')),
              Expanded(child: Text('Reorder ${item.reorderLevel}')),
              statusPill,
            ],
          );
        },
      ),
    );
  }
}

class _FinancialOpportunity extends StatelessWidget {
  const _FinancialOpportunity({
    required this.inventoryValue,
    required this.potentialRevenue,
    required this.potentialProfit,
  });
  final double inventoryValue;
  final double potentialRevenue;
  final double potentialProfit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: _panel(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'Inventory value & opportunity',
          subtitle: 'Financial context from the current inventory snapshot',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 28,
          runSpacing: 16,
          children: [
            _FinancialValue(label: 'Inventory value', value: inventoryValue),
            _FinancialValue(
              label: 'Potential revenue',
              value: potentialRevenue,
            ),
            _FinancialValue(label: 'Potential profit', value: potentialProfit),
          ],
        ),
      ],
    ),
  );
}

class _FinancialValue extends StatelessWidget {
  const _FinancialValue({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 250,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF68758D))),
        const SizedBox(height: 4),
        Text(
          _currency(value),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.item});
  final AnalyticsBreakdown item;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _DetailValue('Inventory', '${_number(item.totalStock)} units'),
      _DetailValue('Inventory value', _currency(item.inventoryValue)),
      _DetailValue('Potential profit', _currency(item.potentialProfit)),
      _DetailValue('Low stock', _number(item.lowStockItems)),
      _DetailValue('Overstock', _number(item.overstockItems)),
    ],
  );
}

class _DetailValue extends StatelessWidget {
  const _DetailValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF68758D)),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

double _metricValue(AnalyticsBreakdown item, AnalyticsMetric metric) =>
    switch (metric) {
      AnalyticsMetric.inventoryValue => item.inventoryValue,
      AnalyticsMetric.potentialProfit => item.potentialProfit,
      AnalyticsMetric.stock => item.totalStock.toDouble(),
      AnalyticsMetric.lowStock => item.lowStockItems.toDouble(),
      AnalyticsMetric.overstock => item.overstockItems.toDouble(),
    };

String _metricFormat(double value, AnalyticsMetric metric) => switch (metric) {
  AnalyticsMetric.inventoryValue ||
  AnalyticsMetric.potentialProfit => _compactCurrency(value),
  _ => _number(value),
};

String _metricLabel(AnalyticsMetric value) => switch (value) {
  AnalyticsMetric.inventoryValue => 'Inventory value',
  AnalyticsMetric.potentialProfit => 'Potential profit',
  AnalyticsMetric.stock => 'Stock',
  AnalyticsMetric.lowStock => 'Low stock',
  AnalyticsMetric.overstock => 'Overstock',
};

String _dimensionLabel(AnalyticsBreakdownDimension value) => switch (value) {
  AnalyticsBreakdownDimension.showrooms => 'Showrooms',
  AnalyticsBreakdownDimension.categories => 'Categories',
  AnalyticsBreakdownDimension.brands => 'Brands',
  AnalyticsBreakdownDimension.genders => 'Gender',
};

BoxDecoration _panel(BuildContext context) => BoxDecoration(
  color: Theme.of(context).colorScheme.surface,
  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
  borderRadius: BorderRadius.circular(14),
);

String _number(num value) {
  final digits = value.round().toString();
  return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

String _currency(double value) => 'LKR ${_number(value)}';
String _compactCurrency(double value) => value >= 1000000000
    ? 'LKR ${(value / 1000000000).toStringAsFixed(1)}B'
    : value >= 1000000
    ? 'LKR ${(value / 1000000).toStringAsFixed(1)}M'
    : value >= 1000
    ? 'LKR ${(value / 1000).toStringAsFixed(1)}K'
    : 'LKR ${value.toStringAsFixed(0)}';
String _rate(int count, int total) =>
    total <= 0 ? 'N/A' : '${(count / total * 100).toStringAsFixed(1)}%';
