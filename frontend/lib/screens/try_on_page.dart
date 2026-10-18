import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:ui';

import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'stylist_chat.dart';

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

class _TryOnPageState extends State<TryOnPage> with TickerProviderStateMixin {
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

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _loadProducts();
    if (widget.initialProduct != null) {
      selectedProduct = widget.initialProduct;
    }
  }

  Future<void> _loadProducts() async {
    try {
      final fetchedProducts = await ApiService.getProducts();
      if (mounted) {
        setState(() {
          products = fetchedProducts;
          isProductsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          productsError = e.toString();
          isProductsLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _pulseController.dispose();
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
      setState(() => message = "Please upload both your photo and a clothing item.");
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

      if (mounted) {
        setState(() {
          generatedImageUrl = result["image_url"];
          message = result["message"] ?? "Try-on generated successfully!";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = e.toString());
      }
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Widget _buildGlassBox({
    required String title,
    required String subtitle,
    required Uint8List? imageBytes,
    required VoidCallback onTap,
    required IconData icon,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.glassCard(isDark),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppTheme.glassBorder(isDark)),
          boxShadow: [
            if (imageBytes != null) BoxShadow(color: AppTheme.accentBlue(isDark).withValues(alpha: 0.15), blurRadius: 40, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageBytes != null)
                Image.memory(imageBytes, fit: BoxFit.cover)
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.glassBackground(isDark),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.glassBorder(isDark)),
                      ),
                      child: Icon(icon, size: 42, color: AppTheme.iconMuted(isDark)),
                    ),
                    const SizedBox(height: 20),
                    Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary(isDark))),
                    const SizedBox(height: 8),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(isDark))),
                  ],
                ),
              if (imageBytes != null)
                Positioned(
                  top: 16,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor(isDark).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.glassBorder(isDark)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 14, color: AppTheme.textPrimary(isDark)),
                            const SizedBox(width: 6),
                            Text("Change", style: TextStyle(color: AppTheme.textPrimary(isDark), fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState().isDarkMode;
    final imageUrlWithCacheBust = generatedImageUrl == null
        ? null
        : "$generatedImageUrl?t=${DateTime.now().millisecondsSinceEpoch}";

    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor(isDark),
          body: Stack(
            children: [
              // Background Glow Effects
              Positioned(
                top: -100,
                left: -100,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.orbPrimary(isDark).withValues(alpha: 0.15)),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                right: -100,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.orbSecondary(isDark).withValues(alpha: 0.15)),
                  ),
                ),
              ),

              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    centerTitle: true,
                    iconTheme: IconThemeData(color: AppTheme.textPrimary(isDark)),
                    title: Text("AI Try-On", style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary(isDark), fontSize: 20, letterSpacing: 0.5)),
                    flexibleSpace: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(color: AppTheme.backgroundColor(isDark).withValues(alpha: 0.7)),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Step 1", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.accentBlue(isDark), letterSpacing: 2)),
                              const SizedBox(height: 8),
                              Text("Your Photo", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary(isDark))),
                              const SizedBox(height: 24),
                              
                              _buildGlassBox(
                                title: "Upload Full Body Photo",
                                subtitle: "Front-facing works best",
                                icon: Icons.camera_front,
                                imageBytes: humanImageBytes,
                                onTap: pickHumanImage,
                                isDark: isDark,
                              ),

                              const SizedBox(height: 48),

                              Text("Step 2", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.orbSecondary(isDark), letterSpacing: 2)),
                              const SizedBox(height: 8),
                              Text("The Outfit", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary(isDark))),
                              const SizedBox(height: 24),

                              if (isProductsLoading)
                                Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: AppTheme.orbSecondary(isDark))))
                              else if (productsError != null)
                                Center(child: Text("Error: $productsError", style: TextStyle(color: AppTheme.accentRed(isDark))))
                              else if (products.isNotEmpty && selectedProduct == null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  decoration: BoxDecoration(
                                    color: AppTheme.glassCard(isDark),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: AppTheme.glassBorder(isDark)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24),
                                        child: Text("Select from Catalog", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary(isDark))),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 140,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          padding: const EdgeInsets.symmetric(horizontal: 20),
                                          itemCount: products.length,
                                          itemBuilder: (context, index) {
                                            final product = products[index];
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
                                                  color: AppTheme.glassCard(isDark),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: AppTheme.glassBorder(isDark)),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(20),
                                                  child: product["image_url"] != null
                                                      ? Image.network(product["image_url"], fit: BoxFit.cover)
                                                      : Center(child: Icon(Icons.image, color: AppTheme.iconMuted(isDark))),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Center(child: Text("— OR —", style: TextStyle(color: AppTheme.textSecondary(isDark), fontWeight: FontWeight.w800, letterSpacing: 2))),
                                const SizedBox(height: 24),
                              ],

                              // Selected Cloth Preview
                              if (selectedProduct != null || clothImageBytes != null)
                                Container(
                                  height: 180,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppTheme.glassCard(isDark),
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(color: AppTheme.glassBorder(isDark)),
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(32),
                                        child: selectedProduct != null
                                            ? Image.network(selectedProduct!["image_url"] ?? "", fit: BoxFit.cover)
                                            : Image.memory(clothImageBytes!, fit: BoxFit.cover),
                                      ),
                                      Positioned(
                                        top: 16,
                                        right: 16,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              selectedProduct = null;
                                              clothImage = null;
                                              clothImageBytes = null;
                                            });
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(20),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.backgroundColor(isDark).withValues(alpha: 0.5),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: AppTheme.glassBorder(isDark)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.close, size: 14, color: AppTheme.textPrimary(isDark)),
                                                    const SizedBox(width: 6),
                                                    Text("Remove", style: TextStyle(color: AppTheme.textPrimary(isDark), fontSize: 12, fontWeight: FontWeight.w600)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                _buildGlassBox(
                                  title: "Upload Custom Garment",
                                  subtitle: "Flat lay images work best",
                                  icon: Icons.checkroom,
                                  imageBytes: null,
                                  onTap: pickClothImage,
                                  isDark: isDark,
                                ),

                              const SizedBox(height: 48),

                              // Magic Button
                              ScaleTransition(
                                scale: isLoading ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
                                child: Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      colors: [AppTheme.accentBlue(isDark), AppTheme.orbSecondary(isDark)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: AppTheme.accentBlue(isDark).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10)),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    onPressed: isLoading ? null : sendImages,
                                    child: isLoading
                                        ? const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                                              SizedBox(width: 12),
                                              Text("Generating Magic...", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                                            ],
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                                              SizedBox(width: 8),
                                              Text("Generate Try-On", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                                            ],
                                          ),
                                  ),
                                ),
                              ),

                              if (message.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: message.contains("success") ? AppTheme.accentGreen(isDark).withValues(alpha: 0.1) : AppTheme.accentRed(isDark).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: message.contains("success") ? AppTheme.accentGreen(isDark).withValues(alpha: 0.3) : AppTheme.accentRed(isDark).withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(message.contains("success") ? Icons.check_circle_outline : Icons.error_outline, color: message.contains("success") ? AppTheme.accentGreen(isDark) : AppTheme.accentRed(isDark)),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(message, style: TextStyle(color: message.contains("success") ? AppTheme.accentGreen(isDark) : AppTheme.accentRed(isDark), fontWeight: FontWeight.w600, height: 1.4))),
                                    ],
                                  ),
                                ),
                              ],

                              if (imageUrlWithCacheBust != null) ...[
                                const SizedBox(height: 64),
                                const Center(child: Text("✨ THE RESULT ✨", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFF59E0B), letterSpacing: 3))),
                                const SizedBox(height: 24),
                                
                                if (widget.recommendedSize != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppTheme.glassCard(isDark),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: AppTheme.accentGreen(isDark).withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.verified, color: AppTheme.accentGreen(isDark), size: 32),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("Perfect Size Match", style: TextStyle(fontSize: 13, color: AppTheme.accentGreen(isDark), fontWeight: FontWeight.w700)),
                                              const SizedBox(height: 4),
                                              Text("Recommended size: ${widget.recommendedSize}", style: TextStyle(fontSize: 16, color: AppTheme.textPrimary(isDark), fontWeight: FontWeight.w900)),
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
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(color: AppTheme.glassBorder(isDark)),
                                    boxShadow: [
                                      BoxShadow(color: AppTheme.orbSecondary(isDark).withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, 20)),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(32),
                                    child: Image.network(
                                      imageUrlWithCacheBust,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => Padding(padding: const EdgeInsets.all(32), child: Center(child: Text("Could not load generated image", style: TextStyle(color: AppTheme.accentRed(isDark))))),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 100),
                              ],
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => StylistChatSheet(customerEmail: widget.customerEmail),
              );
            },
            backgroundColor: AppTheme.textPrimary(isDark),
            icon: Icon(Icons.chat_bubble_outline, color: AppTheme.backgroundColor(isDark), size: 20),
            label: Text("Stylist", style: TextStyle(color: AppTheme.backgroundColor(isDark), fontWeight: FontWeight.w900)),
          ),
        );
      }
    );
  }
}
