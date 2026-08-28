import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/optimization/stock_flow_decision_workspace.dart';
import 'package:smart_inventory_web/models/optimization/optimization_candidate.dart';

void main() {
  testWidgets('shows safe decision totals and filters the priority queue', (
    tester,
  ) async {
    final overview = OptimizationOverview(
      summary: const OptimizationSummary(
        total: 2,
        highPriority: 1,
        mediumPriority: 1,
        lowStock: 2,
        overstock: 0,
        pending: 0,
        recommended: 2,
      ),
      candidates: [
        _candidate('C1', 'P1', 'Hustle Shirt', 15),
        _candidate('C2', 'P2', 'Emerald Skirt', 10),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StockFlowDecisionWorkspace(
              overview: overview,
              analyzingId: null,
              onAnalyze: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('25'), findsOneWidget);
    expect(find.text('Hustle Shirt'), findsOneWidget);
    expect(find.text('Emerald Skirt'), findsOneWidget);
    expect(find.text('Alternative sources (1)'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'Emerald');
    await tester.pump();

    expect(find.text('Hustle Shirt'), findsNothing);
    expect(find.text('Emerald Skirt'), findsOneWidget);
    expect(find.text('1 decision shown in backend order.'), findsOneWidget);
  });
}

OptimizationCandidate _candidate(
  String id,
  String productId,
  String name,
  int shortage,
) => OptimizationCandidate(
  id: id,
  productId: productId,
  productName: name,
  storeId: 'CP001',
  category: 'Clothing',
  brand: 'Brand',
  currentStock: 5,
  reorderLevel: 20,
  maxStock: 100,
  shortageQuantity: shortage,
  surplusQuantity: 0,
  stockHealth: 'Low Stock',
  type: 'LOW_STOCK',
  priority: id == 'C1' ? 'HIGH' : 'MEDIUM',
  status: 'RECOMMENDED',
  recommendedAction: 'TRANSFER',
  decisionReason: 'Backend recommendation.',
  decisionConfidence: 90,
  coverageRatio: 2,
  transferFeasibility: 'FEASIBLE',
  transferReady: true,
  sources: const [
    QualifiedSourceStore(
      storeId: 'CP002',
      currentStock: 100,
      reorderLevel: 30,
      surplusQuantity: 70,
      possibleTransferQuantity: 20,
      stockAfterTransfer: 80,
    ),
    QualifiedSourceStore(
      storeId: 'CP003',
      currentStock: 90,
      reorderLevel: 30,
      surplusQuantity: 60,
      possibleTransferQuantity: 15,
      stockAfterTransfer: 75,
    ),
  ],
);
