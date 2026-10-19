import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/core/auth/inventory_api_client.dart';
import 'package:smart_inventory_web/services/inventory_auth_api_service.dart';
import 'package:smart_inventory_web/core/auth/inventory_session_controller.dart';
import 'auth_test_support.dart';

void main() {
  test('campaign review allowlist admits only exact review routes', () async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    final seen = <String>[];
    final client = InventoryApiClient(
      session: session,
      client: MockClient((request) async {
        seen.add('${request.method} ${request.url.path}');
        expect(request.headers['Authorization'], 'Bearer $fakeToken');
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);
    await client.get(
      session.backendUri.resolve(
        '/inventory-marketing/campaign-reviews?skip=0&limit=50',
      ),
    );
    await client.get(
      session.backendUri.resolve('/inventory-marketing/campaign-reviews/REQ-1'),
    );
    await client.post(
      session.backendUri.resolve(
        '/inventory-marketing/campaign-reviews/REQ-1/accept',
      ),
    );
    await client.post(
      session.backendUri.resolve(
        '/inventory-marketing/campaign-reviews/REQ-1/reject',
      ),
    );
    for (final path in [
      '/inventory-marketing/campaign-reviews/',
      '/inventory-marketing/campaign-reviews/REQ-1/delete',
      '/inventory-marketing/campaign-analysis',
    ]) {
      await expectLater(
        client.get(session.backendUri.resolve(path)),
        throwsA(failsWith(InventoryAuthFailure.disallowedRequest)),
      );
    }
    expect(seen.length, 4);
  });

  test('planning allowlist permits only forecast-share POST', () async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    var calls = 0;
    final client = InventoryApiClient(
      session: session,
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);
    await client.post(
      session.backendUri.resolve('/inventory-marketing/forecast-shares'),
    );
    for (final path in [
      '/inventory-marketing/campaign-analysis',
      '/inventory-marketing/forecast-shares/FS1',
      '/inventory-marketing/forecast-shares/',
    ]) {
      await expectLater(
        client.post(session.backendUri.resolve(path)),
        throwsA(failsWith(InventoryAuthFailure.disallowedRequest)),
      );
    }
    await expectLater(
      client.get(
        session.backendUri.resolve('/inventory-marketing/forecast-shares'),
      ),
      throwsA(failsWith(InventoryAuthFailure.disallowedRequest)),
    );
    expect(calls, 1);
  });

  test(
    'Marketing opportunity publication uses Inventory JWT on exact route',
    () async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixtureuser', fakePassword);
      var calls = 0;
      final client = InventoryApiClient(
        session: session,
        client: MockClient((request) async {
          calls++;
          expect(request.method, 'POST');
          expect(request.url.path, '/marketing-opportunities/');
          expect(request.headers['Authorization'], 'Bearer $fakeToken');
          return http.Response('{}', 200);
        }),
      );
      addTearDown(client.close);
      await client.post(
        session.backendUri.resolve('/marketing-opportunities/'),
      );
      await expectLater(
        client.get(session.backendUri.resolve('/marketing-opportunities/')),
        throwsA(failsWith(InventoryAuthFailure.disallowedRequest)),
      );
      await expectLater(
        client.post(
          session.backendUri.resolve('/marketing-opportunities/extra'),
        ),
        throwsA(failsWith(InventoryAuthFailure.disallowedRequest)),
      );
      expect(calls, 1);
    },
  );

  test(
    'authorized request preserves method, body, headers and response',
    () async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixtureuser', fakePassword);
      final client = InventoryApiClient(
        session: session,
        client: MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.headers['Authorization'], 'Bearer $fakeToken');
          expect(r.headers['X-Trace'], 'fixture');
          expect(r.headers['Content-Type'], contains('application/json'));
          expect(r.body, '{"is_approved":true}');
          expect(r.url.query, 'view=full');
          expect(r.followRedirects, isFalse);
          return http.Response(
            '{"unchanged":true}',
            201,
            headers: {'x-result': 'fixture'},
          );
        }),
      );
      final result = await client.post(
        session.backendUri.resolve('/stock-movement/approve/m1?view=full'),
        headers: {'Content-Type': 'application/json', 'X-Trace': 'fixture'},
        body: '{"is_approved":true}',
      );
      expect(result.statusCode, 201);
      expect(result.body, '{"unchanged":true}');
      expect(result.headers['x-result'], 'fixture');
    },
  );

  for (final target in [
    'https://unrelated.invalid/forecast/daily',
    'http://smartomniretailr26-api.azurewebsites.net/forecast/daily',
    'https://smartomniretailr26-api.azurewebsites.net:444/forecast/daily',
    'https://user@smartomniretailr26-api.azurewebsites.net/forecast/daily',
    '/profile/login',
    '/customer-intelligence',
    '/products',
    '/stores/',
    '/inventory/marketing-opportunities',
    '/inventory-auth/login',
    '/forecast/daily/extra',
    '/forecast/%2e%2e/profile',
    '/forecast/daily#fragment',
  ]) {
    test('unrelated target rejected before dispatch: $target', () async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixtureuser', fakePassword);
      var calls = 0;
      final client = InventoryApiClient(
        session: session,
        client: MockClient((_) async {
          calls++;
          return http.Response('', 200);
        }),
      );
      await expectLater(
        client.post(session.backendUri.resolve(target)),
        throwsA(failsWith(InventoryAuthFailure.disallowedRequest)),
      );
      expect(calls, 0);
    });
  }

  test('only configured localhost origin accepted', () async {
    final transport = MockClient((_) async => loginResponse());
    final api = InventoryAuthApiService(
      client: transport,
      baseUrl: 'http://127.0.0.1:8000',
    );
    final session = InventorySessionController(api: api);
    addTearDown(session.dispose);
    addTearDown(transport.close);
    await session.login('fixtureuser', fakePassword);
    var calls = 0;
    final client = InventoryApiClient(
      session: session,
      client: MockClient((request) async {
        calls++;
        expect(request.url.origin, 'http://127.0.0.1:8000');
        expect(request.headers['Authorization'], 'Bearer $fakeToken');
        return http.Response('local fixture', 200);
      }),
    );
    expect(
      (await client.get(
        Uri.parse('http://127.0.0.1:8000/stock-movement/'),
      )).body,
      'local fixture',
    );
    await expectLater(
      client.get(Uri.parse('http://127.0.0.1:8001/stock-movement/')),
      throwsA(failsWith(InventoryAuthFailure.disallowedRequest)),
    );
    expect(calls, 1);
  });

  test('missing and expired sessions cannot dispatch', () async {
    var now = DateTime.utc(2026);
    final session = sessionWith(
      (_) async => loginResponse(expires: 1),
      clock: () => now,
    );
    var calls = 0;
    final client = InventoryApiClient(
      session: session,
      client: MockClient((_) async {
        calls++;
        return http.Response('', 200);
      }),
    );
    final uri = session.backendUri.resolve('/stock-movement/');
    await expectLater(
      client.get(uri),
      throwsA(failsWith(InventoryAuthFailure.invalidSession)),
    );
    await session.login('fixtureuser', fakePassword);
    now = now.add(const Duration(seconds: 1));
    await expectLater(
      client.get(uri),
      throwsA(failsWith(InventoryAuthFailure.invalidSession)),
    );
    expect(calls, 0);
  });

  for (final status in [401, 403, 429, 503]) {
    test(
      'status $status preserves response and correct session state',
      () async {
        final session = sessionWith((_) async => loginResponse());
        await session.login('fixtureuser', fakePassword);
        final client = InventoryApiClient(
          session: session,
          client: MockClient(
            (_) async => http.Response('{"detail":"safe fixture"}', status),
          ),
        );
        final response = await client.get(
          session.backendUri.resolve('/stock-movement/'),
        );
        expect(response.statusCode, status);
        expect(response.body, '{"detail":"safe fixture"}');
        expect(session.isAuthenticated, status != 401);
      },
    );
  }

  test('client /me 403 invalidates unusable principal', () async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    final client = InventoryApiClient(
      session: session,
      client: MockClient((_) async => http.Response('', 403)),
    );
    expect(
      (await client.get(
        session.backendUri.resolve('/inventory-auth/me'),
      )).statusCode,
      403,
    );
    expect(session.isAuthenticated, isFalse);
  });

  test('redirect cannot forward token', () async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    var calls = 0;
    final client = InventoryApiClient(
      session: session,
      client: MockClient((r) async {
        calls++;
        expect(r.followRedirects, isFalse);
        return http.Response(
          '',
          302,
          headers: {'location': 'https://unrelated.invalid'},
        );
      }),
    );
    expect(
      (await client.get(
        session.backendUri.resolve('/stock-movement/'),
      )).statusCode,
      302,
    );
    expect(calls, 1);
  });

  test('caller credentials and unsupported methods rejected', () async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    var calls = 0;
    final client = InventoryApiClient(
      session: session,
      client: MockClient((_) async {
        calls++;
        return http.Response('', 200);
      }),
    );
    final uri = session.backendUri.resolve('/stock-movement/');
    for (final header in ['Authorization', 'authorization', 'Cookie']) {
      await expectLater(
        client.get(uri, headers: {header: 'not-used'}),
        throwsA(failsWith(InventoryAuthFailure.disallowedRequest)),
      );
    }
    await expectLater(
      client.delete(uri),
      throwsA(failsWith(InventoryAuthFailure.disallowedRequest)),
    );
    expect(calls, 0);
  });

  test(
    'failed mutation is never replayed and transport details hidden',
    () async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixtureuser', fakePassword);
      var calls = 0;
      final client = InventoryApiClient(
        session: session,
        client: MockClient((_) async {
          calls++;
          throw http.ClientException('private token or server details');
        }),
      );
      await expectLater(
        client.post(session.backendUri.resolve('/stock-movement/execute/m1')),
        throwsA(failsWith(InventoryAuthFailure.network)),
      );
      expect(calls, 1);
    },
  );

  test('old 401 cannot log out new session', () async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    final pending = Completer<http.Response>();
    final client = InventoryApiClient(
      session: session,
      client: MockClient((_) => pending.future),
    );
    final old = client.get(session.backendUri.resolve('/stock-movement/'));
    final check = expectLater(
      old,
      throwsA(failsWith(InventoryAuthFailure.staleResponse)),
    );
    session.logout();
    await session.login('fixtureuser', fakePassword);
    pending.complete(http.Response('', 401));
    await check;
    expect(session.isAuthenticated, isTrue);
  });

  test('late streamed body is rejected after logout', () async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    final body = StreamController<List<int>>();
    final transport = MockClient.streaming(
      (_, _) async => http.StreamedResponse(body.stream, 200),
    );
    final client = InventoryApiClient(session: session, client: transport);
    final response = await client.send(
      http.Request('GET', session.backendUri.resolve('/stock-movement/')),
    );
    final bytes = response.stream.toBytes();
    final check = expectLater(
      bytes,
      throwsA(failsWith(InventoryAuthFailure.staleResponse)),
    );
    session.logout();
    body.add(utf8.encode('old response'));
    await body.close();
    await check;
  });
}
