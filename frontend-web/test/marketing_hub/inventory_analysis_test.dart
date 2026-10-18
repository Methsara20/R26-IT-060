import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/marketing_hub/core/auth/marketing_session_controller.dart';
import 'package:smart_inventory_web/marketing_hub/models/inventory_analysis_request.dart';
import 'package:smart_inventory_web/marketing_hub/services/inventory_analysis_service.dart';
import 'package:smart_inventory_web/marketing_hub/services/marketing_auth_service.dart';
import 'package:smart_inventory_web/marketing_hub/core/auth/marketing_auth_scope.dart';
import 'package:smart_inventory_web/marketing_hub/screens/inventory_analysis_screen.dart';
import 'package:smart_inventory_web/marketing_hub/widgets/marketing_product_search_selector.dart';

const token = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJtYXJrZXRpbmcifQ.fixture';

Future<MarketingSessionController> signedIn(http.Client client) async {
  final controller = MarketingSessionController(
    api: MarketingAuthService(client: client, baseUrl: 'https://api.example'),
  );
  await controller.login('marketing', 'fixture-password');
  return controller;
}

void main() {
  test(
    'submits exact campaign contract once with Marketing bearer token',
    () async {
      var submits = 0;
      late Map<String, dynamic> submitted;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'access_token': token,
              'token_type': 'bearer',
              'expires_in': 300,
              'username': 'marketing',
              'store_ids': ['CP002'],
              'global_access': false,
            }),
            200,
          );
        }
        submits++;
        expect(request.headers['authorization'], 'Bearer $token');
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            ...submitted,
            'request_id': 'MKT-${'a' * 40}',
            'request_status': 'PENDING_REVIEW',
          }),
          200,
        );
      });
      final session = await signedIn(client);
      final service = InventoryAnalysisService(
        session: session,
        client: client,
        baseUrl: 'https://api.example',
      );
      final result = await service.submit(
        campaignReference: 'CMP-01',
        campaignName: 'Holiday',
        productId: 'P0005',
        storeId: 'CP002',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 7),
        promotionType: 'DISCOUNT',
        discountPercent: 10,
      );
      expect(submits, 1);
      expect(submitted, {
        'campaign_reference': 'CMP-01',
        'campaign_name': 'Holiday',
        'product_id': 'P0005',
        'store_id': 'CP002',
        'campaign_start_date': '2026-11-01',
        'campaign_end_date': '2026-11-07',
        'promotion_type': 'DISCOUNT',
        'discount_percent': 10.0,
      });
      expect(result.status, 'PENDING_REVIEW');
      session.dispose();
    },
  );

  test('history parses bounded persistent results', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response(
          jsonEncode({
            'access_token': token,
            'token_type': 'bearer',
            'expires_in': 300,
            'username': 'marketing',
            'store_ids': ['CP002'],
            'global_access': false,
          }),
          200,
        );
      }
      expect(request.url.queryParameters, {'skip': '0', 'limit': '20'});
      return http.Response(
        jsonEncode({
          'items': [
            {
              'request_id': 'MKT-${'c' * 40}',
              'request_status': 'UNSUPPORTED_PERIOD',
              'campaign_reference': 'Testing',
              'campaign_name': 'Campaign',
              'product_id': 'P0025',
              'store_id': 'CP002',
              'campaign_start_date': '2026-10-20',
              'campaign_end_date': '2026-10-31',
              'assessment': {
                'assessment_status': 'UNSUPPORTED_PERIOD',
                'explanation': 'Period unsupported',
              },
            },
          ],
          'total': 1,
          'skip': 0,
          'limit': 20,
        }),
        200,
      );
    });
    final session = await signedIn(client);
    final service = InventoryAnalysisService(
      session: session,
      client: client,
      baseUrl: 'https://api.example',
    );
    final history = await service.history();
    expect(history.total, 1);
    expect(history.items.single.status, 'UNSUPPORTED_PERIOD');
    expect(history.items.single.assessment!.explanation, 'Period unsupported');
    session.dispose();
  });

  testWidgets('product search finds names and IDs and returns canonical ID', (
    tester,
  ) async {
    MarketingCatalogChoice? selected;
    const products = [
      MarketingCatalogChoice('P0025', 'Hustle Shirt'),
      MarketingCatalogChoice('P0005', 'Emerald Tee'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketingProductSearchSelector(
            products: products,
            selectedProduct: selected,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'P0025');
    await tester.pump();
    expect(find.text('Hustle Shirt'), findsOneWidget);
    await tester.tap(find.text('Hustle Shirt'));
    await tester.pump();
    expect(selected?.id, 'P0025');
  });

  testWidgets(
    'discount without promotion blocks before any submission request',
    (tester) async {
      var submissions = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'access_token': token,
              'token_type': 'bearer',
              'expires_in': 300,
              'username': 'marketing',
              'store_ids': ['CP002'],
              'global_access': false,
            }),
            200,
          );
        }
        if (request.url.path == '/products') {
          return http.Response(
            jsonEncode({
              'products': [
                {'product_id': 'P0025', 'product_name': 'Hustle Shirt'},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/stores/') {
          return http.Response(
            jsonEncode({
              'stores': [
                {'store_id': 'CP002', 'store_name': 'Showroom 2'},
              ],
            }),
            200,
          );
        }
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({'items': [], 'total': 0, 'skip': 0, 'limit': 20}),
            200,
          );
        }
        submissions++;
        return http.Response('{}', 500);
      });
      final session = await signedIn(client);
      final service = InventoryAnalysisService(
        session: session,
        client: client,
        baseUrl: 'https://api.example',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MarketingAuthScope(
            session: session,
            child: InventoryAnalysisScreen(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Discount % (optional)'),
        '10',
      );
      await tester.pump();
      expect(
        find.text('Select a promotion type when entering a discount.'),
        findsWidgets,
      );
      final submit = find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Check with Inventory'),
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(submissions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );

  test('401 clears session while conflict remains authenticated', () async {
    var status = 409;
    final client = MockClient(
      (request) async => request.url.path.endsWith('/login')
          ? http.Response(
              jsonEncode({
                'access_token': token,
                'token_type': 'bearer',
                'expires_in': 300,
                'username': 'marketing',
                'store_ids': [],
                'global_access': true,
              }),
              200,
            )
          : http.Response('{}', status),
    );
    final session = await signedIn(client);
    final service = InventoryAnalysisService(
      session: session,
      client: client,
      baseUrl: 'https://api.example',
    );
    await expectLater(
      service.status('MKT-${'a' * 40}'),
      throwsA(
        isA<InventoryAnalysisException>().having(
          (e) => e.failure,
          'failure',
          InventoryAnalysisFailure.conflict,
        ),
      ),
    );
    expect(session.isAuthenticated, isTrue);
    status = 401;
    await expectLater(
      service.status('MKT-${'a' * 40}'),
      throwsA(
        isA<InventoryAnalysisException>().having(
          (e) => e.failure,
          'failure',
          InventoryAnalysisFailure.invalidSession,
        ),
      ),
    );
    expect(session.isAuthenticated, isFalse);
    session.dispose();
  });

  test('both promotion fields may be omitted', () async {
    late Map<String, dynamic> submitted;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response(
          jsonEncode({
            'access_token': token,
            'token_type': 'bearer',
            'expires_in': 300,
            'username': 'marketing',
            'store_ids': ['CP002'],
            'global_access': false,
          }),
          200,
        );
      }
      submitted = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          ...submitted,
          'request_id': 'MKT-${'b' * 40}',
          'request_status': 'PENDING_REVIEW',
        }),
        200,
      );
    });
    final session = await signedIn(client);
    final service = InventoryAnalysisService(
      session: session,
      client: client,
      baseUrl: 'https://api.example',
    );
    await service.submit(
      campaignReference: 'CMP-02',
      campaignName: 'No promotion',
      productId: 'P0025',
      storeId: 'CP002',
      startDate: DateTime(2026, 10, 20),
      endDate: DateTime(2026, 10, 31),
    );
    expect(submitted.containsKey('promotion_type'), isFalse);
    expect(submitted.containsKey('discount_percent'), isFalse);
    session.dispose();
  });

  test('safe discount validation detail has user-friendly message', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response(
          jsonEncode({
            'access_token': token,
            'token_type': 'bearer',
            'expires_in': 300,
            'username': 'marketing',
            'store_ids': ['CP002'],
            'global_access': false,
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'detail': {
            'code': 'INVALID_MARKETING_REQUEST',
            'errors': [
              {
                'field': 'discount_percent',
                'reason': 'PROMOTION_TYPE_REQUIRED',
              },
            ],
          },
        }),
        422,
      );
    });
    final session = await signedIn(client);
    final service = InventoryAnalysisService(
      session: session,
      client: client,
      baseUrl: 'https://api.example',
    );
    await expectLater(
      service.submit(
        campaignReference: 'Testing',
        campaignName: 'Test Promotion for Hustle',
        productId: 'P0025',
        storeId: 'CP002',
        startDate: DateTime(2026, 10, 20),
        endDate: DateTime(2026, 10, 31),
        discountPercent: 10,
      ),
      throwsA(
        isA<InventoryAnalysisException>().having(
          (e) => e.toString(),
          'message',
          'Select a promotion type when entering a discount.',
        ),
      ),
    );
    expect(session.isAuthenticated, isTrue);
    session.dispose();
  });

  test(
    'legacy COMPLETE is displayed as COMPLETED with baseline assessment',
    () {
      final value = InventoryAnalysisRequest.fromJson({
        'request_id': 'MKT-${'a' * 40}',
        'request_status': 'COMPLETE',
        'product_id': 'P1',
        'store_id': 'CP1',
        'campaign_name': 'Campaign',
        'campaign_reference': 'CAMPAIGN',
        'campaign_start_date': '2026-10-20',
        'campaign_end_date': '2026-10-31',
        'assessment': {
          'available_stock': 12,
          'forecast_demand': 8,
          'assessment_status': 'COMPLETED',
        },
      });
      expect(value.status, 'COMPLETED');
      expect(value.assessment!.availableStock, 12);
    },
  );
}
