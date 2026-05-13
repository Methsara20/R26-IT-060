import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  static const String baseUrl = "http://127.0.0.1:8000";

  static Future<String> sendMessage(
    String message,
    Map<String, dynamic>? context,
  ) async {
    final url = Uri.parse("$baseUrl/chat");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "message": message,
        "context": context ?? {},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["reply"] ?? "No reply received.";
    } else {
      throw Exception("Chat API Error: ${response.body}");
    }
  }
}