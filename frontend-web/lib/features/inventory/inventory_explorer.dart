import 'package:flutter/material.dart';

import '../../models/forecast/forecast_catalog_option.dart';
import '../../models/inventory/inventory_record.dart';
import '../../models/workflow/decision_workflow.dart';
import 'inventory_current_health.dart';

typedef RunInventoryForecast = void Function(String storeId, String productId);

class InventoryExplorer extends StatefulWidget {
  const InventoryExplorer({
    required this.store,
    required this.records,
    required this.products,
    required this.workflow,
    required this.onBack,
    required this.onRunForecast,
    super.key,
  });

  final ForecastStoreOption store;
  final List<InventoryRecord> records;
  final Map<String, ForecastProductOption> products;
  final DecisionWorkflow? workflow;
  final VoidCallback onBack;
  final RunInventoryForecast onRunForecast;

  @override
  State<InventoryExplorer> createState() => _InventoryExplorerState();
}

class _InventoryExplorerState extends State<InventoryExplorer> {
  final _searchController = TextEditingController();
  InventoryCurrentHealth? _health;
  String? _category;
  String? _brand;
  String? _gender;
  _InventorySort _sort = _InventorySort.product;
  int _pageSize = 25;
  int _page = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _metadata(String Function(ForecastProductOption) select) {
    final values = widget.products.values
        .map(select)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  List<InventoryRecord> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    final result = widget.records.where((record) {
      final product = widget.products[record.productId];
      if (_health != null && inventoryCurrentHealth(record) != _health) {
        return false;
      }
      if (_category != null && product?.category != _category) return false;
      if (_brand != null && product?.brand != _brand) return false;
      if (_gender != null && product?.gender != _gender) return false;
      if (query.isNotEmpty &&
          !(product?.name.toLowerCase().contains(query) ?? false) &&
          !record.productId.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
    result.sort(
      (left, right) => switch (_sort) {
        _InventorySort.product =>
          (widget.products[left.productId]?.name ?? left.productId).compareTo(
            widget.products[right.productId]?.name ?? right.productId,
          ),
        _InventorySort.stockAscending => left.currentStock.compareTo(
          right.currentStock,
        ),
        _InventorySort.stockDescending => right.currentStock.compareTo(
          left.currentStock,
        ),
        _InventorySort.health => _healthPriority(
          inventoryCurrentHealth(left),
        ).compareTo(_healthPriority(inventoryCurrentHealth(right))),
      },
    );
    return result;
  }

  int _healthPriority(InventoryCurrentHealth health) => switch (health) {
    InventoryCurrentHealth.stockout => 0,
    InventoryCurrentHealth.lowStock => 1,
    InventoryCurrentHealth.overstock => 2,
    InventoryCurrentHealth.healthy => 3,
  };

  void _change(VoidCallback change) => setState(() {
    change();
    _page = 0;
  });

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pageCount = filtered.isEmpty
        ? 1
        : (filtered.length / _pageSize).ceil();
    if (_page >= pageCount) _page = pageCount - 1;
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, filtered.length);
    final pageItems = filtered.sublist(start, end);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Inventory Intelligence'),
        ),
        const SizedBox(height: 8),
        Text(
          'Inventory Explorer',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 5),
        Text(
          '${widget.store.name} (${widget.store.id}) | ${widget.records.length} inventory records',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        _filters(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                filtered.isEmpty
                    ? 'No matching inventory records'
                    : 'Showing ${start + 1}-$end of ${filtered.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Text('Rows: '),
            DropdownButton<int>(
              value: _pageSize,
              items: const [
                DropdownMenuItem(value: 25, child: Text('25')),
                DropdownMenuItem(value: 50, child: Text('50')),
              ],
              onChanged: (value) {
                if (value != null) _change(() => _pageSize = value);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        _InventoryExplorerTable(
          records: pageItems,
          products: widget.products,
          onOpen: _openProduct,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
              child: const Text('Previous'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('${_page + 1} of $pageCount'),
            ),
            OutlinedButton(
              onPressed: _page + 1 < pageCount
                  ? () => setState(() => _page++)
                  : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filters() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE1E7F0)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth >= 560
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _change(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search',
                  hintText: 'Product name or ID',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              width: width,
              child: _dropdown<InventoryCurrentHealth>(
                label: 'Health',
                value: _health,
                values: InventoryCurrentHealth.values,
                itemLabel: (value) => value.label,
                onChanged: (value) => _change(() => _health = value),
              ),
            ),
            SizedBox(
              width: width,
              child: _dropdown<String>(
                label: 'Category',
                value: _category,
                values: _metadata((product) => product.category),
                itemLabel: (value) => value,
                onChanged: (value) => _change(() => _category = value),
              ),
            ),
            SizedBox(
              width: width,
              child: _dropdown<String>(
                label: 'Brand',
                value: _brand,
                values: _metadata((product) => product.brand),
                itemLabel: (value) => value,
                onChanged: (value) => _change(() => _brand = value),
              ),
            ),
            SizedBox(
              width: width,
              child: _dropdown<String>(
                label: 'Gender',
                value: _gender,
                values: _metadata((product) => product.gender),
                itemLabel: (value) => value,
                onChanged: (value) => _change(() => _gender = value),
              ),
            ),
            SizedBox(
              width: width,
              child: DropdownButtonFormField<_InventorySort>(
                initialValue: _sort,
                decoration: const InputDecoration(labelText: 'Sort'),
                items: [
                  for (final value in _InventorySort.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) _change(() => _sort = value);
                },
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> values,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) => DropdownButtonFormField<T>(
    key: ValueKey('$label-$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      DropdownMenuItem<T>(value: null, child: const Text('All')),
      for (final item in values)
        DropdownMenuItem(value: item, child: Text(itemLabel(item))),
    ],
    onChanged: onChanged,
  );

  void _openProduct(InventoryRecord record) => showInventoryProductDetail(
    context: context,
    record: record,
    product: widget.products[record.productId],
    store: widget.store,
    workflow: widget.workflow,
    onRunForecast: widget.onRunForecast,
  );
}

enum _InventorySort { product, stockAscending, stockDescending, health }

extension on _InventorySort {
  String get label => switch (this) {
    _InventorySort.product => 'Product name',
    _InventorySort.stockAscending => 'Stock: low to high',
    _InventorySort.stockDescending => 'Stock: high to low',
    _InventorySort.health => 'Attention priority',
  };
}

class _InventoryExplorerTable extends StatelessWidget {
  const _InventoryExplorerTable({
    required this.records,
    required this.products,
    required this.onOpen,
  });
  final List<InventoryRecord> records;
  final Map<String, ForecastProductOption> products;
  final ValueChanged<InventoryRecord> onOpen;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE1E7F0)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Current stock'), numeric: true),
          DataColumn(label: Text('Reorder level'), numeric: true),
          DataColumn(label: Text('Maximum stock'), numeric: true),
          DataColumn(label: Text('Lead time')),
          DataColumn(label: Text('Health')),
        ],
        rows: [
          for (final record in records)
            DataRow(
              onSelectChanged: (_) => onOpen(record),
              cells: [
                DataCell(
                  SizedBox(
                    width: 250,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          products[record.productId]?.name ?? record.productId,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          record.productId,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(Text('${record.currentStock}')),
                DataCell(Text('${record.reorderLevel}')),
                DataCell(Text('${record.maxStock}')),
                DataCell(Text('${record.supplierLeadTime} days')),
                DataCell(_HealthBadge(health: inventoryCurrentHealth(record))),
              ],
            ),
        ],
      ),
    ),
  );
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.health});
  final InventoryCurrentHealth health;
  @override
  Widget build(BuildContext context) {
    final color = switch (health) {
      InventoryCurrentHealth.healthy => const Color(0xFF17875D),
      InventoryCurrentHealth.stockout => const Color(0xFFD92D20),
      InventoryCurrentHealth.lowStock => const Color(0xFFDC6803),
      InventoryCurrentHealth.overstock => const Color(0xFF7A5AF8),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        health.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<void> showInventoryProductDetail({
  required BuildContext context,
  required InventoryRecord record,
  required ForecastProductOption? product,
  required ForecastStoreOption store,
  required DecisionWorkflow? workflow,
  required RunInventoryForecast onRunForecast,
}) async {
  final matchingWorkflow =
      workflow?.storeId == record.storeId &&
          workflow?.productId == record.productId
      ? workflow
      : null;
  final health = inventoryCurrentHealth(record);
  final explanation = switch (health) {
    InventoryCurrentHealth.stockout =>
      'No stock is currently available for this product.',
    InventoryCurrentHealth.lowStock =>
      'Current stock is ${record.reorderLevel - record.currentStock} units below the reorder level.',
    InventoryCurrentHealth.overstock =>
      'Current stock has reached the configured overstock threshold.',
    InventoryCurrentHealth.healthy =>
      'Current stock is within the configured operating range.',
  };
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product?.name ?? record.productId,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${record.productId} | ${store.name} (${store.id})',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 30),
              const Text(
                'CURRENT INVENTORY',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475467),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 14,
                children: [
                  _DetailValue('Current stock', '${record.currentStock} units'),
                  _DetailValue('Reorder level', '${record.reorderLevel} units'),
                  _DetailValue('Maximum stock', '${record.maxStock} units'),
                  _DetailValue('Lead time', '${record.supplierLeadTime} days'),
                  _DetailValue(
                    'Last updated',
                    record.lastUpdated ?? 'Not available',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'INVENTORY HEALTH',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475467),
                ),
              ),
              const SizedBox(height: 10),
              _HealthBadge(health: health),
              const SizedBox(height: 8),
              Text(explanation),
              const Divider(height: 32),
              const Text(
                'FORECAST INTELLIGENCE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475467),
                ),
              ),
              const SizedBox(height: 10),
              if (matchingWorkflow?.intelligence case final intelligence?) ...[
                Wrap(
                  spacing: 24,
                  runSpacing: 14,
                  children: [
                    _DetailValue(
                      'Forecast demand',
                      '${intelligence.forecastDemand} units',
                    ),
                    _DetailValue(
                      'Days on hand',
                      intelligence.daysOnHand.toStringAsFixed(1),
                    ),
                    _DetailValue(
                      'Projected stock',
                      '${matchingWorkflow!.projectedStock.toStringAsFixed(0)} units',
                    ),
                    _DetailValue(
                      'Required stock',
                      '${matchingWorkflow.requiredStock.toStringAsFixed(0)} units',
                    ),
                    _DetailValue(
                      'Safety-stock shortage',
                      '${matchingWorkflow.safetyStockShortage} units',
                    ),
                    _DetailValue('Stockout risk', intelligence.stockoutRisk),
                    _DetailValue(
                      'Recommended action',
                      intelligence.operationalAction,
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'No forecast-backed analysis is available for this product yet.',
                ),
                const SizedBox(height: 4),
                const Text(
                  'Run a forecast to evaluate future demand, projected inventory and stock risk.',
                  style: TextStyle(color: Color(0xFF667085)),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onRunForecast(record.storeId, record.productId);
                },
                icon: const Icon(Icons.show_chart),
                label: Text(
                  matchingWorkflow == null ? 'Run forecast' : 'View forecast',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DetailValue extends StatelessWidget {
  const _DetailValue(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 130, maxWidth: 210),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
