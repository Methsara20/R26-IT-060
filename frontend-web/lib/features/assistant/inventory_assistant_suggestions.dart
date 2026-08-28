// One context resolver keeps quick suggestions consistent between the floating
// Inventory AI Agent and the full Manager Assistant.
import '../../models/assistant/manager_chat.dart';
import '../../models/workflow/decision_workflow.dart';

enum InventoryAssistantContext {
  general,
  product,
  forecast,
  optimization,
  movement,
}

InventoryAssistantContext resolveInventoryAssistantContext({
  DecisionWorkflow? workflow,
  String? movementId,
  List<ManagerChatMessage> messages = const [],
}) {
  
  if (movementId?.isNotEmpty == true || workflow?.movement != null) {
    return InventoryAssistantContext.movement;
  }
  if (workflow?.candidate != null) {
    return InventoryAssistantContext.optimization;
  }
  if (workflow?.forecast != null) {
    return InventoryAssistantContext.forecast;
  }
  if (workflow?.productId.isNotEmpty == true || _mentionsProductId(messages)) {
    return InventoryAssistantContext.product;
  }
  return InventoryAssistantContext.general;
}

List<String> inventoryAssistantSuggestions(InventoryAssistantContext context) =>
    switch (context) {
      InventoryAssistantContext.general => const [
        'Summarize current inventory health',
        'What needs attention now?',
        'Summarize current risks',
        'Review recent stock movements',
      ],
      InventoryAssistantContext.product => const [
        "Explain this product's inventory health",
        'Why is this product at risk?',
        'What action should I consider?',
      ],
      InventoryAssistantContext.forecast => const [
        'Explain this forecast',
        'What is driving this demand?',
        'What should I check next?',
      ],
      InventoryAssistantContext.optimization => const [
        'Why was this recommended?',
        'Why this source showroom?',
        'What risk does this solve?',
      ],
      InventoryAssistantContext.movement => const [
        'Explain this transfer',
        'What happens if I reject it?',
        'How will inventory change?',
      ],
    };

bool _mentionsProductId(List<ManagerChatMessage> messages) => messages.reversed
    .where((message) => message.isManager)
    .take(3)
    .any(
      (message) => RegExp(
        r'\bP\d{3,}\b',
        caseSensitive: false,
      ).hasMatch(message.content),
    );
