import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../models/analytics/dashboard_summary.dart';
import '../models/analytics/dashboard_command_center.dart';
import '../models/analytics/analytics_overview.dart';

class AnalyticsApiException implements Exception {
  const AnalyticsApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AnalyticsApiService {
  AnalyticsApiService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<AnalyticsOverview> getOverview() async {
    final responses = await Future.wait([
      _getMap('/analytics/dashboard'),
      _getMap('/analytics/showroom-performance'),
      _getMap('/analytics/inventory/category-summary'),
      _getList('/analytics/brands'),
      _getList('/analytics/genders'),
      _getMap('/analytics/low-stock-items'),
      _getMap('/analytics/overstock-items'),
      _getMap('/analytics/high-value-inventory'),
    ]);

    try {
      final showroomMap = responses[1] as Map<String, dynamic>;
      final categoryMap = responses[2] as Map<String, dynamic>;
      return AnalyticsOverview(
        dashboard: DashboardSummary.fromJson(
          responses[0] as Map<String, dynamic>,
        ),
        showrooms: _breakdowns(
          showroomMap['showrooms'],
          labelKey: 'store_name',
          secondaryKey: 'city',
        ),
        categories: _breakdowns(
          categoryMap['categories'],
          labelKey: 'category',
        ),
        brands: _breakdowns(responses[3], labelKey: 'brand'),
        genders: _breakdowns(responses[4], labelKey: 'gender'),
        lowStockItems: _alerts((responses[5] as Map<String, dynamic>)['items']),
        overstockItems: _alerts(
          (responses[6] as Map<String, dynamic>)['items'],
        ),
        highValueItems: _alerts(
          (responses[7] as Map<String, dynamic>)['items'],
        ),
      );
    } on (FormatException, TypeError) {
      throw const AnalyticsApiException(
        'The analytics data is incomplete or malformed.',
      );
    }
  }

  Future<DashboardSummary> getDashboardSummary() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConstants.baseUrl}/analytics/dashboard'))
          .timeout(ApiConstants.requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AnalyticsApiException(
          'Dashboard request failed (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AnalyticsApiException(
          'The dashboard returned an unexpected response.',
        );
      }

      final backendError = decoded['error'];
      if (backendError is String && backendError.isNotEmpty) {
        throw AnalyticsApiException(backendError);
      }

      return DashboardSummary.fromJson(decoded);
    } on AnalyticsApiException {
      rethrow;
    } on FormatException {
      throw const AnalyticsApiException(
        'The dashboard data is incomplete or malformed.',
      );
    } on http.ClientException {
      throw const AnalyticsApiException(
        'Cannot connect to the inventory service.',
      );
    } on TimeoutException {
      throw const AnalyticsApiException(
        'The dashboard request timed out. Please try again.',
      );
    } catch (_) {
      throw const AnalyticsApiException('Unable to load the dashboard.');
    }
  }

  /// Loads the dashboard from three targeted aggregate documents.
  ///
  /// The required summary is fetched first. The two alert documents are then
  /// loaded concurrently and degrade to empty lists independently, keeping a
  /// secondary alert failure from hiding the primary dashboard.
  Future<DashboardCommandCenter> getDashboardCommandCenter() async {
    final summary = await getDashboardSummary();
    final alerts = await Future.wait([
      _getDashboardAlerts('/analytics/low-stock-items'),
      _getDashboardAlerts('/analytics/overstock-items'),
    ]);
    return DashboardCommandCenter(
      summary: summary,
      lowStockItems: alerts[0],
      overstockItems: alerts[1],
    );
  }

  Future<List<AnalyticsAlertItem>> _getDashboardAlerts(String path) async {
    try {
      final response = await _getMap(path);
      return _alerts(response['items']);
    } on AnalyticsApiException {
      return const [];
    } on (FormatException, TypeError) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    final decoded = await _get(path);
    if (decoded is! Map) {
      throw const AnalyticsApiException('Unexpected analytics response.');
    }
    final result = Map<String, dynamic>.from(decoded);
    if (result['error'] case final String error when error.isNotEmpty) {
      throw AnalyticsApiException(error);
    }
    return result;
  }

  Future<List<dynamic>> _getList(String path) async {
    final decoded = await _get(path);
    if (decoded is! List) {
      throw const AnalyticsApiException('Unexpected analytics response.');
    }
    return decoded;
  }

  Future<dynamic> _get(String path) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConstants.baseUrl}$path'))
          .timeout(ApiConstants.requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AnalyticsApiException(
          'Analytics request failed (${response.statusCode}).',
        );
      }
      return jsonDecode(response.body);
    } on AnalyticsApiException {
      rethrow;
    } on TimeoutException {
      throw const AnalyticsApiException('The analytics request timed out.');
    } on http.ClientException {
      throw const AnalyticsApiException(
        'Cannot connect to the analytics service.',
      );
    } on FormatException {
      throw const AnalyticsApiException('Invalid analytics response.');
    }
  }

  static List<AnalyticsBreakdown> _breakdowns(
    dynamic value, {
    required String labelKey,
    String? secondaryKey,
  }) {
    if (value is! List) throw const FormatException('Expected a list.');
    return value
        .map(
          (item) => AnalyticsBreakdown.fromJson(
            Map<String, dynamic>.from(item as Map),
            labelKey: labelKey,
            secondaryKey: secondaryKey,
          ),
        )
        .toList();
  }

  static List<AnalyticsAlertItem> _alerts(dynamic value) {
    if (value is! List) throw const FormatException('Expected alert items.');
    return value
        .map(
          (item) => AnalyticsAlertItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
