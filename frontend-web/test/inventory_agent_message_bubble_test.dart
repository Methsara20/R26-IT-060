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
}
