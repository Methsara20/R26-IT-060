import 'package:flutter/material.dart';

import '../core/auth/marketing_auth_scope.dart';
import '../models/inventory_analysis_request.dart';
import '../services/inventory_analysis_service.dart';
import '../widgets/marketing_product_search_selector.dart';

class InventoryAnalysisScreen extends StatefulWidget {
  const InventoryAnalysisScreen({this.service, super.key});
  final InventoryAnalysisService? service;
  @override
  State<InventoryAnalysisScreen> createState() =>
      _InventoryAnalysisScreenState();
}

class _InventoryAnalysisScreenState extends State<InventoryAnalysisScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _reference = TextEditingController(),
      _lookup = TextEditingController(),
      _promotion = TextEditingController(),
      _discount = TextEditingController();
  InventoryAnalysisService? _service;
  bool _ownsService = false;
  List<MarketingCatalogChoice> _products = const [], _stores = const [];
  MarketingCatalogChoice? _product;
  String? _store, _error;
  DateTime? _start, _end;
  bool _loadingCatalog = true, _submitting = false, _refreshing = false;
  InventoryAnalysisRequest? _result;
  InventoryAnalysisHistory? _history;
  bool _loadingHistory = true;
  static const _historyLimit = 20;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service == null) {
      _ownsService = widget.service == null;
      _service =
          widget.service ??
          InventoryAnalysisService(session: MarketingAuthScope.read(context));
      _loadCatalog();
      _loadHistory();
    }
  }

  Future<void> _loadHistory({int skip = 0}) async {
    if (_refreshing) return;
    setState(() {
      _loadingHistory = true;
      _refreshing = true;
      _error = null;
    });
    try {
      final history = await _service!.history(skip: skip, limit: _historyLimit);
      if (mounted) setState(() => _history = history);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loadingHistory = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_ownsService) _service?.close();
    for (final c in [_name, _reference, _lookup, _promotion, _discount]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final data = await _service!.loadCatalog();
      if (!mounted) return;
      final principal = MarketingAuthScope.read(context).principal!;
      setState(() {
        _products = data.products;
        _stores = principal.globalAccess
            ? data.stores
            : data.stores
                  .where((s) => principal.storeIds.contains(s.id))
                  .toList();
        _loadingCatalog = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCatalog = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pick(bool start) async {
    final value = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (value != null) {
      setState(() {
        if (start) {
          _start = value;
          if (_end != null && _end!.isBefore(value)) _end = null;
        } else {
          _end = value;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting ||
        !(_form.currentState?.validate() ?? false) ||
        _start == null ||
        _end == null) {
      if (_start == null || _end == null) {
        setState(() => _error = 'Select campaign start and end dates.');
      }
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await _service!.submit(
        campaignReference: _reference.text.trim(),
        campaignName: _name.text.trim(),
        productId: _product!.id,
        storeId: _store!,
        startDate: _start!,
        endDate: _end!,
        promotionType: _promotion.text.trim().isEmpty
            ? null
            : _promotion.text.trim(),
        discountPercent: _discount.text.trim().isEmpty
            ? null
            : double.tryParse(_discount.text.trim()),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _lookup.text = result.requestId;
      });
      await _loadHistory();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _refresh() async {
    final id = _lookup.text.trim();
    if (id.isEmpty || _refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final value = await _service!.status(id);
      if (mounted) setState(() => _result = value);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String _date(DateTime? d) => d == null
      ? 'Select date'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  InputDecoration _dec(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Check with Inventory',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Submit a campaign proposal for manual Inventory review. Results use the baseline demand forecast; promotional uplift is not modeled.',
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _form,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 700;
                      final fields = [
                        TextFormField(
                          controller: _name,
                          decoration: _dec('Campaign name'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        TextFormField(
                          controller: _reference,
                          decoration: _dec('Campaign reference'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        MarketingProductSearchSelector(
                          products: _products,
                          selectedProduct: _product,
                          enabled: !_submitting,
                          onChanged: (value) =>
                              setState(() => _product = value),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _store,
                          isExpanded: true,
                          decoration: _dec('Showroom'),
                          items: _stores
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(
                                    s.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _store = v),
                          validator: (v) =>
                              v == null ? 'Select a showroom' : null,
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pick(true),
                          icon: const Icon(Icons.event),
                          label: Text('Start: ${_date(_start)}'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pick(false),
                          icon: const Icon(Icons.event),
                          label: Text('End: ${_date(_end)}'),
                        ),
                        TextFormField(
                          controller: _promotion,
                          decoration: _dec('Promotion type (optional)'),
                          onChanged: (_) => _form.currentState?.validate(),
                          validator: (v) {
                            if (_discount.text.trim().isNotEmpty &&
                                (v == null || v.trim().isEmpty)) {
                              return 'Select a promotion type when entering a discount.';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: _discount,
                          keyboardType: TextInputType.number,
                          decoration: _dec('Discount % (optional)'),
                          onChanged: (_) => _form.currentState?.validate(),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = double.tryParse(v);
                            if (n == null || n < 0 || n > 100) {
                              return 'Enter 0–100';
                            }
                            if (_promotion.text.trim().isEmpty) {
                              return 'Select a promotion type when entering a discount.';
                            }
                            return null;
                          },
                        ),
                      ];
                      if (_loadingCatalog) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return Column(
                        children: [
                          if (wide)
                            for (var i = 0; i < fields.length; i += 2)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    Expanded(child: fields[i]),
                                    const SizedBox(width: 16),
                                    Expanded(child: fields[i + 1]),
                                  ],
                                ),
                              )
                          else
                            for (final f in fields)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: f,
                              ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _submitting ? null : _submit,
                              icon: _submitting
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_outlined),
                              label: const Text('Check with Inventory'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Request status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _lookup,
                            decoration: _dec('Request ID'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: _refreshing ? null : _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                    if (_result != null) ...[
                      const SizedBox(height: 16),
                      _ResultCard(_result!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _HistoryCard(
              history: _history,
              loading: _loadingHistory,
              refreshing: _refreshing,
              onRefresh: () => _loadHistory(skip: _history?.skip ?? 0),
              onPrevious: (_history?.skip ?? 0) > 0
                  ? () => _loadHistory(
                      skip: ((_history!.skip - _historyLimit).clamp(
                        0,
                        _history!.total,
                      )).toInt(),
                    )
                  : null,
              onNext:
                  _history != null &&
                      _history!.skip + _history!.items.length < _history!.total
                  ? () => _loadHistory(skip: _history!.skip + _historyLimit)
                  : null,
              onOpen: (request) => setState(() {
                _result = request;
                _lookup.text = request.requestId;
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.history,
    required this.loading,
    required this.refreshing,
    required this.onRefresh,
    required this.onPrevious,
    required this.onNext,
    required this.onOpen,
  });

  final InventoryAnalysisHistory? history;
  final bool loading;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<InventoryAnalysisRequest> onOpen;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Campaign history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Refresh campaign history',
                onPressed: refreshing ? null : onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const Text(
            'Persistent requests visible to your authorized showrooms. Newest requests appear first.',
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (history == null || history!.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No campaign requests are available.'),
            )
          else ...[
            for (final item in history!.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.campaignName),
                subtitle: Text(
                  '${item.productId} • ${item.storeId}\n'
                  '${item.campaignStartDate} to ${item.campaignEndDate}',
                ),
                isThreeLine: true,
                trailing: Chip(label: Text(item.status)),
                onTap: () => onOpen(item),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${history!.skip + 1}–'
                  '${history!.skip + history!.items.length} of ${history!.total}',
                ),
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.value);
  final InventoryAnalysisRequest value;
  @override
  Widget build(BuildContext context) {
    final a = value.assessment;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.status,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Request: ${value.requestId}'),
          Text('Campaign: ${value.campaignName}'),
          Text('Reference: ${value.campaignReference}'),
          Text('Product ${value.productId} • Showroom ${value.storeId}'),
          Text('${value.campaignStartDate} to ${value.campaignEndDate}'),
          if (value.promotionType != null)
            Text(
              'Promotion: ${value.promotionType}'
              '${value.discountPercent == null ? '' : ' • ${value.discountPercent}%'}',
            ),
          if (value.rejectionReason != null)
            Text('Rejection reason: ${value.rejectionReason}'),
          if (a != null) ...[
            const Divider(),
            const Text(
              'Baseline Inventory assessment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Available stock: ${a.availableStock?.toStringAsFixed(0) ?? 'Unavailable'}',
            ),
            Text(
              'Forecast demand: ${a.forecastDemand?.toStringAsFixed(0) ?? 'Unavailable'}',
            ),
            Text('Stock sufficiency: ${a.stockSufficiency ?? 'Unavailable'}'),
            if (a.explanation != null) Text(a.explanation!),
            const Text(
              'Promotional uplift is not included in this forecast.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
