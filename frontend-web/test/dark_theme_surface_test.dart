import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/core/theme/app_theme.dart';
import 'package:smart_inventory_web/features/dashboard/widgets/dashboard_decision_banner.dart';
import 'package:smart_inventory_web/features/dashboard/widgets/dashboard_kpi_card.dart';

void main() {
  testWidgets('custom dashboard surfaces render correctly in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                DashboardDecisionBanner(
                  lowStockCount: 12,
                  overstockCount: 8,
                  onViewInventory: () {},
                  onReviewOptimization: () {},
                ),
                const DashboardKpiCard(
                  label: 'Closing inventory',
                  value: '1,000',
                  icon: Icons.inventory_2_outlined,
                  color: Color(0xFF2563EB),
                  caption: 'Across 8 records',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('12 low-stock records require attention'), findsOneWidget);
    expect(find.text('1,000'), findsOneWidget);
  });
}
