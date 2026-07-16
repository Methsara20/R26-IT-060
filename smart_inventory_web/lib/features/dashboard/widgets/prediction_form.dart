import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../services/prediction_service.dart';

class PredictionForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onResult;

  const PredictionForm({super.key, required this.onResult});

  @override
  State<PredictionForm> createState() => _PredictionFormState();
}

class _PredictionFormState extends State<PredictionForm> {
  //  CONTROLLERS

  final productController = TextEditingController();

  final storeController = TextEditingController();

  final stockController = TextEditingController();

  final priceController = TextEditingController();

  final promotionController = TextEditingController(text: "0");

  //  DROPDOWN DATA

  List<dynamic> products = [];
  List<dynamic> stores = [];

  String? selectedProduct;
  String? selectedStore;

  //  STATES

  bool isLoading = false;

  //  AUTO FETCH DATA

  String productName = "";
  String storeName = "";
  String category = "";
  String brand = "";
  String gender = "";
  String subcategory = "";
  String trend = "";

  double recentSales = 0;

  //  INIT

  @override
  void initState() {
    super.initState();

    loadDropdownData();
  }

  //  LOAD DROPDOWNS

  Future<void> loadDropdownData() async {
    try {
      final data = await PredictionService.getDropdownData();

      setState(() {
        products = data["products"];

        stores = data["stores"];
      });
    } catch (e) {
      print(e);
    }
  }

  //  FETCH PRODUCT INFO

  Future<void> fetchProductInfo() async {
    final product = productController.text.trim();

    final store = storeController.text.trim();

    if (product.isEmpty || store.isEmpty) {
      return;
    }

    try {
      final data = await PredictionService.getProductStoreInfo(
        productId: product,
        storeId: store,
      );

      setState(() {
        productName = data["product_name"] ?? "";

        storeName = data["store_name"] ?? "";

        category = data["category"] ?? "";

        brand = data["brand"] ?? "";

        gender = data["gender"] ?? "";

        subcategory = data["subcategory"] ?? "";

        trend = data["trend"] ?? "";

        recentSales = (data["recent_sales"] ?? 0).toDouble();

        stockController.text = data["current_stock"].toString();

        priceController.text = data["price_lkr"].toString();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to fetch product info")),
      );
    }
  }

  // PREDICT

  Future<void> handlePredict() async {
    final product = productController.text.trim();

    final store = storeController.text.trim();

    final stock = int.tryParse(stockController.text) ?? 0;

    final price = double.tryParse(priceController.text) ?? 0.0;

    final promotionPercent = double.tryParse(promotionController.text) ?? 0;

    if (product.isEmpty || store.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Product and Store")),
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final result = await PredictionService.predict(
        productId: product,

        storeId: store,

        currentStock: stock,

        price: price,

        promotionPercent: promotionPercent,
      );

      widget.onResult(result);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("API Error")));
    }

    setState(() {
      isLoading = false;
    });
  }

  //  CLEAR

  void handleClear() {
    productController.clear();

    storeController.clear();

    stockController.clear();

    priceController.clear();

    promotionController.text = "0";

    setState(() {
      selectedProduct = null;

      selectedStore = null;

      productName = "";
      storeName = "";
      category = "";
      brand = "";
      gender = "";
      subcategory = "";
      trend = "";

      recentSales = 0;
    });

    widget.onResult({});
  }

  //  CONFIRM CLEAR

  void confirmClear() {
    showDialog(
      context: context,

      builder: (_) => AlertDialog(
        title: const Text("Clear Inputs"),

        content: const Text("Are you sure you want to clear all fields?"),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),

            child: const Text("Cancel"),
          ),

          TextButton(
            onPressed: () {
              Navigator.pop(context);

              handleClear();
            },

            child: const Text("Clear"),
          ),
        ],
      ),
    );
  }

  //  INFO ROW

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),

      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1E3A5F)),

          const SizedBox(width: 10),

          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),

          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  //  DISPOSE

  @override
  void dispose() {
    productController.dispose();

    storeController.dispose();

    stockController.dispose();

    priceController.dispose();

    promotionController.dispose();

    super.dispose();
  }

  //  UI

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),

            blurRadius: 20,

            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          //  HEADER
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: Colors.blue.shade50,

                  borderRadius: BorderRadius.circular(12),
                ),

                child: const Icon(
                  LucideIcons.barChart3,

                  color: Color(0xFF1E3A5F),
                ),
              ),

              const SizedBox(width: 15),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    "Inventory Demand Prediction",

                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),

                  Text(
                    "AI-powered retail forecasting",

                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 25),

          //  FIRST ROW
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedProduct,

                  items: products.map((p) {
                    return DropdownMenuItem<String>(
                      value: p["product_id"],

                      child: Text(
                        "${p["product_name"]} "
                        "- ${p["brand"]} "
                        "- ${p["gender"]}",
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),

                  onChanged: (value) {
                    setState(() {
                      selectedProduct = value;

                      productController.text = value!;
                    });

                    fetchProductInfo();
                  },

                  decoration: const InputDecoration(
                    labelText: "Product",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedStore,

                  items: stores.map((s) {
                    return DropdownMenuItem<String>(
                      value: s["store_id"],

                      child: Text("${s["store_id"]} - ${s["store_name"]}"),
                    );
                  }).toList(),

                  onChanged: (value) {
                    setState(() {
                      selectedStore = value;

                      storeController.text = value!;
                    });

                    fetchProductInfo();
                  },

                  decoration: const InputDecoration(
                    labelText: "Store",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: TextField(
                  controller: stockController,

                  readOnly: true,

                  decoration: const InputDecoration(
                    labelText: "Current Stock",

                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          //  SECOND ROW
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: priceController,

                  keyboardType: TextInputType.number,

                  decoration: const InputDecoration(
                    labelText: "Price",

                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: TextField(
                  controller: promotionController,

                  keyboardType: TextInputType.number,

                  decoration: const InputDecoration(
                    labelText: "Promotion %",

                    hintText: "0 - 100",

                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // PRODUCT SUMMARY CARD
          if (productName.isNotEmpty)
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.white],
                ),

                borderRadius: BorderRadius.circular(16),

                border: Border.all(color: Colors.blue.shade100),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  _buildInfoRow(
                    Icons.inventory_2_outlined,
                    "Product",
                    productName,
                  ),

                  _buildInfoRow(Icons.storefront_outlined, "Store", storeName),

                  _buildInfoRow(Icons.category_outlined, "Category", category),

                  _buildInfoRow(Icons.sell_outlined, "Brand", brand),

                  _buildInfoRow(Icons.people_outline, "Gender", gender),

                  _buildInfoRow(Icons.style_outlined, "Subcategory", subcategory,),

                  _buildInfoRow(Icons.trending_up, "Sales Trend", trend),

                  _buildInfoRow(Icons.bar_chart, "Recent Sales", recentSales.toString(),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 25),

          //  BUTTONS
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,

                  child: ElevatedButton(
                    onPressed: isLoading ? null : handlePredict,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),

                      foregroundColor: Colors.white,

                      elevation: 0,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),

                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Predict Demand"),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: SizedBox(
                  height: 50,

                  child: OutlinedButton(
                    onPressed: isLoading ? null : confirmClear,

                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),

                    child: const Text("Reset Form"),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
