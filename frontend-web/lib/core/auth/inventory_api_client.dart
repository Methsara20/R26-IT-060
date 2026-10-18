import 'package:http/http.dart' as http;
import '../../services/inventory_auth_api_service.dart';
import 'inventory_session_controller.dart';

/// Only currently protected Inventory routes are admitted. Shared catalogs,
/// customer/profile routes, Marketing routes and legacy public APIs are denied.
/// Expand this list only after separate ownership/authorization review.
class InventoryApiClient extends http.BaseClient {
  InventoryApiClient({
    required InventorySessionController session,
    http.Client? client,
  }) : _session = session,
       _inner = client ?? http.Client(),
       _ownsClient = client == null;
  final InventorySessionController _session;
  final http.Client _inner;
  final bool _ownsClient;
  bool _closed = false;

  static bool _allowed(String method, String path) {
    final id = r'[A-Za-z0-9_-]+';
    final account = r'oid:[0-9a-f]{24}';
    if (method == 'PATCH') {
      return path == '/inventory-auth/me' ||
          RegExp(
            '^/inventory-users/$account(?:/status)?'
            r'$',
          ).hasMatch(path);
    }
    if (method == 'GET' &&
        (path == '/inventory-users' ||
            RegExp(
              '^/inventory-users/$account'
              r'$',
            ).hasMatch(path))) {
      return true;
    }
    if (method == 'POST' &&
        (path == '/inventory-users' ||
            path == '/inventory-auth/change-password' ||
            RegExp(
              '^/inventory-users/$account/reset-password'
              r'$',
            ).hasMatch(path))) {
      return true;
    }

    if (method == 'GET') {
      return path == '/inventory-auth/me' ||
          path == '/inventory-marketing/campaign-reviews' ||
          RegExp(
            '^/inventory-marketing/campaign-reviews/$id'
            r'$',
          ).hasMatch(path) ||
          RegExp(
            '^/decision-workflow/(?:$id)?'
            r'$',
          ).hasMatch(path) ||
          RegExp(
            '^/optimization-candidates/(?:summary|$id|(?:store|priority|type)/$id)?'
            r'$',
          ).hasMatch(path) ||
          RegExp(
            '^/stock-movement/(?:$id|explain-context/$id)?'
            r'$',
          ).hasMatch(path);
    }
    if (method != 'POST') return false;
    return const {
          '/forecast/daily',
          '/forecast/7-day',
          '/forecast/custom',
          '/forecast/inventory/monthly',
          '/forecast/inventory/quarterly',
          '/forecast/inventory/monthly/auto',
          '/forecast/inventory/quarterly/auto',
          '/intelligence/analyze',
          '/recommendations/generate',
          '/decision-workflow/analyze',
          '/inventory-marketing/forecast-shares',
          '/marketing-opportunities/',
        }.contains(path) ||
        RegExp(
          '^/inventory-marketing/campaign-reviews/$id/(?:accept|reject)'
          r'$',
        ).hasMatch(path) ||
        RegExp(
          '^/decision-engine/analyze/$id'
          r'$',
        ).hasMatch(path) ||
        RegExp(
          '^/stock-movement/(?:recommend-transfer|approve|reject|cancel|execute|explain|execution-summary)/$id'
          r'$',
        ).hasMatch(path);
  }

  bool _approved(http.BaseRequest request) {
    final url = request.url;
    final backend = _session.backendUri;
    return !_closed &&
        url.scheme == backend.scheme &&
        url.host == backend.host &&
        url.port == backend.port &&
        url.userInfo.isEmpty &&
        !url.hasFragment &&
        !url.path.contains('%') &&
        !url.path.contains('\\') &&
        _allowed(request.method, url.path) &&
        !request.headers.keys.any(
          (key) =>
              key.toLowerCase() == 'authorization' ||
              key.toLowerCase() == 'cookie',
        );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_approved(request)) {
      throw const InventoryAuthException(
        InventoryAuthFailure.disallowedRequest,
      );
    }
    final lease = _session.capture();
    final token = lease.token;
    request.headers['Authorization'] = 'Bearer $token';
    request.followRedirects = false;
    http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } catch (_) {
      throw const InventoryAuthException(InventoryAuthFailure.network);
    }
    if (!_session.isCurrent(lease)) {
      await response.stream.listen(null).cancel();
      throw const InventoryAuthException(InventoryAuthFailure.staleResponse);
    }
    final invalidated =
        response.statusCode == 401 ||
        (response.statusCode == 403 &&
            request.url.path == '/inventory-auth/me');
    if (invalidated) _session.invalidate(lease);
    // Preserve status, headers and bytes, including ordinary 403/429 responses.
    // Existing callers can interpret their response contracts. No replay occurs.
    return http.StreamedResponse(
      _body(response.stream, lease, checkSession: !invalidated),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  Stream<List<int>> _body(
    Stream<List<int>> stream,
    InventorySessionLease lease, {
    required bool checkSession,
  }) async* {
    try {
      await for (final bytes in stream) {
        if (checkSession && !_session.isCurrent(lease)) {
          throw const InventoryAuthException(
            InventoryAuthFailure.staleResponse,
          );
        }
        yield bytes;
      }
      if (checkSession && !_session.isCurrent(lease)) {
        throw const InventoryAuthException(InventoryAuthFailure.staleResponse);
      }
    } on InventoryAuthException {
      rethrow;
    } catch (_) {
      throw const InventoryAuthException(InventoryAuthFailure.network);
    }
  }

  @override
  void close() {
    _closed = true;
    if (_ownsClient) _inner.close();
    super.close();
  }
}
