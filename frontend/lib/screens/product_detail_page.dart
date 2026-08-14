import 'package:flutter/material.dart';
import 'dart:ui';
import 'try_on_page.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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

class _ProductDetailPageState extends State<ProductDetailPage> with SingleTickerProviderStateMixin {
  String? aiBrandSize;
  bool isSizeLoading = true;
  bool shouldShowSize = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _fetchBrandSize();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchBrandSize() async {
    if (widget.recommendedSize == null) {
      if (mounted) setState(() => isSizeLoading = false);
      return;
    }
    
    final category = (widget.product["category"] ?? "").toString().toLowerCase();
    
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
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text("Added to Cart", style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState().isDarkMode;
    final isOutOfStock = (widget.product["current_stock"] ?? 0) <= 0;
    final price = widget.product["price_lkr"] ?? 0.0;
    final brand = (widget.product["brand"] ?? "").toString().trim();
    final description = (widget.product["description"] ?? "").toString().trim();
    final category = (widget.product["category"] ?? "").toString().toLowerCase();
    final bool canTryOn = !category.contains("accessories") && !category.contains("footwear");
    bool sizeAdjusted = (aiBrandSize != null && aiBrandSize != widget.recommendedSize);
    
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final isFav = AppState().isFavorite(widget.product);

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor(isDark),
          body: Stack(
            children: [
              // Background Glow
              Positioned(
                top: 400,
                right: -50,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.orbSecondary(isDark).withOpacity(0.15),
                    ),
                  ),
                ),
              ),

              Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        // Hero Image AppBar
                        SliverAppBar(
                          expandedHeight: 450,
                          pinned: true,
                          stretch: true,
                          backgroundColor: Colors.transparent,
                          leading: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor(isDark).withOpacity(0.5),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.glassBorder(isDark)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Icon(Icons.arrow_back, color: AppTheme.textPrimary(isDark), size: 20),
                                ),
                              ),
                            ),
                          ),
                          actions: [
                            GestureDetector(
                              onTap: () => AppState().toggleFavorite(widget.product),
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor(isDark).withOpacity(0.5),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.glassBorder(isDark)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Icon(
                                        isFav ? Icons.favorite : Icons.favorite_border,
                                        color: isFav ? AppTheme.accentRed(isDark) : AppTheme.textPrimary(isDark),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          flexibleSpace: FlexibleSpaceBar(
                            background: Container(
                              color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                              child: widget.product["image_url"] != null
                                  ? Image.network(
                                      widget.product["image_url"],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Center(child: Icon(Icons.broken_image, size: 80, color: AppTheme.iconMuted(isDark))),
                                    )
                                  : Center(child: Icon(Icons.image, size: 80, color: AppTheme.iconMuted(isDark))),
                            ),
                          ),
                        ),

                        // Product Info
                        SliverToBoxAdapter(
                          child: FadeTransition(
                            opacity: _fadeAnim,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor(isDark).withOpacity(0.8),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                                border: Border(top: BorderSide(color: AppTheme.glassBorder(isDark))),
                              ),
                              transform: Matrix4.translationValues(0, -30, 0),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Tags row
                                        Row(
                                          children: [
                                            _buildTag(
                                              (widget.product["gender"] ?? "Unisex").toString().toUpperCase(),
                                              AppTheme.accentBlue(isDark).withOpacity(0.2),
                                              AppTheme.accentBlue(isDark),
                                              AppTheme.accentBlue(isDark).withOpacity(0.5),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildTag(
                                              isOutOfStock ? "OUT OF STOCK" : "IN STOCK",
                                              isOutOfStock ? AppTheme.accentRed(isDark).withOpacity(0.2) : AppTheme.accentGreen(isDark).withOpacity(0.2),
                                              isOutOfStock ? AppTheme.accentRed(isDark) : AppTheme.accentGreen(isDark),
                                              isOutOfStock ? AppTheme.accentRed(isDark).withOpacity(0.5) : AppTheme.accentGreen(isDark).withOpacity(0.5),
                                            ),
                                            const Spacer(),
                                            if (!isOutOfStock)
                                              Text(
                                                "${widget.product["current_stock"]} left",
                                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(isDark), fontWeight: FontWeight.w600),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),

                                        // Brand
                                        if (brand.isNotEmpty)
                                          Text(
                                            brand.toUpperCase(),
                                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(isDark), fontWeight: FontWeight.w900, letterSpacing: 2),
                                          ),
                                        const SizedBox(height: 8),

                                        // Product Name
                                        Text(
                                          widget.product["product_name"] ?? "Unnamed Item",
                                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary(isDark), height: 1.2, letterSpacing: -0.5),
                                        ),
                                        const SizedBox(height: 16),

                                        // Price
                                        Text(
                                          'LKR ${price.toStringAsFixed(2)}',
                                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.accentBlue(isDark)),
                                        ),

                                        // Description
                                        if (description.isNotEmpty) ...[
                                          const SizedBox(height: 32),
                                          Text(
                                            "Description",
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary(isDark)),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            description,
                                            style: TextStyle(fontSize: 15, color: AppTheme.textPrimary(isDark).withOpacity(0.7), height: 1.6),
                                          ),
                                        ],

                                        // AI Size Recommendation
                                        if (shouldShowSize) ...[
                                          const SizedBox(height: 32),
                                          if (isSizeLoading)
                                            Center(child: CircularProgressIndicator(color: AppTheme.accentBlue(isDark)))
                                          else
                                            Container(
                                              padding: const EdgeInsets.all(24),
                                              decoration: BoxDecoration(
                                                color: AppTheme.glassCard(isDark),
                                                borderRadius: BorderRadius.circular(24),
                                                border: Border.all(
                                                  color: sizeAdjusted ? const Color(0xFFF59E0B).withOpacity(0.3) : AppTheme.accentBlue(isDark).withOpacity(0.3),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: sizeAdjusted ? const Color(0xFFF59E0B).withOpacity(0.05) : AppTheme.accentBlue(isDark).withOpacity(0.05),
                                                    blurRadius: 20,
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: sizeAdjusted ? const Color(0xFFF59E0B).withOpacity(0.15) : AppTheme.accentBlue(isDark).withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    child: Icon(
                                                      Icons.auto_awesome,
                                                      color: sizeAdjusted ? const Color(0xFFF59E0B) : AppTheme.accentBlue(isDark),
                                                      size: 28,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 20),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          "AI Recommended: $aiBrandSize",
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.w900,
                                                            fontSize: 17,
                                                            color: sizeAdjusted ? const Color(0xFFF59E0B) : AppTheme.accentBlue(isDark),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          sizeAdjusted
                                                              ? "Adjusted for $brand's unique fit pattern"
                                                              : "Your standard $aiBrandSize is the perfect fit for $brand",
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: AppTheme.textPrimary(isDark).withOpacity(0.6),
                                                            height: 1.4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],

                                        // Product Specs
                                        const SizedBox(height: 36),
                                        Text(
                                          "Details",
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary(isDark)),
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: AppTheme.glassCard(isDark),
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(color: AppTheme.glassBorder(isDark)),
                                          ),
                                          child: Column(
                                            children: [
                                              _specRow("Brand", widget.product["brand"] ?? "Generic", isDark),
                                              _specRow("Category", widget.product["category"] ?? "General", isDark),
                                              _specRow("Segment", widget.product["subcategory"] ?? "General", isDark),
                                              _specRow("Stock", '${widget.product["current_stock"] ?? 0} available', isDark, isLast: true),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 40),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Action Bar (Floating Glass)
                  ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor(isDark).withOpacity(0.8),
                          border: Border(top: BorderSide(color: AppTheme.glassBorder(isDark))),
                        ),
                        child: Row(
                          children: [
                            if (canTryOn) ...[
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: AppTheme.accentBlue(isDark), width: 1.5),
                                      foregroundColor: AppTheme.accentBlue(isDark),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                                    label: const Text("Try On", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentBlue(isDark),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    elevation: 0,
                                  ),
                                  onPressed: isOutOfStock ? null : _addToCart,
                                  icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                                  label: const Text("Add to Cart", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildTag(String text, Color bg, Color fg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  Widget _specRow(String title, String value, bool isDark, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(isDark), fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary(isDark), fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
