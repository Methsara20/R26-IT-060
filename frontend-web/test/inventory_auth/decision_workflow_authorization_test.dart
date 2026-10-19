import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/core/auth/inventory_api_client.dart';
import 'package:smart_inventory_web/core/auth/inventory_auth_scope.dart';
import 'package:smart_inventory_web/core/constants/api_constants.dart';
import 'package:smart_inventory_web/services/decision_workflow_api_service.dart';
import 'package:smart_inventory_web/services/forecast_api_service.dart';
import 'package:smart_inventory_web/services/inventory_auth_api_service.dart';
import 'package:smart_inventory_web/features/forecasting/forecasting_overview_screen.dart';
import 'package:smart_inventory_web/features/workflow/inventory_decision_workflow_controller.dart';
import 'auth_test_support.dart';

const workflow = {
  'workflow_id': 'WF-1',
  'workflow_status': 'COMPLETED',
  'next_action': 'NONE',
  'forecast_type': 'DAILY',
  'store_id': 'S1',
  'product_id': 'P1',
  'forecast_result': {
    'forecast_start_date': '2026-10-17',
    'forecast_end_date': '2026-10-17',
    'forecast_total_demand': 30,
    'forecast_details': {
      'predicted_demand': 30,
      'confidence_percentage': 90,
      'weather': <String, dynamic>{},
    },
  },
  'inventory_snapshot': {
    'current_stock': 80,
    'required_stock_before_demand': 45,
  },
  'inventory_intelligence': {
    'forecast_demand': 30,
    'current_stock': 80,
    'excess_qty': 35,
    'stock_health': 'Overstock',
    'recommended_action': 'PROMOTE',
  },
};
http.Response response(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);
Future<Object> invoke(DecisionWorkflowApiService service, String operation) =>
    switch (operation) {
      'history' => service.getHistory(),
      'details' => service.getWorkflow('WF-1'),
      _ => service.analyze(
        forecastType: 'CUSTOM',
        storeId: 'S1',
        productId: 'P1',
        sellingPrice: 1200,
        promotionPercent: 5,
        idempotencyKey: 'fixture-key',
        startDate: DateTime(2026, 10, 15),
        endDate: DateTime(2026, 10, 16),
      ),
    };
void main() {
  for (final operation in ['analyze', 'history', 'details']) {
    test(
      '$operation attaches JWT and preserves contracts and configured origin',
      () async {
        final session = sessionWith((_) async => loginResponse());
        await session.login('fixtureuser', fakePassword);
        final seen = <http.Request>[];
        final raw = MockClient((request) async {
          seen.add(request);
          return response(operation == 'history' ? [workflow] : workflow);
        });
        addTearDown(raw.close);
        final client = InventoryApiClient(session: session, client: raw);
        addTearDown(client.close);
        final result = await invoke(
          DecisionWorkflowApiService(inventoryClient: client),
          operation,
        );
        expect(result, isNotNull);
        expect(seen, hasLength(1));
        final request = seen.single;
        expect(request.headers['Authorization'], 'Bearer $fakeToken');
        expect(request.url.origin, Uri.parse(ApiConstants.baseUrl).origin);
        expect(request.url.path, switch (operation) {
          'history' => '/decision-workflow/',
          'details' => '/decision-workflow/WF-1',
          _ => '/decision-workflow/analyze',
        });
        expect(request.method, operation == 'analyze' ? 'POST' : 'GET');
        if (operation == 'analyze') {
          expect(jsonDecode(request.body), {
            'forecast_type': 'CUSTOM',
            'store_id': 'S1',
            'product_id': 'P1',
            'selling_price': 1200.0,
            'promotion_percent': 5.0,
            'idempotency_key': 'fixture-key',
            'start_date': '2026-10-15',
            'end_date': '2026-10-16',
          });
        }
      },
    );
    test(
      '$operation blocks missing and expired sessions before dispatch',
      () async {
        var now = DateTime(2026);
        final session = sessionWith(
          (_) async => loginResponse(),
          clock: () => now,
        );
        var calls = 0;
        final raw = MockClient((_) async {
          calls++;
          return response(workflow);
        });
        addTearDown(raw.close);
        final client = InventoryApiClient(session: session, client: raw);
        addTearDown(client.close);
        final service = DecisionWorkflowApiService(inventoryClient: client);
        await expectLater(
          invoke(service, operation),
          throwsA(isA<DecisionWorkflowApiException>()),
        );
        await session.login('fixtureuser', fakePassword);
        now = now.add(const Duration(minutes: 16));
        await expectLater(
          invoke(service, operation),
          throwsA(isA<DecisionWorkflowApiException>()),
        );
        expect(calls, 0);
      },
    );
    for (final status in [401, 403]) {
      test('$operation $status session semantics and no replay', () async {
        final session = sessionWith((_) async => loginResponse());
        await session.login('fixtureuser', fakePassword);
        var calls = 0;
        final raw = MockClient((_) async {
          calls++;
          return response({'detail': 'Access denied.'}, status);
        });
        addTearDown(raw.close);
        final client = InventoryApiClient(session: session, client: raw);
        addTearDown(client.close);
        await expectLater(
          invoke(
            DecisionWorkflowApiService(inventoryClient: client),
            operation,
          ),
          throwsA(isA<DecisionWorkflowApiException>()),
        );
        expect(session.isAuthenticated, status == 403);
        expect(calls, 1);
      });
    }
  }
  test('unrelated endpoints and origins never receive JWT', () async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    var calls = 0;
    final raw = MockClient((_) async {
      calls++;
      return response(workflow);
    });
    addTearDown(raw.close);
    final client = InventoryApiClient(session: session, client: raw);
    addTearDown(client.close);
    for (final url in [
      '${ApiConstants.baseUrl}/marketing/login',
      '${ApiConstants.baseUrl}/auth/login',
      'https://unrelated.invalid/decision-workflow/',
      '${ApiConstants.baseUrl}/decision-workflow/WF-1/execute',
    ]) {
      await expectLater(
        client.get(Uri.parse(url)),
        throwsA(isA<InventoryAuthException>()),
      );
    }
    expect(calls, 0);
  });
  for (final status in [200, 401]) {
    test(
      'stale $status response cannot invalidate replacement session',
      () async {
        final session = sessionWith((_) async => loginResponse());
        await session.login('fixtureuser', fakePassword);
        final pending = Completer<http.Response>();
        final started = Completer<void>();
        final raw = MockClient((_) {
          started.complete();
          return pending.future;
        });
        addTearDown(raw.close);
        final client = InventoryApiClient(session: session, client: raw);
        addTearDown(client.close);
        final check = expectLater(
          invoke(
            DecisionWorkflowApiService(inventoryClient: client),
            'details',
          ),
          throwsA(isA<DecisionWorkflowApiException>()),
        );
        await started.future;
        session.logout();
        await session.login('replacement', fakePassword);
        pending.complete(response(workflow, status));
        await check;
        expect(session.isAuthenticated, isTrue);
      },
    );
  }
  testWidgets('90-second timeout dispatches mutation exactly once', (
    tester,
  ) async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    final pending = Completer<http.Response>();
    var calls = 0;
    final raw = MockClient((_) {
      calls++;
      return pending.future;
    });
    addTearDown(raw.close);
    final client = InventoryApiClient(session: session, client: raw);
    addTearDown(client.close);
    var finished = false;
    final check = expectLater(
      invoke(DecisionWorkflowApiService(inventoryClient: client), 'analyze'),
      throwsA(
        isA<DecisionWorkflowApiException>().having(
          (e) => e.message,
          'message',
          contains('taking too long'),
        ),
      ),
    ).then((_) => finished = true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 89));
    expect(finished, isFalse);
    await tester.pump(const Duration(seconds: 1));
    await check;
    expect(calls, 1);
    pending.complete(response(workflow));
    await tester.pump();
    session.logout();
  });
  testWidgets(
    'Forecasting retries reuse keys; new submissions and sessions discard pending state',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ForecastApiService.clearCatalogCache();
      addTearDown(ForecastApiService.clearCatalogCache);
      final session = sessionWith(
        (_) async => loginResponse(),
        clock: () => tester.binding.clock.now(),
      );
      await session.login('fixtureuser', fakePassword);
      final controller = InventoryDecisionWorkflowController();
      addTearDown(controller.dispose);
      final requests = <http.Request>[];
      final pending = <Completer<http.Response>>[];
      Future<void> tap(String label) async {
        final button = find.text(label);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
      }

      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(splashFactory: NoSplash.splashFactory),
              home: InventoryAuthScope(
                session: session,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: ForecastingOverviewScreen(
                      workflowController: controller,
                      initialStoreId: 'S1',
                      initialProductId: 'P1',
                      onOpenIntelligence: () {},
                      onOpenOptimization: () {},
                      onOpenMovement: () {},
                      onAskAssistant: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await tap('Generate forecast');
          expect(requests, hasLength(1));
          await tester.pump(const Duration(seconds: 90));
          final price = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Selling price',
          );
          await tester.enterText(price, '1201');
          await tap('Retry');
          expect(requests, hasLength(1));
          expect(find.textContaining('selection has changed'), findsOneWidget);
          await tester.enterText(price, '1200');
          await tap('Retry');
          expect(requests, hasLength(2));
          expect(jsonDecode(requests[1].body), jsonDecode(requests[0].body));
          pending[1].complete(response(workflow));
          await tester.pump();
          await tester.pump();
          expect(controller.workflowId, 'WF-1');
          expect(find.text('Send to Marketing'), findsOneWidget);
          expect(find.text('Share with Marketing'), findsNothing);
          await tap('Generate forecast');
          expect(requests, hasLength(3));
          expect(
            jsonDecode(requests[2].body)['idempotency_key'],
            isNot(jsonDecode(requests[0].body)['idempotency_key']),
          );
          session.logout();
          await session.login('replacement', fakePassword);
          await tester.pump();
          expect(controller.current, isNull);
          pending[2].complete(
            response({...workflow, 'workflow_id': 'WF-stale'}),
          );
          pending[0].complete(
            response({...workflow, 'workflow_id': 'WF-timeout'}),
          );
          await tester.pump();
          await tester.pump();
          expect(controller.current, isNull);
          await tap('Generate forecast');
          expect(requests, hasLength(4));
          expect(
            jsonDecode(requests[3].body)['idempotency_key'],
            isNot(jsonDecode(requests[2].body)['idempotency_key']),
          );
          pending[3].complete(response(workflow));
          await tester.pump();
          await tester.pump();
          expect(controller.workflowId, 'WF-1');
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.url.path == '/decision-workflow/analyze') {
            expect(request.headers['Authorization'], 'Bearer $fakeToken');
            requests.add(request);
            final completer = Completer<http.Response>();
            pending.add(completer);
            return completer.future;
          }
          expect(request.headers.containsKey('Authorization'), isFalse);
          if (request.url.path == '/products') {
            return response({
              'products': [
                {
                  'product_id': 'P1',
                  'product_name': 'Fixture',
                  'selling_price': 1200,
                  'category': 'Shoes',
                  'brand': 'Fixture',
                  'gender': 'Unisex',
                },
              ],
            });
          }
          if (request.url.path == '/stores/') {
            return response({
              'stores': [
                {'store_id': 'S1', 'store_name': 'Fixture Store'},
              ],
            });
          }
          throw StateError('Unexpected mocked route');
        }),
      );
      session.logout();
      // Drain the stale fake transport's bounded timeout after disposal.
      await tester.pump(const Duration(seconds: 90));
      expect(tester.takeException(), isNull);
    },
  );
}
