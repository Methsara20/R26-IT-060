import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/monitoring_api_service.dart';
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

      _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
        try {
          Position currentPos = await Geolocator.getCurrentPosition();
          await MonitoringApiService.updateMonitoring(
            customerId: widget.customerEmail,
            lat: currentPos.latitude,
            lon: currentPos.longitude,
            alt: currentPos.altitude,
          );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Assistance requested! Staff is on the way."),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
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
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _requestHelp,
        backgroundColor: const Color(0xFFEF4444),
        elevation: 4,
        child: const Icon(Icons.help_outline, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.storefront, "Shop", 0),
                _buildNavItem(Icons.favorite_border, "Saved", 1),
                _buildNavItem(Icons.shopping_cart_outlined, "Cart", 2),
                _buildNavItem(Icons.person_outline, "Profile", 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade400,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.bold,
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
