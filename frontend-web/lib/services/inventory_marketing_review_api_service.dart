import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/auth/inventory_api_client.dart';
import '../core/auth/inventory_session_controller.dart';
import '../models/marketing_review/inventory_campaign_review.dart';

class InventoryMarketingReviewException implements Exception {
  const InventoryMarketingReviewException(this.status);
  final int status;
}

class InventoryMarketingReviewApiService {
  const InventoryMarketingReviewApiService({
    required this.client,
    required this.session,
  });
  final InventoryApiClient client;
  final InventorySessionController session;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = session.backendUri.resolve(path);
    late http.Response response;
    if (method == 'GET') {
      response = await client.get(uri);
    } else {
      response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body == null ? null : jsonEncode(body),
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw InventoryMarketingReviewException(response.statusCode);
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw const InventoryMarketingReviewException(503);
    }
  }

  Future<InventoryCampaignReviewPage> list({
    int skip = 0,
    int limit = 50,
  }) async => InventoryCampaignReviewPage.fromJson(
    await _request(
      'GET',
      '/inventory-marketing/campaign-reviews?skip=$skip&limit=$limit',
    ),
  );
  Future<InventoryCampaignReview> detail(String id) async =>
      InventoryCampaignReview.fromJson(
        await _request(
          'GET',
          '/inventory-marketing/campaign-reviews/${Uri.encodeComponent(id)}',
        ),
      );
  Future<InventoryCampaignReview> accept(
    String id,
  ) async => InventoryCampaignReview.fromJson(
    await _request(
      'POST',
      '/inventory-marketing/campaign-reviews/${Uri.encodeComponent(id)}/accept',
    ),
  );
  Future<InventoryCampaignReview> reject(
    String id,
    String reason,
  ) async => InventoryCampaignReview.fromJson(
    await _request(
      'POST',
      '/inventory-marketing/campaign-reviews/${Uri.encodeComponent(id)}/reject',
      body: {'reason': reason},
    ),
  );
}

String inventoryMarketingReviewMessage(Object error) {
  if (error is InventoryMarketingReviewException) {
    return switch (error.status) {
      401 => 'Your Inventory session has expired. Sign in again.',
      403 => 'You do not have permission for this campaign request.',
      409 =>
        'This request was already decided. Refreshing its current status is recommended.',
      422 => 'The request or rejection reason is invalid.',
      503 =>
        'Marketing request storage or assessment is temporarily unavailable.',
      _ => 'The Marketing request could not be completed.',
    };
  }
  return 'Network connection failed. Try again.';
}
