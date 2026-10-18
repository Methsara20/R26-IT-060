import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class RecommenderService {
  static Future<http.Response> getRecommendation(Map<String, dynamic> payload) {
    return http
        .post(
          Uri.parse('$backendUrl/recommend'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 15));
  }
}
