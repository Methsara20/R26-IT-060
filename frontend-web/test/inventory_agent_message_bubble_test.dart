import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/assistant/widgets/inventory_agent_components.dart';
import 'package:smart_inventory_web/models/assistant/manager_chat.dart';

void main() {
  testWidgets('clearly identifies user and assistant messages', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              InventoryAgentMessageBubble(
                message: ManagerChatMessage(
                  role: 'user',
                  content: 'What needs attention?',
                ),
              ),
              InventoryAgentMessageBubble(
                message: ManagerChatMessage(
                  role: 'assistant',
                  content: '**Stock levels** require review.',
                  answerSource: 'GROQ',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('INVENTORY AI'), findsOneWidget);
    expect(find.text('Source · GROQ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('composer blocks blank messages and enables valid messages', (
    tester,
  ) async {
    final controller = TextEditingController();
    var sends = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventoryAgentComposer(
            controller: controller,
            sending: false,
            onSend: () => sends++,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    final sendButton = find.ancestor(
      of: find.byIcon(Icons.arrow_upward),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Review low stock');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    expect(sends, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assistant messages remain readable in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: InventoryAgentMessageBubble(
            message: ManagerChatMessage(
              role: 'assistant',
              content: 'A long inventory explanation remains readable.',
              answerSource: 'VERIFIED_DATA',
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('A long inventory explanation remains readable.'),
      findsOneWidget,
    );
    expect(find.byType(Semantics), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
