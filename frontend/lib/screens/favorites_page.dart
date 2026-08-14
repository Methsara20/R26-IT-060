import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'product_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  void _update() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    AppState().addListener(_update);
  }

  @override
  void dispose() {
    AppState().removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = AppState().favoriteItems;
    final isDark = AppState().isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(isDark),
      appBar: AppBar(
        title: Text("Saved Items", style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary(isDark), fontSize: 24, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (favorites.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed(isDark).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.accentRed(isDark).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite, color: AppTheme.accentRed(isDark), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "${favorites.length}",
                      style: TextStyle(color: AppTheme.accentRed(isDark), fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: 200,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentRed(isDark).withOpacity(0.15),
                ),
              ),
            ),
          ),

          favorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppTheme.glassCard(isDark),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.glassBorder(isDark)),
                        ),
                        child: Icon(Icons.favorite_border, size: 80, color: AppTheme.iconMuted(isDark)),
                      ),
                      const SizedBox(height: 32),
                      Text("No saved items yet", style: TextStyle(fontSize: 24, color: AppTheme.textPrimary(isDark), fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Text("Heart items you like to see them here", style: TextStyle(color: AppTheme.textSecondary(isDark), fontSize: 16)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.58,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final product = favorites[index];
                    final price = product["price_lkr"] ?? 0.0;
                    
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailPage(
                              product: product,
                              customerEmail: "demo@user.com",
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
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                      color: AppTheme.glassBackground(isDark),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                      child: product["image_url"] != null
                                          ? Image.network(product["image_url"], fit: BoxFit.cover)
                                          : Icon(Icons.image, size: 40, color: AppTheme.iconMuted(isDark)),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: () => AppState().toggleFavorite(product),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: AppTheme.backgroundColor(isDark).withOpacity(0.5),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: AppTheme.glassBorder(isDark)),
                                            ),
                                            child: Icon(Icons.favorite, color: AppTheme.accentRed(isDark), size: 18),
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
                                    style: TextStyle(color: AppTheme.textSecondary(isDark), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
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
                                    'LKR ${price.toStringAsFixed(0)}',
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
                ),
        ],
      ),
    );
  }
}
