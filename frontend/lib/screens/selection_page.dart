import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'client_page.dart';
import 'store_page.dart';
import 'dart:ui';

class SelectionPage extends StatefulWidget {
  const SelectionPage({super.key});

  @override
  State<SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends State<SelectionPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation1;
  late Animation<Offset> _slideAnimation2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation1 = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.7, curve: Curves.easeOut)));
    _slideAnimation2 = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.9, curve: Curves.easeOut)));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState().isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(isDark),
      body: Stack(
        children: [
          // Background Glow Effects
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
                  color: AppTheme.orbPrimary(isDark).withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.orbSecondary(isDark).withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    // Brand Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.orbPrimary(isDark).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.diamond_outlined, size: 36, color: AppTheme.accentBlue(isDark)),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      "Welcome to",
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary(isDark),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [AppTheme.accentBlue(isDark), isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1)],
                      ).createShader(bounds),
                      child: const Text(
                        "Omni Retail",
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Colors.white, // Keep white for mask gradient
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "AI-powered shopping with virtual try-on, smart sizing, and a personal stylist.",
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.textSecondary(isDark),
                        height: 1.5,
                      ),
                    ),

                    const Spacer(),

                    SlideTransition(
                      position: _slideAnimation1,
                      child: _PremiumRoleCard(
                        title: "Shop Now",
                        subtitle: "Browse products, try outfits & get AI recommendations",
                        icon: Icons.shopping_bag_outlined,
                        gradientColors: isDark 
                            ? const [Color(0xFF3B82F6), Color(0xFF2563EB)]
                            : const [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                        onTap: () => _goToPage(context, const ClientPage()),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SlideTransition(
                      position: _slideAnimation2,
                      child: _PremiumRoleCard(
                        title: "Store Manager",
                        subtitle: "Manage zones, track customers & view analytics",
                        icon: Icons.storefront_outlined,
                        gradientColors: isDark
                            ? const [Color(0xFF6366F1), Color(0xFF4F46E5)]
                            : const [Color(0xFF818CF8), Color(0xFF6366F1)],
                        onTap: () => _goToPage(context, const StorePage()),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumRoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _PremiumRoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_PremiumRoleCard> createState() => _PremiumRoleCardState();
}

class _PremiumRoleCardState extends State<_PremiumRoleCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradientColors,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors.last.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.6), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}