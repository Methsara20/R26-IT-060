import 'dart:convert';

import 'package:http/http.dart' as http;

class ProductService {
  final String baseUrl;

  ProductService({required this.baseUrl});

  Future<List<Map<String, dynamic>>> getProducts({
    String? category,
    String? subcategory,
  }) async {
    final queryParameters = <String, String>{};

    if (category != null && category.trim().isNotEmpty) {
      queryParameters['category'] = category.trim();
    }

    if (subcategory != null && subcategory.trim().isNotEmpty) {
      queryParameters['subcategory'] = subcategory.trim();
    }

    final uri = Uri.parse(
      '$baseUrl/products',
    ).replace(queryParameters: queryParameters);

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load products. '
        'Status: ${response.statusCode}\n'
        'Response: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    List<dynamic> rawProducts;

    if (decoded is List<dynamic>) {
      rawProducts = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final productsValue = decoded['products'];

      if (productsValue is List<dynamic>) {
        rawProducts = productsValue;
      } else {
        throw Exception('The API response does not contain a products list.');
      }
    } else {
      throw Exception('Unexpected API response format.');
    }

    return rawProducts
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
