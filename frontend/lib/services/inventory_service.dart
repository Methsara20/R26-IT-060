import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class InventoryService {
  static Future<http.Response> fetchOverstockSuggestions({String? category, String? limit}) {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (limit != null) params['limit'] = limit;
    final uri = Uri.parse('$backendUrl/inventory/overstock-suggestions').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    return http.get(uri).timeout(const Duration(seconds: 10));
  }
}
