import 'dart:convert';
import 'package:http/http.dart' as http;

class MonitoringApiService {
  static const String baseUrl = "http://172.20.10.5:8000";

  static Future<Map<String, dynamic>> startMonitoring({
    required String customerId,
    required String customerName,
    required double lat,
    required double lon,
    required double alt,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/monitoring/start"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "customer_id": customerId,
        "customer_name": customerName,
        "latitude": lat,
        "longitude": lon,
        "altitude": alt,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateMonitoring({
    required String customerId,
    required double lat,
    required double lon,
    required double alt,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/monitoring/update"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "customer_id": customerId,
        "latitude": lat,
        "longitude": lon,
        "altitude": alt,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> stopMonitoring({
    required String customerId,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/monitoring/stop"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"customer_id": customerId}),
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getActiveSessions() async {
    final response = await http.get(Uri.parse("$baseUrl/monitoring/active"));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<List<dynamic>> getActiveRequests() async {
    final response = await http.get(Uri.parse("$baseUrl/monitoring/requests"));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<Map<String, dynamic>> resolveRequest(String requestId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/monitoring/resolve/$requestId"),
      headers: {"Content-Type": "application/json"},
    );
    return jsonDecode(response.body);
  }
}
