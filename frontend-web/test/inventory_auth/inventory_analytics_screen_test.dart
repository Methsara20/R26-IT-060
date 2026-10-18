import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/core/theme/app_theme.dart';
import 'package:smart_inventory_web/features/analytics/inventory_analytics_screen.dart';
import 'package:smart_inventory_web/features/workflow/inventory_decision_workflow_controller.dart';
import 'package:smart_inventory_web/models/analytics/analytics_overview.dart';
import 'package:smart_inventory_web/models/analytics/dashboard_summary.dart';
import 'package:smart_inventory_web/services/analytics_api_service.dart';

class _FakeAnalyticsApi extends AnalyticsApiService {
  _FakeAnalyticsApi(this.responses);

  final List<Future<AnalyticsOverview> Function()> responses;
  int calls = 0;

  @override
  Future<AnalyticsOverview> getOverview() {
    calls += 1;
    return responses.removeAt(0)();
  }
}

void main() {
  testWidgets('shows loading then premium header and backend timestamp', (
    tester,
  ) async {
    final pending = Completer<AnalyticsOverview>();
    final api = _FakeAnalyticsApi([() => pending.future]);
    await _pump(tester, api);
    expect(find.text('INVENTORY ANALYTICS'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    pending.complete(_overview());
    await tester.pumpAndSettle();
    expect(find.text('Updated 2026-08-26 12:34'), findsOneWidget);
    expect(find.text('Network overview'), findsOneWidget);
  });

  testWidgets(
    'refresh preserves data, prevents duplicates and reports failure',
    (tester) async {
      final refresh = Completer<AnalyticsOverview>();
      final api = _FakeAnalyticsApi([
        () async => _overview(),
        () => refresh.future,
        () async => throw const AnalyticsApiException('Temporary failure.'),
      ]);
      await _pump(tester, api);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Refresh analytics'));
      await tester.pump();
      expect(find.text('Network overview'), findsOneWidget);
      expect(api.calls, 2);
      expect(find.text('Refreshing?'), findsOneWidget);
      await tester.tap(find.text('Refreshing?'), warnIfMissed: false);
      await tester.pump();
      expect(api.calls, 2);

      refresh.complete(_overview());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh analytics'));
      await tester.pumpAndSettle();
      expect(find.text('Refresh failed'), findsOneWidget);
      expect(
        find.textContaining('last successful analytics snapshot'),
        findsOneWidget,
      );
      expect(find.text('Network overview'), findsOneWidget);
    },
  );

  testWidgets('initial error provides a working retry', (tester) async {
    final api = _FakeAnalyticsApi([
      () async => throw const AnalyticsApiException('Unavailable.'),
      () async => _overview(),
    ]);
    await _pump(tester, api);
    await tester.pumpAndSettle();
    expect(find.text('Analytics could not be loaded'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Network overview'), findsOneWidget);
    expect(api.calls, 2);
  });

  testWidgets('premium screen supports dark mode and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeAnalyticsApi([() async => _overview()]);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: InventoryAnalyticsScreen(
                workflowController: InventoryDecisionWorkflowController(),
                api: api,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('INVENTORY ANALYTICS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, AnalyticsApiService api) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: InventoryAnalyticsScreen(
            workflowController: InventoryDecisionWorkflowController(),
            api: api,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

AnalyticsOverview _overview() {
  const breakdown = AnalyticsBreakdown(
    id: 'CP001',
    label: 'Colombo',
    totalStock: 100,
    inventoryValue: 1000,
    potentialRevenue: 1500,
    potentialProfit: 500,
    lowStockItems: 1,
    overstockItems: 2,
  );
  return AnalyticsOverview(
    dashboard: DashboardSummary(
      totalProducts: 1,
      totalStores: 1,
      totalInventoryRecords: 10,
      totalInventoryQuantity: 100,
      totalInventoryValue: 1000,
      totalPotentialRevenue: 1500,
      totalPotentialProfit: 500,
      lowStockItems: 1,
      overstockItems: 2,
      lastUpdated: DateTime(2026, 8, 26, 12, 34),
    ),
    showrooms: const [breakdown],
    categories: const [breakdown],
    brands: const [breakdown],
    genders: const [breakdown],
    lowStockItems: const [],
    overstockItems: const [],
    highValueItems: const [],
  );
}
