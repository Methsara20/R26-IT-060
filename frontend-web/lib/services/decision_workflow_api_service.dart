import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../models/workflow/decision_workflow.dart';

class DecisionWorkflowApiException implements Exception {
  const DecisionWorkflowApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DecisionWorkflowApiService {
  DecisionWorkflowApiService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  Future<DecisionWorkflow> analyze({
    required String forecastType,
    required String storeId,
    required String productId,
    required double sellingPrice,
    required double promotionPercent,
    required String idempotencyKey,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _request('POST', '/decision-workflow/analyze', {
      'forecast_type': forecastType,
      'store_id': storeId,
      'product_id': productId,
      'selling_price': sellingPrice,
      'promotion_percent': promotionPercent,
      'idempotency_key': idempotencyKey,
      if (startDate != null) 'start_date': _date(startDate),
      if (endDate != null) 'end_date': _date(endDate),
    });
    return _parse(response);
  }

  Future<DecisionWorkflow> getWorkflow(String workflowId) async =>
      _parse(await _request('GET', '/decision-workflow/$workflowId'));

  DecisionWorkflow _parse(Map<String, dynamic> response) {
    try {
      return DecisionWorkflow.fromJson(response);
    } on FormatException {
      throw const DecisionWorkflowApiException(
        'The workflow response is incomplete or malformed.',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
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
              .timeout(const Duration(seconds: 90));
      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } on FormatException {
        // FastAPI may return plain text for an unhandled upstream error.
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DecisionWorkflowApiException(
          body?['detail']?.toString() ??
              'Workflow request failed (${response.statusCode}).',
        );
      }
      if (body == null) {
        throw const DecisionWorkflowApiException(
          'The workflow service returned an unexpected response.',
        );
      }
      return body;
    } on DecisionWorkflowApiException {
      rethrow;
    } on TimeoutException {
      throw const DecisionWorkflowApiException(
        'The connected forecast is taking too long. Please try again.',
      );
    } on http.ClientException {
      throw const DecisionWorkflowApiException(
        'Cannot connect to the decision workflow service.',
      );
    }
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
