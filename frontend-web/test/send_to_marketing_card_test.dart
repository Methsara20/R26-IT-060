import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/core/auth/inventory_session_controller.dart';
import 'package:smart_inventory_web/features/marketing_integration/models/marketing_opportunity.dart';
import 'package:smart_inventory_web/features/marketing_integration/services/marketing_opportunity_api_service.dart';
import 'package:smart_inventory_web/features/marketing_integration/widgets/send_to_marketing_card.dart';
import 'package:smart_inventory_web/models/workflow/decision_workflow.dart';

import 'inventory_auth/auth_test_support.dart';

void main() {
  const promoteRequest = MarketingOpportunityRequest(
    workflowId: 'WF-1',
    productId: 'P-1',
    productName: 'Classic Shirt',
    storeId: 'S-1',
    category: 'Apparel',
    brand: 'North',
    gender: 'Unisex',
    currentStock: 80,
    forecastDemand: 30,
    requiredStock: 45,
    excessQuantity: 35,
    sellingPrice: 2500,
    stockHealth: 'Overstock',
    recommendedAction: 'PROMOTE',
  );

  test('serializes a real promotion and omits an absent promotion', () {
    final promotedJson = const MarketingOpportunityRequest(
      workflowId: 'WF-15',
      productId: 'P-1',
      productName: 'Classic Shirt',
      storeId: 'S-1',
      currentStock: 80,
      forecastDemand: 30,
      requiredStock: 45,
      excessQuantity: 35,
      sellingPrice: 2500,
      promotionPercent: 15,
      stockHealth: 'Overstock',
      recommendedAction: 'PROMOTE',
    ).toJson();
    expect(promotedJson['promotion_percent'], 15);
    expect(promoteRequest.toJson().containsKey('promotion_percent'), isFalse);
  });

  testWidgets('review dialog shows available forecast context', (tester) async {
    const request = MarketingOpportunityRequest(
      workflowId: 'WF-15',
      productId: 'P-1',
      productName: 'Classic Shirt',
      storeId: 'S-1',
      currentStock: 80,
      forecastDemand: 30,
      requiredStock: 45,
      excessQuantity: 35,
      promotionPercent: 15,
      stockHealth: 'Overstock',
      recommendedAction: 'PROMOTE',
    );
    await tester.pumpWidget(
      _app(
        request,
        showroomName: 'Central Showroom',
        preview: ForecastSharePreview(
          start: DateTime(2026, 10, 17),
          end: DateTime(2026, 10, 19),
          demand: 30,
          stock: 80,
        ),
      ),
    );
    expect(find.text('Forecast Promotion Scenario: 15%'), findsOneWidget);
    await tester.tap(find.text('Send to Marketing'));
    await tester.pumpAndSettle();
    expect(find.text('Classic Shirt'), findsOneWidget);
    expect(find.text('Central Showroom (S-1)'), findsOneWidget);
    expect(find.text('2026-10-17 to 2026-10-19'), findsOneWidget);
    expect(find.text('30 units'), findsOneWidget);
    expect(find.text('80 units'), findsOneWidget);
    expect(find.text('PROMOTE'), findsOneWidget);
    expect(find.text('Promotion Scenario'), findsOneWidget);
    expect(find.text('15%'), findsOneWidget);
    expect(find.textContaining('No promotion or campaign'), findsOneWidget);
  });

  testWidgets('shows only for a PROMOTE recommendation', (tester) async {
    await tester.pumpWidget(_app(promoteRequest));
    expect(find.text('Send to Marketing'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        const MarketingOpportunityRequest(
          workflowId: 'WF-2',
          productId: 'P-1',
          productName: 'Classic Shirt',
          storeId: 'S-1',
          currentStock: 10,
          forecastDemand: 30,
          requiredStock: 40,
          excessQuantity: 0,
          stockHealth: 'Understock',
          recommendedAction: 'REORDER',
        ),
      ),
    );
    expect(find.text('Send to Marketing'), findsNothing);
  });

  testWidgets('cancel does not submit a request', (tester) async {
    var calls = 0;
    final service = MarketingOpportunityApiService(
      client: MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await tester.pumpWidget(_app(promoteRequest, service: service));
    await tester.tap(find.text('Send to Marketing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('confirmation publishes exactly once with the existing payload', (
    tester,
  ) async {
    var calls = 0;
    http.Request? sent;
    final service = MarketingOpportunityApiService(
      client: MockClient((request) async {
        calls++;
        sent = request;
        return http.Response(
          '{"opportunity_id":"MKT-1","workflow_id":"WF-1",'
          '"status":"PENDING_MARKETING","message":"sent"}',
          200,
        );
      }),
    );
    await tester.pumpWidget(_app(promoteRequest, service: service));
    await tester.tap(find.text('Send to Marketing'));
    await tester.pumpAndSettle();
    final confirm = tester.widget<FilledButton>(_confirmationButton());
    expect(confirm.onPressed, isNotNull);
    await tester.tap(_confirmationButton());
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(sent!.method, 'POST');
    expect(sent!.url.path, '/marketing-opportunities/');
    expect(sent!.body, contains('"workflow_id":"WF-1"'));
    expect(find.text('Sent to Marketing'), findsOneWidget);
  });

  testWidgets('workflow changes invalidate an open preview', (tester) async {
    var calls = 0;
    final service = MarketingOpportunityApiService(
      client: MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await tester.pumpWidget(_app(promoteRequest, service: service));
    await tester.tap(find.text('Send to Marketing'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _app(
        const MarketingOpportunityRequest(
          workflowId: 'WF-2',
          productId: 'P-2',
          productName: 'Other product',
          storeId: 'S-2',
          currentStock: 20,
          forecastDemand: 10,
          requiredStock: 12,
          excessQuantity: 8,
          stockHealth: 'Overstock',
          recommendedAction: 'PROMOTE',
        ),
        service: service,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Preview no longer current'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('rapid repeated clicks open one preview and send no POST', (
    tester,
  ) async {
    var calls = 0;
    final service = MarketingOpportunityApiService(
      client: MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await tester.pumpWidget(_app(promoteRequest, service: service));
    await tester.tap(find.text('Send to Marketing'));
    await tester.pump();
    await tester.tap(find.text('Send to Marketing'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('session change invalidates an open preview', (tester) async {
    final session = sessionWith((_) async => loginResponse());
    await session.login('fixtureuser', fakePassword);
    var calls = 0;
    final service = MarketingOpportunityApiService(
      client: MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await tester.pumpWidget(
      _app(promoteRequest, service: service, session: session),
    );
    await tester.tap(find.text('Send to Marketing'));
    await tester.pumpAndSettle();
    session.logout();
    await tester.pumpAndSettle();
    expect(find.text('Preview no longer current'), findsOneWidget);
    expect(calls, 0);
  });
}

Widget _app(
  MarketingOpportunityRequest request, {
  MarketingOpportunityApiService? service,
  InventorySessionController? session,
  String? showroomName,
  ForecastSharePreview? preview,
}) => MaterialApp(
  home: Scaffold(
    body: SendToMarketingCard(
      opportunity: request,
      service:
          service ??
          MarketingOpportunityApiService(
            client: MockClient((_) async => http.Response('{}', 500)),
          ),
      session: session,
      showroomName: showroomName,
      forecastPreview: preview,
    ),
  ),
);

Finder _confirmationButton() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.widgetWithText(FilledButton, 'Confirm Send'),
);
