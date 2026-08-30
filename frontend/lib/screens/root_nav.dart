import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
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

  final screens = const [
    HubScreen(),
    UploadScreen(),
    RecommenderScreen(),
    PosterScreen(),
    InventoryInsightsScreen(),
    PromotionCalendarScreen(),
    CustomerIntelligenceScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => setState(() => currentIndex = index),
        backgroundColor: AppColors.cardBackground,
        indicatorColor: AppColors.goldAccent.withValues(alpha: 0.25),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Hub'),
          NavigationDestination(icon: Icon(Icons.upload_outlined), selectedIcon: Icon(Icons.upload), label: 'Upload'),
          NavigationDestination(icon: Icon(Icons.recommend_outlined), selectedIcon: Icon(Icons.recommend), label: 'Recommender'),
          NavigationDestination(icon: Icon(Icons.image_outlined), selectedIcon: Icon(Icons.image), label: 'Poster'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
        ],
      ),
    );
  }
}
