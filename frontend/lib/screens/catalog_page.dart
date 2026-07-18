import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/monitoring_api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
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

  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _initializeAssistanceMonitoring();
    _fetchProducts();
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

      _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (
        timer,
      ) async {
        try {
          Position currentPos = await Geolocator.getCurrentPosition();
          await MonitoringApiService.updateMonitoring(
            customerId: widget.customerEmail,
            lat: currentPos.latitude,
            lon: currentPos.longitude,
            alt: currentPos.altitude,
          );
        } catch (e) {
          debugPrint("Failed to update location: $e");
        }
      });
    } catch (e) {
      debugPrint("Failed to start monitoring: $e");
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    MonitoringApiService.stopMonitoring(customerId: widget.customerEmail);
    super.dispose();
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

        final matchesCategory =
            selectedCategory == "All" || cat == selectedCategory;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Fashion Catalog",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            await MonitoringApiService.requestManualAssistance(widget.customerEmail);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Assistance requested! Staff is on the way."),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Failed to request assistance: $e"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.help_outline, color: Colors.white),
        label: const Text("Request Help", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          "Failed to load products\n$errorMessage",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                              errorMessage = null;
                            });
                            _fetchProducts();
                          },
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Search & Categories Section
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (val) {
                              searchQuery = val;
                              _applyFilters();
                            },
                            decoration: InputDecoration(
                              hintText: "Search clothing or brands...",
                              prefixIcon: const Icon(Icons.search, color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 38,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final cat = categories[index];
                                final isSelected = selectedCategory == cat;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      cat,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFF2563EB),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          selectedCategory = cat;
                                          _applyFilters();
                                        });
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Products Grid
                    Expanded(
                      child: filteredProducts.isEmpty
                          ? const Center(
                              child: Text(
                                "No items match your criteria",
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.68,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                final isOutOfStock = (product["current_stock"] ?? 0) <= 0;
                                final price = product["price_lkr"] ?? 0.0;

                                return Card(
                                  color: Colors.white,
                                  elevation: 2,
                                  shadowColor: Colors.black12,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Product Image Box
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              Container(
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  borderRadius: const BorderRadius.vertical(
                                                    top: Radius.circular(16),
                                                  ),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: const BorderRadius.vertical(
                                                    top: Radius.circular(16),
                                                  ),
                                                  child: product["image_url"] != null
                                                      ? Image.network(
                                                          product["image_url"],
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) =>
                                                              const Center(child: Icon(Icons.broken_image, size: 40)),
                                                        )
                                                      : const Center(child: Icon(Icons.image, size: 40)),
                                                ),
                                              ),
                                              // Stock Badge
                                              Positioned(
                                                top: 10,
                                                left: 10,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isOutOfStock
                                                        ? const Color(0xFFFEE2E2)
                                                        : const Color(0xFFDCFCE7),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    isOutOfStock ? "Out of Stock" : "In Stock",
                                                    style: TextStyle(
                                                      color: isOutOfStock
                                                          ? const Color(0xFFEF4444)
                                                          : const Color(0xFF16A34A),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Product Details
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product["brand"] ?? "Generic",
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                product["product_name"] ?? "Unnamed Item",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    "LKR ${price.toStringAsFixed(0)}",
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFF2563EB),
                                                    ),
                                                  ),
                                                  Text(
                                                    product["category"] ?? "",
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
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
                    ),
                  ],
                ),
    );
  }
}
