import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:ui';
import '../services/monitoring_api_service.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'catalog_page.dart';
import 'favorites_page.dart';
import 'cart_page.dart';
import 'profile_page.dart';

class CustomerMainPage extends StatefulWidget {
  final String customerEmail;
  final String? recommendedSize;
  final String? profileId;
  final Map<String, dynamic>? bodyMeasurements;

  const CustomerMainPage({
    super.key,
    required this.customerEmail,
    this.recommendedSize,
    this.profileId,
    this.bodyMeasurements,
  });

  @override
  State<CustomerMainPage> createState() => _CustomerMainPageState();
}

class _CustomerMainPageState extends State<CustomerMainPage> {
  int _currentIndex = 0;
  Timer? _heartbeatTimer;

  late String? _recommendedSize;
  late Map<String, dynamic>? _bodyMeasurements;

  @override
  void initState() {
    super.initState();
    _recommendedSize = widget.recommendedSize;
    _bodyMeasurements = widget.bodyMeasurements;
    _initializeAssistanceMonitoring();
  }

  Future<void> _initializeAssistanceMonitoring() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      Position pos = await Geolocator.getCurrentPosition();
      String name = widget.customerEmail.split('@')[0];

      await MonitoringApiService.startMonitoring(
        customerId: widget.customerEmail,
        customerName: name,
        lat: pos.latitude,
        lon: pos.longitude,
        alt: pos.altitude,
      );

      _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        try {
          Position currentPos = await Geolocator.getCurrentPosition();
          await MonitoringApiService.updateMonitoring(
            customerId: widget.customerEmail,
            lat: currentPos.latitude,
            lon: currentPos.longitude,
            alt: currentPos.altitude,
          );
          debugPrint('📍 GPS Heartbeat sent from background main page! Lat: ${currentPos.latitude}');
        } catch (e) {
          debugPrint('Failed to update location: $e');
        }
      });
    } catch (e) {
      debugPrint('Failed to start monitoring: $e');
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    MonitoringApiService.stopMonitoring(customerId: widget.customerEmail);
    super.dispose();
  }

  Future<void> _requestHelp() async {
    try {
      await MonitoringApiService.requestManualAssistance(widget.customerEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text("Staff is on the way!", style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to request assistance: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState().isDarkMode;
    
    final List<Widget> pages = [
      CatalogPage(
        customerEmail: widget.customerEmail,
        recommendedSize: _recommendedSize,
      ),
      const FavoritesPage(),
      const CartPage(),
      ProfilePage(
        customerEmail: widget.customerEmail,
        recommendedSize: _recommendedSize,
        profileId: widget.profileId,
        bodyMeasurements: _bodyMeasurements,
        onProfileUpdated: (newSize, newMeasurements) {
           setState(() {
              _recommendedSize = newSize;
              _bodyMeasurements = newMeasurements;
           });
        },
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(isDark),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          
          // Floating Bottom Navigation Bar
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.glassCard(isDark),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: AppTheme.glassBorder(isDark)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(Icons.storefront_outlined, Icons.storefront, "Shop", 0),
                      _buildNavItem(Icons.favorite_border, Icons.favorite, "Saved", 1),
                      _buildNavItem(Icons.shopping_bag_outlined, Icons.shopping_bag, "Cart", 2),
                      _buildNavItem(Icons.person_outline, Icons.person, "Profile", 3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentRed(isDark).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: _requestHelp,
            backgroundColor: AppTheme.accentRed(isDark),
            elevation: 0,
            child: const Icon(Icons.support_agent, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
    final isDark = AppState().isDarkMode;
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.glassBorder(isDark) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppTheme.glassBorder(isDark) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppTheme.textPrimary(isDark) : AppTheme.iconMuted(isDark),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textPrimary(isDark),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
