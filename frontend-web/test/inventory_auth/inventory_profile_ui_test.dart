import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/core/auth/inventory_api_client.dart';
import 'package:smart_inventory_web/core/auth/inventory_auth_scope.dart';
import 'package:smart_inventory_web/features/profile/my_profile_screen.dart';
import 'package:smart_inventory_web/services/inventory_profile_api_service.dart';
import 'package:smart_inventory_web/services/inventory_user_management_api_service.dart';
import 'auth_test_support.dart';

void main() {
  test(
    'profile revision and password contracts; successful password change logs out',
    () async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixture', fakePassword);
      final requests = <http.Request>[];
      final client = InventoryApiClient(
        session: session,
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode(
              r.method == 'PATCH'
                  ? {'user': userJson(), 'revision': 8}
                  : {
                      'message': 'Password changed. Sign in again.',
                      'reauthentication_required': true,
                    },
            ),
            200,
          );
        }),
      );
      addTearDown(client.close);
      final api = InventoryProfileApiService(client: client, session: session);
      final revision = await api.update('Name');
      expect(jsonDecode(requests.first.body), {'display_name': 'Name'});
      await api.changePassword(
        'old',
        'new-password',
        'new-password',
        revision: revision,
      );
      expect(jsonDecode(requests.last.body), {
        'current_password': 'old',
        'new_password': 'new-password',
        'new_password_confirmation': 'new-password',
        'revision': 8,
      });
      expect(session.isAuthenticated, false);
      expect(requests.length, 2);
    },
  );
  test(
    'failed password change does not log out or retry; response body is not exposed',
    () async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixture', fakePassword);
      var calls = 0;
      final client = InventoryApiClient(
        session: session,
        client: MockClient((_) async {
          calls++;
          return http.Response('secret-marker', 400);
        }),
      );
      addTearDown(client.close);
      final api = InventoryProfileApiService(client: client, session: session);
      try {
        await api.changePassword('old', 'new-password', 'new-password');
        fail('Expected error');
      } catch (e) {
        expect(e, isA<InventoryAccountError>());
        expect(e.toString(), isNot(contains('secret-marker')));
      }
      expect(calls, 1);
      expect(session.isAuthenticated, true);
    },
  );
  testWidgets('all roles can view profile; form allows display name only', (
    tester,
  ) async {
    for (final role in ['admin', 'manager', 'analyst', 'operator', 'viewer']) {
      final session = sessionWith(
        (_) async => loginResponse(user: userJson(role: role)),
      );
      await session.login('fixture', fakePassword);
      final client = InventoryApiClient(
        session: session,
        client: MockClient(
          (_) async => http.Response(jsonEncode(userJson(role: role)), 200),
        ),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryAuthScope(
              session: session,
              child: MyProfileScreen(key: ValueKey(role), client: client),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Role:'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField), findsNothing);
      session.logout();
      await tester.pumpAndSettle();
      expect(find.text('Sign in again to access My Profile.'), findsOneWidget);
    }
  });
  testWidgets(
    'profile password validation and conflict block further mutations',
    (tester) async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixture', fakePassword);
      var writes = 0;
      final client = InventoryApiClient(
        session: session,
        client: MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response(jsonEncode(userJson()), 200);
          }
          writes++;
          return http.Response('{}', 409);
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryAuthScope(
              session: session,
              child: MyProfileScreen(client: client),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save display name'));
      await tester.tap(find.text('Save display name'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.textContaining('Reload before editing'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save display name'),
            )
            .onPressed,
        isNull,
      );
      session.logout();
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'password form confirms change and requires sign-in on a narrow layout',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixture', fakePassword);
      final writes = <http.Request>[];
      final client = InventoryApiClient(
        session: session,
        client: MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response(jsonEncode(userJson()), 200);
          }
          writes.add(r);
          return http.Response(
            jsonEncode({
              'reauthentication_required': true,
              'message': 'Password changed. Sign in again.',
            }),
            200,
          );
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryAuthScope(
              session: session,
              child: MyProfileScreen(client: client),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Personal information'), findsOneWidget);
      expect(find.text('Password security'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Show Current password'));
      await tester.tap(find.byTooltip('Show Current password'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        false,
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'old-password');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'new-password-123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'new-password-123',
      );
      final button = find.widgetWithText(FilledButton, 'Change password');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(writes.length, 1);
      expect(session.isAuthenticated, false);
      expect(find.text('Sign in again to access My Profile.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        'premium profile renders at ${width.toInt()} in ${brightness.name}',
        (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final global = brightness == Brightness.dark;
          final profile = {
            ...userJson(
              role: 'manager',
              global: global,
              stores: global
                  ? const <String>[]
                  : const ['CP001', 'CP002', 'CP003', 'CP004'],
            ),
            'display_name':
                'A long Inventory profile display name for responsive verification',
          };
          final session = sessionWith(
            (_) async => loginResponse(user: profile),
          );
          await session.login('fixture', fakePassword);
          final client = InventoryApiClient(
            session: session,
            client: MockClient(
              (_) async => http.Response(jsonEncode(profile), 200),
            ),
          );
          addTearDown(client.close);

          await tester.pumpWidget(
            MaterialApp(
              theme: brightness == Brightness.dark
                  ? ThemeData.dark(useMaterial3: true)
                  : ThemeData.light(useMaterial3: true),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 1200),
                  textScaler: const TextScaler.linear(1.15),
                ),
                child: Scaffold(
                  body: InventoryAuthScope(
                    session: session,
                    child: MyProfileScreen(client: client),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('INVENTORY ACCOUNT'), findsOneWidget);
          expect(find.text('Authenticated'), findsOneWidget);
          expect(find.text('Manager'), findsOneWidget);
          expect(find.text(global ? 'Global Access' : 'CP001'), findsOneWidget);
          expect(find.text('Personal information'), findsOneWidget);
          expect(find.text('Password security'), findsOneWidget);
          expect(tester.takeException(), isNull);
          session.logout();
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
