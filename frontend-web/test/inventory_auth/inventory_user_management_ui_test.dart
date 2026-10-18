import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/core/auth/inventory_api_client.dart';
import 'package:smart_inventory_web/core/auth/inventory_auth_scope.dart';
import 'package:smart_inventory_web/core/auth/inventory_ui_permissions.dart';
import 'package:smart_inventory_web/features/user_management/user_management_screen.dart';
import 'package:smart_inventory_web/features/user_management/widgets/user_form_dialog.dart';
import 'package:smart_inventory_web/features/user_management/widgets/reset_password_dialog.dart';
import 'package:smart_inventory_web/models/auth/inventory_user.dart';
import 'package:smart_inventory_web/services/inventory_user_management_api_service.dart';
import 'package:smart_inventory_web/services/inventory_auth_api_service.dart';
import 'auth_test_support.dart';

Map<String, dynamic> accountJson() => {
  ...userJson(global: true, stores: []),
  'revision': 7,
  'is_active': true,
};
void main() {
  test('only explicit global Admin can manage users', () {
    for (final role in InventoryRole.values) {
      for (final global in [false, true]) {
        expect(
          InventoryUiPermissions(
            InventoryUser.fromJson(userJson(role: role.name, global: global)),
          ).canManageUsers,
          role == InventoryRole.admin && global,
        );
      }
    }
  });
  test(
    'mutations carry JWT and exact stale revision once; ordinary 403 retains session',
    () async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixture', fakePassword);
      final requests = <http.Request>[];
      var status = 200;
      final client = InventoryApiClient(
        session: session,
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(jsonEncode(accountJson()), status);
        }),
      );
      addTearDown(client.close);
      final api = InventoryUserManagementApiService(
        client: client,
        session: session,
      );
      final account = ManagedInventoryUser.fromJson(accountJson());
      await api.status(account);
      await api.reset(account, 'fixture-password');
      await api.save({
        'revision': 7,
        'display_name': 'Updated',
      }, id: account.user.userId);
      expect(requests.map((r) => r.method), ['PATCH', 'POST', 'PATCH']);
      for (final request in requests) {
        expect(jsonDecode(request.body)['revision'], 7);
        expect(request.headers['Authorization'], 'Bearer $fakeToken');
        expect(request.url.host, session.backendUri.host);
      }
      status = 409;
      await expectLater(
        api.status(account),
        throwsA(isA<InventoryAccountError>()),
      );
      expect(requests.length, 4);
      status = 403;
      await expectLater(
        api.status(account),
        throwsA(isA<InventoryAccountError>()),
      );
      expect(session.isAuthenticated, true);
      status = 401;
      await expectLater(
        api.status(account),
        throwsA(isA<InventoryAccountError>()),
      );
      expect(session.isAuthenticated, false);
      await expectLater(
        api.status(account),
        throwsA(isA<InventoryAuthException>()),
      );
      expect(requests.length, 6);
    },
  );
  test('PATCH remains denied outside approved Inventory endpoints', () async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixture', fakePassword);
    var calls = 0;
    final client = InventoryApiClient(
      session: session,
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);
    for (final path in [
      '/profiles/me',
      '/marketing/users',
      '/inventory-users/not-an-id',
      '/inventory-auth/login',
    ]) {
      await expectLater(
        client.patch(session.backendUri.replace(path: path)),
        throwsA(isA<InventoryAuthException>()),
      );
    }
    await expectLater(
      client.get(Uri.parse('https://unrelated.example/inventory-users')),
      throwsA(isA<InventoryAuthException>()),
    );
    expect(calls, 0);
  });
  testWidgets('non-global Admin denied before list request', (tester) async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixture', fakePassword);
    var calls = 0;
    final client = InventoryApiClient(
      session: session,
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventoryAuthScope(
            session: session,
            child: UserManagementScreen(client: client),
          ),
        ),
      ),
    );
    expect(find.textContaining('access denied'), findsOneWidget);
    expect(calls, 0);
    session.logout();
    await tester.pumpAndSettle();
  });
  testWidgets(
    'list search pagination empty state and self-deactivation protection',
    (tester) async {
      final session = sessionWith(
        (_) async => loginResponse(user: userJson(global: true, stores: [])),
      );
      await session.login('fixture', fakePassword);
      final requests = <http.Request>[];
      final client = InventoryApiClient(
        session: session,
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({
              'users': r.url.queryParameters['search'] == 'nobody'
                  ? []
                  : [accountJson()],
              'total': 21,
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
              child: UserManagementScreen(client: client),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Deactivate'))
            .onPressed,
        isNull,
      );
      final beforeFilter = requests.length;
      await tester.tap(find.widgetWithText(ChoiceChip, 'Inactive'));
      await tester.pumpAndSettle();
      expect(find.text('No users found.'), findsOneWidget);
      expect(requests.length, beforeFilter);
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      expect(find.text('Deactivate'), findsOneWidget);
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['offset'], '20');
      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['offset'], '0');
      expect(find.text('No users found.'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear user search'));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['search'], '');
      expect(find.text('Fixture User'), findsOneWidget);
      session.logout();
      await tester.pumpAndSettle();
    },
  );
  testWidgets('create validates password confirmation and store assignments', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserFormDialog(
            loadStores: () async => const [
              InventoryStoreChoice('S1', 'Central'),
              InventoryStoreChoice('S2', 'North'),
            ],
            onSave: (body) async {
              sent = body;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(sent, isNull);
    expect(
      find.text('Select at least one store (maximum 200).'),
      findsOneWidget,
    );
    expect(find.text('Use 12-1024 characters.'), findsOneWidget);
  });
  testWidgets(
    'self edit sends display and revision only; conflict prevents resubmit',
    (tester) async {
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserFormDialog(
              loadStores: () async => const [
                InventoryStoreChoice('S1', 'Central'),
                InventoryStoreChoice('S2', 'North'),
              ],
              account: ManagedInventoryUser.fromJson(accountJson()),
              isSelf: true,
              onSave: (body) async {
                sent = body;
                throw const InventoryAccountError(409);
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent, {'display_name': 'Fixture User', 'revision': 7});
      expect(find.textContaining('Reload before editing'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets('reset password validation never submits mismatched values', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResetPasswordDialog(
            onReset: (_) async {
              calls++;
            },
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'fixture-password',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'different-password',
    );
    await tester.tap(find.text('Reset password'));
    await tester.pump();
    expect(find.text('Passwords must match.'), findsOneWidget);
    expect(calls, 0);
  });
  testWidgets(
    'valid create form sends scoped fields without invented account metadata',
    (tester) async {
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => UserFormDialog(
                    loadStores: () async => const [
                      InventoryStoreChoice('S1', 'Central'),
                      InventoryStoreChoice('S2', 'North'),
                    ],
                    onSave: (body) async {
                      sent = body;
                    },
                  ),
                ),
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open form'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'newuser');
      await tester.enterText(fields.at(1), 'New User');
      await tester.ensureVisible(find.byKey(const ValueKey('store-S1')));
      await tester.tap(find.byKey(const ValueKey('store-S1')));
      await tester.ensureVisible(find.byKey(const ValueKey('store-S2')));
      await tester.tap(find.byKey(const ValueKey('store-S2')));
      await tester.enterText(
        find.byKey(const ValueKey('Initial password')),
        'fixture-password',
      );
      await tester.enterText(
        find.byKey(const ValueKey('Confirm password')),
        'fixture-password',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent, {
        'username': 'newuser',
        'display_name': 'New User',
        'role': 'viewer',
        'global_access': false,
        'store_ids': ['S1', 'S2'],
        'password': 'fixture-password',
      });
      expect(find.byType(UserFormDialog), findsNothing);
    },
  );
  test(
    'store catalog uses exact business IDs without JWT or redirects',
    () async {
      final session = sessionWith(
        (_) async => loginResponse(user: userJson(global: true, stores: [])),
      );
      await session.login('fixture', fakePassword);
      final inventory = InventoryApiClient(
        session: session,
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      addTearDown(inventory.close);
      final catalog = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/stores/');
        expect(request.url.host, session.backendUri.host);
        expect(request.headers.containsKey('Authorization'), false);
        expect(request.followRedirects, false);
        return http.Response(
          jsonEncode({
            'stores': [
              {
                'store_id': 'Ab_001',
                'id': 'not-the-business-id',
                'store_name': 'Central',
              },
            ],
          }),
          200,
        );
      });
      addTearDown(catalog.close);
      final api = InventoryUserManagementApiService(
        client: inventory,
        session: session,
        catalogClient: catalog,
      );
      expect((await api.stores()).single.id, 'Ab_001');
    },
  );

  testWidgets(
    'edit preselects exact IDs and global toggle submits empty assignments on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? sent;
      final account = ManagedInventoryUser.fromJson({
        ...accountJson(),
        'global_access': false,
        'store_ids': ['Ab_001'],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserFormDialog(
              account: account,
              loadStores: () async => const [
                InventoryStoreChoice('Ab_001', 'Central'),
                InventoryStoreChoice('S2', 'North'),
              ],
              onSave: (body) async {
                sent = body;
                throw const InventoryAccountError(409);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ab_001 - Central'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('store-Ab_001')),
            )
            .value,
        true,
      );
      final search = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Search store ID or name',
      );
      await tester.enterText(search, 'North');
      await tester.pump();
      expect(find.byKey(const ValueKey('store-S2')), findsOneWidget);
      expect(find.byKey(const ValueKey('store-Ab_001')), findsNothing);
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent!['store_ids'], isEmpty);
      expect(sent!['global_access'], true);
      expect(sent!['revision'], 7);
      expect(sent!['role'], 'admin');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'store loading errors preserve IDs and block unsafe scoped saves',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserFormDialog(
              account: ManagedInventoryUser.fromJson({
                ...accountJson(),
                'global_access': false,
                'store_ids': ['S1'],
              }),
              loadStores: () async => throw const InventoryAccountError(503),
              onSave: (_) async {
                calls++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('S1 - name unavailable'), findsOneWidget);
      expect(find.text('Retry stores'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(calls, 0);
    },
  );

  testWidgets(
    'reset visibility and pending request prevent duplicate submission',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ResetPasswordDialog(
                    onReset: (_) {
                      calls++;
                      return pending.future;
                    },
                  ),
                ),
                child: const Text('Open reset'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open reset'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'fixture-password',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'fixture-password',
      );
      await tester.ensureVisible(find.byTooltip('Show new password'));
      await tester.tap(find.byTooltip('Show new password'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).obscureText,
        false,
      );
      await tester.tap(find.text('Reset password'));
      await tester.pump();
      expect(calls, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Resetting...'),
            )
            .onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordDialog), findsNothing);
    },
  );

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        'premium directory renders at ${width.toInt()} in ${brightness.name}',
        (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final session = sessionWith(
            (_) async =>
                loginResponse(user: userJson(global: true, stores: const [])),
          );
          await session.login('fixture', fakePassword);
          final longAccount = {
            ...accountJson(),
            'display_name':
                'A very long Inventory administrator display name for responsive testing',
            'store_ids': ['CP001', 'CP002', 'CP003', 'CP004'],
            'global_access': false,
          };
          final client = InventoryApiClient(
            session: session,
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'users': [longAccount],
                  'total': 1,
                }),
                200,
              ),
            ),
          );
          addTearDown(client.close);

          await tester.pumpWidget(
            MaterialApp(
              theme: brightness == Brightness.dark
                  ? ThemeData.dark(useMaterial3: true)
                  : ThemeData.light(useMaterial3: true),
              home: Scaffold(
                body: InventoryAuthScope(
                  session: session,
                  child: UserManagementScreen(client: client),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('INVENTORY ADMINISTRATION'), findsOneWidget);
          expect(find.text('Assigned stores'), findsOneWidget);
          expect(find.text('Search directory'), findsOneWidget);
          expect(find.textContaining('current page'), findsOneWidget);
          expect(tester.takeException(), isNull);
          session.logout();
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
