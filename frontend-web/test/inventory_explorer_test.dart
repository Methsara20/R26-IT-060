import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/inventory/inventory_explorer.dart';
import 'package:smart_inventory_web/models/forecast/forecast_catalog_option.dart';
import 'package:smart_inventory_web/models/inventory/inventory_record.dart';

void main() {
  testWidgets('paginates and searches the already-loaded inventory', (
    tester,
  ) async {
    final records = [
      for (var index = 1; index <= 30; index++)
        InventoryRecord(
          inventoryId: 'I$index',
          storeId: 'S1',
          productId: 'P${index.toString().padLeft(3, '0')}',
          currentStock: index,
          reorderLevel: 5,
          maxStock: 100,
          supplierLeadTime: 2,
        ),
    ];
    final products = {
      for (var index = 1; index <= 30; index++)
        'P${index.toString().padLeft(3, '0')}': ForecastProductOption(
          id: 'P${index.toString().padLeft(3, '0')}',
          name: 'Product $index',
          sellingPrice: 100,
          category: 'Shirts',
          brand: 'Hustle',
          gender: 'Men',
        ),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InventoryExplorer(
              store: const ForecastStoreOption(id: 'S1', name: 'Showroom'),
              records: records,
              products: products,
              workflow: null,
              onBack: () {},
              onRunForecast: (_, _) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Showing 1-25 of 30'), findsOneWidget);
    await tester.ensureVisible(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Showing 26-30 of 30'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'P003');
    await tester.pump();
    expect(find.text('Showing 1-1 of 1'), findsOneWidget);
    expect(find.text('Product 3'), findsOneWidget);
  });
}
