import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/core/auth/inventory_api_client.dart';
import 'package:smart_inventory_web/features/forecasting/forecast_share_action.dart';
import 'package:smart_inventory_web/models/workflow/decision_workflow.dart';
import 'package:smart_inventory_web/services/inventory_forecast_sharing_api_service.dart';
import 'auth_test_support.dart';

DecisionWorkflow workflow({
  String id = 'WF1',
  String type = 'DAILY',
  String status = 'NO_ACTION_REQUIRED',
  bool metadata = true,
}) => DecisionWorkflow.fromJson({
  'workflow_id': id,
  'workflow_status': status,
  'forecast_type': type,
  'store_id': 'S1',
  'product_id': 'P1',
  if (metadata)
    'forecast_result': {
      'forecast_start_date': '2026-10-17',
      'forecast_end_date': '2026-10-19',
      'forecast_total_demand': 12.5,
    },
  if (metadata) 'inventory_snapshot': {'current_stock': 0},
});
http.Response success() => http.Response(
  jsonEncode({
    'share_id': 'FS1',
    'workflow_id': 'WF1',
    'share_status': 'SHARED',
  }),
  200,
);

void main() {
  test('eligibility and optional metadata preserve missing versus zero', () {
    for (final type in ['DAILY', 'SEVEN_DAY', 'CUSTOM']) {
      expect(workflow(type: type).canShareForecast, isTrue);
    }
    for (final type in ['MONTHLY', 'QUARTERLY']) {
      expect(workflow(type: type).canShareForecast, isFalse);
    }
    for (final status in ['PROCESSING', 'FORECAST_READY', 'FAILED']) {
      expect(workflow(status: status).canShareForecast, isFalse);
    }
    expect(workflow(id: '').canShareForecast, isFalse);
    expect(workflow(metadata: false).canShareForecast, isFalse);
    expect(workflow(metadata: false).sharePreview!.stock, isNull);
    expect(workflow().sharePreview!.stock, 0);
    expect(workflow().sharePreview!.demand, 12.5);
  });
  test(
    'authenticated exact payload; missing confirmation sends nothing',
    () async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixtureuser', fakePassword);
      var calls = 0;
      final client = InventoryApiClient(
        session: session,
        client: MockClient((request) async {
          calls++;
          expect(request.method, 'POST');
          expect(
            request.url,
            session.backendUri.resolve('/inventory-marketing/forecast-shares'),
          );
          expect(request.headers['Authorization'], 'Bearer $fakeToken');
          expect(jsonDecode(request.body), {
            'workflow_id': 'WF1',
            'confirmed': true,
          });
          return success();
        }),
      );
      addTearDown(client.close);
      final service = InventoryForecastSharingApiService(client: client);
      await expectLater(
        service.share('WF1', confirmed: false),
        throwsA(isA<ForecastSharingException>()),
      );
      await expectLater(
        service.share('', confirmed: true),
        throwsA(isA<ForecastSharingException>()),
      );
      expect(calls, 0);
      await service.share('WF1', confirmed: true);
      expect(calls, 1);
    },
  );
  for (final status in [401, 403, 404, 409, 422, 503]) {
    test('status $status sanitized, no retry', () async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixtureuser', fakePassword);
      var calls = 0;
      final client = InventoryApiClient(
        session: session,
        client: MockClient((_) async {
          calls++;
          return http.Response('private details', status);
        }),
      );
      addTearDown(client.close);
      await expectLater(
        InventoryForecastSharingApiService(
          client: client,
        ).share('WF1', confirmed: true),
        throwsA(
          isA<ForecastSharingException>().having(
            (e) => e.message,
            'sanitized',
            isNot(contains('private details')),
          ),
        ),
      );
      expect(calls, 1);
      expect(session.isAuthenticated, status != 401);
    });
  }
  test('expired session rejected before dispatch', () async {
    var now = DateTime(2026);
    final session = sessionWith((_) async => loginResponse(), clock: () => now);
    await session.login('fixtureuser', fakePassword);
    now = now.add(const Duration(hours: 1));
    var calls = 0;
    final client = InventoryApiClient(
      session: session,
      client: MockClient((_) async {
        calls++;
        return success();
      }),
    );
    addTearDown(client.close);
    await expectLater(
      InventoryForecastSharingApiService(
        client: client,
      ).share('WF1', confirmed: true),
      throwsA(isA<ForecastSharingException>()),
    );
    expect(calls, 0);
  });
  test('network failure sanitized without retry', () async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    var calls = 0;
    final client = InventoryApiClient(
      session: session,
      client: MockClient((_) async {
        calls++;
        throw http.ClientException('private');
      }),
    );
    addTearDown(client.close);
    await expectLater(
      InventoryForecastSharingApiService(
        client: client,
      ).share('WF1', confirmed: true),
      throwsA(
        isA<ForecastSharingException>().having(
          (e) => e.message,
          'message',
          contains('no automatic retry'),
        ),
      ),
    );
    expect(calls, 1);
  });
  for (final width in [360.0, 1100.0]) {
    testWidgets('confirmation cancel and share responsive $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixtureuser', fakePassword);
      var calls = 0;
      final pending = Completer<http.Response>();
      final client = InventoryApiClient(
        session: session,
        client: MockClient((_) {
          calls++;
          return pending.future;
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForecastShareAction(
              workflow: workflow(),
              session: session,
              service: InventoryForecastSharingApiService(client: client),
              productName: 'Product',
              storeName: 'Showroom',
            ),
          ),
        ),
      );
      await tester.tap(find.text('Share with Marketing'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.textContaining('Product (P1)'), findsOneWidget);
      expect(find.textContaining('2026-10-17 to 2026-10-19'), findsOneWidget);
      expect(find.textContaining('12.5'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('Share with Marketing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Share'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      pending.complete(success());
      await tester.pumpAndSettle();
      expect(find.text('Forecast shared or already shared.'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      session.logout();
    });
  }
  for (final role in ['admin', 'manager', 'analyst', 'operator', 'viewer']) {
    testWidgets('role $role respects sharing permission', (tester) async {
      final session = sessionWith(
        (_) async => loginResponse(user: userJson(role: role)),
      );
      await session.login('fixtureuser', fakePassword);
      final client = InventoryApiClient(
        session: session,
        client: MockClient((_) async => throw StateError('no request')),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForecastShareAction(
              workflow: workflow(),
              session: session,
              service: InventoryForecastSharingApiService(client: client),
            ),
          ),
        ),
      );
      expect(
        find.text('Share with Marketing'),
        ['admin', 'manager', 'analyst'].contains(role)
            ? findsOneWidget
            : findsNothing,
      );
      session.logout();
    });
  }
  testWidgets('unrelated store hides sharing action', (tester) async {
    final session = sessionWith(
      (_) async => loginResponse(user: userJson(stores: ['OTHER'])),
    );
    await session.login('fixtureuser', fakePassword);
    final client = InventoryApiClient(
      session: session,
      client: MockClient((_) async => http.Response('', 503)),
    );
    addTearDown(client.close);
    Widget screen(DecisionWorkflow value) => MaterialApp(
      home: Scaffold(
        body: ForecastShareAction(
          key: ValueKey(value.id),
          workflow: value,
          session: session,
          service: InventoryForecastSharingApiService(client: client),
        ),
      ),
    );
    await tester.pumpWidget(screen(workflow()));
    expect(find.text('Share with Marketing'), findsNothing);
    session.logout();
  });
  testWidgets('missing reference and unavailable service feedback', (
    tester,
  ) async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    final client = InventoryApiClient(
      session: session,
      client: MockClient((_) async => http.Response('', 503)),
    );
    addTearDown(client.close);
    Widget screen(DecisionWorkflow value) => MaterialApp(
      home: Scaffold(
        body: ForecastShareAction(
          key: ValueKey(value.id),
          workflow: value,
          session: session,
          service: InventoryForecastSharingApiService(client: client),
        ),
      ),
    );
    await tester.pumpWidget(screen(workflow(id: '')));
    expect(
      find.textContaining('valid stored workflow reference'),
      findsOneWidget,
    );
    expect(find.text('Share with Marketing'), findsNothing);
    await tester.pumpWidget(screen(workflow()));
    await tester.tap(find.text('Share with Marketing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Share'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('service or storage is unavailable'),
      findsOneWidget,
    );
    session.logout();
  });
  testWidgets('session change during confirmation sends nothing', (
    tester,
  ) async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    var calls = 0;
    final client = InventoryApiClient(
      session: session,
      client: MockClient((_) async {
        calls++;
        return success();
      }),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForecastShareAction(
            workflow: workflow(),
            session: session,
            service: InventoryForecastSharingApiService(client: client),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share with Marketing'));
    await tester.pumpAndSettle();
    session.logout();
    await tester.tap(find.text('Confirm Share'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });
}
