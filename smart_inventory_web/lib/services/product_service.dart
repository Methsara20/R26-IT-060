import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductService {
  final String baseUrl;

  ProductService({
    required this.baseUrl,
  });

  Future<List<Map<String, dynamic>>> getProducts({
    String? category,
    String? subcategory,
  }) async {
    final queryParameters = <String, String>{};

    if (category != null && category.trim().isNotEmpty) {
      queryParameters['category'] = category;
    }

    if (
        subcategory != null &&
        subcategory.trim().isNotEmpty
    ) {
      queryParameters['subcategory'] = subcategory;
    }

    final uri = Uri.parse(
      '$baseUrl/products',
    ).replace(
      queryParameters: queryParameters,
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load products: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    final List<dynamic> items;

    if (decoded is List) {
      items = decoded;
    } else {
      items = decoded['products'] ?? [];
    }

    return items
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }
}