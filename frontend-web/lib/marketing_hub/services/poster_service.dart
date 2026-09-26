import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class PosterService {
  static Future<http.Response> generatePoster(Map<String, dynamic> payload) {
    return http
        .post(
          Uri.parse('$backendUrl/poster/generate'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 190));
  }

  static Future<http.Response> sendEmail(Map<String, dynamic> payload) {
    return http
        .post(
          Uri.parse('$backendUrl/poster/send-email'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 30));
  }

  static Future<http.Response> schedulePoster(Map<String, dynamic> payload) {
    return http
        .post(
          Uri.parse('$backendUrl/poster/schedule'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 30));
  }

  static Future<http.Response> fetchHistory() {
    return http.get(Uri.parse('$backendUrl/poster/history')).timeout(const Duration(seconds: 10));
  }

  static Future<http.Response> fetchScheduled() {
    return http.get(Uri.parse('$backendUrl/poster/scheduled')).timeout(const Duration(seconds: 10));
  }

  static Future<http.Response> sendScheduledNow(String id) {
    return http.post(Uri.parse('$backendUrl/poster/send-scheduled/$id')).timeout(const Duration(seconds: 30));
  }
}
