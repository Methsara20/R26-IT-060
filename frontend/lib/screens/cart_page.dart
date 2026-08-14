import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'payment_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  void _update() => setState(() {});

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
    final cartItems = AppState().cartItems;
    final total = AppState().cartTotal;
    final isDark = AppState().isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(isDark),
      appBar: AppBar(
        title: Text("My Cart", style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary(isDark), fontSize: 24, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (cartItems.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue(isDark).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.accentBlue(isDark).withOpacity(0.3)),
                ),
                child: Text(
                  "${cartItems.length} items",
                  style: TextStyle(color: AppTheme.accentBlue(isDark), fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            left: -100,
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

          cartItems.isEmpty
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
                        child: Icon(Icons.shopping_bag_outlined, size: 80, color: AppTheme.iconMuted(isDark)),
                      ),
                      const SizedBox(height: 32),
                      Text("Your cart is empty", style: TextStyle(fontSize: 24, color: AppTheme.textPrimary(isDark), fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Text("Explore the catalog to add items", style: TextStyle(color: AppTheme.textSecondary(isDark), fontSize: 16)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          final price = item["price_lkr"] ?? 0.0;
                          return Dismissible(
                            key: UniqueKey(),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => AppState().removeFromCart(index),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 32),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.accentRed(isDark).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppTheme.accentRed(isDark).withOpacity(0.5)),
                              ),
                              child: Icon(Icons.delete_outline, color: AppTheme.accentRed(isDark), size: 32),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.glassCard(isDark),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppTheme.glassBorder(isDark)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: AppTheme.glassBackground(isDark),
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                                      child: item["image_url"] != null
                                          ? Image.network(item["image_url"], fit: BoxFit.cover)
                                          : Icon(Icons.image, color: AppTheme.iconMuted(isDark)),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (item["brand"] ?? "BRAND").toString().toUpperCase(),
                                            style: TextStyle(color: AppTheme.textSecondary(isDark), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item["product_name"] ?? "Item",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary(isDark), height: 1.2),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'LKR ${price.toStringAsFixed(0)}',
                                            style: TextStyle(color: AppTheme.accentBlue(isDark), fontWeight: FontWeight.w900, fontSize: 18),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Checkout Bar
                    ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor(isDark).withOpacity(0.8),
                            border: Border(top: BorderSide(color: AppTheme.glassBorder(isDark))),
                          ),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Total", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textSecondary(isDark))),
                                    Text(
                                      'LKR ${total.toStringAsFixed(0)}',
                                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary(isDark)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 60,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentBlue(isDark),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentPage()));
                                    },
                                    child: const Text(
                                      "Proceed to Checkout",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
}
