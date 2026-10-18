import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/core/auth/inventory_auth_guard.dart';
import 'package:smart_inventory_web/screens/landing_screen.dart';
import 'package:smart_inventory_web/core/auth/inventory_auth_scope.dart';
import 'package:smart_inventory_web/core/auth/inventory_session_controller.dart';
import 'package:smart_inventory_web/marketing_hub/core/auth/marketing_auth_scope.dart';
import 'package:smart_inventory_web/marketing_hub/core/auth/marketing_session_controller.dart';
import 'package:smart_inventory_web/marketing_hub/services/marketing_auth_service.dart';
import 'auth_test_support.dart';

MarketingSessionController marketingSessionWith(
  Future<http.Response> Function(http.Request) handler,
) => MarketingSessionController(
  api: MarketingAuthService(
    client: MockClient(handler),
    baseUrl: 'https://api.example',
  ),
);

Widget harness(
  InventorySessionController session, {
  String initialRoute = '/login',
  GlobalKey<NavigatorState>? navigatorKey,
  VoidCallback? onInventoryBuild,
  MarketingSessionController? marketingSession,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: ThemeData(
    brightness: brightness,
    splashFactory: NoSplash.splashFactory,
  ),
  navigatorKey: navigatorKey,
  initialRoute: initialRoute,
  routes: {
    '/login': (_) => InventoryAuthScope(
      session: session,
      child: MarketingAuthScope(
        session:
            marketingSession ??
            marketingSessionWith((_) async => http.Response('{}', 401)),
        child: const LandingScreen(),
      ),
    ),
    '/inventory': (_) => InventoryAuthenticatedRoute(
      session: session,
      builder: (context) {
        onInventoryBuild?.call();
        return Scaffold(
          body: Column(
            children: [
              const Text('Inventory destination'),
              Text(InventoryAuthScope.of(context).user!.role.name),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Existing shell logout'),
              ),
            ],
          ),
        );
      },
    ),
    '/marketing': (_) => const Scaffold(body: Text('Marketing destination')),
  },
);

Future<void> submit(
  WidgetTester tester,
  String username,
  String password,
) async {
  await tester.enterText(find.byType(TextField).at(0), username);
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.ensureVisible(find.text('Sign In'));
  await tester.tap(find.text('Sign In'));
}

void main() {
  testWidgets(
    'shared login presents platform-wide Smart Omni-Retail branding',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = sessionWith((_) async => http.Response('{}', 401));

      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();

      expect(find.text('Smart Omni-Retail'), findsOneWidget);
      expect(
        find.text(
          'Smarter Decisions. Personalized Experiences. Seamless Retail.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'An integrated retail intelligence platform connecting inventory '
          'optimization, personalized marketing, and intelligent shopping '
          'experiences.',
        ),
        findsOneWidget,
      );
      expect(find.text('Intelligent Operations'), findsOneWidget);
      expect(
        find.text(
          'Optimize stock, anticipate demand, and support smarter business '
          'decisions.',
        ),
        findsOneWidget,
      );
      expect(find.text('Personalized Experiences'), findsOneWidget);
      expect(
        find.text(
          'Connect customer insights, targeted marketing, and interactive '
          'shopping experiences.',
        ),
        findsOneWidget,
      );
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(
        find.text('Sign in to access your Smart Omni-Retail workspace.'),
        findsOneWidget,
      );
      expect(find.text('Smart Inventory'), findsNothing);
      expect(find.text('Smart Inventory workspace'), findsNothing);
      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'Marketing keeps trimmed case-sensitive credentials and destination, no JWT',
    (tester) async {
      var requests = 0;
      final session = sessionWith((_) async {
        requests++;
        return http.Response('{}', 401);
      });
      final marketingRequests = <http.Request>[];
      final marketingSession = marketingSessionWith((request) async {
        marketingRequests.add(request);
        return http.Response(
          jsonEncode({
            'access_token': 'a.b.c',
            'token_type': 'bearer',
            'expires_in': 300,
            'username': 'marketing',
            'store_ids': <String>[],
            'global_access': true,
          }),
          200,
        );
      });
      await tester.pumpWidget(
        harness(session, marketingSession: marketingSession),
      );
      await tester.pumpAndSettle();
      await submit(tester, ' marketing ', ' marketing123 ');
      await tester.pumpAndSettle();
      expect(find.text('Marketing destination'), findsOneWidget);
      expect(find.text('Inventory destination'), findsNothing);
      expect(requests, 0);
      expect(marketingRequests.length, 1);
      expect(session.isAuthenticated, isFalse);
      marketingSession.dispose();
    },
  );

  testWidgets('failed Marketing password never falls back to Inventory', (
    tester,
  ) async {
    var requests = 0;
    final session = sessionWith((_) async {
      requests++;
      return loginResponse();
    });
    final marketingSession = marketingSessionWith(
      (_) async => http.Response('{}', 401),
    );
    await tester.pumpWidget(
      harness(session, marketingSession: marketingSession),
    );
    await tester.pumpAndSettle();
    await submit(tester, 'marketing', 'wrong');
    await tester.pumpAndSettle();
    expect(find.text('Invalid username or password.'), findsOneWidget);
    expect(requests, 0);
    expect(session.isAuthenticated, isFalse);
    marketingSession.dispose();
  });

  testWidgets('Marketing comparison stays case-sensitive', (tester) async {
    final requests = <http.Request>[];
    final session = sessionWith((request) async {
      requests.add(request);
      return http.Response('{}', 401);
    });
    await tester.pumpWidget(harness(session));
    await tester.pumpAndSettle();
    await submit(tester, 'Marketing', fakePassword);
    await tester.pumpAndSettle();
    expect(requests.single.url.path, '/inventory-auth/login');
    expect(find.text('Marketing destination'), findsNothing);
  });

  testWidgets(
    'Inventory login preserves input, validates me and never enters Marketing',
    (tester) async {
      final requests = <http.Request>[];
      final session = sessionWith((request) async {
        requests.add(request);
        return request.url.path.endsWith('/login')
            ? loginResponse()
            : http.Response(jsonEncode(userJson()), 200);
      });
      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();
      await submit(tester, ' InventoryAdmin ', fakePassword);
      await tester.pumpAndSettle();
      expect(jsonDecode(requests.first.body), {
        'username': ' InventoryAdmin ',
        'password': fakePassword,
      });
      expect(requests.map((r) => r.url.path), [
        '/inventory-auth/login',
        '/inventory-auth/me',
      ]);
      expect(requests.last.headers['authorization'], 'Bearer $fakeToken');
      expect(find.text('Inventory destination'), findsOneWidget);
      expect(find.text('admin'), findsOneWidget);
      expect(find.text('Marketing destination'), findsNothing);
      expect(session.isAuthenticated, isTrue);
      session.logout();
      await tester.pumpAndSettle();
    },
  );

  for (final username in ['inventoryadmin', 'admin', 'unknown']) {
    testWidgets('$username cannot bypass a failed backend login', (
      tester,
    ) async {
      var requests = 0;
      final session = sessionWith((_) async {
        requests++;
        return http.Response('{"detail":"sensitive server detail"}', 401);
      });
      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();
      await submit(
        tester,
        username,
        username == 'admin' ? 'password123' : fakePassword,
      );
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('Invalid username or password.'), findsOneWidget);
      expect(find.textContaining('sensitive server detail'), findsNothing);
      expect(find.text('Inventory destination'), findsNothing);
    });
  }

  testWidgets(
    'duplicate submissions are blocked while authentication is pending',
    (tester) async {
      var requests = 0;
      final pending = Completer<http.Response>();
      final session = sessionWith((_) {
        requests++;
        return pending.future;
      });
      await tester.pumpWidget(harness(session));
      await tester.pumpAndSettle();
      await submit(tester, 'inventoryadmin', fakePassword);
      await tester.pump();
      tester.widget<TextField>(find.byType(TextField).last).onSubmitted!(
        'ignored',
      );
      expect(requests, 1);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(http.Response('{}', 401));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'direct Inventory route never mounts protected screens without session',
    (tester) async {
      var builds = 0;
      var requests = 0;
      final session = sessionWith((_) async {
        requests++;
        return loginResponse();
      });
      await tester.pumpWidget(
        harness(
          session,
          initialRoute: '/inventory',
          onInventoryBuild: () => builds++,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(builds, 0);
      expect(requests, 0);
      expect(
        ModalRoute.of(
          tester.element(find.byType(LandingScreen)),
        )!.settings.name,
        '/login',
      );
    },
  );

  for (final status in [401, 403, 503]) {
    testWidgets(
      '/me $status cannot mount Inventory or disclose response detail',
      (tester) async {
        final session = sessionWith(
          (request) async => request.url.path.endsWith('/login')
              ? loginResponse()
              : http.Response('{"detail":"sensitive server detail"}', status),
        );
        await session.login('fixtureuser', fakePassword);
        var builds = 0;
        await tester.pumpWidget(
          harness(
            session,
            initialRoute: '/inventory',
            onInventoryBuild: () => builds++,
          ),
        );
        await tester.pumpAndSettle();
        expect(builds, 0);
        expect(find.textContaining('sensitive server detail'), findsNothing);
        if (status == 503) {
          expect(find.text('Retry'), findsOneWidget);
          expect(find.text('Return to login'), findsOneWidget);
          await tester.tap(find.text('Return to login'));
          await tester.pumpAndSettle();
        } else {
          expect(find.byType(LandingScreen), findsOneWidget);
          expect(session.isAuthenticated, isFalse);
        }
      },
    );
  }

  testWidgets('protected content waits for me and uses current backend role', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final session = sessionWith(
      (request) async => request.url.path.endsWith('/login')
          ? loginResponse()
          : pending.future,
    );
    await session.login('fixtureuser', fakePassword);
    var builds = 0;
    await tester.pumpWidget(
      harness(
        session,
        initialRoute: '/inventory',
        onInventoryBuild: () => builds++,
      ),
    );
    await tester.pump();
    expect(builds, 0);
    pending.complete(http.Response(jsonEncode(userJson(role: 'viewer')), 200));
    await tester.pumpAndSettle();
    expect(find.text('viewer'), findsOneWidget);
    session.logout();
    await tester.pumpAndSettle();
  });

  testWidgets('expired session redirects and cannot re-enter Inventory', (
    tester,
  ) async {
    final session = sessionWith(
      (request) async => request.url.path.endsWith('/login')
          ? loginResponse(expires: 2)
          : http.Response(jsonEncode(userJson()), 200),
      clock: () => tester.binding.clock.now(),
    );
    final navigator = GlobalKey<NavigatorState>();
    await session.login('fixtureuser', fakePassword);
    await tester.pumpWidget(
      harness(session, initialRoute: '/inventory', navigatorKey: navigator),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inventory destination'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(LandingScreen), findsOneWidget);
    navigator.currentState!.pushReplacementNamed('/inventory');
    await tester.pumpAndSettle();
    expect(find.text('Inventory destination'), findsNothing);
  });

  testWidgets('existing shell logout clears token; re-entry requires login', (
    tester,
  ) async {
    final session = sessionWith(
      (request) async => request.url.path.endsWith('/login')
          ? loginResponse()
          : http.Response(jsonEncode(userJson()), 200),
    );
    final navigator = GlobalKey<NavigatorState>();
    await session.login('fixtureuser', fakePassword);
    await tester.pumpWidget(
      harness(session, initialRoute: '/inventory', navigatorKey: navigator),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Existing shell logout'));
    await tester.pumpAndSettle();
    expect(session.isAuthenticated, isFalse);
    navigator.currentState!.pushReplacementNamed('/inventory');
    await tester.pumpAndSettle();
    expect(find.byType(LandingScreen), findsOneWidget);
    expect(find.text('Inventory destination'), findsNothing);
  });

  testWidgets(
    'fresh application session after browser refresh cannot restore JWT',
    (tester) async {
      final oldSession = sessionWith((_) async => loginResponse());
      await oldSession.login('fixtureuser', fakePassword);
      final freshSession = sessionWith(
        (_) async => throw StateError('No network expected'),
      );
      await tester.pumpWidget(
        harness(freshSession, initialRoute: '/inventory'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(freshSession.isAuthenticated, isFalse);
      oldSession.logout();
    },
  );

  for (final size in [
    const Size(375, 420),
    const Size(768, 560),
    const Size(1024, 900),
    const Size(1440, 900),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('login layout at $size in ${brightness.name}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = sessionWith((_) async => http.Response('{}', 401));
        await tester.pumpWidget(harness(session, brightness: brightness));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<TextField>(find.byType(TextField).last).obscureText,
          isTrue,
        );
        await tester.ensureVisible(find.byType(TextField).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Show password'));
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField).last).obscureText,
          isFalse,
        );
        await tester.ensureVisible(find.text('Sign In'));
        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle();
        expect(find.text('Enter your username and password.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('username submission moves focus to password without a request', (
    tester,
  ) async {
    var requests = 0;
    final session = sessionWith((_) async {
      requests++;
      return http.Response('{}', 401);
    });
    await tester.pumpWidget(harness(session));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'inventoryadmin');
    tester.widget<TextField>(find.byType(TextField).first).onSubmitted!(
      'inventoryadmin',
    );
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Shared login password',
    );
    expect(requests, 0);
  });

  test(
    'shared app wires guarded Inventory and leaves Marketing route unchanged',
    () {
      final source = File('lib/main.dart').readAsStringSync();
      final webDocument = File('web/index.html').readAsStringSync();
      expect(source, contains("title: 'Smart Omni-Retail'"));
      expect(webDocument, contains('<title>Smart Omni-Retail</title>'));
      expect(
        webDocument,
        contains(
          'name="apple-mobile-web-app-title" content="Smart Omni-Retail"',
        ),
      );
      expect(source, contains("'/login': (context) => InventoryAuthScope("));
      expect(
        source,
        contains("'/inventory': (context) => InventoryAuthenticatedRoute("),
      );
      expect(
        source,
        contains("'/marketing': (context) => MarketingAuthScope("),
      );
      expect(
        source,
        contains('InventorySessionController(api: _inventoryApi)'),
      );
      expect(source, contains('_inventorySession.dispose()'));
    },
  );
}
