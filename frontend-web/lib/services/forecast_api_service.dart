import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../models/forecast/forecast_catalog_option.dart';
import '../models/forecast/inventory_period_forecast.dart';
import '../models/forecast/short_range_forecast.dart';

class ForecastApiException implements Exception {
  const ForecastApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ForecastApiService {
  ForecastApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // =========================================================
  // SHARED CATALOG CACHE
  // =========================================================
  //
  // Products and stores are master/reference data.
  //
  // ForecastingOverviewScreen may be destroyed and recreated
  // when the manager navigates between application modules.
  //
  // Without this shared cache, each new screen instance calls:
  //
  //   GET /products
  //   GET /stores/
  //
  // again.
  //
  // Keeping the Future static means all ForecastApiService
  // instances inside the same Flutter application session reuse
  // the same catalog request/result.
  //
  // This reduces:
  // - unnecessary HTTP requests
  // - backend processing
  // - possible Firestore reads after backend cache resets
  // - Firebase free-tier usage
  //
  // =========================================================

  static Future<ForecastCatalog>? _catalogFuture;

  /// Returns the product/store catalog.
  ///
  /// Normal calls reuse the existing in-memory catalog Future.
  ///
  /// Use [forceRefresh] only when the manager explicitly retries
  /// after an error or when master catalog data really changed.
  Future<ForecastCatalog> getCatalog({bool forceRefresh = false}) {
    if (forceRefresh || _catalogFuture == null) {
      _catalogFuture = _loadCatalog();
    }

    return _catalogFuture!;
  }

  /// Clears the frontend catalog cache.
  ///
  /// This should not normally be called during navigation.
  /// It can be used later after product/store administration
  /// changes if such a feature is introduced.
  static void clearCatalogCache() {
    _catalogFuture = null;
  }

  /// Performs the real API calls used to build the catalog.
  ///
  /// This method should only run when the catalog cache is empty
  /// or when a deliberate force refresh is requested.
  Future<ForecastCatalog> _loadCatalog() async {
    final responses = await Future.wait([_get('/products'), _get('/stores/')]);

    final productItems = responses[0]['products'];
    final storeItems = responses[1]['stores'];

    if (productItems is! List || storeItems is! List) {
      throw const ForecastApiException(
        'Product or showroom data is malformed.',
      );
    }

    try {
      return ForecastCatalog(
        products: productItems
            .map(
              (item) => ForecastProductOption.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        stores: storeItems
            .map(
              (item) => ForecastStoreOption.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );
    } on FormatException {
      throw const ForecastApiException(
        'Product or showroom data is incomplete.',
      );
    }
  }

  // =========================================================
  // SHORT-RANGE FORECAST
  // =========================================================

  Future<ShortRangeForecast> createShortRangeForecast({
    required bool sevenDay,
    required String storeId,
    required String productId,
    required double priceLkr,
    required double promotionPercent,
  }) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    final response =
        await _post(sevenDay ? '/forecast/7-day' : '/forecast/daily', {
          'store_id': storeId,
          'product_id': productId,
          'price_lkr': priceLkr,
          'promotion_percent': promotionPercent,
          'month': tomorrow.month,
          'day': tomorrow.day,
          'day_of_week_num': tomorrow.weekday - 1,
        });

    try {
      return ShortRangeForecast.fromJson(response);
    } on FormatException {
      throw const ForecastApiException(
        'The forecast response is incomplete or malformed.',
      );
    }
  }

  // =========================================================
  // CUSTOM FORECAST
  // =========================================================

  /// Requests a date-specific forecast within the backend's
  /// 14-day weather window.
  ///
  /// Date validation is duplicated in the UI for fast feedback,
  /// while the backend remains the final authority for the
  /// supported range.
  Future<ShortRangeForecast> createCustomForecast({
    required String storeId,
    required String productId,
    required double priceLkr,
    required double promotionPercent,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _post('/forecast/custom', {
      'store_id': storeId,
      'product_id': productId,
      'price_lkr': priceLkr,
      'promotion_percent': promotionPercent,
      'start_date': _apiDate(startDate),
      'end_date': _apiDate(endDate),
    });

    try {
      return ShortRangeForecast.fromJson(response);
    } on FormatException {
      throw const ForecastApiException(
        'The custom forecast response is incomplete or malformed.',
      );
    }
  }

  // =========================================================
  // MONTHLY / QUARTERLY FORECAST
  // =========================================================

  /// Requests a system-prepared monthly or quarterly inventory
  /// forecast.
  Future<InventoryPeriodForecast> createInventoryPeriodForecast({
    required bool quarterly,
    required String storeId,
    required String category,
    required String brand,
    required String gender,
    required int year,
    required int period,
  }) async {
    final response = await _post(
      quarterly
          ? '/forecast/inventory/quarterly/auto'
          : '/forecast/inventory/monthly/auto',
      {
        'store_id': storeId,
        'category': category,
        'brand': brand,
        'gender': gender,
        'year': year,
        quarterly ? 'quarter' : 'month': period,
      },
    );

    try {
      return InventoryPeriodForecast.fromJson(response);
    } on FormatException {
      throw const ForecastApiException(
        'The inventory forecast response is incomplete or malformed.',
      );
    }
  }

  // =========================================================
  // DATE FORMATTER
  // =========================================================

  String _apiDate(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${value.year}-'
        '${twoDigits(value.month)}-'
        '${twoDigits(value.day)}';
  }

  // =========================================================
  // HTTP GET
  // =========================================================

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConstants.baseUrl}$path'))
          .timeout(ApiConstants.requestTimeout);

      return _decode(response);
    } on ForecastApiException {
      rethrow;
    } on TimeoutException {
      throw const ForecastApiException(
        'The request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const ForecastApiException(
        'Cannot connect to the inventory service.',
      );
    } on FormatException {
      throw const ForecastApiException('The service returned malformed data.');
    }
  }

  // =========================================================
  // HTTP POST
  // =========================================================

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConstants.baseUrl}$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(ApiConstants.requestTimeout);

      return _decode(response);
    } on ForecastApiException {
      rethrow;
    } on TimeoutException {
      throw const ForecastApiException('The forecast request timed out.');
    } on http.ClientException {
      throw const ForecastApiException(
        'Cannot connect to the forecasting service.',
      );
    } on FormatException {
      throw const ForecastApiException('The service returned malformed data.');
    }
  }

  // =========================================================
  // RESPONSE DECODER
  // =========================================================

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic>? decoded;

    try {
      final body = jsonDecode(response.body);

      if (body is Map<String, dynamic>) {
        decoded = body;
      }
    } on FormatException {
      // Some unhandled backend failures return plain text
      // rather than JSON.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded?['detail'];

      throw ForecastApiException(
        detail is String
            ? detail
            : 'The forecasting service failed '
                  '(${response.statusCode}). '
                  'Please try a supported date range.',
      );
    }

    if (decoded == null) {
      throw const ForecastApiException(
        'The service returned an unexpected response.',
      );
    }

    return decoded;
  }
}
