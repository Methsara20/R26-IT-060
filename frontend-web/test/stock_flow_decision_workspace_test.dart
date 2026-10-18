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
              canAnalyze: (_) => true,
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

    expect(find.text('Filters active'), findsOneWidget);
    await tester.ensureVisible(find.text('Clear filters'));
    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.text('Hustle Shirt'), findsOneWidget);
    expect(find.text('Emerald Skirt'), findsOneWidget);
  });

  testWidgets('restores authorized pending analysis and prevents duplicates', (
    tester,
  ) async {
    var analyses = 0;
    final pending = _candidate(
      'C1',
      'P1',
      'Pending shirt',
      15,
      status: 'PENDING',
      action: 'PENDING',
    );

    await tester.pumpWidget(
      _host(
        StockFlowDecisionWorkspace(
          overview: _overview([pending]),
          analyzingId: null,
          canAnalyze: (_) => true,
          onAnalyze: (_) => analyses++,
        ),
      ),
    );

    expect(find.text('Analyze candidate'), findsOneWidget);
    await tester.ensureVisible(find.text('Analyze candidate'));
    await tester.tap(find.text('Analyze candidate'));
    expect(analyses, 1);

    await tester.pumpWidget(
      _host(
        StockFlowDecisionWorkspace(
          overview: _overview([pending]),
          analyzingId: pending.id,
          canAnalyze: (_) => true,
          onAnalyze: (_) => analyses++,
        ),
      ),
    );
    expect(find.text('Analyzing…'), findsOneWidget);
    await tester.ensureVisible(find.text('Analyzing…'));
    await tester.tap(find.text('Analyzing…'));
    expect(analyses, 1);
  });

  testWidgets('hides analysis when current permissions deny it', (
    tester,
  ) async {
    final pending = _candidate(
      'C1',
      'P1',
      'Pending shirt',
      15,
      status: 'PENDING',
      action: 'PENDING',
    );
    await tester.pumpWidget(
      _host(
        StockFlowDecisionWorkspace(
          overview: _overview([pending]),
          analyzingId: null,
          canAnalyze: (_) => false,
          onAnalyze: (_) {},
        ),
      ),
    );
    expect(find.text('Analyze candidate'), findsNothing);
  });
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

OptimizationOverview _overview(List<OptimizationCandidate> candidates) =>
    OptimizationOverview(
      summary: OptimizationSummary(
        total: candidates.length,
        highPriority: candidates
            .where((item) => item.priority == 'HIGH')
            .length,
        mediumPriority: candidates
            .where((item) => item.priority == 'MEDIUM')
            .length,
        lowStock: candidates.where((item) => item.type == 'LOW_STOCK').length,
        overstock: candidates.where((item) => item.type == 'OVERSTOCK').length,
        pending: candidates.where((item) => item.status == 'PENDING').length,
        recommended: candidates
            .where((item) => item.status == 'RECOMMENDED')
            .length,
      ),
      candidates: candidates,
    );

OptimizationCandidate _candidate(
  String id,
  String productId,
  String name,
  int shortage, {
  String status = 'RECOMMENDED',
  String action = 'TRANSFER',
}) => OptimizationCandidate(
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
  status: status,
  recommendedAction: action,
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
