import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/marketing_auth_service.dart';

class MarketingSessionLease {
  const MarketingSessionLease._(this.generation, this.token);
  final int generation;
  final String token;
}

class MarketingSessionController extends ChangeNotifier {
  MarketingSessionController({
    required MarketingAuthService api,
    DateTime Function()? clock,
  }) : _api = api,
       _clock = clock ?? DateTime.now;

  final MarketingAuthService _api;
  final DateTime Function() _clock;
  String? _token;
  DateTime? _expiresAt;
  Timer? _timer;
  int _generation = 0;
  bool _busy = false;
  MarketingPrincipal? _principal;

  Uri get backendUri => _api.baseUri;
  bool get isBusy => _busy;
  bool get isAuthenticated =>
      _token != null && _expiresAt != null && _clock().isBefore(_expiresAt!);
  MarketingPrincipal? get principal => isAuthenticated ? _principal : null;

  Future<void> login(String username, String password) async {
    if (_busy) throw const MarketingAuthException(MarketingAuthFailure.busy);
    logout(notify: false);
    final generation = _generation;
    final started = _clock();
    _busy = true;
    notifyListeners();
    try {
      final result = await _api.login(username, password);
      if (generation != _generation) {
        throw const MarketingAuthException(MarketingAuthFailure.stale);
      }
      final expiry = started.add(result.expiresIn);
      if (!_clock().isBefore(expiry)) {
        throw const MarketingAuthException(MarketingAuthFailure.invalidSession);
      }
      _token = result.token;
      _expiresAt = expiry;
      _principal = result.principal;
      _scheduleExpiry();
    } finally {
      if (generation == _generation) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  MarketingSessionLease capture() {
    if (!isAuthenticated) {
      logout();
      throw const MarketingAuthException(MarketingAuthFailure.invalidSession);
    }
    return MarketingSessionLease._(_generation, _token!);
  }

  bool isCurrent(MarketingSessionLease lease) =>
      isAuthenticated &&
      lease.generation == _generation &&
      lease.token == _token;

  void invalidate(MarketingSessionLease lease) {
    if (lease.generation == _generation && lease.token == _token) logout();
  }

  void _scheduleExpiry() {
    _timer?.cancel();
    _timer = Timer(_expiresAt!.difference(_clock()), logout);
  }

  void logout({bool notify = true}) {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _token = null;
    _expiresAt = null;
    _principal = null;
    _busy = false;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    logout(notify: false);
    super.dispose();
  }
}
