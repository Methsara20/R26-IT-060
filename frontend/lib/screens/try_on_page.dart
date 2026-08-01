import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/monitoring_api_service.dart';

class TryOnPage extends StatefulWidget {
  final String customerEmail;
  final Map<String, dynamic>? initialProduct;
  final String? recommendedSize;
  const TryOnPage({
    super.key,
    required this.customerEmail,
    this.initialProduct,
    this.recommendedSize,
  });

  @override
  State<TryOnPage> createState() => _TryOnPageState();
}

class _TryOnPageState extends State<TryOnPage> {
  final ImagePicker picker = ImagePicker();

  XFile? humanImage;
  XFile? clothImage;

  Uint8List? humanImageBytes;
  Uint8List? clothImageBytes;

  List<dynamic> products = [];
  Map<String, dynamic>? selectedProduct;
  bool isProductsLoading = true;
  String? productsError;

  bool isLoading = false;
  String message = "";
  String? generatedImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    if (widget.initialProduct != null) {
      selectedProduct = widget.initialProduct;
    }
  }

  Future<void> _loadProducts() async {
    try {
      final fetchedProducts = await ApiService.getProducts();
      setState(() {
        products = fetchedProducts;
        isProductsLoading = false;
      });
    } catch (e) {
      setState(() {
        productsError = e.toString();
        isProductsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> pickHumanImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();

      setState(() {
        humanImage = pickedFile;
        humanImageBytes = bytes;
      });
    }
  }

  Future<void> pickClothImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();

      setState(() {
        clothImage = pickedFile;
        clothImageBytes = bytes;
        selectedProduct = null;
      });
    }
  }

  Future<void> sendImages() async {
    if (humanImage == null || (clothImage == null && selectedProduct == null)) {
      setState(() {
        message = "Please upload both human image and clothing image/product";
      });
      return;
    }

    setState(() {
      isLoading = true;
      message = "";
      generatedImageUrl = null;
    });

    try {
      Map<String, dynamic> result;
      if (selectedProduct != null) {
        final response = await http.get(Uri.parse(selectedProduct!["image_url"]));
        if (response.statusCode == 200) {
          result = await ApiService.generateTryOn(
            humanImage: humanImage!,
            clothBytes: response.bodyBytes,
          );
        } else {
          throw Exception("Failed to download catalog product image");
        }
      } else {
        result = await ApiService.generateTryOn(
          humanImage: humanImage!,
          clothImage: clothImage!,
        );
      }

      setState(() {
        generatedImageUrl = result["image_url"];
        message = result["message"] ?? "Try-on image generated successfully";
      });
    } catch (e) {
      setState(() {
        message = e.toString();
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Widget imageBox({
    required String title,
    required Uint8List? imageBytes,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 220,
          child: imageBytes == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(imageBytes, fit: BoxFit.cover),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrlWithCacheBust = generatedImageUrl == null
        ? null
        : "$generatedImageUrl?t=${DateTime.now().millisecondsSinceEpoch}";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Virtual Try-On",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your Photo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            imageBox(
              title: "Upload Human Image",
              imageBytes: humanImageBytes,
              onTap: pickHumanImage,
            ),
            const SizedBox(height: 24),

            if (isProductsLoading)
              const Center(child: CircularProgressIndicator())
            else if (productsError != null)
              Center(child: Text("Error loading catalog: $productsError", style: const TextStyle(color: Colors.red)))
            else if (products.isNotEmpty && selectedProduct == null) ...[
              const Text(
                "Select from Catalog",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isSelected = selectedProduct == product;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedProduct = product;
                          clothImage = null;
                          clothImageBytes = null;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                            width: isSelected ? 3 : 0,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: product["image_url"] != null
                              ? Image.network(
                                  product["image_url"],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                )
                              : const Center(child: Icon(Icons.image, color: Colors.grey)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Text(
              "Selected Clothing",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: pickClothImage,
                child: Container(
                  width: double.infinity,
                  height: 220,
                  child: selectedProduct != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: double.infinity,
                                height: 220,
                                color: const Color(0xFFF1F5F9),
                                child: Image.network(
                                  selectedProduct!["image_url"] ?? "",
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image, size: 50),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedProduct = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                                ),
                              ),
                            ),
                          ],
                        )
                      : clothImageBytes == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  "Upload from gallery",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(clothImageBytes!, fit: BoxFit.cover),
                            ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: isLoading ? null : sendImages,
                icon: isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.auto_awesome, color: Colors.white),
                label: isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        "Generate Try-On",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            if (message.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(message, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
              ),
              
            if (imageUrlWithCacheBust != null) ...[
              const SizedBox(height: 40),
              const Text(
                "Your Virtual Look",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              
              if (widget.recommendedSize != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Recommended Size Match",
                              style: TextStyle(fontSize: 13, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Matches your profile: ${widget.recommendedSize}",
                              style: const TextStyle(fontSize: 16, color: Color(0xFF14532D), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    imageUrlWithCacheBust,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text("Could not load generated image", style: TextStyle(color: Colors.red))),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }
}
