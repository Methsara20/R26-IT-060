// Final-polish pass: standardizes the page header and waiting-state treatment.
import 'package:flutter/material.dart';

import '../../models/forecast/forecast_catalog_option.dart';
import '../../models/forecast/short_range_forecast.dart';
import '../../models/workflow/decision_workflow.dart';
import '../../services/decision_workflow_api_service.dart';
import '../../services/forecast_api_service.dart';
import '../../core/widgets/application_page_layout.dart';
import '../../core/widgets/application_ui_components.dart';
import '../workflow/inventory_decision_workflow_controller.dart';
import '../marketing_integration/models/marketing_opportunity.dart';
import '../marketing_integration/widgets/send_to_marketing_card.dart';
import 'forecast_daily_breakdown.dart';
import 'forecast_product_search_selector.dart';
import 'forecast_demand_trend_chart.dart';
import 'forecast_inventory_decision_panel.dart';
import 'forecast_result_summary.dart';
import 'forecast_selection_summary.dart';
import 'forecast_type_selector.dart';
import 'inventory_period_forecast_panel.dart';

/// Manager-facing entry point for weather-aware product forecasts.
class ForecastingOverviewScreen extends StatefulWidget {
  const ForecastingOverviewScreen({
    required this.workflowController,
    required this.onOpenIntelligence,
    required this.onOpenOptimization,
    required this.onOpenMovement,
    required this.onAskAssistant,
    this.initialStoreId,
    this.initialProductId,
    super.key,
  });

  final InventoryDecisionWorkflowController workflowController;
  final VoidCallback onOpenIntelligence;
  final VoidCallback onOpenOptimization;
  final VoidCallback onOpenMovement;
  final VoidCallback onAskAssistant;
  final String? initialStoreId;
  final String? initialProductId;

  @override
  State<ForecastingOverviewScreen> createState() =>
      _ForecastingOverviewScreenState();
}

class _ForecastingOverviewScreenState extends State<ForecastingOverviewScreen> {
  final _service = ForecastApiService();
  final _workflowService = DecisionWorkflowApiService();

  final _formKey = GlobalKey<FormState>();

  final _priceController = TextEditingController();

  final _promotionController = TextEditingController(text: '0');

  late Future<ForecastCatalog> _catalogFuture;

  ForecastProductOption? _product;
  ForecastStoreOption? _store;

  ShortRangeForecast? _result;
  DecisionWorkflow? _workflow;
  double? _submittedSellingPrice;
  double? _submittedPromotionPercent;

  String? _requestError;

  ForecastMode _mode = ForecastMode.daily;

  DateTime? _startDate;
  DateTime? _endDate;

  bool _submitting = false;
  bool _initialSelectionApplied = false;

  @override
  void initState() {
    super.initState();

    // ForecastApiService maintains a shared session-level cache.
    //
    // If this screen is recreated because the user navigates away
    // and returns, this call reuses the existing catalog instead
    // of requesting /products and /stores again.
    _catalogFuture = _service.getCatalog();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _promotionController.dispose();

    super.dispose();
  }

  void _refreshCatalog() {
    ForecastApiService.clearCatalogCache();
    setState(() {
      _catalogFuture = _service.getCatalog();
      _requestError = null;
    });
  }

  // =========================================================
  // SUBMIT CONNECTED WORKFLOW
  // =========================================================

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Custom requests require a complete range before
    // reaching the API.
    if (_mode == ForecastMode.custom &&
        (_startDate == null || _endDate == null)) {
      setState(() => _requestError = 'Select both a start date and end date.');

      return;
    }

    // Keep this guard at submission time as well as in the
    // date picker.
    //
    // Hot reload preserves widget state, so a date selected
    // before constraints changed could otherwise still reach
    // the backend.
    if (_mode == ForecastMode.custom &&
        (_startDate!.isBefore(
              _dateOnly(DateTime.now().add(const Duration(days: 1))),
            ) ||
            _endDate!.isAfter(_lastCustomForecastDate()) ||
            _endDate!.isBefore(_startDate!))) {
      setState(() {
        _requestError =
            'The selected dates are outside the available '
            'weather forecast window. Please choose new dates.';

        _result = null;
      });

      return;
    }

    final submittedSellingPrice = double.parse(_priceController.text);
    final enteredPromotionPercent = double.parse(_promotionController.text);
    final submittedPromotionPercent = enteredPromotionPercent > 0
        ? enteredPromotionPercent
        : null;

    setState(() {
      _submitting = true;
      _requestError = null;
      _result = null;
      _workflow = null;
      _submittedSellingPrice = null;
      _submittedPromotionPercent = null;
    });

    try {
      // One backend-owned workflow now produces:
      //
      // forecast
      //      ↓
      // inventory intelligence
      //      ↓
      // optimization analysis
      //      ↓
      // safe movement recommendation
      //
      // without duplicating the business logic in Flutter.

      final workflow = await _workflowService.analyze(
        forecastType: switch (_mode) {
          ForecastMode.daily => 'DAILY',
          ForecastMode.sevenDay => 'SEVEN_DAY',
          ForecastMode.custom => 'CUSTOM',
          _ => throw StateError('Grouped forecasts do not use this workflow.'),
        },
        storeId: _store!.id,
        productId: _product!.id,
        sellingPrice: submittedSellingPrice,
        promotionPercent: enteredPromotionPercent,
        startDate: _mode == ForecastMode.custom ? _startDate : null,
        endDate: _mode == ForecastMode.custom ? _endDate : null,
        idempotencyKey:
            'WEB-'
            '${DateTime.now().microsecondsSinceEpoch}-'
            '${_product!.id}-'
            '${_store!.id}',
      );

      if (!mounted) {
        return;
      }

      widget.workflowController.setCurrent(workflow);

      setState(() {
        _workflow = workflow;
        _result = workflow.forecast;
        _submittedSellingPrice = submittedSellingPrice;
        _submittedPromotionPercent = submittedPromotionPercent;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _requestError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  // =========================================================
  // SCREEN
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return ApplicationPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ApplicationPageHeader(
            title: 'Forecasting',
            subtitle:
                'Predict product demand using weather, historical patterns and inventory context',
            contextual: Chip(
              avatar: Icon(
                Icons.cloud_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: const Text('Weather-aware forecasting'),
            ),
            onRefresh: _refreshCatalog,
            refreshTooltip: 'Refresh forecast catalog',
          ),

          const SizedBox(height: 24),

          ForecastTypeSelector(
            selectedMode: _mode,
            onChanged: (value) {
              setState(() {
                _mode = value;

                _result = null;
                _workflow = null;
                _requestError = null;

                if (value == ForecastMode.custom) {
                  // Start with a clean range instead of
                  // retaining dates that may no longer fit
                  // the current weather window.
                  _startDate = null;
                  _endDate = null;
                }
              });
            },
          ),

          const SizedBox(height: 20),

          FutureBuilder<ForecastCatalog>(
            // IMPORTANT:
            //
            // Never call _service.getCatalog() directly here.
            //
            // FutureBuilder can rebuild many times.
            //
            // We use the Future created in initState instead.
            future: _catalogFuture,

            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _CatalogLoadingState();
              }

              if (snapshot.hasError) {
                return _CatalogErrorState(
                  message: snapshot.error.toString(),

                  // Retry is an explicit user action, so this
                  // is one of the few situations where we
                  // intentionally bypass the shared cache.
                  onRetry: () {
                    setState(() {
                      _catalogFuture = _service.getCatalog(forceRefresh: true);
                    });
                  },
                );
              }

              return _buildForm(snapshot.data!);
            },
          ),

          if (_requestError != null) ...[
            const SizedBox(height: 20),

            _InlineError(message: _requestError!, onRetry: _submit),
          ],

          if (_result == null &&
              _requestError == null &&
              !_submitting &&
              _mode != ForecastMode.monthly &&
              _mode != ForecastMode.quarterly) ...[
            const SizedBox(height: 20),
            const _ForecastEmptyState(),
          ],

          if (_result != null) ...[
            const SizedBox(height: 20),

            _ForecastResults(result: _result!),
          ],

          if (_workflow != null) ...[
            const SizedBox(height: 20),

            _DecisionWorkflowPanel(
              workflow: _workflow!,
              onOpenIntelligence: widget.onOpenIntelligence,
              onOpenOptimization: widget.onOpenOptimization,
              onOpenMovement: widget.onOpenMovement,
              onAskAssistant: widget.onAskAssistant,
            ),
            if (_workflow!.intelligence?.recommendedAction
                    .trim()
                    .toUpperCase() ==
                'PROMOTE') ...[
              const SizedBox(height: 14),
              SendToMarketingCard(
                opportunity: MarketingOpportunityRequest(
                  workflowId: _workflow!.id,
                  productId: _workflow!.productId,
                  productName: _product!.name,
                  storeId: _workflow!.storeId,
                  category: _product!.category,
                  subcategory: null,
                  brand: _product!.brand,
                  gender: _product!.gender,
                  currentStock: _workflow!.currentStock,
                  forecastDemand: _workflow!.intelligence!.forecastDemand,
                  requiredStock: _workflow!.requiredStock.round(),
                  excessQuantity: _workflow!.intelligence!.excessQuantity,
                  sellingPrice: _submittedSellingPrice,
                  promotionPercent: _submittedPromotionPercent,
                  stockHealth: _workflow!.intelligence!.stockHealth,
                  recommendedAction: _workflow!.intelligence!.recommendedAction,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // =========================================================
  // FORECAST FORM
  // =========================================================

  Widget _buildForm(ForecastCatalog catalog) {
    _applyInitialSelection(catalog);
    if (_mode == ForecastMode.monthly || _mode == ForecastMode.quarterly) {
      return InventoryPeriodForecastPanel(
        key: ValueKey(_mode),
        catalog: catalog,
        quarterly: _mode == ForecastMode.quarterly,
        onStartOperationalWorkflow: (store, product) {
          setState(() {
            _mode = ForecastMode.daily;
            _store = store;
            _product = product;
            _priceController.text = product.sellingPrice.toStringAsFixed(2);
            _promotionController.text = '0';
            _result = null;
            _workflow = null;
            _requestError = null;
          });
        },
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(switch (_mode) {
                ForecastMode.daily => 'Generate daily forecast',

                ForecastMode.sevenDay => 'Generate 7-day forecast',

                ForecastMode.custom => 'Generate custom forecast',

                ForecastMode.monthly => 'Generate monthly forecast',

                ForecastMode.quarterly => 'Generate quarterly forecast',
              }, style: Theme.of(context).textTheme.titleLarge),

              const SizedBox(height: 6),

              Text(
                _mode == ForecastMode.custom
                    ? 'Choose a future range inside the available '
                          'weather window. Weather is supplied '
                          'automatically by the backend.'
                    : 'Weather and forecast dates are supplied '
                          'automatically by the backend.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 20),

              const _GuidedStep(
                number: 1,
                title: 'Choose showroom',
                description: 'Select the retail location for this forecast.',
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<ForecastStoreOption>(
                initialValue: _store,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Showroom',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                items: [
                  for (final store in catalog.stores)
                    DropdownMenuItem(
                      value: store,
                      child: Text(
                        '${store.name} (${store.id})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() {
                        _store = value;
                        _result = null;
                        _workflow = null;
                      }),
                validator: (value) =>
                    value == null ? 'Select a showroom' : null,
              ),

              if (_store != null) ...[
                const SizedBox(height: 22),
                const _GuidedStep(
                  number: 2,
                  title: 'Choose product',
                  description:
                      'Search the cached catalog or narrow it with optional filters.',
                ),
                const SizedBox(height: 12),

                ForecastProductSearchSelector(
                  products: catalog.products,
                  selectedProduct: _product,
                  enabled: !_submitting,
                  onChanged: (value) {
                    setState(() {
                      _product = value;

                      if (value != null) {
                        _priceController.text = value.sellingPrice
                            .toStringAsFixed(2);
                      } else {
                        _priceController.clear();
                      }

                      _result = null;
                      _workflow = null;
                      _requestError = null;
                    });
                  },
                ),
              ],

              if (_product != null) ...[
                const SizedBox(height: 22),
                const _GuidedStep(
                  number: 3,
                  title: 'Forecast settings',
                  description:
                      'Review the auto-filled price and adjust promotion if needed.',
                ),
                const SizedBox(height: 12),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 720;

                    final fields = <Widget>[
                      TextFormField(
                        controller: _priceController,
                        enabled: !_submitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Selling price',
                          prefixText: 'LKR ',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final number = double.tryParse(value ?? '');

                          return number == null || number <= 0
                              ? 'Enter a valid price'
                              : null;
                        },
                      ),

                      TextFormField(
                        controller: _promotionController,
                        enabled: !_submitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Promotion',
                          suffixText: '%',
                          helperText:
                              'Included in the forecast demand request.',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final number = double.tryParse(value ?? '');

                          return number == null || number < 0 || number > 100
                              ? 'Enter 0–100'
                              : null;
                        },
                      ),
                    ];

                    if (_mode == ForecastMode.custom) {
                      fields.addAll([
                        _DateField(
                          label: 'Start date',
                          value: _startDate,
                          enabled: !_submitting,
                          onTap: _selectStartDate,
                        ),

                        _DateField(
                          label: 'End date',
                          value: _endDate,
                          enabled: !_submitting && _startDate != null,
                          onTap: _selectEndDate,
                        ),
                      ]);
                    }

                    if (stacked) {
                      return Column(
                        children: [
                          for (final field in fields)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: field,
                            ),
                        ],
                      );
                    }

                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final field in fields)
                          SizedBox(
                            width: (constraints.maxWidth - 14) / 2,
                            child: field,
                          ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                if (_store != null && _product != null)
                  ForecastSelectionSummary(
                    showroom: '${_store!.name} (${_store!.id})',
                    product: '${_product!.name} (${_product!.id})',
                    forecastType: switch (_mode) {
                      ForecastMode.daily => 'Daily',
                      ForecastMode.sevenDay => '7-Day',
                      ForecastMode.custom => 'Custom',
                      ForecastMode.monthly => 'Monthly',
                      ForecastMode.quarterly => 'Quarterly',
                    },
                    sellingPrice: 'LKR ${_priceController.text}',
                    promotion: '${_promotionController.text}%',
                    dateRange:
                        _mode == ForecastMode.custom &&
                            _startDate != null &&
                            _endDate != null
                        ? '${_formatDate(_startDate!)} – ${_formatDate(_endDate!)}'
                        : null,
                    submitting: _submitting,
                    onGenerate: _submitting ? null : _submit,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Applies an Inventory Intelligence handoff to the existing forecast form.
  /// Catalog data is already cached by [ForecastApiService], so this creates
  /// no additional request and does not bypass normal form validation.
  void _applyInitialSelection(ForecastCatalog catalog) {
    if (_initialSelectionApplied) return;
    _initialSelectionApplied = true;
    for (final store in catalog.stores) {
      if (store.id == widget.initialStoreId) {
        _store = store;
        break;
      }
    }
    for (final product in catalog.products) {
      if (product.id == widget.initialProductId) {
        _product = product;
        _priceController.text = product.sellingPrice.toStringAsFixed(2);
        break;
      }
    }
  }

  // =========================================================
  // CUSTOM FORECAST DATE PICKERS
  // =========================================================

  Future<void> _selectStartDate() async {
    final tomorrow = _dateOnly(DateTime.now().add(const Duration(days: 1)));

    final lastSupportedDate = _lastCustomForecastDate();

    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate ?? tomorrow,
      firstDate: tomorrow,
      lastDate: lastSupportedDate,
      helpText: 'Select forecast start date',
    );

    if (selected == null || !mounted) {
      return;
    }

    // Reset an end date that would make the range invalid
    // after this change.
    setState(() {
      _startDate = selected;

      if (_endDate == null ||
          _endDate!.isBefore(selected) ||
          _endDate!.difference(selected).inDays >= 14) {
        _endDate = selected;
      }

      _result = null;
      _requestError = null;
    });
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      return;
    }

    final weatherLimit = _lastCustomForecastDate();

    final rangeLimit = _startDate!.add(const Duration(days: 13));

    final lastDate = rangeLimit.isBefore(weatherLimit)
        ? rangeLimit
        : weatherLimit;

    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: lastDate,
      helpText: 'Select forecast end date',
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _endDate = selected;
      _result = null;
      _requestError = null;
    });
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _formatDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  DateTime _lastCustomForecastDate() {
    // The backend fetch includes today in its Open-Meteo
    // request.
    //
    // Therefore its 14-day request limit makes 13 days ahead
    // the last usable date.
    return _dateOnly(DateTime.now().add(const Duration(days: 13)));
  }
}

// ===========================================================
// DATE FIELD
// ===========================================================

class _GuidedStep extends StatelessWidget {
  const _GuidedStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final int number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEDF4FF),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          '$number',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatted = value == null
        ? 'Select date'
        : '${value!.year}-'
              '${value!.month.toString().padLeft(2, '0')}-'
              '${value!.day.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(formatted),
      ),
    );
  }
}

// ===========================================================
// FORECAST RESULTS
// ===========================================================

class _ForecastResults extends StatelessWidget {
  const _ForecastResults({required this.result});

  final ShortRangeForecast result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Forecast result', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ForecastResultSummary(result: result),
        if (result.days.length > 1) const SizedBox(height: 14),
        ForecastDemandTrendChart(days: result.days),
        const SizedBox(height: 14),
        ForecastDailyBreakdown(days: result.days),
      ],
    );
  }
}

class _ForecastEmptyState extends StatelessWidget {
  const _ForecastEmptyState();

  @override
  Widget build(BuildContext context) => const ApplicationEmptyState(
    icon: Icons.query_stats_outlined,
    title: 'No forecast generated yet',
    message: 'Choose a forecast type, showroom and product to begin.',
  );
}

// ===========================================================
// CONNECTED DECISION WORKFLOW
// ===========================================================

class _DecisionWorkflowPanel extends StatelessWidget {
  const _DecisionWorkflowPanel({
    required this.workflow,
    required this.onOpenIntelligence,
    required this.onOpenOptimization,
    required this.onOpenMovement,
    required this.onAskAssistant,
  });

  final DecisionWorkflow workflow;

  final VoidCallback onOpenIntelligence;

  final VoidCallback onOpenOptimization;

  final VoidCallback onOpenMovement;

  final VoidCallback onAskAssistant;

  @override
  Widget build(BuildContext context) {
    return ForecastInventoryDecisionPanel(
      workflow: workflow,
      onOpenIntelligence: onOpenIntelligence,
      onOpenOptimization: onOpenOptimization,
      onOpenMovement: onOpenMovement,
      onAskAssistant: onAskAssistant,
    );
  }
}

// ===========================================================
// WORKFLOW METRIC
// ===========================================================

// ignore: unused_element
class _WorkflowMetric extends StatelessWidget {
  const _WorkflowMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 175,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF68758C))),

        const SizedBox(height: 4),

        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

// ignore: unused_element
String _workflowLabel(String value) => value
    .toLowerCase()
    .split('_')
    .map(
      (part) => part.isEmpty
          ? part
          : '${part[0].toUpperCase()}'
                '${part.substring(1)}',
    )
    .join(' ');

// ===========================================================
// SUMMARY CARD
// ===========================================================

// ignore: unused_element
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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

// ===========================================================
// FORECAST DAY CARD
// ===========================================================

// ignore: unused_element
class _ForecastDayCard extends StatelessWidget {
  const _ForecastDayCard({required this.day});

  final ForecastDayResult day;

  @override
  Widget build(BuildContext context) {
    final date = day.date == null
        ? 'Date unavailable'
        : '${day.date!.year}-'
              '${day.date!.month.toString().padLeft(2, '0')}-'
              '${day.date!.day.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 28,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Day ${day.day}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(date),
                ],
              ),
            ),

            _DayValue(
              icon: Icons.shopping_bag_outlined,
              label: '${day.predictedDemand} units',
            ),

            _DayValue(
              icon: Icons.verified_outlined,
              label: '${day.confidencePercentage}% confidence',
            ),

            _DayValue(
              icon: Icons.thermostat,
              label: day.weather.temperature == null
                  ? '—'
                  : '${day.weather.temperature!.toStringAsFixed(1)}°C',
            ),

            _DayValue(
              icon: Icons.water_drop_outlined,
              label: day.weather.humidity == null
                  ? '—'
                  : '${day.weather.humidity!.toStringAsFixed(0)}% humidity',
            ),

            _DayValue(
              icon: Icons.grain,
              label: '${day.weather.rainfall?.toStringAsFixed(1) ?? '—'} mm',
            ),

            _DayValue(icon: Icons.cloud_outlined, label: day.weather.condition),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// DAY VALUE
// ===========================================================

class _DayValue extends StatelessWidget {
  const _DayValue({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF667085)),

      const SizedBox(width: 6),

      Text(label),
    ],
  );
}

// ===========================================================
// CATALOG LOADING
// ===========================================================

class _CatalogLoadingState extends StatelessWidget {
  const _CatalogLoadingState();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

// ===========================================================
// CATALOG ERROR
// ===========================================================

class _CatalogErrorState extends StatelessWidget {
  const _CatalogErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      _InlineError(message: message, onRetry: onRetry);
}

// ===========================================================
// INLINE ERROR
// ===========================================================

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
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
