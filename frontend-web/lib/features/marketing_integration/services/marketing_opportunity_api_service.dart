import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../models/marketing_opportunity.dart';

class MarketingOpportunityApiException implements Exception {
  const MarketingOpportunityApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MarketingOpportunityApiService {
  MarketingOpportunityApiService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<MarketingOpportunityResponse> create(
    MarketingOpportunityRequest request,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConstants.baseUrl}/marketing-opportunities/'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(ApiConstants.requestTimeout);

      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          body = Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        // Handled below as either a backend error or malformed success response.
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MarketingOpportunityApiException(
          body?['detail']?.toString() ??
              'Unable to send this opportunity to Marketing. Please try again.',
        );
      }
      if (body == null) {
        throw const MarketingOpportunityApiException(
          'The Marketing service returned an unexpected response.',
        );
      }

      try {
        return MarketingOpportunityResponse.fromJson(body);
      } on FormatException {
        throw const MarketingOpportunityApiException(
          'The Marketing service returned an incomplete response.',
        );
      }
    } on MarketingOpportunityApiException {
      rethrow;
    } on TimeoutException {
      throw const MarketingOpportunityApiException(
        'The Marketing service is taking too long. Please try again.',
      );
    } on http.ClientException {
      throw const MarketingOpportunityApiException(
        'Cannot connect to the Marketing service. Please try again.',
      );
    }
  }
}
