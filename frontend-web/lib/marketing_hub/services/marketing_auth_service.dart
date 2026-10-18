import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

enum MarketingAuthFailure {
  invalidCredentials,
  invalidSession,
  forbidden,
  invalidRequest,
  unavailable,
  network,
  busy,
  stale,
}

class MarketingAuthException implements Exception {
  const MarketingAuthException(this.failure);
  final MarketingAuthFailure failure;
  @override
  String toString() => switch (failure) {
    MarketingAuthFailure.invalidCredentials => 'Invalid username or password.',
    MarketingAuthFailure.invalidSession =>
      'Your Marketing session has ended. Sign in again.',
    MarketingAuthFailure.forbidden => 'Marketing access denied.',
    MarketingAuthFailure.invalidRequest => 'Check the submitted fields.',
    MarketingAuthFailure.network =>
      'Unable to connect to the Marketing service.',
    MarketingAuthFailure.busy => 'A sign-in request is already in progress.',
    MarketingAuthFailure.stale => 'The previous Marketing session has ended.',
    MarketingAuthFailure.unavailable =>
      'Marketing authentication is unavailable.',
  };
}

class MarketingPrincipal {
  const MarketingPrincipal({
    required this.username,
    required this.storeIds,
    required this.globalAccess,
  });
  final String username;
  final List<String> storeIds;
  final bool globalAccess;
}

class MarketingLoginResult {
  const MarketingLoginResult(this.token, this.expiresIn, this.principal);
  final String token;
  final Duration expiresIn;
  final MarketingPrincipal principal;
}

class MarketingAuthService {
  MarketingAuthService({
    http.Client? client,
    String baseUrl = ApiConstants.baseUrl,
    this.timeout = ApiConstants.requestTimeout,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       baseUri = _validBase(baseUrl);
  final http.Client _client;
  final bool _ownsClient;
  final Uri baseUri;
  final Duration timeout;

  static Uri _validBase(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const MarketingAuthException(MarketingAuthFailure.unavailable);
    }
    return uri;
  }

  Future<MarketingLoginResult> login(String username, String password) async {
    final request =
        http.Request('POST', baseUri.resolve('/marketing-inventory/login'))
          ..followRedirects = false
          ..headers.addAll({
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode({'username': username, 'password': password});
    try {
      final response = await http.Response.fromStream(
        await _client.send(request),
      ).timeout(timeout);
      if (response.statusCode != 200) {
        throw MarketingAuthException(switch (response.statusCode) {
          401 => MarketingAuthFailure.invalidCredentials,
          403 => MarketingAuthFailure.forbidden,
          422 => MarketingAuthFailure.invalidRequest,
          _ => MarketingAuthFailure.unavailable,
        });
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) throw const FormatException();
      final token = json['access_token'];
      final expires = json['expires_in'];
      final stores = json['store_ids'];
      if (token is! String ||
          !RegExp(
            r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
          ).hasMatch(token) ||
          expires is! int ||
          expires <= 0 ||
          expires > 3600 ||
          json['token_type'] != 'bearer' ||
          json['username'] is! String ||
          stores is! List ||
          json['global_access'] is! bool) {
        throw const FormatException();
      }
      return MarketingLoginResult(
        token,
        Duration(seconds: expires),
        MarketingPrincipal(
          username: json['username'] as String,
          storeIds: stores.map((e) => e.toString()).toList(growable: false),
          globalAccess: json['global_access'] as bool,
        ),
      );
    } on MarketingAuthException {
      rethrow;
    } on TimeoutException {
      throw const MarketingAuthException(MarketingAuthFailure.network);
    } on http.ClientException {
      throw const MarketingAuthException(MarketingAuthFailure.network);
    } catch (_) {
      throw const MarketingAuthException(MarketingAuthFailure.unavailable);
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
