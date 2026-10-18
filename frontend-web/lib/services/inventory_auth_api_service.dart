import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/auth/inventory_user.dart';

enum InventoryAuthFailure {
  invalidCredentials,
  invalidSession,
  forbidden,
  rateLimited,
  unavailable,
  network,
  invalidRequest,
  busy,
  staleResponse,
  disallowedRequest,
}

/// Never includes response bodies, request data, tokens or transport details.
class InventoryAuthException implements Exception {
  const InventoryAuthException(this.failure, {this.retryAfter});
  final InventoryAuthFailure failure;
  final Duration? retryAfter;
  @override
  String toString() => switch (failure) {
    InventoryAuthFailure.invalidCredentials => 'Invalid username or password.',
    InventoryAuthFailure.invalidSession =>
      'Your Inventory session has ended. Sign in again.',
    InventoryAuthFailure.forbidden => 'Inventory access denied.',
    InventoryAuthFailure.rateLimited =>
      'Too many attempts. Please wait before trying again.',
    InventoryAuthFailure.unavailable =>
      'Inventory authentication is unavailable.',
    InventoryAuthFailure.network => 'Unable to connect to Inventory.',
    InventoryAuthFailure.invalidRequest => 'Check the authentication fields.',
    InventoryAuthFailure.busy =>
      'An authentication request is already in progress.',
    InventoryAuthFailure.staleResponse =>
      'The previous Inventory session has ended.',
    InventoryAuthFailure.disallowedRequest =>
      'This request is outside Inventory authentication scope.',
  };
}

/// Transient login result; never persist or include in diagnostic output.
class InventoryLoginResult {
  const InventoryLoginResult(this.accessToken, this.expiresIn, this.user);
  final String accessToken;
  final Duration expiresIn;
  final InventoryUser user;
}

class InventoryAuthApiService {
  InventoryAuthApiService({
    http.Client? client,
    String baseUrl = ApiConstants.baseUrl,
    this.timeout = ApiConstants.requestTimeout,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       baseUri = _backendUri(baseUrl);
  final http.Client _client;
  final bool _ownsClient;
  final Uri baseUri;
  final Duration timeout;

  static Uri _backendUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const InventoryAuthException(
        InventoryAuthFailure.disallowedRequest,
      );
    }
    return uri;
  }

  Future<InventoryLoginResult> login(String username, String password) async {
    // Backend owns username normalization, including Unicode casefold.
    final body = await _request(
      '/inventory-auth/login',
      password: password,
      username: username,
    );
    try {
      final token = body['access_token'];
      final expires = body['expires_in'];
      if (token is! String ||
          !validTokenSyntax(token) ||
          body['token_type'] != 'bearer' ||
          expires is! int ||
          expires <= 0 ||
          expires > 900 ||
          body['user'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return InventoryLoginResult(
        token,
        Duration(seconds: expires),
        InventoryUser.fromJson(body['user'] as Map<String, dynamic>),
      );
    } catch (_) {
      throw const InventoryAuthException(InventoryAuthFailure.unavailable);
    }
  }

  Future<InventoryUser> me(String token) async {
    if (!validTokenSyntax(token)) {
      throw const InventoryAuthException(InventoryAuthFailure.invalidSession);
    }
    final body = await _request('/inventory-auth/me', token: token);
    try {
      return InventoryUser.fromJson(body);
    } catch (_) {
      throw const InventoryAuthException(InventoryAuthFailure.invalidSession);
    }
  }

  static bool validTokenSyntax(String token) =>
      token.codeUnits.every((code) => code > 32 && code < 127) &&
      RegExp(
        r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
      ).hasMatch(token);

  Future<Map<String, dynamic>> _request(
    String path, {
    String? username,
    String? password,
    String? token,
  }) async {
    final login = token == null;
    final request = http.Request(login ? 'POST' : 'GET', baseUri.resolve(path))
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    if (login) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'username': username, 'password': password});
    } else {
      request.headers['Authorization'] = 'Bearer $token';
    }
    try {
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
      if (response.statusCode != 200) {
        final status = response.statusCode;
        if (status == 401) {
          throw InventoryAuthException(
            login
                ? InventoryAuthFailure.invalidCredentials
                : InventoryAuthFailure.invalidSession,
          );
        }
        if (status == 403) {
          throw const InventoryAuthException(InventoryAuthFailure.forbidden);
        }
        if (status == 429) {
          final seconds = int.tryParse(response.headers['retry-after'] ?? '');
          throw InventoryAuthException(
            InventoryAuthFailure.rateLimited,
            retryAfter: seconds != null && seconds >= 0
                ? Duration(seconds: seconds)
                : null,
          );
        }
        if (status == 422) {
          throw const InventoryAuthException(
            InventoryAuthFailure.invalidRequest,
          );
        }
        throw const InventoryAuthException(InventoryAuthFailure.unavailable);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } on InventoryAuthException {
      rethrow;
    } on TimeoutException {
      throw const InventoryAuthException(InventoryAuthFailure.network);
    } on http.ClientException {
      throw const InventoryAuthException(InventoryAuthFailure.network);
    } catch (_) {
      throw const InventoryAuthException(InventoryAuthFailure.unavailable);
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
