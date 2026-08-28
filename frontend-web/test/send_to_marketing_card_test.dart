import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_inventory_web/features/marketing_integration/models/marketing_opportunity.dart';
import 'package:smart_inventory_web/features/marketing_integration/services/marketing_opportunity_api_service.dart';
import 'package:smart_inventory_web/features/marketing_integration/widgets/send_to_marketing_card.dart';

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

  testWidgets('shows the submitted promotion in the card and dialog', (
    tester,
  ) async {
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
    await tester.pumpWidget(_app(request));
    expect(find.text('Forecast Promotion Scenario: 15%'), findsOneWidget);
    await tester.tap(find.text('Send to Marketing'));
    await tester.pumpAndSettle();
    expect(find.text('Promotion Scenario'), findsOneWidget);
    expect(find.text('15%'), findsOneWidget);
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

  testWidgets('confirm posts once and displays confirmed success', (
    tester,
  ) async {
    var calls = 0;
    final service = MarketingOpportunityApiService(
      client: MockClient((request) async {
        calls++;
        expect(request.url.path, '/marketing-opportunities/');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['workflow_id'], 'WF-1');
        expect(body.containsKey('promotion_percent'), isFalse);
        return http.Response(
          jsonEncode({
            'opportunity_id': 'MKT-OPP-1',
            'workflow_id': 'WF-1',
            'status': 'PENDING_MARKETING',
            'message': 'Marketing opportunity sent successfully.',
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(_app(promoteRequest, service: service));
    await tester.tap(find.text('Send to Marketing'));
    await tester.pumpAndSettle();
    await tester.tap(_confirmationButton());
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Sent to Marketing'), findsOneWidget);
    expect(find.text('Reference: MKT-OPP-1'), findsOneWidget);
  });

  testWidgets('failure is readable and allows retry', (tester) async {
    var calls = 0;
    final service = MarketingOpportunityApiService(
      client: MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({'detail': 'Service unavailable.'}),
          503,
        );
      }),
    );
    await tester.pumpWidget(_app(promoteRequest, service: service));
    await tester.tap(find.text('Send to Marketing'));
    await tester.pumpAndSettle();
    await tester.tap(_confirmationButton());
    await tester.pumpAndSettle();
    expect(find.text('Service unavailable.'), findsOneWidget);
    expect(find.text('Send to Marketing'), findsOneWidget);
    expect(calls, 1);
  });

  testWidgets('rapid duplicate submission produces one POST', (tester) async {
    var calls = 0;
    final responseCompleter = Completer<http.Response>();
    final service = MarketingOpportunityApiService(
      client: MockClient((request) {
        calls++;
        return responseCompleter.future;
      }),
    );
    await tester.pumpWidget(_app(promoteRequest, service: service));
    await tester.tap(find.text('Send to Marketing'));
    await tester.pumpAndSettle();
    await tester.tap(_confirmationButton());
    await tester.pump();
    expect(find.text('Sending…'), findsOneWidget);
    await tester.tap(find.text('Sending…'), warnIfMissed: false);
    expect(calls, 1);
    responseCompleter.complete(
      http.Response(
        jsonEncode({
          'opportunity_id': 'MKT-OPP-1',
          'workflow_id': 'WF-1',
          'status': 'PENDING_MARKETING',
          'message': 'Marketing opportunity sent successfully.',
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}

Widget _app(
  MarketingOpportunityRequest request, {
  MarketingOpportunityApiService? service,
}) => MaterialApp(
  home: Scaffold(
    body: SendToMarketingCard(opportunity: request, service: service),
  ),
);

Finder _confirmationButton() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.widgetWithText(FilledButton, 'Send to Marketing'),
);
