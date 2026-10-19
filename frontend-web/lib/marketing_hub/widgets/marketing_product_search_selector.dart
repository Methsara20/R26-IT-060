import 'package:flutter/material.dart';

import '../models/inventory_analysis_request.dart';

class MarketingProductSearchSelector extends StatefulWidget {
  const MarketingProductSearchSelector({
    required this.products,
    required this.selectedProduct,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<MarketingCatalogChoice> products;
  final MarketingCatalogChoice? selectedProduct;
  final ValueChanged<MarketingCatalogChoice?> onChanged;
  final bool enabled;

  @override
  State<MarketingProductSearchSelector> createState() =>
      _MarketingProductSearchSelectorState();
}

class _MarketingProductSearchSelectorState
    extends State<MarketingProductSearchSelector> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.selectedProduct?.label ?? '';
  }

  @override
  void didUpdateWidget(covariant MarketingProductSearchSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProduct?.id != widget.selectedProduct?.id) {
      _controller.text = widget.selectedProduct?.label ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<MarketingCatalogChoice>(
    textEditingController: _controller,
    focusNode: _focusNode,
    displayStringForOption: (option) => option.label,
    optionsBuilder: (value) {
      final query = value.text.trim().toLowerCase();
      if (query.isEmpty || value.text == widget.selectedProduct?.label) {
        return widget.products;
      }
      return widget.products.where(
        (product) =>
            product.id.toLowerCase().contains(query) ||
            product.name.toLowerCase().contains(query),
      );
    },
    onSelected: (product) {
      _controller.text = product.label;
      widget.onChanged(product);
    },
    fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          decoration: const InputDecoration(
            labelText: 'Product',
            hintText: 'Search by product name or ID',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            if (value != widget.selectedProduct?.label &&
                widget.selectedProduct != null) {
              widget.onChanged(null);
            }
          },
          onFieldSubmitted: (_) => onSubmitted(),
          validator: (_) => widget.selectedProduct == null
              ? 'Select a product from the search results'
              : null,
        ),
    optionsViewBuilder: (context, onSelected, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 300),
          child: options.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No products match this search.'),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final product = options.elementAt(index);
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text(product.id),
                      onTap: () => onSelected(product),
                    );
                  },
                ),
        ),
      ),
    ),
  );
}
