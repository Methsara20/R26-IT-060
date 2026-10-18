import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/auth/inventory_user.dart';
import '../../services/inventory_auth_api_service.dart';

/// Short-lived transport snapshot. Never serialize or log this object.
class InventorySessionLease {
  const InventorySessionLease._(this.generation, this.token);
  final int generation;
  final String token;
}

/// Per-application memory only. A new controller always starts signed out.
/// No persistence, automatic refresh, singleton, or cross-component identity.
class InventorySessionController extends ChangeNotifier {
  InventorySessionController({
    required InventoryAuthApiService api,
    DateTime Function()? clock,
  }) : _api = api,
       _clock = clock ?? DateTime.now;
  final InventoryAuthApiService _api;
  final DateTime Function() _clock;
  String? _token;
  InventoryUser? _user;
  DateTime? _expiresAt;
  Timer? _expiryTimer;
  int _generation = 0;
  bool _disposed = false;
  bool _loggingIn = false;
  Future<void>? _validation;

  Uri get backendUri => _api.baseUri;
  bool get isLoggingIn => _loggingIn;
  bool get isValidating => _validation != null;
  bool get isAuthenticated =>
      !_disposed &&
      _token != null &&
      _expiresAt != null &&
      _clock().isBefore(_expiresAt!);
  InventoryUser? get user => isAuthenticated ? _user : null;
  DateTime? get expiresAt => isAuthenticated ? _expiresAt : null;

  Future<void> login(String username, String password) async {
    if (_disposed) {
      throw const InventoryAuthException(InventoryAuthFailure.invalidSession);
    }
    if (_loggingIn) {
      throw const InventoryAuthException(InventoryAuthFailure.busy);
    }
    _clear();
    final generation = _generation;
    final started = _clock();
    _loggingIn = true;
    notifyListeners();
    try {
      final result = await _api.login(username, password);
      if (_disposed || generation != _generation) {
        throw const InventoryAuthException(InventoryAuthFailure.staleResponse);
      }
      // Count from dispatch to conservatively account for transit time.
      final expiry = started.add(result.expiresIn);
      if (!_clock().isBefore(expiry)) {
        throw const InventoryAuthException(InventoryAuthFailure.invalidSession);
      }
      _token = result.accessToken;
      _user = result.user;
      _expiresAt = expiry;
      _scheduleExpiry();
    } on InventoryAuthException {
      if (_disposed || generation != _generation) {
        throw const InventoryAuthException(InventoryAuthFailure.staleResponse);
      }
      rethrow;
    } finally {
      if (!_disposed && generation == _generation) {
        _loggingIn = false;
        notifyListeners();
      }
    }
  }

  InventorySessionLease capture() {
    if (!isAuthenticated) {
      if (!_disposed && _token != null) logout();
      throw const InventoryAuthException(InventoryAuthFailure.invalidSession);
    }
    return InventorySessionLease._(_generation, _token!);
  }

  bool isCurrent(InventorySessionLease lease) =>
      isAuthenticated &&
      lease.generation == _generation &&
      lease.token == _token;

  void invalidate(InventorySessionLease lease) {
    if (!_disposed &&
        lease.generation == _generation &&
        lease.token == _token) {
      logout();
    }
  }

  Future<void> validate() {
    if (_validation != null) return _validation!;
    final lease = capture();
    final pending = _validate(lease);
    _validation = pending;
    notifyListeners();
    return pending;
  }

  Future<void> _validate(InventorySessionLease lease) async {
    try {
      final principal = await _api.me(lease.token);
      if (!isCurrent(lease)) {
        throw const InventoryAuthException(InventoryAuthFailure.staleResponse);
      }
      if (principal.userId != _user!.userId) {
        throw const InventoryAuthException(InventoryAuthFailure.invalidSession);
      }
      _user = principal;
      // Revoke older in-flight leases when current permissions are accepted.
      _generation++;
      _validation = null;
      notifyListeners();
    } on InventoryAuthException catch (error) {
      if (!_disposed && lease.generation == _generation) {
        if (error.failure == InventoryAuthFailure.invalidSession ||
            error.failure == InventoryAuthFailure.forbidden) {
          invalidate(lease);
        }
        rethrow;
      }
      throw const InventoryAuthException(InventoryAuthFailure.staleResponse);
    } finally {
      if (!_disposed && lease.generation == _generation) {
        _validation = null;
        notifyListeners();
      }
    }
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final remaining = _expiresAt!.difference(_clock());
    _expiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (_disposed || _expiresAt == null) return;
      if (!_clock().isBefore(_expiresAt!)) {
        logout();
      } else {
        _scheduleExpiry();
      }
    });
  }

  void _clear() {
    _generation++;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _token = null;
    _user = null;
    _expiresAt = null;
    _validation = null;
    _loggingIn = false;
  }

  void logout() {
    if (_disposed) return;
    _clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _clear();
    _disposed = true;
    super.dispose();
  }
}
