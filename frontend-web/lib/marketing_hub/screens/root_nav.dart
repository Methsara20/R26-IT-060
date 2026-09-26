import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/widgets/mesh_background.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_notifier.dart';
import 'hub_screen.dart';
import 'upload_screen.dart';
import 'recommender_screen.dart';
import 'poster_screen.dart';
import 'inventory_screen.dart';
import 'calendar_screen.dart';
import 'customer_intelligence_screen.dart';

class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int currentIndex = 0;
  Map<String, dynamic>? selectedInventoryOpportunity;

  void createPosterFromInventory(Map<String, dynamic> opportunity) {
    setState(() {
      selectedInventoryOpportunity = opportunity;
      currentIndex = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimary : const Color(0xFF1E293B);
    final mutedColor = isDark ? AppColors.textMuted : const Color(0xFF64748B);
    final navBgColor = isDark ? const Color(0x22FFFFFF) : const Color(0xBBFFFFFF);
    final navBorderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6);
    final navShadowColor = isDark ? Colors.black.withOpacity(0.3) : const Color(0xFF6366F1).withOpacity(0.1);

    final screens = [
      const HubScreen(),
      const UploadScreen(),
      const RecommenderScreen(),
      PosterScreen(
        key: ValueKey(selectedInventoryOpportunity?['opportunity_id']),
        inventoryOpportunity: selectedInventoryOpportunity,
      ),
      InventoryInsightsScreen(onCreatePoster: createPosterFromInventory),
      const PromotionCalendarScreen(),
      const CustomerIntelligenceScreen(),
    ];

    return MeshBackground(
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.primaryBlue, AppColors.goldAccent],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Marketing Intelligence',
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 17),
              ),
            ],
          ),
          actions: [
            // Dark/Light toggle
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeNotifier.instance,
              builder: (context, mode, _) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: isDark ? AppColors.goldAccent : const Color(0xFF6366F1),
                    ),
                    onPressed: ThemeNotifier.instance.toggle,
                  ),
                );
              },
            ),
            // Logout
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                tooltip: 'Log out',
                icon: Icon(Icons.logout_rounded, color: mutedColor),
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.only(bottom: 100),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: screens[currentIndex],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: navBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: navBorderColor),
              boxShadow: [
                BoxShadow(
                  color: navShadowColor,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      indicatorColor: AppColors.primaryBlue.withOpacity(isDark ? 0.3 : 0.15),
                      labelTextStyle: WidgetStateProperty.all(
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textColor),
                      ),
                      iconTheme: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return IconThemeData(color: AppColors.primaryBlue, size: 22);
                        }
                        return IconThemeData(color: mutedColor, size: 22);
                      }),
                    ),
                    child: NavigationBar(
                      height: 60,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      selectedIndex: currentIndex,
                      onDestinationSelected: (index) => setState(() => currentIndex = index),
                      destinations: const [
                        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Hub'),
                        NavigationDestination(icon: Icon(Icons.upload_outlined), selectedIcon: Icon(Icons.upload_rounded), label: 'Upload'),
                        NavigationDestination(icon: Icon(Icons.psychology_outlined), selectedIcon: Icon(Icons.psychology_rounded), label: 'AI'),
                        NavigationDestination(icon: Icon(Icons.image_outlined), selectedIcon: Icon(Icons.image_rounded), label: 'Poster'),
                        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Inventory'),
                        NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
                        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Customers'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
