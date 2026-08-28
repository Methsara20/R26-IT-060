import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/inventory/showroom_inventory_kpi_summary.dart';
import 'package:smart_inventory_web/models/inventory/inventory_record.dart';

void main() {
  testWidgets('uses the documented current inventory KPI rules', (
    tester,
  ) async {
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
        currentStock: 85,
        reorderLevel: 10,
        maxStock: 100,
        supplierLeadTime: 2,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            child: ShowroomInventoryKpiSummary(records: records),
          ),
        ),
      ),
    );

    expect(find.text('90 units'), findsOneWidget);
    expect(find.text('Stockout records'), findsOneWidget);
    expect(find.text('Low-stock records'), findsOneWidget);
    expect(find.text('Overstock records'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget);
  });
}
