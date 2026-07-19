import 'package:flutter/material.dart';
import 'try_on_page.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';

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
  String? aiBrandSize;
  bool isSizeLoading = true;
  bool shouldShowSize = false;

  @override
  void initState() {
    super.initState();
    _fetchBrandSize();
  }

  Future<void> _fetchBrandSize() async {
    if (widget.recommendedSize == null) {
      if (mounted) setState(() => isSizeLoading = false);
      return;
    }
    
    final category = (widget.product["category"] ?? "").toString().toLowerCase();
    
    // Ignore sizes for footwear and accessories
    if (category.contains("footwear") || category.contains("accessories")) {
      if (mounted) {
        setState(() {
          shouldShowSize = false;
          isSizeLoading = false;
        });
      }
      return;
    }

    try {
      final size = await ApiService.predictBrandSize(
        standardSize: widget.recommendedSize!,
        brand: widget.product["brand"] ?? "Unknown",
        category: category.isEmpty ? "clothing" : category,
      );
      if (mounted) {
        setState(() {
          aiBrandSize = size;
          // If model returns N/A for some reason, hide it
          shouldShowSize = size != "N/A";
          isSizeLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSizeLoading = false;
          shouldShowSize = true;
          aiBrandSize = widget.recommendedSize;
        });
      }
    }
  }

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
    final brand = (widget.product["brand"] ?? "").toString().trim();
    
    bool sizeAdjusted = (aiBrandSize != null && aiBrandSize != widget.recommendedSize);
    
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final isFav = AppState().isFavorite(widget.product);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              brand.isNotEmpty ? brand : "Garment Details",
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

                            Text(
                              'LKR ${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2563EB),
                              ),
                            ),

                            if (shouldShowSize) ...[
                              const SizedBox(height: 20),
                              if (isSizeLoading)
                                const Center(child: CircularProgressIndicator())
                              else
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: sizeAdjusted ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: sizeAdjusted ? const Color(0xFFF97316).withOpacity(0.3) : const Color(0xFF2563EB).withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome, 
                                        color: sizeAdjusted ? const Color(0xFFF97316) : const Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "AI Brand Sizing: $aiBrandSize",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: sizeAdjusted ? const Color(0xFF9A3412) : const Color(0xFF1E40AF),
                                              ),
                                            ),
                                            if (sizeAdjusted)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Text(
                                                  "We dynamically adjusted your size for $brand based on their unique fit pattern.",
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                                                ),
                                              )
                                            else
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Text(
                                                  "Your standard $aiBrandSize is the perfect fit for $brand.",
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],

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
