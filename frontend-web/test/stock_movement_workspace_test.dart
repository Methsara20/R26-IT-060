import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/stock_movements/stock_movement_workspace.dart';
import 'package:smart_inventory_web/models/stock_movement/stock_movement.dart';

void main() {
  testWidgets('lays out an active transfer at desktop width', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final movement = StockMovement.fromJson({
      'movement_id': 'MOV-001',
      'candidate_id': 'CAN-001',
      'product_id': 'P0001',
      'product_name': 'Test Shirt',
      'movement_type': 'TRANSFER',
      'movement_status': 'RECOMMENDED',
      'from_store': 'CP001',
      'to_store': 'CP002',
      'recommended_qty': 25,
      'coverage_percentage': 100,
      'recommendation_confidence': 92,
      'transfer_priority': 'HIGH',
      'source_stock_before': 100,
      'source_stock_after': 75,
      'target_stock_before': 10,
      'target_stock_after': 35,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StockMovementWorkspace(
              movements: [movement],
              busyMovementId: null,
              generatingReplacement: false,
              onRefresh: () {},
              onDetails: (_) {},
              onAction: (_, _) {},
              onGenerateAnother: (_) {},
              onCheckStatus: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Test Shirt'), findsOneWidget);
    expect(find.text('Approve transfer'), findsOneWidget);
  });
}
