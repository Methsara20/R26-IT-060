import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/analytics/analytics_decision_dashboard.dart';
import 'package:smart_inventory_web/models/analytics/analytics_overview.dart';
import 'package:smart_inventory_web/models/analytics/dashboard_summary.dart';

void main() {
  for (final size in [const Size(1440, 1000), const Size(520, 900)]) {
    testWidgets('analytics dashboard lays out at ${size.width}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsDecisionDashboard(overview: _overview()),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Performance overview'), findsOneWidget);
      expect(find.text('Items requiring attention'), findsOneWidget);
    });
  }
}

AnalyticsOverview _overview() {
  const breakdown = AnalyticsBreakdown(
    id: 'CP001',
    label: 'Cool Planet Colombo',
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
    productName: 'Emerald Shirt',
    storeId: 'CP001',
    category: 'Shirts',
    brand: 'Emerald',
    currentStock: 2,
    reorderLevel: 10,
    maximumStock: 50,
  );
  return AnalyticsOverview(
    dashboard: DashboardSummary(
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
    overstockItems: const [],
    highValueItems: const [alert],
  );
}
