import 'package:flutter/material.dart';
import 'try_on_page.dart';
import '../services/app_state.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final String customerEmail;
  final String? recommendedSize;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.customerEmail,
    this.recommendedSize,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  void _addToCart() {
    AppState().addToCart(widget.product);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Added to Cart"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = (widget.product["current_stock"] ?? 0) <= 0;
    final price = widget.product["price_lkr"] ?? 0.0;
    
    // Listen to changes so the favorite icon updates if toggled
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final isFav = AppState().isFavorite(widget.product);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              widget.product["brand"] ?? "Garment Details",
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black87),
            actions: [
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.redAccent : Colors.grey.shade400,
                  size: 28,
                ),
                onPressed: () {
                  AppState().toggleFavorite(widget.product);
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // Scrollable Info
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product image
                      Container(
                        width: double.infinity,
                        height: 380,
                        color: const Color(0xFFF8FAFC),
                        child: widget.product["image_url"] != null
                            ? Image.network(
                                widget.product["image_url"],
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(child: Icon(Icons.broken_image, size: 80)),
                              )
                            : const Center(child: Icon(Icons.image, size: 80)),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Subtitle/Gender row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    (widget.product["gender"] ?? "Unisex").toString().toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isOutOfStock
                                        ? const Color(0xFFFEE2E2)
                                        : const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isOutOfStock ? "OUT OF STOCK" : 'IN STOCK (${widget.product["current_stock"]} left)',
                                    style: TextStyle(
                                      color: isOutOfStock
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF16A34A),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Title
                            Text(
                              widget.product["product_name"] ?? "Unnamed Item",
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                height: 1.2,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Price
                            Text(
                              'LKR ${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2563EB),
                              ),
                            ),

                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),

                            const Text(
                              "Product Specifications",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Info grid list
                            _SpecRow(title: "Brand", value: widget.product["brand"] ?? "Generic"),
                            _SpecRow(title: "Category", value: widget.product["category"] ?? "General"),
                            _SpecRow(title: "Segment", value: widget.product["subcategory"] ?? "General"),
                            _SpecRow(
                              title: "Stock Count",
                              value: '${widget.product["current_stock"] ?? 0} available',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom CTA Buttons
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, -4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              foregroundColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TryOnPage(
                                    customerEmail: widget.customerEmail,
                                    initialProduct: widget.product,
                                    recommendedSize: widget.recommendedSize,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.checkroom_outlined, size: 20),
                            label: const Text(
                              "Try On",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            onPressed: isOutOfStock ? null : _addToCart,
                            icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                            label: const Text(
                              "Add to Cart",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String title;
  final String value;

  const _SpecRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
