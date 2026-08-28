import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../models/inventory/inventory_record.dart';

class InventoryApiException implements Exception {
  const InventoryApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class InventoryApiService {
  InventoryApiService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  /// Loads current inventory for one showroom without deriving intelligence
  /// locally. Forecast-dependent health fields remain backend-owned.
  Future<List<InventoryRecord>> getStoreInventory(String storeId) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConstants.baseUrl}/inventory/store/$storeId'))
          .timeout(ApiConstants.requestTimeout);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const InventoryApiException('Unexpected inventory response.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw InventoryApiException(
          decoded['detail']?.toString() ??
              'Inventory request failed (${response.statusCode}).',
        );
      }
      final records = decoded['inventory'];
      if (records is! List) {
        throw const InventoryApiException('Inventory records are malformed.');
      }
      return records
          .map(
            (item) => InventoryRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on InventoryApiException {
      rethrow;
    } on TimeoutException {
      throw const InventoryApiException('The inventory request timed out.');
    } on http.ClientException {
      throw const InventoryApiException(
        'Cannot connect to the inventory service.',
      );
    } on FormatException {
      throw const InventoryApiException(
        'The inventory service returned malformed data.',
      );
    }
  }
}
