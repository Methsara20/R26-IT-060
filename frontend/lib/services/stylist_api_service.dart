import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class StylistApiService {
  static Future<Map<String, dynamic>> sendChatMessage({
    required String customerId,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse("${ApiService.baseUrl}/stylist/chat"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "customer_id": customerId,
        "message": message,
      }),
    );

    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    final decoded = response.body.isNotEmpty &&
            response.headers["content-type"]?.contains("application/json") ==
                true
        ? jsonDecode(response.body)
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw Exception(decoded["detail"] ?? "Something went wrong");
  }
}
