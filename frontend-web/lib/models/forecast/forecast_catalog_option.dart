/// Minimal product data required by the manager-facing forecast form.
class ForecastProductOption {
  const ForecastProductOption({
    required this.id,
    required this.name,
    required this.sellingPrice,
    required this.category,
    required this.brand,
    required this.gender,
  });


  factory ForecastProductOption.fromJson(Map<String, dynamic> json) {
    final id = (json['product_id'] ?? json['id'])?.toString();
    final name = json['product_name']?.toString();
    final price = json['selling_price'];
    final category = json['category']?.toString();
    final brand = json['brand']?.toString();
    final gender = json['gender']?.toString();
    if (id == null ||
        name == null ||
        price is! num ||
        category == null ||
        brand == null ||
        gender == null) {
      throw const FormatException('Invalid product option');
    }
    return ForecastProductOption(
      id: id,
      name: name,
      sellingPrice: price.toDouble(),
      category: category,
      brand: brand,
      gender: gender,
    );
  }

  final String id;
  final String name;
  final double sellingPrice;
  final String category;
  final String brand;
  final String gender;
}

/// Minimal showroom data required by the forecast form.
class ForecastStoreOption {
  const ForecastStoreOption({required this.id, required this.name});

  factory ForecastStoreOption.fromJson(Map<String, dynamic> json) {
    final id = (json['store_id'] ?? json['id'])?.toString();
    final name = json['store_name']?.toString();
    if (id == null || name == null) {
      throw const FormatException('Invalid store option');
    }
    return ForecastStoreOption(id: id, name: name);
  }

  final String id;
  final String name;
}

/// Product and showroom choices loaded from their existing API endpoints.
class ForecastCatalog {
  const ForecastCatalog({required this.products, required this.stores});
  final List<ForecastProductOption> products;
  final List<ForecastStoreOption> stores;
}
