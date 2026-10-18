import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../core/auth/marketing_session_controller.dart';
import '../models/inventory_analysis_request.dart';

enum InventoryAnalysisFailure {
  invalidSession,
  forbidden,
  invalidRequest,
  conflict,
  unavailable,
  network,
  stale,
}

class InventoryAnalysisException implements Exception {
  const InventoryAnalysisException(
    this.failure, {
    this.validationField,
    this.validationReason,
  });
  final InventoryAnalysisFailure failure;
  final String? validationField;
  final String? validationReason;
  @override
  String toString() {
    if (failure == InventoryAnalysisFailure.invalidRequest &&
        validationField == 'discount_percent' &&
        validationReason == 'PROMOTION_TYPE_REQUIRED') {
      return 'Select a promotion type when entering a discount.';
    }
    return switch (failure) {
      InventoryAnalysisFailure.invalidSession =>
        'Your Marketing session has ended. Sign in again.',
      InventoryAnalysisFailure.forbidden =>
        'You are not authorized for this showroom.',
      InventoryAnalysisFailure.invalidRequest =>
        'Check the campaign details and try again.',
      InventoryAnalysisFailure.conflict =>
        'This campaign reference conflicts with an existing request.',
      InventoryAnalysisFailure.network =>
        'Unable to reach Inventory. The submission outcome may be unknown.',
      InventoryAnalysisFailure.stale =>
        'This response belongs to an earlier session.',
      InventoryAnalysisFailure.unavailable =>
        'Inventory planning is temporarily unavailable.',
    };
  }
}

class InventoryAnalysisService {
  InventoryAnalysisService({
    required this.session,
    http.Client? client,
    String baseUrl = ApiConstants.baseUrl,
    this.timeout = ApiConstants.requestTimeout,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _base = Uri.parse(baseUrl);
  final MarketingSessionController session;
  final http.Client _client;
  final bool _ownsClient;
  final Uri _base;
  final Duration timeout;

  Future<InventoryAnalysisRequest> submit({
    required String campaignReference,
    required String campaignName,
    required String productId,
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
    String? promotionType,
    double? discountPercent,
  }) => _request(
    'POST',
    '/marketing-inventory/campaign-analysis',
    body: {
      'campaign_reference': campaignReference,
      'campaign_name': campaignName,
      'product_id': productId,
      'store_id': storeId,
      'campaign_start_date': _date(startDate),
      'campaign_end_date': _date(endDate),
      if (promotionType != null && promotionType.isNotEmpty)
        'promotion_type': promotionType,
      'discount_percent': ?discountPercent,
    },
  );

  Future<InventoryAnalysisRequest> status(String requestId) => _request(
    'GET',
    '/marketing-inventory/campaign-analysis/${Uri.encodeComponent(requestId)}',
  );

  Future<InventoryAnalysisHistory> history({
    int skip = 0,
    int limit = 20,
  }) async {
    if (skip < 0 || limit < 1 || limit > 100) {
      throw const InventoryAnalysisException(
        InventoryAnalysisFailure.invalidRequest,
      );
    }
    final body = await _requestJson(
      'GET',
      '/marketing-inventory/campaign-analysis?skip=$skip&limit=$limit',
    );
    try {
      return InventoryAnalysisHistory.fromJson(body);
    } catch (_) {
      throw const InventoryAnalysisException(
        InventoryAnalysisFailure.unavailable,
      );
    }
  }

  Future<InventoryAnalysisRequest> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final decoded = await _requestJson(method, path, body: body);
    try {
      return InventoryAnalysisRequest.fromJson(decoded);
    } catch (_) {
      throw const InventoryAnalysisException(
        InventoryAnalysisFailure.unavailable,
      );
    }
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final lease = session.capture();
    final uri = _base.resolve(path);
    if (uri.origin != _base.origin ||
        !(path == '/marketing-inventory/campaign-analysis' ||
            (method == 'GET' &&
                (path.startsWith('/marketing-inventory/campaign-analysis/') ||
                    path.startsWith(
                      '/marketing-inventory/campaign-analysis?',
                    ))))) {
      throw const InventoryAnalysisException(
        InventoryAnalysisFailure.unavailable,
      );
    }
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer ${lease.token}',
      });
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await http.Response.fromStream(
        await _client.send(request),
      ).timeout(timeout);
      if (!session.isCurrent(lease)) {
        throw const InventoryAnalysisException(InventoryAnalysisFailure.stale);
      }
      if (response.statusCode != 200) {
        if (response.statusCode == 401) {
          session.invalidate(lease);
          throw const InventoryAnalysisException(
            InventoryAnalysisFailure.invalidSession,
          );
        }
        if (response.statusCode == 422) {
          final validation = _safeValidation(response.body);
          throw InventoryAnalysisException(
            InventoryAnalysisFailure.invalidRequest,
            validationField: validation?.$1,
            validationReason: validation?.$2,
          );
        }
        throw InventoryAnalysisException(
          response.statusCode == 403
              ? InventoryAnalysisFailure.forbidden
              : response.statusCode == 409
              ? InventoryAnalysisFailure.conflict
              : InventoryAnalysisFailure.unavailable,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } on InventoryAnalysisException {
      rethrow;
    } on TimeoutException {
      throw const InventoryAnalysisException(InventoryAnalysisFailure.network);
    } on http.ClientException {
      throw const InventoryAnalysisException(InventoryAnalysisFailure.network);
    } catch (_) {
      throw const InventoryAnalysisException(
        InventoryAnalysisFailure.unavailable,
      );
    }
  }

  Future<
    ({
      List<MarketingCatalogChoice> products,
      List<MarketingCatalogChoice> stores,
    })
  >
  loadCatalog() async {
    Future<Map<String, dynamic>> get(String path) async {
      final response = await _client.get(_base.resolve(path)).timeout(timeout);
      if (response.statusCode != 200) {
        throw const InventoryAnalysisException(
          InventoryAnalysisFailure.unavailable,
        );
      }
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const FormatException();
      return value;
    }

    try {
      final values = await Future.wait([
        get('/products?all_products=true'),
        get('/stores/'),
      ]);
      final products = values[0]['products'] as List;
      final stores = values[1]['stores'] as List;
      return (
        products: products.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return MarketingCatalogChoice(
            (m['product_id'] ?? m['id']).toString(),
            (m['product_name'] ?? m['name'] ?? m['product_id']).toString(),
          );
        }).toList(),
        stores: stores.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return MarketingCatalogChoice(
            (m['store_id'] ?? m['id']).toString(),
            (m['store_name'] ?? m['name'] ?? m['store_id']).toString(),
          );
        }).toList(),
      );
    } catch (e) {
      if (e is InventoryAnalysisException) rethrow;
      throw const InventoryAnalysisException(
        InventoryAnalysisFailure.unavailable,
      );
    }
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static (String, String)? _safeValidation(String body) {
    try {
      final decoded = jsonDecode(body);
      final detail = decoded is Map ? decoded['detail'] : null;
      final errors = detail is Map ? detail['errors'] : null;
      if (errors is! List || errors.isEmpty || errors.first is! Map) {
        return null;
      }
      final error = errors.first as Map;
      final field = error['field'];
      final reason = error['reason'];
      const fields = {
        'campaign_reference',
        'campaign_name',
        'product_id',
        'store_id',
        'campaign_start_date',
        'campaign_end_date',
        'promotion_type',
        'discount_percent',
        'request',
      };
      const reasons = {'PROMOTION_TYPE_REQUIRED', 'REQUIRED', 'INVALID'};
      return field is String &&
              reason is String &&
              fields.contains(field) &&
              reasons.contains(reason)
          ? (field, reason)
          : null;
    } catch (_) {
      return null;
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
