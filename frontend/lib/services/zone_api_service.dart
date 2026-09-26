import 'dart:convert';
import 'package:http/http.dart' as http;

class ZoneApiService {
  static const String baseUrl = "https://r26-it-060.onrender.com";

  static Future<Map<String, dynamic>> createZone({
    required String zoneName,
    required List<Map<String, dynamic>> points,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/zone/create"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"zone_name": zoneName, "points": points}),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> identifyZone({
    required double latitude,
    required double longitude,
    required double altitude,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/zone/identify"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "latitude": latitude,
        "longitude": longitude,
        "altitude": altitude,
      }),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getAllZones() async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/zone/all"))
          .timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {"zones": []};
    }
  }

  static Future<Map<String, dynamic>> deleteZone(String zoneId) async {
    final response = await http.delete(Uri.parse("$baseUrl/zone/$zoneId"));
    return jsonDecode(response.body);
  }
}
