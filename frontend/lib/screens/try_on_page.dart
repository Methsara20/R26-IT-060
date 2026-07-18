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
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 220,
          padding: const EdgeInsets.all(12),
          child: imageBytes == null
              ? Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : Image.memory(imageBytes, fit: BoxFit.contain),
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text("Virtual Try-On"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            imageBox(
              title: "Upload Human Image",
              imageBytes: humanImageBytes,
              onTap: pickHumanImage,
            ),
            const SizedBox(height: 12),
            if (isProductsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (productsError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Center(child: Text("Error loading catalog: $productsError")),
              )
            else if (products.isNotEmpty && selectedProduct == null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "Select from Catalog:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
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
                        margin: const EdgeInsets.only(right: 12),
                        width: 100,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey.shade300,
                            width: isSelected ? 3 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: product["image_url"] != null
                              ? Image.network(
                                  product["image_url"],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(child: Icon(Icons.broken_image)),
                                )
                              : const Center(child: Icon(Icons.image)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "Selected Clothing Image:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Card(
              elevation: 3,
              child: InkWell(
                onTap: pickClothImage,
                child: Container(
                  width: double.infinity,
                  height: 220,
                  padding: const EdgeInsets.all(12),
                  child: selectedProduct != null
                      ? Stack(
                          children: [
                            Center(
                              child: Image.network(
                                selectedProduct!["image_url"] ?? "",
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image, size: 50),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    selectedProduct = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        )
                      : clothImageBytes == null
                          ? const Center(
                              child: Text(
                                "Tap here to upload from gallery",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : Image.memory(clothImageBytes!, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : sendImages,
                icon: const Icon(Icons.send),
                label: const Text("Send"),
              ),
            ),
            const SizedBox(height: 16),
            if (isLoading) const CircularProgressIndicator(),
            if (message.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(message),
                ),
              ),
            if (imageUrlWithCacheBust != null) ...[
              const SizedBox(height: 20),
              const Text(
                "Generated Try-On Result",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (widget.recommendedSize != null) ...[
                Card(
                  color: const Color(0xFFEFF6FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFBFDBFE), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF2563EB),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Recommended Size Match",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1E40AF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Your body profile matches size: ${widget.recommendedSize}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.network(
                    imageUrlWithCacheBust,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text("Could not load generated image"),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
