import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class TryOnPage extends StatefulWidget {
  const TryOnPage({super.key});

  @override
  State<TryOnPage> createState() => _TryOnPageState();
}

class _TryOnPageState extends State<TryOnPage> {
  final ImagePicker picker = ImagePicker();

  XFile? humanImage;
  XFile? clothImage;

  Uint8List? humanImageBytes;
  Uint8List? clothImageBytes;

  bool isLoading = false;
  String message = "";
  String? generatedImageUrl;

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
      });
    }
  }

  Future<void> sendImages() async {
    if (humanImage == null || clothImage == null) {
      setState(() {
        message = "Please upload both human image and clothing image";
      });
      return;
    }

    setState(() {
      isLoading = true;
      message = "";
      generatedImageUrl = null;
    });

    try {
      final result = await ApiService.generateTryOn(
        humanImage: humanImage!,
        clothImage: clothImage!,
      );

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
              : Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Virtual Try-On"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            imageBox(
              title: "Upload Human Image",
              imageBytes: humanImageBytes,
              onTap: pickHumanImage,
            ),
            const SizedBox(height: 12),
            imageBox(
              title: "Upload Clothing Image",
              imageBytes: clothImageBytes,
              onTap: pickClothImage,
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
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