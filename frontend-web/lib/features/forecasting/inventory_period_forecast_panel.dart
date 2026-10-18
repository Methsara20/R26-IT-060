import 'package:flutter/material.dart';

import '../../models/forecast/forecast_catalog_option.dart';
import '../../models/forecast/inventory_period_forecast.dart';
import '../../services/forecast_api_service.dart';

/// Manager-facing form for backend-prepared monthly and quarterly forecasts.
class InventoryPeriodForecastPanel extends StatefulWidget {
  const InventoryPeriodForecastPanel({
    required this.catalog,
    required this.quarterly,
    required this.onStartOperationalWorkflow,
    super.key,
  });

  final ForecastCatalog catalog;
  final bool quarterly;
  final void Function(ForecastStoreOption, ForecastProductOption)
  onStartOperationalWorkflow;

  @override
  State<InventoryPeriodForecastPanel> createState() =>
      _InventoryPeriodForecastPanelState();
}

class _InventoryPeriodForecastPanelState
    extends State<InventoryPeriodForecastPanel> {
  final _service = ForecastApiService();
  final _formKey = GlobalKey<FormState>();
  ForecastStoreOption? _store;
  String? _category;
  String? _brand;
  String? _gender;
  late int _year;
  late int _period;
  bool _submitting = false;
  String? _error;
  InventoryPeriodForecast? _result;
  ForecastProductOption? _drillDownProduct;

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _period = widget.quarterly ? ((now.month - 1) ~/ 3) + 1 : now.month;
  }

  @override
  void didUpdateWidget(covariant InventoryPeriodForecastPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quarterly != widget.quarterly) {
      final now = DateTime.now();
      _period = widget.quarterly ? ((now.month - 1) ~/ 3) + 1 : now.month;
      _result = null;
      _drillDownProduct = null;
      _error = null;
    }
  }

  List<String> get _categories =>
      _unique(widget.catalog.products.map((product) => product.category));

  List<String> get _brands => _unique(
    widget.catalog.products
        .where((product) => product.category == _category)
        .map((product) => product.brand),
  );

  List<String> get _genders => _unique(
    widget.catalog.products
        .where(
          (product) => product.category == _category && product.brand == _brand,
        )
        .map((product) => product.gender),
  );

  List<String> _unique(Iterable<String> values) {
    final result = values.toSet().toList()..sort();
    return result;
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
      _result = null;
      _drillDownProduct = null;
    });
    try {
      final result = await _service.createInventoryPeriodForecast(
        quarterly: widget.quarterly,
        storeId: _store!.id,
        category: _category!,
        brand: _brand!,
        gender: _gender!,
        year: _year,
        period: _period,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Strategic inventory forecast',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.quarterly
                        ? 'Plan a long-term quarterly inventory outlook. '
                              'System-prepared historical, weather and inventory '
                              'features are added automatically.'
                        : 'Plan demand for a selected month. System-prepared '
                              'historical, weather and inventory features are '
                              'added automatically.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 900
                          ? 3
                          : constraints.maxWidth >= 620
                          ? 2
                          : 1;
                      const spacing = 14.0;
                      final width =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                      final fields = <Widget>[
                        _dropdown<ForecastStoreOption>(
                          label: 'Showroom',
                          value: _store,
                          items: widget.catalog.stores,
                          itemLabel: (store) => '${store.name} (${store.id})',
                          onChanged: (value) => setState(() => _store = value),
                        ),
                        _dropdown<String>(
                          label: 'Category',
                          value: _category,
                          items: _categories,
                          itemLabel: (value) => value,
                          onChanged: (value) => setState(() {
                            _category = value;
                            _brand = null;
                            _gender = null;
                          }),
                        ),
                        _dropdown<String>(
                          label: 'Brand',
                          value: _brand,
                          items: _brands,
                          itemLabel: (value) => value,
                          onChanged: _category == null
                              ? null
                              : (value) => setState(() {
                                  _brand = value;
                                  _gender = null;
                                }),
                        ),
                        _dropdown<String>(
                          label: 'Gender',
                          value: _gender,
                          items: _genders,
                          itemLabel: (value) => value,
                          onChanged: _brand == null
                              ? null
                              : (value) => setState(() => _gender = value),
                        ),
                        _dropdown<int>(
                          label: 'Year',
                          value: _year,
                          items: [
                            for (
                              var year = DateTime.now().year;
                              year <= DateTime.now().year + 4;
                              year++
                            )
                              year,
                          ],
                          itemLabel: (value) => value.toString(),
                          onChanged: (value) => setState(() => _year = value!),
                        ),
                        _dropdown<int>(
                          label: widget.quarterly ? 'Quarter' : 'Month',
                          value: _period,
                          items: widget.quarterly
                              ? [1, 2, 3, 4]
                              : [
                                  for (var month = 1; month <= 12; month++)
                                    month,
                                ],
                          itemLabel: (value) => widget.quarterly
                              ? 'Quarter $value'
                              : _monthNames[value - 1],
                          onChanged: (value) =>
                              setState(() => _period = value!),
                        ),
                      ];
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final field in fields)
                            SizedBox(width: width, child: field),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_graph),
                      label: Text(
                        _submitting ? 'Generating…' : 'Generate forecast',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 20),
          _PeriodError(message: _error!, onRetry: _submit),
        ],
        if (_result != null) ...[
          const SizedBox(height: 20),
          _InventoryPeriodResults(
            result: _result!,
            matchingProducts: widget.catalog.products
                .where(
                  (product) =>
                      product.category == _result!.category &&
                      product.brand == _result!.brand &&
                      product.gender == _result!.gender,
                )
                .toList(),
            selectedProduct: _drillDownProduct,
            onProductChanged: (product) =>
                setState(() => _drillDownProduct = product),
            onStartOperationalWorkflow:
                _drillDownProduct == null || _store == null
                ? null
                : () => widget.onStartOperationalWorkflow(
                    _store!,
                    _drillDownProduct!,
                  ),
          ),
        ],
      ],
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?>? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item,
            child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _submitting ? null : onChanged,
      validator: (value) => value == null ? 'Select $label' : null,
    );
  }
}

class _InventoryPeriodResults extends StatelessWidget {
  const _InventoryPeriodResults({
    required this.result,
    required this.matchingProducts,
    required this.selectedProduct,
    required this.onProductChanged,
    required this.onStartOperationalWorkflow,
  });
  final InventoryPeriodForecast result;
  final List<ForecastProductOption> matchingProducts;
  final ForecastProductOption? selectedProduct;
  final ValueChanged<ForecastProductOption?> onProductChanged;
  final VoidCallback? onStartOperationalWorkflow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Strategic demand outlook',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                _StrategyIdentity(label: 'Showroom', value: result.storeId),
                _StrategyIdentity(label: 'Category', value: result.category),
                _StrategyIdentity(label: 'Brand', value: result.brand),
                _StrategyIdentity(label: 'Gender', value: result.gender),
                _StrategyIdentity(
                  label: 'Planning horizon',
                  value: result.months.length == 1 ? 'Monthly' : 'Quarterly',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _PeriodSummary(
              label: result.months.length == 1
                  ? 'Monthly demand'
                  : 'Quarterly demand',
              value: '${result.totalPredictedDemand} units',
              icon: Icons.inventory_2_outlined,
            ),
            _PeriodSummary(
              label: 'Average confidence',
              value: '${result.averageConfidencePercentage}%',
              icon: Icons.verified_outlined,
            ),
            _PeriodSummary(
              label: 'Weather source',
              value: result.weatherSource,
              icon: Icons.cloud_outlined,
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final month in result.months)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MonthForecastCard(month: month),
          ),
        const SizedBox(height: 6),
        _StrategicInterpretation(result: result),
        const SizedBox(height: 14),
        _ProductDrillDown(
          products: matchingProducts,
          selectedProduct: selectedProduct,
          onProductChanged: onProductChanged,
          onStartOperationalWorkflow: onStartOperationalWorkflow,
        ),
      ],
    );
  }
}

class _StrategyIdentity extends StatelessWidget {
  const _StrategyIdentity({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 170,
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

class _StrategicInterpretation extends StatelessWidget {
  const _StrategicInterpretation({required this.result});
  final InventoryPeriodForecast result;

  @override
  Widget build(BuildContext context) {
    final peak = result.months.reduce(
      (current, next) =>
          next.predictedDemand > current.predictedDemand ? next : current,
    );
    final peakName =
        peak.monthName ??
        _InventoryPeriodForecastPanelState._monthNames[peak.month - 1];
    final totalRainyDays = result.months.fold<int>(
      0,
      (total, month) => total + (month.weather.rainyDays ?? 0),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory planning interpretation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _PlanningSignal(
                  icon: Icons.trending_up,
                  title: 'Peak planning month',
                  description:
                      '$peakName has the highest returned demand forecast '
                      'at ${peak.predictedDemand} units.',
                ),
                _PlanningSignal(
                  icon: Icons.verified_outlined,
                  title: 'Forecast confidence',
                  description:
                      '${result.averageConfidencePercentage}% average '
                      'confidence across this planning horizon.',
                ),
                _PlanningSignal(
                  icon: Icons.umbrella_outlined,
                  title: 'Weather consideration',
                  description:
                      '$totalRainyDays rainy day(s) are represented in the '
                      'backend seasonal profiles.',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'This is aggregated category/brand/gender demand. It identifies '
              'a planning opportunity, but it cannot confirm a product-level '
              'stockout or safely create a transfer.',
              style: TextStyle(color: Color(0xFF5D6B82), height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningSignal extends StatelessWidget {
  const _PlanningSignal({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
    width: 330,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE4E8F0)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(description),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProductDrillDown extends StatelessWidget {
  const _ProductDrillDown({
    required this.products,
    required this.selectedProduct,
    required this.onProductChanged,
    required this.onStartOperationalWorkflow,
  });
  final List<ForecastProductOption> products;
  final ForecastProductOption? selectedProduct;
  final ValueChanged<ForecastProductOption?> onProductChanged;
  final VoidCallback? onStartOperationalWorkflow;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product drill-down',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a real product from this forecast group to begin a new '
            'product-level operational forecast. Aggregated demand will not '
            'be copied into the product workflow.',
          ),
          const SizedBox(height: 16),
          if (products.isEmpty)
            const Text('No matching catalog products are available.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 620;
                final selector = DropdownButtonFormField<ForecastProductOption>(
                  initialValue: selectedProduct,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: [
                    for (final product in products)
                      DropdownMenuItem(
                        value: product,
                        child: Text(
                          '${product.name} (${product.id})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onProductChanged,
                );
                final button = FilledButton.icon(
                  onPressed: onStartOperationalWorkflow,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Start operational workflow'),
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [selector, const SizedBox(height: 12), button],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: selector),
                    const SizedBox(width: 12),
                    button,
                  ],
                );
              },
            ),
        ],
      ),
    ),
  );
}

class _MonthForecastCard extends StatelessWidget {
  const _MonthForecastCard({required this.month});
  final InventoryMonthForecast month;
  @override
  Widget build(BuildContext context) {
    final name =
        month.monthName ??
        _InventoryPeriodForecastPanelState._monthNames[month.month - 1];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  Text('${month.year}'),
                ],
              ),
            ),
            _PeriodValue(
              icon: Icons.inventory_2_outlined,
              text: '${month.predictedDemand} units',
            ),
            _PeriodValue(
              icon: Icons.verified_outlined,
              text: '${month.confidencePercentage}% confidence',
            ),
            _PeriodValue(
              icon: Icons.thermostat,
              text: month.weather.averageTemperature == null
                  ? '—'
                  : '${month.weather.averageTemperature!.toStringAsFixed(1)}°C avg',
            ),
            _PeriodValue(
              icon: Icons.water_drop_outlined,
              text: month.weather.averageHumidity == null
                  ? '—'
                  : '${month.weather.averageHumidity!.toStringAsFixed(0)}% humidity',
            ),
            _PeriodValue(
              icon: Icons.grain,
              text:
                  '${month.weather.totalRainfall?.toStringAsFixed(1) ?? '—'} mm rain',
            ),
            _PeriodValue(
              icon: Icons.umbrella_outlined,
              text: '${month.weather.rainyDays ?? '—'} rainy days',
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSummary extends StatelessWidget {
  const _PeriodSummary({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 250,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PeriodValue extends StatelessWidget {
  const _PeriodValue({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF667085)),
      const SizedBox(width: 6),
      Text(text),
    ],
  );
}

class _PeriodError extends StatelessWidget {
  const _PeriodError({required this.message, required this.onRetry});
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
