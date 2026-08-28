import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../models/assistant/manager_chat.dart';

class ManagerAssistantApiException implements Exception {
  const ManagerAssistantApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ManagerAssistantApiService {
  ManagerAssistantApiService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<ManagerChatSession>> getSessions({int limit = 20}) async {
    final decoded = await _request(
      'GET',
      '/manager-assistant/history?limit=$limit',
    );
    if (decoded is! List) {
      throw const ManagerAssistantApiException('Chat history is malformed.');
    }
    return decoded
        .map(
          (item) => ManagerChatSession.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<ManagerChatHistory> getHistory(String sessionId) async {
    final decoded = await _request(
      'GET',
      '/manager-assistant/history/$sessionId?limit=50',
    );
    if (decoded is! Map) {
      throw const ManagerAssistantApiException('Chat messages are malformed.');
    }
    return ManagerChatHistory.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<ManagerChatReply> sendMessage({
    required String message,
    required String sessionId,
    String? movementId,
  }) async {
    final decoded = await _request(
      'POST',
      '/manager-assistant/chat',
      payload: {
        'message': message,
        'session_id': sessionId,
        'movement_id': movementId,
        'mode': movementId == null ? 'GENERAL' : 'CONTEXTUAL',
      },
    );
    if (decoded is! Map) {
      throw const ManagerAssistantApiException('Assistant reply is malformed.');
    }
    return ManagerChatReply.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? payload,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$path');
      final response =
          await (method == 'POST'
                  ? _client.post(
                      uri,
                      headers: const {'Content-Type': 'application/json'},
                      body: jsonEncode(payload),
                    )
                  : _client.get(uri))
              .timeout(const Duration(seconds: 45));
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        // The server may return plain text after an unhandled AI error.
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map ? decoded['detail'] : null;
        final message = detail is Map
            ? detail['answer'] ?? detail['error_code']
            : detail;
        throw ManagerAssistantApiException(
          message?.toString() ??
              'Assistant request failed (${response.statusCode}).',
        );
      }
      if (decoded == null) {
        throw const ManagerAssistantApiException(
          'The assistant returned an unexpected response.',
        );
      }
      return decoded;
    } on ManagerAssistantApiException {
      rethrow;
    } on TimeoutException {
      throw const ManagerAssistantApiException(
        'The assistant is taking too long. Please try again.',
      );
    } on http.ClientException {
      throw const ManagerAssistantApiException(
        'Cannot connect to the Manager Assistant.',
      );
    } on FormatException {
      throw const ManagerAssistantApiException(
        'The assistant data is incomplete.',
      );
    }
  }
}
