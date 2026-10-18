import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/assistant/widgets/floating_inventory_agent.dart';
import 'package:smart_inventory_web/features/workflow/inventory_decision_workflow_controller.dart';

void main() {
  testWidgets('opens a responsive page-aware assistant panel', (tester) async {
    tester.view.physicalSize = const Size(520, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final workflow = InventoryDecisionWorkflowController();
    addTearDown(workflow.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FloatingInventoryAgent(
                moduleName: 'Analytics',
                suggestions: const [
                  'Summarize this performance',
                  'Which showroom needs attention?',
                ],
                workflowController: workflow,
                onOpenFullAssistant: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Ask Inventory AI'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Inventory AI'), findsOneWidget);
    expect(find.text('Analytics · General questions'), findsOneWidget);
    expect(find.text('Summarize this performance'), findsOneWidget);
    expect(find.text('Open full Manager Assistant'), findsOneWidget);
  });
}
