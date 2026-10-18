import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/core/auth/inventory_ui_permissions.dart';
import 'package:smart_inventory_web/core/theme/app_theme.dart';
import 'package:smart_inventory_web/features/stock_movements/stock_movement_workspace.dart';
import 'package:smart_inventory_web/models/auth/inventory_user.dart';
import 'package:smart_inventory_web/models/stock_movement/stock_movement.dart';

StockMovement movement(String id, String status) => StockMovement.fromJson({
  'movement_id': id,
  'candidate_id': 'CAN-$id',
  'product_id': 'P0001',
  'product_name': 'Premium Test Shirt',
  'movement_type': 'TRANSFER',
  'movement_status': status,
  'from_store': 'CP001',
  'to_store': 'CP002',
  'recommended_qty': 25,
  'coverage_percentage': 88,
  'recommendation_confidence': 92,
  'transfer_priority': 'HIGH',
  'source_stock_before': 100,
  'source_stock_after': 75,
  'target_stock_before': 10,
  'target_stock_after': 35,
});

InventoryUiPermissions permissions(String role) => InventoryUiPermissions(
  InventoryUser.fromJson({
    'user_id': 'oid:0123456789abcdef01234567',
    'username_normalized': role,
    'display_name': role,
    'role': role,
    'global_access': false,
    'store_ids': ['CP001', 'CP002'],
  }),
);

Widget workspace({
  required ThemeData theme,
  required InventoryUiPermissions permissions,
}) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: SingleChildScrollView(
      child: StockMovementWorkspace(
        movements: [
          movement('MOV-REC', 'RECOMMENDED'),
          movement('MOV-APP', 'APPROVED'),
        ],
        busyMovementId: null,
        generatingReplacement: false,
        refreshing: false,
        onRefresh: () {},
        onDetails: (_) {},
        onAction: (_, _) {},
        onGenerateAnother: (_) {},
        onCheckStatus: (_) {},
        canGenerateAnother: (item) => permissions.canForStores(
          InventoryOperation.recommendMovement,
          [item.fromStore, item.toStore],
        ),
        canPerformAction: (item, action) => permissions.canForStores(
          switch (action) {
            StockMovementWorkspaceAction.approve =>
              InventoryOperation.approveMovement,
            StockMovementWorkspaceAction.reject =>
              InventoryOperation.rejectMovement,
            StockMovementWorkspaceAction.cancel =>
              InventoryOperation.cancelMovement,
            StockMovementWorkspaceAction.execute =>
              InventoryOperation.executeMovement,
          },
          [item.fromStore, item.toStore],
        ),
      ),
    ),
  ),
);

void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      testWidgets(
        'premium workspace fits ${width.toInt()} in ${theme.brightness.name}',
        (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            workspace(theme: theme, permissions: permissions('admin')),
          );
          await tester.pump();
          expect(find.text('STOCK MOVEMENT CONTROL'), findsOneWidget);
          expect(find.text('NEEDS REVIEW'), findsOneWidget);
          expect(find.text('2 results'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('role actions preserve the approved permission matrix', (
    tester,
  ) async {
    Future<void> verify(
      String role, {
      required bool approve,
      required bool execute,
    }) async {
      await tester.pumpWidget(
        workspace(theme: AppTheme.light, permissions: permissions(role)),
      );
      await tester.pump();
      expect(
        find.text('Approve transfer'),
        approve ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Execute transfer'),
        execute ? findsOneWidget : findsNothing,
      );
    }

    await verify('admin', approve: true, execute: true);
    await verify('manager', approve: true, execute: false);
    await verify('analyst', approve: false, execute: false);
    await verify('operator', approve: false, execute: true);
    await verify('viewer', approve: false, execute: false);
  });

  testWidgets('unauthorized store scope hides mutation actions', (
    tester,
  ) async {
    final scoped = InventoryUiPermissions(
      InventoryUser.fromJson({
        'user_id': 'oid:0123456789abcdef01234567',
        'username_normalized': 'manager',
        'display_name': 'Manager',
        'role': 'manager',
        'global_access': false,
        'store_ids': ['CP001'],
      }),
    );
    await tester.pumpWidget(
      workspace(theme: AppTheme.light, permissions: scoped),
    );
    await tester.pump();
    expect(find.text('Approve transfer'), findsNothing);
    expect(find.text('Reject'), findsNothing);
  });

  testWidgets('filters show local result count and can be reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      workspace(theme: AppTheme.light, permissions: permissions('admin')),
    );
    await tester.enterText(find.byType(TextField), 'missing product');
    await tester.pump();
    expect(find.text('0 results'), findsOneWidget);
    expect(find.text('No movements match these filters'), findsOneWidget);
    await tester.ensureVisible(find.text('Reset filters').last);
    await tester.tap(find.text('Reset filters').last);
    await tester.pump();
    expect(find.text('2 results'), findsOneWidget);
  });
}
