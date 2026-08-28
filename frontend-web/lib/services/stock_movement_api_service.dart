import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../models/stock_movement/stock_movement.dart';

class StockMovementApiException implements Exception {
  const StockMovementApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A state-changing request timed out after dispatch, so its result must be
/// verified before the manager is allowed to try the action again.
class StockMovementOutcomeUnknownException extends StockMovementApiException {
  const StockMovementOutcomeUnknownException()
    : super('The request is taking longer than expected.');
}

class StockMovementApiService {
  StockMovementApiService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<StockMovement>> getMovements() async {
    final response = await _request('GET', '/stock-movement/');
    final items = response['movements'];
    if (items is! List) {
      throw const StockMovementApiException('Movement data is malformed.');
    }

    try {
      return items
          .map(
            (item) =>
                StockMovement.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on (FormatException, TypeError) {
      throw const StockMovementApiException('Movement data is incomplete.');
    }
  }

  Future<StockMovement> getMovement(String movementId) async {
    final response = await _request('GET', '/stock-movement/$movementId');
    try {
      return StockMovement.fromJson(response);
    } on FormatException {
      throw const StockMovementApiException('Movement data is incomplete.');
    }
  }

  /// Requests the next backend-ranked recommendation version for a candidate.
  ///
  /// The backend remains responsible for source ranking, transfer quantity,
  /// validation, version numbering, and persistence.
  Future<StockMovement> recommendTransfer(String candidateId) =>
      _mutate('/stock-movement/recommend-transfer/$candidateId', const {});

  Future<StockMovement> approve(String movementId) => _mutate(
    '/stock-movement/approve/$movementId',
    const {'is_approved': true},
  );

  Future<StockMovement> reject(String movementId, String? reason) => _mutate(
    '/stock-movement/reject/$movementId',
    {'is_rejected': true, 'rejection_reason': reason},
  );

  Future<StockMovement> cancel(String movementId, String? reason) => _mutate(
    '/stock-movement/cancel/$movementId',
    {'is_cancelled': true, 'cancel_reason': reason},
  );

  Future<StockMovement> execute(String movementId) => _mutate(
    '/stock-movement/execute/$movementId',
    const {'is_executed': true},
  );

  Future<StockMovement> _mutate(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request('POST', path, payload: payload);
    return StockMovement.fromJson(response);
  }

  Future<Map<String, dynamic>> _request(
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
              .timeout(ApiConstants.requestTimeout);

      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } on FormatException {
        // FastAPI may return plain text when an unhandled exception occurs.
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = body?['detail'];
        final message = detail is Map
            ? detail['error']?.toString()
            : detail?.toString();
        throw StockMovementApiException(
          message ?? 'Movement request failed (${response.statusCode}).',
        );
      }
      if (body == null) {
        throw const StockMovementApiException(
          'Unexpected stock movement response.',
        );
      }
      return body;
    } on StockMovementApiException {
      rethrow;
    } on TimeoutException {
      if (method == 'POST') {
        throw const StockMovementOutcomeUnknownException();
      }
      throw const StockMovementApiException(
        'The stock movement request timed out.',
      );
    } on http.ClientException {
      throw const StockMovementApiException(
        'Cannot connect to the stock movement service.',
      );
    }
  }
}
