import 'dart:async';
import 'dart:convert';
import '../core/auth/inventory_api_client.dart';
import '../core/constants/api_constants.dart';
import 'inventory_auth_api_service.dart';

class ForecastSharingException implements Exception {
  const ForecastSharingException(this.message);
  final String message;
  @override
  String toString() => message;
}

class InventoryForecastSharingApiService {
  InventoryForecastSharingApiService({required InventoryApiClient client})
    : _client = client;
  final InventoryApiClient _client;
  Future<void> share(String workflowId, {required bool confirmed}) async {
    if (!confirmed ||
        workflowId.isEmpty ||
        workflowId != workflowId.trim() ||
        workflowId.length > 128 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(workflowId)) {
      throw const ForecastSharingException(
        'A valid stored workflow and explicit confirmation are required.',
      );
    }
    try {
      final response = await _client
          .post(
            Uri.parse(
              '${ApiConstants.baseUrl}/inventory-marketing/forecast-shares',
            ),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'workflow_id': workflowId, 'confirmed': true}),
          )
          .timeout(ApiConstants.requestTimeout);
      if (response.statusCode == 401) {
        throw const ForecastSharingException(
          'Your Inventory session has ended. Sign in again.',
        );
      }
      if (response.statusCode == 403) {
        throw const ForecastSharingException(
          'You do not have permission to share this workflow or its showrooms.',
        );
      }
      if (response.statusCode == 404 || response.statusCode == 422) {
        throw const ForecastSharingException(
          'An eligible stored workflow was not found. Generate a completed operational forecast.',
        );
      }
      if (response.statusCode == 409) {
        throw const ForecastSharingException(
          'The workflow has changed or sharing is in progress. Sharing was not confirmed.',
        );
      }
      if (response.statusCode >= 500) {
        throw const ForecastSharingException(
          'The sharing service or storage is unavailable. The share outcome is not confirmed.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ForecastSharingException(
          'Unable to confirm sharing. Please try again later.',
        );
      }
      final result = jsonDecode(response.body);
      if (result is! Map ||
          result['workflow_id'] != workflowId ||
          result['share_status'] != 'SHARED' ||
          result['share_id'] is! String ||
          (result['share_id'] as String).isEmpty) {
        throw const FormatException();
      }
    } on InventoryAuthException catch (error) {
      throw ForecastSharingException(
        error.failure == InventoryAuthFailure.network
            ? 'Unable to connect. The share outcome is not confirmed; no automatic retry was sent.'
            : error.toString(),
      );
    } on TimeoutException {
      throw const ForecastSharingException(
        'Sharing timed out. The outcome is not confirmed; no automatic retry was sent.',
      );
    } on FormatException {
      throw const ForecastSharingException(
        'The sharing response could not be verified.',
      );
    }
  }
}
