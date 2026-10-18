import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/core/theme/app_theme.dart';
import 'package:smart_inventory_web/features/analytics/analytics_decision_dashboard.dart';
import 'package:smart_inventory_web/models/analytics/analytics_overview.dart';
import 'package:smart_inventory_web/models/analytics/dashboard_summary.dart';

void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      testWidgets(
        'analytics fits ${width.toInt()}px in ${theme.brightness.name}',
        (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await _pump(tester, theme: theme);
          expect(find.text('Network overview'), findsOneWidget);
          expect(find.text('Performance comparison'), findsOneWidget);
          expect(find.text('Filtered inventory attention'), findsOneWidget);
          expect(find.text('Financial snapshot'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('preserves KPI values, rates and financial snapshot', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('10,000'), findsOneWidget);
    expect(find.text('LKR 25,000,000'), findsAtLeastNWidgets(2));
    expect(find.text('3.1%'), findsAtLeastNWidgets(1));
    expect(find.text('5.0%'), findsAtLeastNWidgets(1));
    expect(find.text('LKR 35,000,000'), findsOneWidget);
    expect(find.text('LKR 10,000,000'), findsOneWidget);
  });

  testWidgets('zero denominator remains N/A', (tester) async {
    final value = _overview(
      dashboard: DashboardSummary(
        totalProducts: 0,
        totalStores: 0,
        totalInventoryRecords: 0,
        totalInventoryQuantity: 0,
        totalInventoryValue: 0,
        totalPotentialRevenue: 0,
        totalPotentialProfit: 0,
        lowStockItems: 0,
        overstockItems: 0,
        lastUpdated: DateTime(2026, 8, 26, 12),
      ),
    );
    await _pump(tester, overview: value);
    expect(find.text('N/A'), findsNWidgets(4));
  });

  testWidgets('attention filters expose scope, counts and reset', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('2 attention records'), findsOneWidget);
    expect(
      find.textContaining('filters apply to attention records only'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('All').first);
    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Very Long Colombo Flagship Showroom').last);
    await tester.pumpAndSettle();
    expect(find.text('1 active'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('1 active'), findsNothing);
  });

  testWidgets('comparison and drill-down remain interactive', (tester) async {
    var openedIntelligence = false;
    await _pump(
      tester,
      onOpenInventoryIntelligence: () => openedIntelligence = true,
    );
    await tester.ensureVisible(find.text('Categories'));
    await tester.tap(find.text('Categories'));
    await tester.pump();
    expect(find.textContaining('Categories ranked by'), findsOneWidget);
    await tester.ensureVisible(find.text('View detailed comparison'));
    await tester.tap(find.text('View detailed comparison'));
    await tester.pump();
    expect(find.byType(DataTable), findsOneWidget);
    await tester.ensureVisible(
      find.text('Very Long Colombo Flagship Showroom').first,
    );
    await tester.tap(find.text('Very Long Colombo Flagship Showroom').first);
    await tester.pumpAndSettle();
    expect(find.text('Open Inventory Intelligence'), findsOneWidget);
    await tester.tap(find.text('Open Inventory Intelligence'));
    expect(openedIntelligence, isTrue);
  });

  testWidgets('all breakdown dimensions and metrics remain selectable', (
    tester,
  ) async {
    await _pump(tester);
    for (final label in ['Categories', 'Brands', 'Gender', 'Showrooms']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pump();
      expect(find.textContaining('$label ranked by'), findsOneWidget);
    }

    for (final metric in [
      'Inventory value',
      'Stock',
      'Low stock',
      'Overstock',
      'Potential profit',
    ]) {
      final selector = find.byType(DropdownButtonFormField<AnalyticsMetric>);
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text(metric).last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining(metric.toLowerCase()),
        findsAtLeastNWidgets(1),
      );
    }
  });

  testWidgets('empty datasets use explicit zero-data states', (tester) async {
    final base = _overview();
    await _pump(
      tester,
      overview: AnalyticsOverview(
        dashboard: base.dashboard,
        showrooms: const [],
        categories: const [],
        brands: const [],
        genders: const [],
        lowStockItems: const [],
        overstockItems: const [],
        highValueItems: const [],
      ),
    );
    expect(
      find.text('No analytics data is available for this breakdown.'),
      findsOneWidget,
    );
    expect(find.text('0 attention records'), findsOneWidget);
    expect(
      find.text('No analytics data is available for the selected filters.'),
      findsOneWidget,
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  ThemeData? theme,
  AnalyticsOverview? overview,
  VoidCallback? onOpenInventoryIntelligence,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: AnalyticsDecisionDashboard(
            overview: overview ?? _overview(),
            onOpenInventoryIntelligence: onOpenInventoryIntelligence,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

AnalyticsOverview _overview({DashboardSummary? dashboard}) {
  const breakdown = AnalyticsBreakdown(
    id: 'CP001',
    label: 'Very Long Colombo Flagship Showroom',
    totalStock: 1000,
    inventoryValue: 2500000,
    potentialRevenue: 3500000,
    potentialProfit: 1000000,
    lowStockItems: 12,
    overstockItems: 8,
  );
  const alert = AnalyticsAlertItem(
    inventoryId: 'I001',
    productId: 'P001',
    productName: 'Emerald Shirt With A Very Long Product Name',
    storeId: 'CP001',
    category: 'Shirts',
    brand: 'Emerald',
    currentStock: 2,
    reorderLevel: 10,
    maximumStock: 50,
  );
  return AnalyticsOverview(
    dashboard:
        dashboard ??
        DashboardSummary(
          totalProducts: 100,
          totalStores: 8,
          totalInventoryRecords: 800,
          totalInventoryQuantity: 10000,
          totalInventoryValue: 25000000,
          totalPotentialRevenue: 35000000,
          totalPotentialProfit: 10000000,
          lowStockItems: 25,
          overstockItems: 40,
          lastUpdated: DateTime(2026, 8, 26, 12),
        ),
    showrooms: const [breakdown],
    categories: const [breakdown],
    brands: const [breakdown],
    genders: const [breakdown],
    lowStockItems: const [alert],
    overstockItems: const [alert],
    highValueItems: const [alert],
  );
}
