import 'dart:convert';
import 'package:http/http.dart' as http;

class ZoneApiService {
  static const String baseUrl = "http://172.20.10.5:8000";

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
    final response = await http.get(Uri.parse("$baseUrl/zone/all"));
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteZone(String zoneId) async {
    final response = await http.delete(Uri.parse("$baseUrl/zone/$zoneId"));
    return jsonDecode(response.body);
  }
}
