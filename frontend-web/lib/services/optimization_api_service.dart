import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/optimization/optimization_candidate.dart';

class OptimizationApiException implements Exception {
  const OptimizationApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OptimizationApiService {
  OptimizationApiService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  Future<OptimizationOverview> getOverview() async {
    final responses = await Future.wait([
      _get('/optimization-candidates/summary'),
      _get('/optimization-candidates/'),
    ]);
    final candidateItems = responses[1]['candidates'];
    if (candidateItems is! List) {
      throw const OptimizationApiException('Candidate data is malformed.');
    }
    try {
      return OptimizationOverview(
        summary: OptimizationSummary.fromJson(responses[0]),
        candidates: candidateItems
            .map(
              (item) => OptimizationCandidate.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );
    } on FormatException {
      throw const OptimizationApiException('Candidate data is incomplete.');
    }
  }

  /// Runs the state-changing decision analysis and returns the confirmed candidate.
  Future<OptimizationCandidate> analyzeCandidate(String candidateId) async {
    final response = await _request(
      'POST',
      '/decision-engine/analyze/$candidateId',
    );
    final candidate = response['candidate'];
    if (candidate is! Map) {
      throw const OptimizationApiException(
        'The decision response is incomplete.',
      );
    }
    return OptimizationCandidate.fromJson(Map<String, dynamic>.from(candidate));
  }

  Future<Map<String, dynamic>> _get(String path) => _request('GET', path);

  Future<Map<String, dynamic>> _request(String method, String path) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$path');
      final response =
          await (method == 'POST' ? _client.post(uri) : _client.get(uri))
              .timeout(ApiConstants.requestTimeout);
      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } on FormatException {
        // FastAPI can return a plain-text body for an unhandled server error.
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OptimizationApiException(
          body?['detail']?.toString() ??
              'Optimization request failed (${response.statusCode}).',
        );
      }
      if (body == null) {
        throw const OptimizationApiException(
          'Unexpected optimization response.',
        );
      }
      return body;
    } on OptimizationApiException {
      rethrow;
    } on TimeoutException {
      throw const OptimizationApiException(
        'The optimization request timed out.',
      );
    } on http.ClientException {
      throw const OptimizationApiException(
        'Cannot connect to the optimization service.',
      );
    }
  }
}
