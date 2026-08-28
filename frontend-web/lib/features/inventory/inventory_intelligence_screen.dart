// Final-polish pass: standardizes the header, refresh action, and empty states.
import 'package:flutter/material.dart';

import '../workflow/inventory_decision_workflow_controller.dart';
import '../workflow/active_workflow_banner.dart';
import '../workflow/workflow_progress_indicator.dart';

import '../../models/forecast/forecast_catalog_option.dart';
import '../../models/inventory/inventory_record.dart';
import '../../services/forecast_api_service.dart';
import '../../services/inventory_api_service.dart';
import '../../core/widgets/application_page_layout.dart';
import '../../core/widgets/application_ui_components.dart';
import 'inventory_attention_section.dart';
import 'inventory_explorer.dart';
import 'inventory_health_summary.dart';
import 'showroom_inventory_kpi_summary.dart';

/// Live inventory explorer and foundation for forecast-backed intelligence.
class InventoryIntelligenceScreen extends StatefulWidget {
  const InventoryIntelligenceScreen({
    required this.workflowController,
    required this.onRunForecast,
    super.key,
  });

  final InventoryDecisionWorkflowController workflowController;
  final RunInventoryForecast onRunForecast;
  @override
  State<InventoryIntelligenceScreen> createState() =>
      _InventoryIntelligenceScreenState();
}

class _InventoryIntelligenceScreenState
    extends State<InventoryIntelligenceScreen> {
  final _catalogService = ForecastApiService();
  final _inventoryService = InventoryApiService();
  late Future<ForecastCatalog> _catalogFuture;
  ForecastStoreOption? _store;
  Future<List<InventoryRecord>>? _inventoryFuture;
  bool _showExplorer = false;
  bool _showWorkflowIntelligence = false;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _catalogService.getCatalog();
  }

  void _loadInventory(ForecastStoreOption store) {
    setState(() {
      _store = store;
      _inventoryFuture = _inventoryService.getStoreInventory(store.id);
      _showExplorer = false;
    });
  }

  void _refresh() {
    ForecastApiService.clearCatalogCache();
    setState(() {
      _catalogFuture = _catalogService.getCatalog();
      if (_store != null) {
        _inventoryFuture = _inventoryService.getStoreInventory(_store!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final workflow = widget.workflowController.current;
    return ApplicationPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ApplicationPageHeader(
            title: 'Inventory Intelligence',
            subtitle:
                'Inspect inventory health and stock conditions across showrooms',
            onRefresh: _refresh,
            refreshTooltip: 'Refresh inventory data',
          ),
          const SizedBox(height: 24),
          if (workflow != null && _showWorkflowIntelligence) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _showWorkflowIntelligence = false),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to showroom inventory'),
              ),
            ),
            const SizedBox(height: 14),
            _ActiveWorkflowIntelligence(
              workflowController: widget.workflowController,
            ),
          ] else ...[
            if (workflow != null) ...[
              _AvailableInventoryWorkflow(
                storeId: workflow.storeId,
                productId: workflow.productId,
                forecastType: workflow.forecastType,
                onView: () => setState(() => _showWorkflowIntelligence = true),
                onClear: widget.workflowController.clearActiveWorkflow,
              ),
              const SizedBox(height: 18),
            ],
            FutureBuilder<ForecastCatalog>(
              future: _catalogFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _InventoryLoading(
                    label: 'Loading showroom catalog…',
                  );
                }
                if (snapshot.hasError) {
                  return _InventoryError(
                    message: snapshot.error.toString(),
                    onRetry: () => setState(
                      () => _catalogFuture = _catalogService.getCatalog(),
                    ),
                  );
                }
                final catalog = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: DropdownButtonFormField<ForecastStoreOption>(
                          initialValue: _store,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Showroom',
                          ),
                          items: [
                            for (final store in catalog.stores)
                              DropdownMenuItem(
                                value: store,
                                child: Text('${store.name} (${store.id})'),
                              ),
                          ],
                          onChanged: (store) {
                            if (store != null) {
                              _loadInventory(store);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_inventoryFuture == null)
                      const _InventoryInitialState()
                    else
                      FutureBuilder<List<InventoryRecord>>(
                        future: _inventoryFuture,
                        builder: (context, inventorySnapshot) {
                          if (inventorySnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const _InventoryLoading(
                              label: 'Loading current inventory…',
                            );
                          }
                          if (inventorySnapshot.hasError) {
                            return _InventoryError(
                              message: inventorySnapshot.error.toString(),
                              onRetry: () => _loadInventory(_store!),
                            );
                          }
                          final records = inventorySnapshot.data ?? const [];
                          if (records.isEmpty) {
                            return const _InventoryEmptyState();
                          }
                          final products = {
                            for (final product in catalog.products)
                              product.id: product,
                          };
                          if (_showExplorer) {
                            return InventoryExplorer(
                              store: _store!,
                              records: records,
                              products: products,
                              workflow: widget.workflowController.current,
                              onBack: () =>
                                  setState(() => _showExplorer = false),
                              onRunForecast: widget.onRunForecast,
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShowroomInventoryKpiSummary(records: records),
                              const SizedBox(height: 20),
                              InventoryHealthSummary(records: records),
                              const SizedBox(height: 24),
                              InventoryAttentionSection(
                                records: records,
                                products: products,
                                onOpenProduct: (record) =>
                                    showInventoryProductDetail(
                                      context: context,
                                      record: record,
                                      product: products[record.productId],
                                      store: _store!,
                                      workflow:
                                          widget.workflowController.current,
                                      onRunForecast: widget.onRunForecast,
                                    ),
                                onViewAll: () =>
                                    setState(() => _showExplorer = true),
                              ),
                              const SizedBox(height: 24),
                              _BrowseAllInventory(
                                count: records.length,
                                onBrowse: () =>
                                    setState(() => _showExplorer = true),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Keeps workflow context visible without replacing the showroom workspace.
class _AvailableInventoryWorkflow extends StatelessWidget {
  const _AvailableInventoryWorkflow({
    required this.storeId,
    required this.productId,
    required this.forecastType,
    required this.onView,
    required this.onClear,
  });

  final String storeId;
  final String productId;
  final String forecastType;
  final VoidCallback onView;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.account_tree_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Forecast workflow available',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text('$storeId  •  $productId  •  ${_label(forecastType)}'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(onPressed: onClear, child: const Text('Clear workflow')),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onView,
            child: const Text('View workflow intelligence'),
          ),
        ],
      ),
    ),
  );
}

/// Detailed intelligence view derived from the backend-owned active workflow.
/// It deliberately performs no API request when managers arrive from Forecasting.
class _ActiveWorkflowIntelligence extends StatelessWidget {
  const _ActiveWorkflowIntelligence({required this.workflowController});

  final InventoryDecisionWorkflowController workflowController;

  @override
  Widget build(BuildContext context) {
    final workflow = workflowController.current!;
    final intelligence = workflow.intelligence;
    if (intelligence == null) {
      return const _InventoryEmptyState(
        message: 'This workflow does not contain inventory intelligence.',
      );
    }

    final horizonDays = workflow.forecast?.days.length;
    final primaryAction = intelligence.operationalAction;
    final commercialAction = intelligence.recommendedAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActiveWorkflowBanner(workflow: workflow),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkflowProgressIndicator(
                  currentStage: workflowController.currentStage,
                  noReplenishmentRequired:
                      workflow.status == 'NO_ACTION_REQUIRED',
                ),
                const SizedBox(height: 20),
                Text(
                  'Operational inventory position',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  horizonDays == null
                      ? 'Forecast-backed inventory interpretation'
                      : '$horizonDays-day forecast-backed inventory interpretation',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                _IntelligenceMetricGrid(
                  metrics: [
                    ('Current stock', '${workflow.currentStock} units'),
                    ('Forecast demand', '${intelligence.forecastDemand} units'),
                    (
                      'Projected stock',
                      '${workflow.projectedStock.toStringAsFixed(0)} units',
                    ),
                    ('Reorder level', '${workflow.reorderLevel} units'),
                    (
                      'Required stock',
                      '${workflow.requiredStock.toStringAsFixed(0)} units',
                    ),
                    (
                      'Safety-stock shortage',
                      '${workflow.safetyStockShortage} units',
                    ),
                    (
                      'Days on hand',
                      intelligence.daysOnHand.toStringAsFixed(1),
                    ),
                    ('Stock health', _label(intelligence.stockHealth)),
                    ('Stockout risk', _label(intelligence.stockoutRisk)),
                    ('Overstock risk', _label(intelligence.overstockRisk)),
                    ('Inventory value', _currency(intelligence.inventoryValue)),
                    (
                      'Potential revenue',
                      _currency(intelligence.potentialRevenue),
                    ),
                    (
                      'Potential profit',
                      _currency(intelligence.potentialProfit),
                    ),
                  ],
                ),
                const Divider(height: 34),
                _DecisionInterpretation(
                  noReplenishmentRequired:
                      workflow.status == 'NO_ACTION_REQUIRED',
                  operationalStatus: intelligence.operationalStatus,
                  primaryAction: primaryAction,
                  operationalReason: intelligence.operationalReason,
                  commercialAction: commercialAction,
                  commercialReason: intelligence.reason,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IntelligenceMetricGrid extends StatelessWidget {
  const _IntelligenceMetricGrid({required this.metrics});

  final List<(String, String)> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= 900
          ? 4
          : width >= 600
          ? 3
          : width >= 360
          ? 2
          : 1;
      const gap = 12.0;
      final itemWidth = (width - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final metric in metrics)
            SizedBox(
              width: itemWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE4E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metric.$1,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        metric.$2,
                        style: const TextStyle(fontWeight: FontWeight.w700),
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

class _DecisionInterpretation extends StatelessWidget {
  const _DecisionInterpretation({
    required this.noReplenishmentRequired,
    required this.operationalStatus,
    required this.primaryAction,
    required this.operationalReason,
    required this.commercialAction,
    required this.commercialReason,
  });

  final bool noReplenishmentRequired;
  final String operationalStatus;
  final String primaryAction;
  final String operationalReason;
  final String commercialAction;
  final String commercialReason;

  @override
  Widget build(BuildContext context) {
    final showCommercialGuidance =
        noReplenishmentRequired &&
        commercialAction != 'NO_ACTION' &&
        commercialAction != 'MONITOR';
    final displayedPrimaryAction = noReplenishmentRequired
        ? 'No replenishment required'
        : _label(primaryAction);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connected workflow decision',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Chip(label: Text('Status: ${_label(operationalStatus)}')),
            Chip(
              avatar: const Icon(Icons.task_alt, size: 18),
              label: Text('Primary action: $displayedPrimaryAction'),
            ),
          ],
        ),
        if (operationalReason.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(operationalReason),
        ],
        if (showCommercialGuidance) ...[
          const SizedBox(height: 16),
          Text(
            'Supporting commercial analysis',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            '${_label(commercialAction)}${commercialReason.isEmpty ? '' : ': $commercialReason'}',
          ),
        ],
      ],
    );
  }
}

String _currency(double value) => 'LKR ${value.toStringAsFixed(2)}';

String _label(String value) => value
    .toLowerCase()
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

// Kept temporarily as a legacy rendering reference while the explorer is
// verified against the same API response.
// ignore: unused_element
class _InventoryTable extends StatelessWidget {
  const _InventoryTable({required this.records, required this.products});
  final List<InventoryRecord> records;
  final Map<String, ForecastProductOption> products;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Current inventory (${records.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Tooltip(
                  message:
                      'Forecast-backed health analysis will use a product-level 30-day demand contract.',
                  child: Icon(Icons.info_outline, color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('Current stock'), numeric: true),
                DataColumn(label: Text('Reorder level'), numeric: true),
                DataColumn(label: Text('Maximum stock'), numeric: true),
                DataColumn(label: Text('Lead time')),
                DataColumn(label: Text('Last updated')),
              ],
              rows: [
                for (final record in records)
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 250,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                products[record.productId]?.name ??
                                    record.productId,
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
                      DataCell(Text(record.lastUpdated ?? '—')),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseAllInventory extends StatelessWidget {
  const _BrowseAllInventory({required this.count, required this.onBrowse});
  final int count;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE1E7F0)),
    ),
    child: Row(
      children: [
        const Icon(Icons.view_list_outlined, color: Color(0xFF155EEF)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All inventory',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '$count products available in this showroom',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onBrowse,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Browse all inventory'),
        ),
      ],
    ),
  );
}

class _InventoryInitialState extends StatelessWidget {
  const _InventoryInitialState();
  @override
  Widget build(BuildContext context) => const ApplicationEmptyState(
    icon: Icons.storefront_outlined,
    title: 'Select a showroom',
    message: 'Choose a showroom to inspect its current inventory.',
  );
}

class _InventoryLoading extends StatelessWidget {
  const _InventoryLoading({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class _InventoryEmptyState extends StatelessWidget {
  const _InventoryEmptyState({
    this.message = 'No inventory records were found for this showroom.',
  });

  final String message;
  @override
  Widget build(BuildContext context) => ApplicationEmptyState(
    icon: Icons.inventory_2_outlined,
    title: 'No inventory records',
    message: message,
  );
}

class _InventoryError extends StatelessWidget {
  const _InventoryError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
