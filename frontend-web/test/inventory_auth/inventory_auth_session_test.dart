import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/core/auth/inventory_session_controller.dart';
import 'package:smart_inventory_web/services/inventory_auth_api_service.dart';
import 'auth_test_support.dart';

void main() {
  test('login preserves password whitespace and immutable principal', () async {
    final session = sessionWith((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/inventory-auth/login');
      expect(jsonDecode(request.body), {
        'username': ' FixtureUser ',
        'password': fakePassword,
      });
      expect(request.headers['Authorization'], isNull);
      expect(request.followRedirects, isFalse);
      return loginResponse();
    });
    await session.login(' FixtureUser ', fakePassword);
    expect(session.isAuthenticated, isTrue);
    expect(session.user!.username, 'fixtureuser');
    expect(session.capture().token, fakeToken);
    expect(() => session.user!.storeIds.add('S3'), throwsUnsupportedError);
  });

  for (final entry in {
    401: InventoryAuthFailure.invalidCredentials,
    403: InventoryAuthFailure.forbidden,
    422: InventoryAuthFailure.invalidRequest,
    429: InventoryAuthFailure.rateLimited,
    500: InventoryAuthFailure.unavailable,
    503: InventoryAuthFailure.unavailable,
    302: InventoryAuthFailure.unavailable,
  }.entries) {
    test('login status ${entry.key} is sanitized', () async {
      final session = sessionWith(
        (_) async => http.Response(
          'private password token hash internal traceback',
          entry.key,
          headers: {'retry-after': '60'},
        ),
      );
      try {
        await session.login('fixtureuser', fakePassword);
        fail('Expected safe failure');
      } on InventoryAuthException catch (error) {
        expect(error.failure, entry.value);
        expect(error.toString(), isNot(contains('traceback')));
        expect(error.toString(), isNot(contains(fakePassword)));
        if (entry.key == 429) {
          expect(error.retryAfter, const Duration(seconds: 60));
        }
      }
      expect(session.isAuthenticated, isFalse);
      expect(session.isLoggingIn, isFalse);
    });
  }

  test('transport failure hides internal details', () async {
    final session = sessionWith(
      (_) async => throw http.ClientException('private credentials'),
    );
    await expectLater(
      session.login('fixtureuser', fakePassword),
      throwsA(failsWith(InventoryAuthFailure.network)),
    );
  });

  test('login timeout is sanitized without replay', () async {
    var calls = 0;
    final client = MockClient((_) {
      calls++;
      return Completer<http.Response>().future;
    });
    final api = InventoryAuthApiService(
      client: client,
      timeout: const Duration(milliseconds: 1),
    );
    addTearDown(client.close);
    await expectLater(
      api.login('fixtureuser', fakePassword),
      throwsA(failsWith(InventoryAuthFailure.network)),
    );
    expect(calls, 1);
  });

  test('new controller never restores another controller session', () async {
    final first = sessionWith((_) async => loginResponse());
    final second = sessionWith((_) async => loginResponse());
    await first.login('fixtureuser', fakePassword);
    expect(second.isAuthenticated, isFalse);
    expect(second.user, isNull);
    expect(
      () => second.capture(),
      throwsA(failsWith(InventoryAuthFailure.invalidSession)),
    );
  });

  test('logout clears credentials, principal and expiry', () async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    final lease = session.capture();
    session.logout();
    expect(session.user, isNull);
    expect(session.expiresAt, isNull);
    expect(session.isCurrent(lease), isFalse);
    expect(
      () => session.capture(),
      throwsA(failsWith(InventoryAuthFailure.invalidSession)),
    );
  });

  test('expiry enforced without foreground timer', () async {
    var now = DateTime.utc(2026);
    final session = sessionWith(
      (_) async => loginResponse(expires: 2),
      clock: () => now,
    );
    await session.login('fixtureuser', fakePassword);
    now = now.add(const Duration(seconds: 2));
    expect(session.isAuthenticated, isFalse);
    expect(
      () => session.capture(),
      throwsA(failsWith(InventoryAuthFailure.invalidSession)),
    );
    expect(session.user, isNull);
  });

  testWidgets('expiry timer notifies and clears session', (tester) async {
    var now = DateTime.utc(2026);
    final session = sessionWith(
      (_) async => loginResponse(expires: 2),
      clock: () => now,
    );
    await session.login('fixtureuser', fakePassword);
    var notifications = 0;
    session.addListener(() => notifications++);
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(notifications, greaterThan(0));
    expect(session.user, isNull);
  });

  test('duplicate login rejected before HTTP', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final session = sessionWith((_) {
      calls++;
      return pending.future;
    });
    final first = session.login('fixtureuser', fakePassword);
    await expectLater(
      session.login('fixtureuser', fakePassword),
      throwsA(failsWith(InventoryAuthFailure.busy)),
    );
    pending.complete(loginResponse());
    await first;
    expect(calls, 1);
  });

  test('late login cannot restore a logged-out session', () async {
    final pending = Completer<http.Response>();
    final session = sessionWith((_) => pending.future);
    final first = session.login('fixtureuser', fakePassword);
    final check = expectLater(
      first,
      throwsA(failsWith(InventoryAuthFailure.staleResponse)),
    );
    session.logout();
    pending.complete(loginResponse());
    await check;
    expect(session.isAuthenticated, isFalse);
  });

  test('older login cannot replace a newer session', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final session = sessionWith(
      (_) => ++calls == 1
          ? pending.future
          : Future.value(loginResponse(token: 'new.payload.signature')),
    );
    final old = session.login('fixtureuser', fakePassword);
    final check = expectLater(
      old,
      throwsA(failsWith(InventoryAuthFailure.staleResponse)),
    );
    // Let the first fake transport enter its handler before starting another.
    await Future<void>.delayed(Duration.zero);
    session.logout();
    await session.login('fixtureuser', fakePassword);
    pending.complete(loginResponse());
    await check;
    expect(session.capture().token, 'new.payload.signature');
  });

  test('/me reloads permissions, coalesces and preserves expiry', () async {
    final pending = Completer<http.Response>();
    var meCalls = 0;
    final session = sessionWith((request) {
      if (request.url.path.endsWith('/login')) {
        return Future.value(loginResponse());
      }
      meCalls++;
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer $fakeToken');
      expect(request.followRedirects, isFalse);
      return pending.future;
    });
    await session.login('fixtureuser', fakePassword);
    final expiry = session.expiresAt;
    final oldLease = session.capture();
    final first = session.validate();
    final second = session.validate();
    pending.complete(
      http.Response(jsonEncode(userJson(role: 'viewer', stores: ['S2'])), 200),
    );
    await Future.wait([first, second]);
    expect(meCalls, 1);
    expect(session.user!.role.name, 'viewer');
    expect(session.user!.storeIds, ['S2']);
    expect(session.expiresAt, expiry);
    expect(session.isCurrent(oldLease), isFalse);
    expect(session.isValidating, isFalse);
  });

  for (final status in [401, 403]) {
    test('/me $status invalidates principal', () async {
      final session = sessionWith(
        (r) async => r.method == 'POST'
            ? loginResponse()
            : http.Response('private', status),
      );
      await session.login('fixtureuser', fakePassword);
      await expectLater(
        session.validate(),
        throwsA(isA<InventoryAuthException>()),
      );
      expect(session.isAuthenticated, isFalse);
    });
  }

  test('/me unavailable retains session without extending expiry', () async {
    final session = sessionWith(
      (r) async =>
          r.method == 'POST' ? loginResponse() : http.Response('private', 503),
    );
    await session.login('fixtureuser', fakePassword);
    final expiry = session.expiresAt;
    await expectLater(
      session.validate(),
      throwsA(failsWith(InventoryAuthFailure.unavailable)),
    );
    expect(session.isAuthenticated, isTrue);
    expect(session.expiresAt, expiry);
  });

  test('late /me cannot invalidate a newer login', () async {
    final pending = Completer<http.Response>();
    final session = sessionWith(
      (r) =>
          r.method == 'POST' ? Future.value(loginResponse()) : pending.future,
    );
    await session.login('fixtureuser', fakePassword);
    final old = session.validate();
    final check = expectLater(
      old,
      throwsA(failsWith(InventoryAuthFailure.staleResponse)),
    );
    session.logout();
    await session.login('fixtureuser', fakePassword);
    pending.complete(http.Response('denied', 401));
    await check;
    expect(session.isAuthenticated, isTrue);
  });

  final malformed = [
    http.Response('not-json', 200),
    loginResponse(token: 'bad\r\nheader'),
    loginResponse(expires: 0),
    loginResponse(expires: 901),
    loginResponse(user: {...userJson(), 'role': 'superadmin'}),
    loginResponse(user: {...userJson(), 'global_access': 'true'}),
    loginResponse(user: {...userJson(), 'user_id': '0123456789abcdef01234567'}),
    loginResponse(
      user: {
        ...userJson(),
        'store_ids': [' S1'],
      },
    ),
  ];
  for (var index = 0; index < malformed.length; index++) {
    final response = malformed[index];
    test('malformed login response $index fails closed', () async {
      final session = sessionWith((_) async => response);
      await expectLater(
        session.login('fixtureuser', fakePassword),
        throwsA(failsWith(InventoryAuthFailure.unavailable)),
      );
      expect(session.isAuthenticated, isFalse);
    });
  }

  test(
    '/me malformed principal ends session without private details',
    () async {
      final session = sessionWith(
        (r) async => r.method == 'POST'
            ? loginResponse()
            : http.Response('{"role":"private unexpected role"}', 200),
      );
      await session.login('fixtureuser', fakePassword);
      await expectLater(
        session.validate(),
        throwsA(failsWith(InventoryAuthFailure.invalidSession)),
      );
      expect(session.user, isNull);
    },
  );

  test('/me cannot switch the authenticated account identity', () async {
    final other = {...userJson(), 'user_id': 'oid:1123456789abcdef01234567'};
    final session = sessionWith(
      (r) async => r.method == 'POST'
          ? loginResponse()
          : http.Response(jsonEncode(other), 200),
    );
    await session.login('fixtureuser', fakePassword);
    await expectLater(
      session.validate(),
      throwsA(failsWith(InventoryAuthFailure.invalidSession)),
    );
    expect(session.user, isNull);
  });

  test('late successful /me cannot restore logout', () async {
    final pending = Completer<http.Response>();
    final session = sessionWith(
      (r) =>
          r.method == 'POST' ? Future.value(loginResponse()) : pending.future,
    );
    await session.login('fixtureuser', fakePassword);
    final check = expectLater(
      session.validate(),
      throwsA(failsWith(InventoryAuthFailure.staleResponse)),
    );
    session.logout();
    pending.complete(http.Response(jsonEncode(userJson()), 200));
    await check;
    expect(session.user, isNull);
  });

  test('disposed controller rejects late login', () async {
    final pending = Completer<http.Response>();
    final client = MockClient((_) => pending.future);
    addTearDown(client.close);
    final session = InventorySessionController(
      api: InventoryAuthApiService(client: client),
    );
    final first = session.login('fixtureuser', fakePassword);
    final check = expectLater(
      first,
      throwsA(failsWith(InventoryAuthFailure.staleResponse)),
    );
    session.dispose();
    pending.complete(loginResponse());
    await check;
  });
}
