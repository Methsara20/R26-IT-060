import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/core/auth/inventory_api_client.dart';
import 'package:smart_inventory_web/core/auth/inventory_auth_scope.dart';
import 'package:smart_inventory_web/features/marketing_requests/marketing_requests_screen.dart';
import 'package:smart_inventory_web/services/inventory_marketing_review_api_service.dart';
import 'auth_test_support.dart';

Map<String, dynamic> requestJson({String status = 'PENDING_REVIEW'}) => {
  'request_id': 'REQ-1',
  'campaign_reference': 'CAM-1',
  'campaign_name': 'Spring Campaign',
  'product_id': 'P0005',
  'store_id': 'CP003',
  'campaign_start_date': '2026-10-20',
  'campaign_end_date': '2026-10-25',
  'promotion_type': 'PERCENT_DISCOUNT',
  'discount_percent': 10,
  'request_status': status,
  if (status == 'COMPLETED')
    'assessment': {
      'available_stock': 42,
      'forecast_demand': 30,
      'forecast_start_date': '2026-10-20',
      'forecast_end_date': '2026-10-25',
      'forecast_basis': 'BASELINE_NO_PROMOTION',
      'promotion_adjusted': false,
      'stock_sufficiency': 'SUFFICIENT',
      'assessment_status': 'COMPLETED',
      'explanation': 'Baseline only.',
    },
};

void main() {
  test(
    'service maps list, legacy COMPLETE, and exact mutation bodies',
    () async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixture', fakePassword);
      final requests = <http.Request>[];
      final client = InventoryApiClient(
        session: session,
        client: MockClient((r) async {
          requests.add(r);
          if (r.url.path.endsWith('/reject')) {
            expect(jsonDecode(r.body), {'reason': 'Not suitable'});
          }
          if (r.url.path == '/inventory-marketing/campaign-reviews') {
            return http.Response(
              jsonEncode({
                'items': [requestJson(status: 'COMPLETE')],
                'total': 1,
                'skip': 0,
                'limit': 50,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(
              requestJson(
                status: r.url.path.endsWith('/reject')
                    ? 'REJECTED'
                    : 'COMPLETED',
              ),
            ),
            200,
          );
        }),
      );
      final api = InventoryMarketingReviewApiService(
        client: client,
        session: session,
      );
      expect((await api.list()).items.single.status, 'COMPLETED');
      await api.accept('REQ-1');
      await api.reject('REQ-1', 'Not suitable');
      expect(requests.where((r) => r.method == 'POST').length, 2);
      session.logout();
    },
  );

  for (final role in ['admin', 'manager', 'analyst']) {
    testWidgets('$role views requests and decision controls follow role', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = sessionWith(
        (_) async => loginResponse(
          user: userJson(role: role, stores: ['CP003']),
        ),
      );
      await session.login('fixture', fakePassword);
      var mutationCount = 0;
      final client = InventoryApiClient(
        session: session,
        client: MockClient((r) async {
          if (r.method == 'POST') mutationCount++;
          if (r.url.path == '/inventory-marketing/campaign-reviews') {
            return http.Response(
              jsonEncode({
                'items': [requestJson()],
                'total': 1,
                'skip': 0,
                'limit': 50,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(
              requestJson(
                status: r.method == 'POST' ? 'COMPLETED' : 'PENDING_REVIEW',
              ),
            ),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryAuthScope(
            session: session,
            child: Scaffold(
              body: SingleChildScrollView(
                child: MarketingRequestsScreen(client: client),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Spring Campaign'), findsOneWidget);
      expect(find.text('All on this page'), findsOneWidget);
      await tester.tap(find.text('Spring Campaign'));
      await tester.pumpAndSettle();
      if (role == 'analyst') {
        expect(find.text('Generate Forecast'), findsNothing);
        expect(find.text('Reject'), findsNothing);
      } else {
        await tester.tap(find.text('Generate Forecast'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Run a baseline stock and demand assessment'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(mutationCount, 0);
      }
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      session.logout();
    });
  }

  testWidgets('reject requires reason and sends once', (tester) async {
    final session = sessionWith(
      (_) async => loginResponse(
        user: userJson(role: 'manager', stores: ['CP003']),
      ),
    );
    await session.login('fixture', fakePassword);
    var rejects = 0;
    final client = InventoryApiClient(
      session: session,
      client: MockClient((r) async {
        if (r.method == 'POST') {
          rejects++;
          return http.Response(
            jsonEncode(requestJson(status: 'REJECTED')),
            200,
          );
        }
        if (r.url.path == '/inventory-marketing/campaign-reviews') {
          return http.Response(
            jsonEncode({
              'items': [requestJson()],
              'total': 1,
              'skip': 0,
              'limit': 50,
            }),
            200,
          );
        }
        return http.Response(jsonEncode(requestJson()), 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryAuthScope(
          session: session,
          child: Scaffold(
            body: SingleChildScrollView(
              child: MarketingRequestsScreen(client: client),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Spring Campaign'));
    await tester.tap(find.text('Spring Campaign'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm rejection'));
    await tester.pump();
    expect(find.text('Enter a meaningful reason.'), findsOneWidget);
    expect(rejects, 0);
    await tester.enterText(
      find.widgetWithText(TextField, 'Rejection reason'),
      'Campaign dates conflict',
    );
    await tester.tap(find.text('Confirm rejection'));
    await tester.pumpAndSettle();
    expect(rejects, 1);
    session.logout();
  });

  testWidgets('completed assessment is explicitly baseline', (tester) async {
    final session = sessionWith(
      (_) async => loginResponse(
        user: userJson(role: 'analyst', stores: ['CP003']),
      ),
    );
    await session.login('fixture', fakePassword);
    final client = InventoryApiClient(
      session: session,
      client: MockClient(
        (r) async => http.Response(
          jsonEncode(
            r.url.path == '/inventory-marketing/campaign-reviews'
                ? {
                    'items': [requestJson(status: 'COMPLETED')],
                    'total': 1,
                    'skip': 0,
                    'limit': 50,
                  }
                : requestJson(status: 'COMPLETED'),
          ),
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryAuthScope(
          session: session,
          child: Scaffold(
            body: SingleChildScrollView(
              child: MarketingRequestsScreen(client: client),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Spring Campaign'));
    await tester.tap(find.text('Spring Campaign'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('not a promotion-adjusted prediction'),
      findsOneWidget,
    );
    expect(find.text('Available stock'), findsOneWidget);
    expect(find.text('42.0'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    session.logout();
  });

  testWidgets('searches and filters only the loaded page', (tester) async {
    final session = sessionWith(
      (_) async => loginResponse(
        user: userJson(role: 'manager', stores: ['CP003']),
      ),
    );
    await session.login('fixture', fakePassword);
    final second = {
      ...requestJson(status: 'FAILED'),
      'request_id': 'REQ-SECOND',
      'campaign_reference': 'CAM-WINTER',
      'campaign_name': 'Winter Launch',
      'product_id': 'P0099',
      'store_id': 'CP004',
    };
    final client = InventoryApiClient(
      session: session,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'items': [requestJson(), second],
            'total': 2,
            'skip': 0,
            'limit': 50,
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryAuthScope(
          session: session,
          child: Scaffold(
            body: SingleChildScrollView(
              child: MarketingRequestsScreen(client: client),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MARKETING CAMPAIGN REVIEW'), findsOneWidget);
    expect(find.text('2 of 2 loaded requests shown'), findsOneWidget);
    expect(
      find.textContaining('currently loaded page'),
      findsAtLeastNWidgets(1),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Search loaded requests'),
      'P0099',
    );
    await tester.pump();
    expect(find.text('Winter Launch'), findsOneWidget);
    expect(find.text('Spring Campaign'), findsNothing);
    expect(find.text('1 of 2 loaded requests shown'), findsOneWidget);

    await tester.ensureVisible(find.text('Clear filters'));
    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.text('Spring Campaign'), findsOneWidget);
    final failedFilter = find.widgetWithText(FilterChip, 'Failed');
    await tester.ensureVisible(failedFilter);
    await tester.tap(failedFilter);
    await tester.pump();
    expect(find.text('Winter Launch'), findsOneWidget);
    expect(find.text('Spring Campaign'), findsNothing);
    session.logout();
  });

  testWidgets('filtered empty state can clear filters', (tester) async {
    final session = sessionWith(
      (_) async => loginResponse(user: userJson(role: 'analyst')),
    );
    await session.login('fixture', fakePassword);
    final client = InventoryApiClient(
      session: session,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'items': [requestJson()],
            'total': 1,
            'skip': 0,
            'limit': 50,
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryAuthScope(
          session: session,
          child: Scaffold(
            body: SingleChildScrollView(
              child: MarketingRequestsScreen(client: client),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search loaded requests'),
      'no-match',
    );
    await tester.pump();
    expect(find.text('No requests match these filters'), findsOneWidget);
    await tester.ensureVisible(find.text('Clear filters').last);
    await tester.tap(find.text('Clear filters').last);
    await tester.pump();
    expect(find.text('Spring Campaign'), findsOneWidget);
    session.logout();
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        'premium request directory renders at ${width.toInt()} in ${brightness.name}',
        (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final session = sessionWith(
            (_) async => loginResponse(
              user: userJson(role: 'manager', stores: ['CP003']),
            ),
          );
          await session.login('fixture', fakePassword);
          final longRequest = {
            ...requestJson(),
            'campaign_name':
                'A long campaign request name for responsive layout verification',
            'campaign_reference': 'CAMPAIGN-REFERENCE-WITH-LONG-CONTENT',
          };
          final client = InventoryApiClient(
            session: session,
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'items': [longRequest],
                  'total': 1,
                  'skip': 0,
                  'limit': 50,
                }),
                200,
              ),
            ),
          );
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
                  body: SingleChildScrollView(
                    child: InventoryAuthScope(
                      session: session,
                      child: MarketingRequestsScreen(client: client),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('MARKETING CAMPAIGN REVIEW'), findsOneWidget);
          expect(find.text('Current-page overview'), findsOneWidget);
          expect(find.text('Pending review'), findsAtLeastNWidgets(1));
          expect(tester.takeException(), isNull);
          session.logout();
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
