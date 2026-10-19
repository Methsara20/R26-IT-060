import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/inventory/inventory_attention_section.dart';
import 'package:smart_inventory_web/features/inventory/inventory_health_summary.dart';
import 'package:smart_inventory_web/features/inventory/showroom_inventory_kpi_summary.dart';
import 'package:smart_inventory_web/models/forecast/forecast_catalog_option.dart';
import 'package:smart_inventory_web/models/inventory/inventory_record.dart';

void main() {
  const records = [
    InventoryRecord(
      inventoryId: 'I1',
      storeId: 'S1',
      productId: 'P1',
      currentStock: 0,
      reorderLevel: 10,
      maxStock: 100,
      supplierLeadTime: 2,
    ),
    InventoryRecord(
      inventoryId: 'I2',
      storeId: 'S1',
      productId: 'P2',
      currentStock: 5,
      reorderLevel: 10,
      maxStock: 100,
      supplierLeadTime: 2,
    ),
    InventoryRecord(
      inventoryId: 'I3',
      storeId: 'S1',
      productId: 'P3',
      currentStock: 90,
      reorderLevel: 10,
      maxStock: 100,
      supplierLeadTime: 2,
    ),
    InventoryRecord(
      inventoryId: 'I4',
      storeId: 'S1',
      productId: 'P4',
      currentStock: 40,
      reorderLevel: 10,
      maxStock: 100,
      supplierLeadTime: 2,
    ),
  ];

  final products = {
    for (var index = 1; index <= 4; index++)
      'P$index': ForecastProductOption(
        id: 'P$index',
        name: 'Long descriptive inventory product $index',
        sellingPrice: 100,
        category: 'Shirts',
        brand: 'Hustle',
        gender: 'Men',
      ),
  };

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('inventory summaries fit $width in $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2563EB),
                brightness: brightness,
              ),
            ),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const ShowroomInventoryKpiSummary(records: records),
                      const SizedBox(height: 16),
                      const InventoryHealthSummary(records: records),
                      const SizedBox(height: 16),
                      InventoryAttentionSection(
                        records: records,
                        products: products,
                        onOpenProduct: (_) {},
                        onViewAll: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Current inventory KPIs'), findsOneWidget);
        expect(find.text('Inventory health'), findsOneWidget);
        expect(find.text('Needs attention'), findsOneWidget);
        expect(find.text('Stockout'), findsWidgets);
        expect(find.text('Low Stock'), findsWidgets);
        expect(find.text('Overstock'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
