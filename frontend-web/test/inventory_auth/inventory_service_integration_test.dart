import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/core/auth/inventory_api_client.dart';
import 'package:smart_inventory_web/core/auth/inventory_auth_scope.dart';
import 'package:smart_inventory_web/core/constants/api_constants.dart';
import 'package:smart_inventory_web/services/forecast_api_service.dart';
import 'package:smart_inventory_web/services/optimization_api_service.dart';
import 'package:smart_inventory_web/services/stock_movement_api_service.dart';
import 'package:smart_inventory_web/features/assistant/manager_assistant_screen.dart';
import 'package:smart_inventory_web/features/optimization/optimization_candidates_screen.dart';
import 'package:smart_inventory_web/features/stock_movements/stock_movements_screen.dart';
import 'package:smart_inventory_web/features/forecasting/forecasting_overview_screen.dart';
import 'package:smart_inventory_web/features/forecasting/inventory_period_forecast_panel.dart';
import 'package:smart_inventory_web/features/workflow/inventory_decision_workflow_controller.dart';
import 'package:smart_inventory_web/models/forecast/forecast_catalog_option.dart';
import 'auth_test_support.dart';

const candidate = {
  'candidate_id': 'C1',
  'product_id': 'P1',
  'store_id': 'S1',
  'current_stock': 12,
};
const movement = {
  'movement_id': 'M1',
  'candidate_id': 'C1',
  'movement_status': 'APPROVED',
  'from_store': 'S1',
  'to_store': 'S2',
  'recommended_qty': 7,
};
const day = {
  'predicted_demand': 11,
  'confidence_percentage': 83,
  'weather': <String, dynamic>{},
};
Map<String, dynamic> forecast(String type) => {
  'forecast_type': type,
  'store_id': 'S1',
  'product_id': 'P1',
  if (type == 'daily')
    ...day
  else ...{
    'forecast': [day],
    'total_predicted_demand': 11,
    'average_confidence_percentage': 83,
  },
};
http.Response jsonResponse(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);
Future<dynamic> invoke(String service, InventoryApiClient client) =>
    switch (service) {
      'forecast' =>
        ForecastApiService(inventoryClient: client).createShortRangeForecast(
          sevenDay: false,
          storeId: 'S1',
          productId: 'P1',
          priceLkr: 1200,
          promotionPercent: 5,
        ),
      'optimization' => OptimizationApiService(
        client: client,
      ).analyzeCandidate('C1'),
      _ => StockMovementApiService(client: client).execute('M1'),
    };
Matcher serviceError(String service) => switch (service) {
  'forecast' => isA<ForecastApiException>(),
  'optimization' => isA<OptimizationApiException>(),
  _ => isA<StockMovementApiException>(),
};

void main() {
  for (final service in ['forecast', 'optimization', 'movement']) {
    test('$service missing and expired sessions never dispatch', () async {
      var now = DateTime(2026);
      final session = sessionWith(
        (_) async => loginResponse(),
        clock: () => now,
      );
      var requests = 0;
      final raw = MockClient((_) async {
        requests++;
        return jsonResponse({});
      });
      addTearDown(raw.close);
      final client = InventoryApiClient(session: session, client: raw);
      addTearDown(client.close);
      await expectLater(
        invoke(service, client),
        throwsA(serviceError(service)),
      );
      await session.login('fixtureuser', fakePassword);
      now = now.add(const Duration(minutes: 16));
      await expectLater(
        invoke(service, client),
        throwsA(serviceError(service)),
      );
      expect(requests, 0);
    });
    for (final status in [401, 403, 503]) {
      test(
        '$service status $status preserves session policy and never retries',
        () async {
          final session = sessionWith((_) async => loginResponse());
          await session.login('fixtureuser', fakePassword);
          var requests = 0;
          final raw = MockClient((request) async {
            requests++;
            expect(request.headers['authorization'], 'Bearer $fakeToken');
            expect(request.url.origin, Uri.parse(ApiConstants.baseUrl).origin);
            return jsonResponse({
              'detail': status == 503
                  ? 'Service unavailable'
                  : 'untrusted detail',
            }, status);
          });
          addTearDown(raw.close);
          final client = InventoryApiClient(session: session, client: raw);
          addTearDown(client.close);
          await expectLater(
            invoke(service, client),
            throwsA(serviceError(service)),
          );
          expect(requests, 1);
          expect(session.isAuthenticated, status != 401);
        },
      );
    }
    test(
      '$service discards late response after logout and new login',
      () async {
        final session = sessionWith((_) async => loginResponse());
        await session.login('fixtureuser', fakePassword);
        final pending = Completer<http.Response>();
        final raw = MockClient((_) => pending.future);
        addTearDown(raw.close);
        final client = InventoryApiClient(session: session, client: raw);
        addTearDown(client.close);
        final result = invoke(service, client);
        final check = expectLater(result, throwsA(serviceError(service)));
        await Future<void>.delayed(Duration.zero);
        session.logout();
        await session.login('fixtureuser', fakePassword);
        pending.complete(
          jsonResponse(
            service == 'forecast'
                ? forecast('daily')
                : service == 'optimization'
                ? {'candidate': candidate}
                : movement,
          ),
        );
        await check;
        expect(session.isAuthenticated, isTrue);
      },
    );
  }

  test(
    'optimization summary, candidates and analysis preserve contracts and bearer',
    () async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixtureuser', fakePassword);
      final seen = <http.Request>[];
      final raw = MockClient((request) async {
        seen.add(request);
        expect(request.headers['authorization'], 'Bearer $fakeToken');
        return jsonResponse(switch (request.url.path) {
          '/optimization-candidates/summary' => {'total_candidates': 1},
          '/optimization-candidates/' => {
            'candidates': [candidate],
          },
          _ => {'candidate': candidate},
        });
      });
      addTearDown(raw.close);
      final client = InventoryApiClient(session: session, client: raw);
      addTearDown(client.close);
      final service = OptimizationApiService(client: client);
      final overview = await service.getOverview();
      expect(overview.summary.total, 1);
      expect(overview.candidates.single.id, 'C1');
      final result = await service.analyzeCandidate('C1');
      expect(result.currentStock, 12);
      expect(seen.map((r) => r.method), ['GET', 'GET', 'POST']);
      expect(seen.last.body, '');
    },
  );

  test(
    'movement reads and every mutation preserve methods, payloads and response',
    () async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixtureuser', fakePassword);
      final seen = <http.Request>[];
      final raw = MockClient((request) async {
        seen.add(request);
        expect(request.headers['authorization'], 'Bearer $fakeToken');
        return jsonResponse(
          request.url.path == '/stock-movement/'
              ? {
                  'movements': [movement],
                }
              : movement,
        );
      });
      addTearDown(raw.close);
      final client = InventoryApiClient(session: session, client: raw);
      addTearDown(client.close);
      final service = StockMovementApiService(client: client);
      expect((await service.getMovements()).single.movementId, 'M1');
      expect((await service.getMovement('M1')).recommendedQuantity, 7);
      expect((await service.recommendTransfer('C1')).fromStore, 'S1');
      await service.approve('M1');
      await service.reject('M1', 'review');
      await service.cancel('M1', 'cancel reason');
      expect((await service.execute('M1')).toStore, 'S2');
      expect(seen.map((r) => r.method), [
        'GET',
        'GET',
        'POST',
        'POST',
        'POST',
        'POST',
        'POST',
      ]);
      expect(seen.skip(2).map((r) => jsonDecode(r.body)), [
        {},
        {'is_approved': true},
        {'is_rejected': true, 'rejection_reason': 'review'},
        {'is_cancelled': true, 'cancel_reason': 'cancel reason'},
        {'is_executed': true},
      ]);
    },
  );

  test(
    'forecast endpoints preserve payloads and parsed results; catalog is token-free',
    () async {
      final session = sessionWith((_) async => loginResponse());
      await session.login('fixtureuser', fakePassword);
      ForecastApiService.clearCatalogCache();
      addTearDown(ForecastApiService.clearCatalogCache);
      final seen = <http.Request>[];
      final raw = MockClient((request) async {
        seen.add(request);
        if (request.method == 'GET') {
          expect(request.headers.containsKey('authorization'), isFalse);
          return jsonResponse(
            request.url.path == '/products' ? {'products': []} : {'stores': []},
          );
        }
        expect(request.headers['authorization'], 'Bearer $fakeToken');
        expect(request.headers['content-type'], contains('application/json'));
        final path = request.url.path;
        if (path.contains('/inventory/')) {
          final quarterly = path.contains('quarterly');
          return jsonResponse({
            'forecast_type': quarterly
                ? 'inventory_quarterly_auto'
                : 'inventory_monthly_auto',
            'store_id': 'S1',
            'category': 'Shoes',
            'brand': 'Fixture',
            'gender': 'Unisex',
            if (quarterly) ...{
              'monthly_forecasts': [],
              'predicted_quarterly_demand': 30,
              'average_confidence_percentage': 80,
            } else ...{
              'year': 2026,
              'month': 3,
              'predicted_monthly_demand': 10,
              'confidence_percentage': 80,
              'weather_profile': {},
            },
          });
        }
        return jsonResponse(
          forecast(path.endsWith('/daily') ? 'daily' : 'custom'),
        );
      });
      addTearDown(raw.close);
      final client = InventoryApiClient(session: session, client: raw);
      addTearDown(client.close);
      final service = ForecastApiService(client: raw, inventoryClient: client);
      expect((await service.getCatalog()).products, isEmpty);
      for (final sevenDay in [false, true]) {
        final result = await service.createShortRangeForecast(
          sevenDay: sevenDay,
          storeId: 'S1',
          productId: 'P1',
          priceLkr: 1200,
          promotionPercent: 5,
        );
        expect(result.totalPredictedDemand, 11);
        expect(jsonDecode(seen.last.body), containsPair('price_lkr', 1200));
        expect(
          seen.last.url.path,
          sevenDay ? '/forecast/7-day' : '/forecast/daily',
        );
      }
      await service.createCustomForecast(
        storeId: 'S1',
        productId: 'P1',
        priceLkr: 1200,
        promotionPercent: 5,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 2),
      );
      expect(
        jsonDecode(seen.last.body),
        containsPair('start_date', '2026-03-01'),
      );
      for (final quarterly in [false, true]) {
        final result = await service.createInventoryPeriodForecast(
          quarterly: quarterly,
          storeId: 'S1',
          category: 'Shoes',
          brand: 'Fixture',
          gender: 'Unisex',
          year: 2026,
          period: 3,
        );
        expect(result.totalPredictedDemand, quarterly ? 30 : 10);
        expect(
          jsonDecode(seen.last.body),
          containsPair(quarterly ? 'quarter' : 'month', 3),
        );
      }
      expect(seen.length, 7);
    },
  );

  test(
    'catalog-only constructor cannot silently send unauthenticated forecasts',
    () async {
      var requests = 0;
      final raw = MockClient((_) async {
        requests++;
        return jsonResponse({});
      });
      addTearDown(raw.close);
      final service = ForecastApiService(client: raw);
      await expectLater(
        service.createShortRangeForecast(
          sevenDay: false,
          storeId: 'S1',
          productId: 'P1',
          priceLkr: 1,
          promotionPercent: 0,
        ),
        throwsA(isA<ForecastApiException>()),
      );
      expect(requests, 0);
    },
  );

  testWidgets('movement timeout remains outcome-unknown and dispatches once', (
    tester,
  ) async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    final pending = Completer<http.Response>();
    var requests = 0;
    final raw = MockClient((_) {
      requests++;
      return pending.future;
    });
    addTearDown(raw.close);
    final client = InventoryApiClient(session: session, client: raw);
    addTearDown(client.close);
    final check = expectLater(
      StockMovementApiService(client: client).execute('M1'),
      throwsA(isA<StockMovementOutcomeUnknownException>()),
    );
    await tester.pump(const Duration(seconds: 21));
    await check;
    expect(requests, 1);
    pending.complete(jsonResponse(movement));
    await tester.pump();
    session.logout();
  });

  for (final screen in [
    'optimization',
    'movements',
    'assistant',
    'forecast',
    'period',
  ]) {
    testWidgets(
      '$screen screen obtains current scope client without altering other transports',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ForecastApiService.clearCatalogCache();
        addTearDown(ForecastApiService.clearCatalogCache);
        final session = sessionWith((_) async => loginResponse());
        await session.login('fixtureuser', fakePassword);
        final workflow = InventoryDecisionWorkflowController();
        addTearDown(workflow.dispose);
        final seen = <http.Request>[];
        await http.runWithClient(
          () async {
            final child = switch (screen) {
              'optimization' => OptimizationCandidatesScreen(
                workflowController: workflow,
                onOpenMovement: () {},
              ),
              'movements' => StockMovementsScreen(
                workflowController: workflow,
                onOpenAnalytics: () {},
                onAskAssistant: () {},
              ),
              'assistant' => ManagerAssistantScreen(
                workflowController: workflow,
              ),
              'forecast' => ForecastingOverviewScreen(
                workflowController: workflow,
                onOpenIntelligence: () {},
                onOpenOptimization: () {},
                onOpenMovement: () {},
                onAskAssistant: () {},
              ),
              _ => const InventoryPeriodForecastPanel(
                catalog: ForecastCatalog(products: [], stores: []),
                quarterly: false,
                onStartOperationalWorkflow: ignoreWorkflow,
              ),
            };
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(splashFactory: NoSplash.splashFactory),
                home: InventoryAuthScope(
                  session: session,
                  child: Scaffold(body: SingleChildScrollView(child: child)),
                ),
              ),
            );
            // Assistant decoration may animate continuously after loading.
            for (var frame = 0; frame < 5; frame++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(tester.takeException(), isNull);
            expect(find.byType(CircularProgressIndicator), findsNothing);
            if (screen == 'assistant') {
              expect(
                seen.map((r) => r.url.path),
                containsAll(['/manager-assistant/history', '/stock-movement/']),
              );
            }
            if (screen == 'movements') {
              expect(seen.single.url.path, '/stock-movement/');
            }
            if (screen == 'optimization') expect(seen.length, 2);
            if (screen == 'forecast') expect(seen.length, 2);
            await tester.pumpWidget(const SizedBox.shrink());
          },
          () => MockClient((request) async {
            seen.add(request);
            final path = request.url.path;
            final protected =
                path.startsWith('/stock-movement') ||
                path.startsWith('/optimization-candidates');
            expect(
              request.headers['authorization'],
              protected ? 'Bearer $fakeToken' : isNull,
            );
            return jsonResponse(switch (path) {
              '/stock-movement/' => {'movements': []},
              '/optimization-candidates/summary' => {'total_candidates': 0},
              '/optimization-candidates/' => {'candidates': []},
              '/manager-assistant/history' => [],
              '/products' => {'products': []},
              '/stores/' => {'stores': []},
              _ => throw StateError('Unexpected test endpoint'),
            });
          }),
        );
        session.logout();
      },
    );
  }
}

void ignoreWorkflow(ForecastStoreOption store, ForecastProductOption product) {}
