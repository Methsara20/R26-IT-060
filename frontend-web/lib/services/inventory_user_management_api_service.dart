import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/auth/inventory_ui_permissions.dart';
import '../core/auth/inventory_api_client.dart';
import '../core/auth/inventory_session_controller.dart';
import '../core/constants/api_constants.dart';
import '../models/auth/inventory_user.dart';
import 'inventory_auth_api_service.dart';

class InventoryAccountError implements Exception {
  const InventoryAccountError(this.status);
  final int status;
  @override
  String toString() => switch (status) {
    400 => 'Current password could not be verified.',
    401 => 'Your session has ended. Sign in again.',
    403 => 'Inventory access denied.',
    404 => 'Account or service not available.',
    409 =>
      'Account changed or protected Admin operation. Reload before editing.',
    422 => 'Check the fields, store assignments and password requirements.',
    429 => 'Too many attempts. Please wait.',
    _ =>
      'Service unavailable. A change may have an unknown outcome. Reload or sign in again before further action.',
  };
}

String inventoryAccountMessage(Object error) =>
    error is InventoryAccountError || error is InventoryAuthException
    ? error.toString()
    : 'Unable to complete request. Reload before further action.';

class ManagedInventoryUser {
  ManagedInventoryUser.fromJson(Map<String, dynamic> json)
    : user = InventoryUser.fromJson(json),
      revision = json['revision'] as int,
      active = json['is_active'] as bool;
  final InventoryUser user;
  final int revision;
  final bool active;
}

class InventoryUserPage {
  InventoryUserPage(this.users, this.total);
  final List<ManagedInventoryUser> users;
  final int total;
}

/// Shared transport for the two Inventory account services, never logs bodies.
class InventoryAccountTransport {
  InventoryAccountTransport(this.client, this.session);
  final InventoryApiClient client;
  final InventorySessionController session;
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = session.backendUri.replace(path: path, queryParameters: query);
    const headers = {'Content-Type': 'application/json'};
    final response = await (switch (method) {
      'GET' => client.get(uri),
      'PATCH' => client.patch(uri, headers: headers, body: jsonEncode(body)),
      'POST' => client.post(uri, headers: headers, body: jsonEncode(body)),
      _ => throw const InventoryAccountError(403),
    }).timeout(ApiConstants.requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw InventoryAccountError(response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

class InventoryStoreChoice {
  const InventoryStoreChoice(this.id, this.name);
  final String id;
  final String name;
  String get label => '$id - $name';
}

class InventoryUserManagementApiService {
  InventoryUserManagementApiService({
    required InventoryApiClient client,
    required InventorySessionController session,
    http.Client? catalogClient,
  }) : transport = InventoryAccountTransport(client, session),
       _catalogClient = catalogClient;
  final http.Client? _catalogClient;

  Future<List<InventoryStoreChoice>> stores() async {
    final session = transport.session;
    final lease = session.capture();
    if (!InventoryUiPermissions(session.user!).canManageUsers) {
      throw const InventoryAccountError(403);
    }
    // Public read-only catalog: never send Inventory Authorization headers.
    final catalog = _catalogClient ?? http.Client();
    try {
      final request = http.Request(
        'GET',
        session.backendUri.replace(path: '/stores/'),
      )..followRedirects = false;
      final response = await catalog
          .send(request)
          .then(http.Response.fromStream)
          .timeout(ApiConstants.requestTimeout);
      if (!session.isCurrent(lease)) {
        throw const InventoryAuthException(InventoryAuthFailure.staleResponse);
      }
      if (response.statusCode != 200) throw const InventoryAccountError(503);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = data['stores'] as List;
      final ids = <String>{};
      final choices = <InventoryStoreChoice>[];
      for (final row in rows) {
        final id = row['store_id'];
        final name = row['store_name'];
        if (id is! String ||
            !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ||
            name is! String ||
            name.trim().isEmpty ||
            !ids.add(id)) {
          throw const InventoryAccountError(503);
        }
        choices.add(InventoryStoreChoice(id, name));
      }
      return choices;
    } on InventoryAuthException {
      rethrow;
    } on InventoryAccountError {
      rethrow;
    } catch (_) {
      throw const InventoryAccountError(503);
    } finally {
      if (_catalogClient == null) catalog.close();
    }
  }

  final InventoryAccountTransport transport;
  String _path(String id) {
    if (!RegExp(r'^oid:[0-9a-f]{24}$').hasMatch(id)) {
      throw const InventoryAccountError(422);
    }
    return '/inventory-users/$id';
  }

  Future<InventoryUserPage> list({String search = '', int offset = 0}) async {
    final data = await transport.request(
      'GET',
      '/inventory-users',
      query: {'search': search, 'offset': '$offset', 'limit': '20'},
    );
    return InventoryUserPage(
      (data['users'] as List)
          .map((v) => ManagedInventoryUser.fromJson(v as Map<String, dynamic>))
          .toList(),
      data['total'] as int,
    );
  }

  Future<ManagedInventoryUser> save(
    Map<String, dynamic> body, {
    String? id,
  }) async => ManagedInventoryUser.fromJson(
    await transport.request(
      id == null ? 'POST' : 'PATCH',
      id == null ? '/inventory-users' : _path(id),
      body: body,
    ),
  );
  Future<void> status(ManagedInventoryUser account) async {
    await transport.request(
      'PATCH',
      '${_path(account.user.userId)}/status',
      body: {'revision': account.revision, 'is_active': !account.active},
    );
  }

  Future<void> reset(ManagedInventoryUser account, String password) async {
    await transport.request(
      'POST',
      '${_path(account.user.userId)}/reset-password',
      body: {'revision': account.revision, 'password': password},
    );
  }
}
