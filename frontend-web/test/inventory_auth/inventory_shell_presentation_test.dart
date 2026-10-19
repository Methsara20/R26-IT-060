import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/core/auth/inventory_auth_scope.dart';
import 'package:smart_inventory_web/core/theme/application_design_tokens.dart';
import 'package:smart_inventory_web/features/shell/inventory_application_shell.dart';
import 'package:smart_inventory_web/features/profile/my_profile_screen.dart';
import 'auth_test_support.dart';

void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final height in [420.0, 560.0, 900.0]) {
      for (final dark in [false, true]) {
        testWidgets('navigation ${width}x$height dark=$dark', (tester) async {
          tester.view.physicalSize = Size(width, height);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final user = userJson(role: 'viewer');
          final session = sessionWith((_) async => loginResponse(user: user));
          ThemeMode? changedMode;
          await http.runWithClient(
            () async {
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(
                    brightness: dark ? Brightness.dark : Brightness.light,
                  ),
                  home: InventoryAuthScope(
                    session: session,
                    child: InventoryApplicationShell(
                      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                      onThemeModeChanged: (mode) => changedMode = mode,
                    ),
                  ),
                ),
              );
              final observer =
                  tester.state(find.byType(InventoryApplicationShell))
                      as WidgetsBindingObserver;
              await observer.didPushRouteInformation(
                RouteInformation(uri: Uri.parse('/?module=my-profile')),
              );
              await session.login('fixture', fakePassword);
              await tester.pumpAndSettle();
              expect(find.byType(MyProfileScreen), findsOneWidget);
              if (width < 760) {
                await tester.tap(find.byTooltip('Open navigation menu'));
                await tester.pumpAndSettle();
              }
              final selectedNavigation = width >= 760 && width < 1100
                  ? find.byTooltip('My Profile')
                  : find.widgetWithText(ListTile, 'My Profile');
              expect(selectedNavigation, findsOneWidget);
              final selectedRect = tester.getRect(selectedNavigation);
              expect(selectedRect.top, greaterThanOrEqualTo(0));
              expect(selectedRect.bottom, lessThanOrEqualTo(height));
              if (width >= 760 && width < 1100) {
                final rail = tester.widget<NavigationRail>(
                  find.byType(NavigationRail),
                );
                expect(
                  rail.backgroundColor,
                  dark
                      ? ApplicationColors.darkPanel
                      : ApplicationColors.lightPanel,
                );
                expect(
                  find.byTooltip('Inventory Intelligence'),
                  findsOneWidget,
                );
                expect(find.byTooltip('Stock Movements'), findsOneWidget);
                expect(find.byTooltip('My Profile'), findsOneWidget);
                final toggle = find.byTooltip(
                  dark ? 'Use light mode' : 'Use dark mode',
                );
                await tester.ensureVisible(toggle);
                await tester.tap(toggle);
              } else {
                expect(
                  find.widgetWithText(ListTile, 'Marketing Requests'),
                  findsNothing,
                );
                expect(
                  find.widgetWithText(ListTile, 'User Management'),
                  findsNothing,
                );
                await tester.tap(find.byType(Switch));
              }
              await tester.pump();
              expect(changedMode, dark ? ThemeMode.light : ThemeMode.dark);
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              expect(FocusManager.instance.primaryFocus, isNotNull);
              expect(tester.takeException(), isNull);
              session.logout();
              await tester.pumpWidget(const SizedBox());
            },
            () => MockClient((_) async => http.Response(jsonEncode(user), 200)),
          );
        });
      }
    }
  }
}
