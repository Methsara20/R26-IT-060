import 'package:flutter/material.dart';
import 'try_on_page.dart';

class ProductDetailPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isOutOfStock = (product["current_stock"] ?? 0) <= 0;
    final price = product["price_lkr"] ?? 0.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          product["brand"] ?? "Garment Details",
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
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
                    child: product["image_url"] != null
                        ? Image.network(
                            product["image_url"],
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
                                (product["gender"] ?? "Unisex").toString().toUpperCase(),
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
                                isOutOfStock ? "OUT OF STOCK" : "IN STOCK (${product["current_stock"]} items left)",
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
                          product["product_name"] ?? "Unnamed Item",
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
                          "LKR ${price.toStringAsFixed(0)}",
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
                        _SpecRow(title: "Brand", value: product["brand"] ?? "Generic"),
                        _SpecRow(title: "Category", value: product["category"] ?? "General"),
                        _SpecRow(title: "Segment", value: product["subcategory"] ?? "General"),
                        _SpecRow(
                          title: "Stock Count",
                          value: "${product["current_stock"] ?? 0} available",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Virtual Try-On CTA Button Box
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
            child: SizedBox(
              width: double.infinity,
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TryOnPage(
                        customerEmail: customerEmail,
                        initialProduct: product,
                        recommendedSize: recommendedSize,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.checkroom_outlined, size: 24),
                label: const Text(
                  "Try on Virtual App",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
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
