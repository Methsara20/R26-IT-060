import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/core/auth/inventory_session_controller.dart';
import 'package:smart_inventory_web/services/inventory_auth_api_service.dart';

// Synthetic fixtures, not usable JWTs or real account credentials.
const fakeToken = 'fixture.payload.signature';
const fakePassword = ' fake test input ';
Map<String, dynamic> userJson({
  String role = 'admin',
  bool global = false,
  List<String> stores = const ['S1', 'S2'],
}) => {
  'user_id': 'oid:0123456789abcdef01234567',
  'username_normalized': 'fixtureuser',
  'display_name': 'Fixture User',
  'role': role,
  'global_access': global,
  'store_ids': stores,
};
http.Response loginResponse({
  String token = fakeToken,
  int expires = 900,
  Map<String, dynamic>? user,
}) => http.Response(
  jsonEncode({
    'access_token': token,
    'token_type': 'bearer',
    'expires_in': expires,
    'user': user ?? userJson(),
  }),
  200,
);
Matcher failsWith(InventoryAuthFailure failure) => isA<InventoryAuthException>()
    .having((error) => error.failure, 'failure', failure);

InventorySessionController sessionWith(
  Future<http.Response> Function(http.Request) handler, {
  DateTime Function()? clock,
}) {
  final client = MockClient(handler);
  final api = InventoryAuthApiService(client: client);
  final session = InventorySessionController(api: api, clock: clock);
  addTearDown(session.dispose);
  addTearDown(client.close);
  return session;
}
