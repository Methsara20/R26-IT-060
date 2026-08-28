import 'package:flutter/material.dart';

import '../../models/forecast/forecast_catalog_option.dart';

/// Searchable product selector used by the operational forecast forms.
///
/// Filtering is performed against the catalog already loaded by
/// [ForecastApiService]. It therefore does not create additional backend or
/// Firestore reads while the manager types or changes a filter.
class ForecastProductSearchSelector extends StatefulWidget {
  const ForecastProductSearchSelector({
    required this.products,
    required this.selectedProduct,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<ForecastProductOption> products;
  final ForecastProductOption? selectedProduct;
  final ValueChanged<ForecastProductOption?> onChanged;
  final bool enabled;

  @override
  State<ForecastProductSearchSelector> createState() =>
      _ForecastProductSearchSelectorState();
}

class _ForecastProductSearchSelectorState
    extends State<ForecastProductSearchSelector> {
  final _searchController = TextEditingController();

  String? _brand;
  String? _gender;
  String? _category;

  @override
  void initState() {
    super.initState();
    _showSelectedProduct(widget.selectedProduct);
  }

  @override
  void didUpdateWidget(covariant ForecastProductSearchSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedProduct?.id != widget.selectedProduct?.id) {
      _showSelectedProduct(widget.selectedProduct);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _brands => _distinct(
    widget.products
        .where((product) => _category == null || product.category == _category)
        .map((product) => product.brand),
  );

  List<String> get _genders => _distinct(
    widget.products
        .where(
          (product) =>
              (_category == null || product.category == _category) &&
              (_brand == null || product.brand == _brand),
        )
        .map((product) => product.gender),
  );

  List<String> get _categories =>
      _distinct(widget.products.map((product) => product.category));

  List<String> _distinct(Iterable<String> values) {
    final result = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    result.sort(
      (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
    );
    return result;
  }

  void _showSelectedProduct(ForecastProductOption? product) {
    _searchController.text = product == null ? '' : _productLabel(product);
  }

  String _productLabel(ForecastProductOption product) =>
      '${product.name} (${product.id})';

  bool _passesFilters(ForecastProductOption product) {
    return (_brand == null || product.brand == _brand) &&
        (_gender == null || product.gender == _gender) &&
        (_category == null || product.category == _category);
  }

  Iterable<ForecastProductOption> _matchingProducts(
    TextEditingValue textEditingValue,
  ) {
    final query = textEditingValue.text.trim().toLowerCase();

    return widget.products.where((product) {
      if (!_passesFilters(product)) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final searchableText = [
        product.name,
        product.id,
        product.category,
        product.brand,
        product.gender,
      ].join(' ').toLowerCase();

      return searchableText.contains(query);
    });
  }

  void _setBrand(String? value) {
    setState(() {
      _brand = value;
      if (_gender != null && !_genders.contains(_gender)) {
        _gender = null;
      }
      _clearInvalidSelection();
    });
  }

  void _setGender(String? value) {
    setState(() {
      _gender = value;
      _clearInvalidSelection();
    });
  }

  void _setCategory(String? value) {
    setState(() {
      _category = value;
      if (_brand != null && !_brands.contains(_brand)) {
        _brand = null;
      }
      if (_gender != null && !_genders.contains(_gender)) {
        _gender = null;
      }
      _clearInvalidSelection();
    });
  }

  void _clearInvalidSelection() {
    final selected = widget.selectedProduct;
    if (selected != null && !_passesFilters(selected)) {
      _searchController.clear();
      widget.onChanged(null);
    }
  }

  int get _filteredProductCount => widget.products.where(_passesFilters).length;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 940
            ? 4
            : constraints.maxWidth >= 580
            ? 2
            : 1;
        final fieldWidth =
            (constraints.maxWidth - 14 * (columns - 1)) / columns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(width: fieldWidth, child: _buildCategoryFilter()),
                SizedBox(width: fieldWidth, child: _buildBrandFilter()),
                SizedBox(width: fieldWidth, child: _buildGenderFilter()),
                SizedBox(width: fieldWidth, child: _buildProductSearch()),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _filteredProductCount == 0
                  ? 'No products match these filters. Change Category, Brand, '
                        'or Gender to continue.'
                  : '$_filteredProductCount matching product(s). Select the '
                        'search field to view suggestions.',
              style: TextStyle(
                color: _filteredProductCount == 0
                    ? Theme.of(context).colorScheme.error
                    : const Color(0xFF667085),
                fontSize: 12,
                fontWeight: _filteredProductCount == 0
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    return DropdownButtonFormField<String>(
      key: ValueKey('category-$_category'),
      initialValue: _category,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Category (optional)',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('All categories')),
        for (final category in _categories)
          DropdownMenuItem(value: category, child: Text(category)),
      ],
      onChanged: widget.enabled
          ? (value) =>
                _setCategory(value == null || value.isEmpty ? null : value)
          : null,
    );
  }

  Widget _buildBrandFilter() {
    return DropdownButtonFormField<String>(
      key: ValueKey('brand-$_category-$_brand'),
      initialValue: _brand,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Brand (optional)',
        prefixIcon: Icon(Icons.sell_outlined),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('All brands')),
        for (final brand in _brands)
          DropdownMenuItem(value: brand, child: Text(brand)),
      ],
      onChanged: widget.enabled
          ? (value) => _setBrand(value == null || value.isEmpty ? null : value)
          : null,
    );
  }

  Widget _buildGenderFilter() {
    return DropdownButtonFormField<String>(
      key: ValueKey('gender-$_category-$_brand-$_gender'),
      initialValue: _gender,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Gender (optional)',
        prefixIcon: Icon(Icons.people_outline),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('All genders')),
        for (final gender in _genders)
          DropdownMenuItem(value: gender, child: Text(gender)),
      ],
      onChanged: widget.enabled
          ? (value) => _setGender(value == null || value.isEmpty ? null : value)
          : null,
    );
  }

  Widget _buildProductSearch() {
    return TextFormField(
      controller: _searchController,
      enabled: widget.enabled,
      readOnly: true,
      onTap: _filteredProductCount == 0 ? null : _openProductPicker,
      decoration: InputDecoration(
        labelText: 'Product',
        hintText: 'Select a product',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: widget.selectedProduct == null
            ? const Icon(Icons.arrow_drop_down)
            : IconButton(
                tooltip: 'Clear product',
                onPressed: widget.enabled
                    ? () {
                        _searchController.clear();
                        widget.onChanged(null);
                        setState(() {});
                      }
                    : null,
                icon: const Icon(Icons.close),
              ),
      ),
      validator: (_) =>
          widget.selectedProduct == null ? 'Select a product' : null,
    );
  }

  Future<void> _openProductPicker() async {
    var query = '';
    final selected = await showDialog<ForecastProductOption>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final matches = _matchingProducts(
            TextEditingValue(text: query),
          ).take(100).toList();
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                                'Select product',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Showing products that match the selected filters.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Search products',
                        hintText: 'Name, ID, category, brand or gender',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setDialogState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${matches.length} result(s)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: matches.isEmpty
                          ? const Center(
                              child: Text(
                                'No products match your search and filters.',
                              ),
                            )
                          : ListView.separated(
                              itemCount: matches.length,
                              separatorBuilder: (_, _) => const Divider(),
                              itemBuilder: (context, index) {
                                final product = matches[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  leading: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDF4FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.checkroom_outlined,
                                      color: Color(0xFF155EEF),
                                    ),
                                  ),
                                  title: Text(product.name),
                                  subtitle: Text(
                                    '${product.id} • ${product.category} • '
                                    '${product.brand} • ${product.gender}\n'
                                    'LKR ${product.sellingPrice.toStringAsFixed(2)}',
                                  ),
                                  isThreeLine: true,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () =>
                                      Navigator.pop(dialogContext, product),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (selected == null || !mounted) return;
    _searchController.text = _productLabel(selected);
    widget.onChanged(selected);
    setState(() {});
  }
}
