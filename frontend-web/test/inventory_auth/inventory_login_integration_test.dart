import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/marketing_hub/core/auth/marketing_session_controller.dart';
import 'package:smart_inventory_web/marketing_hub/services/marketing_auth_service.dart';

void main() {
  test('Marketing login is backend verified and memory only', () async {
    late http.Request captured;
    final api = MarketingAuthService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'access_token': 'a.b.c',
            'token_type': 'bearer',
            'expires_in': 300,
            'username': 'marketing',
            'store_ids': ['CP004'],
            'global_access': false,
          }),
          200,
        );
      }),
      baseUrl: 'https://api.example',
    );
    final session = MarketingSessionController(api: api);
    await session.login('marketing', 'not-hardcoded');
    expect(captured.url.path, '/marketing-inventory/login');
    expect(jsonDecode(captured.body), {
      'username': 'marketing',
      'password': 'not-hardcoded',
    });
    expect(session.isAuthenticated, isTrue);
    expect(session.principal!.storeIds, ['CP004']);
    session.logout();
    expect(session.isAuthenticated, isFalse);
    session.dispose();
  });

  test('failed Marketing login never creates a session', () async {
    final api = MarketingAuthService(
      client: MockClient(
        (_) async => http.Response('{"detail":"private"}', 401),
      ),
      baseUrl: 'https://api.example',
    );
    final session = MarketingSessionController(api: api);
    await expectLater(
      session.login('marketing', 'wrong'),
      throwsA(
        isA<MarketingAuthException>().having(
          (e) => e.failure,
          'failure',
          MarketingAuthFailure.invalidCredentials,
        ),
      ),
    );
    expect(session.isAuthenticated, isFalse);
    session.dispose();
  });
}
