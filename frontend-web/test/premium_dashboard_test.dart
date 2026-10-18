import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/core/theme/app_theme.dart';
import 'package:smart_inventory_web/features/dashboard/widgets/premium_dashboard_components.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      testWidgets(
        'Dashboard presentation $width dark=$dark preserves data and actions',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var inventory = 0;
          var optimization = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ExecutiveInventoryOverview(
                          lowStockCount: 255,
                          overstockCount: 439,
                          onViewInventory: () => inventory++,
                          onReviewOptimization: () => optimization++,
                        ),
                        const PremiumDashboardMetric(
                          label: 'Closing inventory value',
                          value: 'LKR 2.94B',
                          caption: 'LKR 2,937,069,748',
                          icon: Icons.payments_outlined,
                          color: Colors.blue,
                        ),
                        const DashboardAttentionProfile(
                          totalRecords: 8000,
                          lowStock: 255,
                          overstock: 439,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(
            find.text('255 low-stock records require attention'),
            findsOneWidget,
          );
          expect(find.text('LKR 2,937,069,748'), findsOneWidget);
          expect(find.text('3.2%'), findsOneWidget);
          expect(find.text('5.5%'), findsOneWidget);
          await tester.ensureVisible(find.text('View inventory'));
          await tester.tap(find.text('View inventory'));
          await tester.ensureVisible(find.text('Review optimization'));
          await tester.tap(find.text('Review optimization'));
          expect(inventory, 1);
          expect(optimization, 1);
        },
      );
    }
  }
}
