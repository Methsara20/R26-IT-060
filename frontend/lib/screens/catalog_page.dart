import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'product_detail_page.dart';

class CatalogPage extends StatefulWidget {
  final String customerEmail;
  final String? recommendedSize;

  const CatalogPage({
    super.key,
    required this.customerEmail,
    this.recommendedSize,
  });

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  List<dynamic> allProducts = [];
  List<dynamic> filteredProducts = [];
  bool isLoading = true;
  String? errorMessage;

  String searchQuery = "";
  String selectedCategory = "All";
  List<String> categories = ["All"];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final products = await ApiService.getProducts();
      final Set<String> uniqueCats = {"All"};
      for (var p in products) {
        final cat = p["category"];
        if (cat != null && cat.toString().isNotEmpty) {
          uniqueCats.add(cat.toString());
        }
      }

      setState(() {
        allProducts = products;
        categories = uniqueCats.toList();
        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      filteredProducts = allProducts.where((product) {
        final name = (product["product_name"] ?? "").toString().toLowerCase();
        final brand = (product["brand"] ?? "").toString().toLowerCase();
        final cat = (product["category"] ?? "").toString();

        final matchesSearch = name.contains(searchQuery.toLowerCase()) ||
            brand.contains(searchQuery.toLowerCase());
        final matchesCategory = selectedCategory == "All" || cat == selectedCategory;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState().isDarkMode;
    final firstName = widget.customerEmail.split('@')[0];
    final capitalizedName = firstName.isNotEmpty 
        ? firstName[0].toUpperCase() + firstName.substring(1) 
        : "there";

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(isDark),
      body: Stack(
        children: [
          // Background Glow Effects
          Positioned(
            top: -150,
            left: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.orbPrimary(isDark).withOpacity(0.2),
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.orbSecondary(isDark).withOpacity(0.15),
                ),
              ),
            ),
          ),
          
          isLoading
              ? Center(child: CircularProgressIndicator(color: AppTheme.accentBlue(isDark)))
              : errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.glassCard(isDark),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.wifi_off_rounded, size: 60, color: AppTheme.iconMuted(isDark)),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "Failed to load products\n$errorMessage",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, color: AppTheme.textSecondary(isDark)),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: () {
                                setState(() { isLoading = true; errorMessage = null; });
                                _fetchProducts();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentBlue(isDark),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              ),
                              child: const Text("Retry", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        // Glass Header
                        SliverToBoxAdapter(
                          child: ClipRRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
                                decoration: BoxDecoration(
                                  color: AppTheme.glassBackground(isDark),
                                  border: Border(bottom: BorderSide(color: AppTheme.glassBorder(isDark))),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Hey, $capitalizedName! ✨",
                                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary(isDark), letterSpacing: -0.5),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Discover your perfect style today",
                                      style: TextStyle(fontSize: 15, color: AppTheme.textPrimary(isDark).withOpacity(0.6)),
                                    ),
                                    const SizedBox(height: 28),
        
                                    // Glass Search Bar
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.glassInput(isDark),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppTheme.glassBorder(isDark)),
                                      ),
                                      child: TextField(
                                        onChanged: (val) {
                                          searchQuery = val;
                                          _applyFilters();
                                        },
                                        style: TextStyle(color: AppTheme.textPrimary(isDark), fontSize: 16),
                                        decoration: InputDecoration(
                                          hintText: "Search clothing or brands...",
                                          hintStyle: TextStyle(color: AppTheme.textPrimary(isDark).withOpacity(0.4)),
                                          prefixIcon: Icon(Icons.search, color: AppTheme.textPrimary(isDark).withOpacity(0.4)),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
        
                        // Category Chips
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24, bottom: 12),
                            child: SizedBox(
                              height: 44,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                itemCount: categories.length,
                                itemBuilder: (context, index) {
                                  final cat = categories[index];
                                  final isSelected = selectedCategory == cat;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedCategory = cat;
                                          _applyFilters();
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppTheme.accentBlue(isDark) : AppTheme.glassCard(isDark),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(color: isSelected ? AppTheme.accentBlue(isDark) : AppTheme.glassBorder(isDark)),
                                          boxShadow: isSelected 
                                            ? [BoxShadow(color: AppTheme.accentBlue(isDark).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))] 
                                            : null,
                                        ),
                                        child: Text(
                                          cat,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : AppTheme.textPrimary(isDark).withOpacity(0.7),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
        
                        // Results count
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                            child: Text(
                              "${filteredProducts.length} items found",
                              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(isDark).withOpacity(0.5), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
        
                        // Product Grid
                        filteredProducts.isEmpty
                            ? SliverFillRemaining(
                                child: Center(
                                  child: Text("No items match your criteria", style: TextStyle(fontSize: 16, color: AppTheme.textPrimary(isDark).withOpacity(0.5))),
                                ),
                              )
                            : SliverPadding(
                                padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 120),
                                sliver: SliverGrid(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.58,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final product = filteredProducts[index];
                                      final isOutOfStock = (product["current_stock"] ?? 0) <= 0;
                                      final price = product["price_lkr"] ?? 0.0;
        
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ProductDetailPage(
                                                product: product,
                                                customerEmail: widget.customerEmail,
                                                recommendedSize: widget.recommendedSize,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppTheme.glassCard(isDark),
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(color: AppTheme.glassBorder(isDark)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Stack(
                                                  children: [
                                                    Container(
                                                      width: double.infinity,
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.glassBackground(isDark),
                                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                                        child: product["image_url"] != null
                                                            ? Image.network(
                                                                product["image_url"],
                                                                fit: BoxFit.cover,
                                                                errorBuilder: (context, error, stackTrace) =>
                                                                    Center(child: Icon(Icons.broken_image, size: 40, color: AppTheme.iconMuted(isDark))),
                                                              )
                                                            : Center(child: Icon(Icons.image, size: 40, color: AppTheme.iconMuted(isDark))),
                                                      ),
                                                    ),
                                                    if (isOutOfStock)
                                                      Positioned(
                                                        top: 12,
                                                        left: 12,
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: BackdropFilter(
                                                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                              decoration: BoxDecoration(
                                                                color: AppTheme.accentRed(isDark).withOpacity(0.2),
                                                                border: Border.all(color: AppTheme.accentRed(isDark).withOpacity(0.5)),
                                                                borderRadius: BorderRadius.circular(8),
                                                              ),
                                                              child: Text(
                                                                "SOLD OUT",
                                                                style: TextStyle(color: AppTheme.accentRed(isDark), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      (product["brand"] ?? "Brand").toString().toUpperCase(),
                                                      style: TextStyle(color: AppTheme.textPrimary(isDark).withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      product["product_name"] ?? "Item",
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary(isDark)),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      "LKR ${price.toStringAsFixed(0)}",
                                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.accentBlue(isDark)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: filteredProducts.length,
                                  ),
                                ),
                              ),
                      ],
                    ),
        ],
      ),
    );
  }
}
