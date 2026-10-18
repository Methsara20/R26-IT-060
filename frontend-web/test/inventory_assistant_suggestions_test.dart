import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/assistant/inventory_assistant_suggestions.dart';
import 'package:smart_inventory_web/models/assistant/manager_chat.dart';

void main() {
  test('general mode never includes product-specific suggestions', () {
    final context = resolveInventoryAssistantContext();
    final suggestions = inventoryAssistantSuggestions(context);

    expect(context, InventoryAssistantContext.general);
    expect(suggestions, contains('What needs attention now?'));
    expect(
      suggestions,
      isNot(contains("Explain this product's inventory health")),
    );
  });

  test('manual product ID follow-up activates product context', () {
    final context = resolveInventoryAssistantContext(
      messages: const [
        ManagerChatMessage(role: 'user', content: 'Please review P0100'),
      ],
    );

    expect(context, InventoryAssistantContext.product);
    expect(
      inventoryAssistantSuggestions(context),
      contains("Explain this product's inventory health"),
    );
  });

  test('forecast context has only forecast prompts', () {
    expect(
      inventoryAssistantSuggestions(InventoryAssistantContext.forecast),
      const [
        'Explain this forecast',
        'What is driving this demand?',
        'What should I check next?',
      ],
    );
  });

  test('optimization context has recommendation prompts', () {
    expect(
      inventoryAssistantSuggestions(InventoryAssistantContext.optimization),
      contains('Why this source showroom?'),
    );
  });

  test('movement context has transfer prompts', () {
    expect(
      inventoryAssistantSuggestions(InventoryAssistantContext.movement),
      const [
        'Explain this transfer',
        'What happens if I reject it?',
        'How will inventory change?',
      ],
    );
  });
}
