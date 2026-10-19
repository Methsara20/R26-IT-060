import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/core/auth/inventory_auth_scope.dart';
import 'package:smart_inventory_web/features/shell/inventory_application_shell.dart';
import 'package:smart_inventory_web/features/profile/my_profile_screen.dart';
import 'package:smart_inventory_web/features/user_management/user_management_screen.dart';
import 'package:smart_inventory_web/features/marketing_requests/marketing_requests_screen.dart';
import 'auth_test_support.dart';

void main() {
  Future<void> location(WidgetTester tester, String module) async {
    final observer =
        tester.state(find.byType(InventoryApplicationShell))
            as WidgetsBindingObserver;
    expect(
      await observer.didPushRouteInformation(
        RouteInformation(uri: Uri.parse('/?module=$module')),
      ),
      true,
    );
    await tester.pumpAndSettle();
  }

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final role in ['admin', 'manager', 'analyst', 'operator', 'viewer']) {
      for (final global in role == 'admin' ? [false, true] : [false]) {
        testWidgets('$role global=$global navigation and deep links at $width', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final user = userJson(
            role: role,
            global: global,
            stores: global ? [] : ['S1'],
          );
          final session = sessionWith((_) async => loginResponse(user: user));
          final requests = <http.Request>[];
          await http.runWithClient(
            () async {
              await tester.pumpWidget(
                MaterialApp(
                  routes: {
                    '/login': (_) =>
                        const Scaffold(body: Text('Login destination')),
                  },
                  home: InventoryAuthScope(
                    session: session,
                    child: InventoryApplicationShell(
                      themeMode: ThemeMode.light,
                      onThemeModeChanged: (_) {},
                    ),
                  ),
                ),
              );
              // Missing-session direct URL must never mount either account page.
              await location(tester, 'user-management');
              expect(find.byType(UserManagementScreen), findsNothing);
              expect(requests, isEmpty);
              await session.login('fixture', fakePassword);
              await tester.pumpAndSettle();
              if (role == 'admin' && global) {
                expect(find.byType(UserManagementScreen), findsOneWidget);
                expect(
                  requests.any((r) => r.url.path == '/inventory-users'),
                  true,
                );
              } else {
                expect(find.byType(UserManagementScreen), findsNothing);
                expect(
                  find.textContaining('Global Admin access is required'),
                  findsOneWidget,
                );
                expect(requests, isEmpty);
              }
              if (width < 760) {
                await tester.tap(find.byTooltip('Open navigation menu'));
                await tester.pumpAndSettle();
              }
              if (width >= 760 && width < 1100) {
                final rail = tester.widget<NavigationRail>(
                  find.byType(NavigationRail),
                );
                final labels = rail.destinations
                    .map((d) => (d.label as Text).data)
                    .toList();
                expect(
                  labels.contains('User Management'),
                  role == 'admin' && global,
                );
                expect(labels.contains('My Profile'), true);
              } else {
                final profile = find.widgetWithText(ListTile, 'My Profile');
                await tester.scrollUntilVisible(
                  profile,
                  150,
                  scrollable: find
                      .descendant(
                        of: find.byType(ListView),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                );
                expect(profile, findsOneWidget);
                expect(
                  find.widgetWithText(ListTile, 'User Management'),
                  role == 'admin' && global ? findsOneWidget : findsNothing,
                );
                await tester.tap(profile);
                await tester.pumpAndSettle();
                expect(find.byType(MyProfileScreen), findsOneWidget);
              }
              await location(tester, 'my-profile');
              expect(find.byType(MyProfileScreen), findsOneWidget);
              expect(
                requests.any((r) => r.url.path == '/inventory-auth/me'),
                true,
              );
              await location(tester, 'marketing-requests');
              final reviewsAllowed = [
                'admin',
                'manager',
                'analyst',
              ].contains(role);
              expect(
                find.byType(MarketingRequestsScreen),
                reviewsAllowed ? findsOneWidget : findsNothing,
              );
              if (!reviewsAllowed) {
                expect(find.textContaining('access denied'), findsOneWidget);
              }
              // Permission loss removes a previously mounted Admin screen.
              if (role == 'admin' && global) {
                await location(tester, 'user-management');
                session.logout();
                await tester.pumpAndSettle();
                expect(find.byType(UserManagementScreen), findsNothing);
              } else {
                session.logout();
                await tester.pumpAndSettle();
              }
              expect(find.byType(MyProfileScreen), findsNothing);
              expect(find.text('Sign in to access Inventory.'), findsOneWidget);
              expect(tester.takeException(), isNull);
            },
            () => MockClient((request) async {
              requests.add(request);
              return http.Response(
                jsonEncode(
                  request.url.path == '/inventory-users'
                      ? {'users': [], 'total': 0, 'offset': 0, 'limit': 20}
                      : user,
                ),
                200,
              );
            }),
          );
        });
      }
    }
  }

  test(
    'existing destination indices and slugs remain in order; account pages appended',
    () {
      final source = File(
        'lib/features/shell/inventory_application_shell.dart',
      ).readAsStringSync();
      final slugs = RegExp(
        r"static const _moduleSlugs = <String>\[([\s\S]*?)\];",
      ).firstMatch(source)!.group(1)!;
      expect(
        RegExp("'([^']+)'").allMatches(slugs).map((m) => m.group(1)).toList(),
        [
          'dashboard',
          'forecasting',
          'inventory-intelligence',
          'optimization',
          'stock-movements',
          'analytics',
          'manager-assistant',
          'user-management',
          'my-profile',
          'marketing-requests',
        ],
      );
      for (final index in [0, 1, 2, 3, 4, 5, 6]) {
        expect(source, contains('_selectedIndex == $index'));
      }
      expect(source, contains('_indexFromLocation(Uri.base)'));
      expect(source, contains('session.isAuthenticated'));
      expect(source, contains('onSelected(indices[position])'));
      expect(source, contains('_selectedIndex < 6 && permitted'));
    },
  );

  testWidgets(
    'shell logout clears session; fresh refresh has no remembered JWT',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = sessionWith((_) async => loginResponse());
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              routes: {
                '/login': (_) =>
                    const Scaffold(body: Text('Login destination')),
              },
              home: InventoryAuthScope(
                session: session,
                child: InventoryApplicationShell(
                  themeMode: ThemeMode.light,
                  onThemeModeChanged: (_) {},
                ),
              ),
            ),
          );
          await location(tester, 'my-profile');
          await session.login('fixture', fakePassword);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Log out'));
          await tester.pumpAndSettle();
          expect(session.isAuthenticated, false);
          expect(find.text('Login destination'), findsOneWidget);
        },
        () =>
            MockClient((_) async => http.Response(jsonEncode(userJson()), 200)),
      );
    },
  );
}
