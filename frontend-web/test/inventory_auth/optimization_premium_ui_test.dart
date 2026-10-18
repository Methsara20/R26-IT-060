import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/optimization/stock_flow_decision_workspace.dart';
import 'package:smart_inventory_web/models/optimization/optimization_candidate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final brightness in Brightness.values) {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      testWidgets(
        'premium optimization workspace supports ${brightness.name} at ${width.toInt()}px',
        (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            _host(
              brightness: brightness,
              child: StockFlowDecisionWorkspace(
                overview: _overview([_candidate()]),
                analyzingId: null,
                canAnalyze: (_) => true,
                onAnalyze: (_) {},
              ),
            ),
          );

          expect(find.text('ACTION REQUIRED'), findsOneWidget);
          expect(find.text('HIGH PRIORITY'), findsOneWidget);
          expect(find.text('UNITS REQUIRED'), findsOneWidget);
          expect(find.text('RECOMMENDED TRANSFERS'), findsOneWidget);
          expect(
            find.text('Destination CP002-LONG-SHOWROOM-NAME'),
            findsOneWidget,
          );
          expect(find.text('CP004-LONG-SOURCE-NAME'), findsOneWidget);
          expect(find.text('44 units'), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('explanation and alternative sources retain backend content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        child: StockFlowDecisionWorkspace(
          overview: _overview([_candidate()]),
          analyzingId: null,
          canAnalyze: (_) => true,
          onAnalyze: (_) {},
        ),
      ),
    );

    await tester.ensureVisible(find.text('Why this decision?'));
    await tester.tap(find.text('Why this decision?'));
    await tester.pumpAndSettle();
    expect(find.text('Demand exceeds safe stock coverage.'), findsOneWidget);
    expect(find.text('Decision confidence: 91%'), findsOneWidget);

    await tester.ensureVisible(find.text('Alternative sources (1)'));
    await tester.tap(find.text('Alternative sources (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('#2 CP005'), findsOneWidget);
    expect(find.text('Transferable: 20'), findsOneWidget);
  });

  testWidgets('enlarged text and long labels do not overflow', (tester) async {
    tester.view.physicalSize = const Size(375, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _host(
          child: StockFlowDecisionWorkspace(
            overview: _overview([_candidate()]),
            analyzingId: null,
            canAnalyze: (_) => true,
            onAnalyze: (_) {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _host({
  required Widget child,
  Brightness brightness = Brightness.light,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2563EB),
    brightness: brightness,
  );
  return MaterialApp(
    theme: ThemeData(colorScheme: scheme, brightness: brightness),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

OptimizationOverview _overview(List<OptimizationCandidate> candidates) =>
    OptimizationOverview(
      summary: const OptimizationSummary(
        total: 1,
        highPriority: 1,
        mediumPriority: 0,
        lowStock: 1,
        overstock: 0,
        pending: 0,
        recommended: 1,
      ),
      candidates: candidates,
    );

OptimizationCandidate _candidate() => const OptimizationCandidate(
  id: 'C1',
  productId: 'P0025',
  productName:
      'Hustle Premium Long Product Name for Responsive Optimization Review',
  storeId: 'CP002-LONG-SHOWROOM-NAME',
  category: 'Apparel and lifestyle collection',
  brand: 'Hustle',
  currentStock: 6,
  reorderLevel: 50,
  maxStock: 100,
  shortageQuantity: 44,
  surplusQuantity: 0,
  stockHealth: 'Low Stock',
  type: 'LOW_STOCK',
  priority: 'HIGH',
  status: 'RECOMMENDED',
  recommendedAction: 'TRANSFER',
  decisionReason: 'Demand exceeds safe stock coverage.',
  decisionConfidence: 91,
  coverageRatio: 1,
  transferFeasibility: 'FEASIBLE',
  transferReady: true,
  sources: [
    QualifiedSourceStore(
      storeId: 'CP004-LONG-SOURCE-NAME',
      currentStock: 90,
      reorderLevel: 30,
      surplusQuantity: 60,
      possibleTransferQuantity: 44,
      stockAfterTransfer: 46,
    ),
    QualifiedSourceStore(
      storeId: 'CP005',
      currentStock: 70,
      reorderLevel: 30,
      surplusQuantity: 40,
      possibleTransferQuantity: 20,
      stockAfterTransfer: 50,
    ),
  ],
);
