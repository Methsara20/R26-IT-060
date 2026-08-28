import 'package:flutter/material.dart';

import '../../../models/assistant/manager_chat.dart';
import '../../../models/stock_movement/stock_movement.dart';
import '../../../services/manager_assistant_api_service.dart';
import '../../workflow/inventory_decision_workflow_controller.dart';
import 'inventory_agent_components.dart';

class FloatingInventoryAgent extends StatefulWidget {
  const FloatingInventoryAgent({
    required this.moduleName,
    required this.suggestions,
    required this.workflowController,
    required this.onOpenFullAssistant,
    super.key,
  });
  final String moduleName;
  final List<String> suggestions;
  final InventoryDecisionWorkflowController workflowController;
  final VoidCallback onOpenFullAssistant;

  @override
  State<FloatingInventoryAgent> createState() => _FloatingInventoryAgentState();
}

class _FloatingInventoryAgentState extends State<FloatingInventoryAgent> {
  final _api = ManagerAssistantApiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ManagerChatMessage> _messages = [];
  late String _sessionId;
  String? _failedQuestion;
  bool _open = false;
  bool _sending = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _sessionId =
        widget.workflowController.assistantSessionId ??
        'CHAT-WEB-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movement = widget.workflowController.current?.movement;
    return Positioned(
      right: 18,
      bottom: 18,
      child: SafeArea(
        child: _open
            ? _AgentPanel(
                moduleName: widget.moduleName,
                movement: movement,
                messages: _messages,
                suggestions: widget.suggestions,
                controller: _controller,
                scrollController: _scrollController,
                sending: _sending,
                unavailable: _unavailable,
                onMinimize: () => setState(() => _open = false),
                onClose: _close,
                onSend: _send,
                onSuggestion: (question) {
                  _controller.text = question;
                  _send();
                },
                onRetry: _retry,
                onOpenFull: widget.onOpenFullAssistant,
              )
            : Semantics(
                button: true,
                label: 'Ask Inventory AI',
                child: Tooltip(
                  message: 'Ask Inventory AI',
                  child: FloatingActionButton(
                    heroTag: 'floating-inventory-agent',
                    onPressed: () => setState(() => _open = true),
                    child: const Icon(Icons.auto_awesome_outlined),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _sending = true;
      _unavailable = false;
      _failedQuestion = question;
      _messages.add(ManagerChatMessage(role: 'user', content: question));
    });
    _scrollToEnd();
    try {
      final movementId = widget.workflowController.movementId;
      final reply = await _api.sendMessage(
        message: question,
        sessionId: _sessionId,
        movementId: movementId,
      );
      if (!mounted) return;
      setState(() {
        _sessionId = reply.sessionId ?? _sessionId;
        _messages.add(
          ManagerChatMessage(
            role: 'assistant',
            content: reply.answer,
            answerSource: reply.answerSource,
            aiModel: reply.aiModel,
          ),
        );
        _sending = false;
        _failedQuestion = null;
      });
      widget.workflowController.setAssistantSession(_sessionId);
      _scrollToEnd();
    } on ManagerAssistantApiException {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _unavailable = true;
      });
    }
  }

  void _retry() {
    final question = _failedQuestion;
    if (question == null || _sending) return;
    if (_messages.isNotEmpty && _messages.last.isManager) {
      _messages.removeLast();
    }
    _controller.text = question;
    _send();
  }

  void _close() => setState(() {
    _open = false;
    _unavailable = false;
  });

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _AgentPanel extends StatelessWidget {
  const _AgentPanel({
    required this.moduleName,
    required this.movement,
    required this.messages,
    required this.suggestions,
    required this.controller,
    required this.scrollController,
    required this.sending,
    required this.unavailable,
    required this.onMinimize,
    required this.onClose,
    required this.onSend,
    required this.onSuggestion,
    required this.onRetry,
    required this.onOpenFull,
  });
  final String moduleName;
  final StockMovement? movement;
  final List<ManagerChatMessage> messages;
  final List<String> suggestions;
  final TextEditingController controller;
  final ScrollController scrollController;
  final bool sending;
  final bool unavailable;
  final VoidCallback onMinimize;
  final VoidCallback onClose;
  final VoidCallback onSend;
  final ValueChanged<String> onSuggestion;
  final VoidCallback onRetry;
  final VoidCallback onOpenFull;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = (screen.width - 28).clamp(300.0, 400.0);
    final height = (screen.height - 120).clamp(420.0, 570.0);
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              color: const Color(0xFF132845),
              child: Row(
                children: [
                  const InventoryAgentIcon(size: 36),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        InventoryAgentStatus(compact: true),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Minimize',
                    onPressed: onMinimize,
                    icon: const Icon(Icons.remove, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            if (movement != null)
              _MovementContext(movement: movement!)
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                color: const Color(0xFFF7F9FC),
                child: Text(
                  '$moduleName · General questions',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF68758D),
                  ),
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How can I help with this page?',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ask about $moduleName using the inventory context available to the Manager Assistant.',
                            style: const TextStyle(color: Color(0xFF68758D)),
                          ),
                          const SizedBox(height: 16),
                          InventoryAgentSuggestions(
                            suggestions: suggestions,
                            onSelected: onSuggestion,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(14),
                      itemCount: messages.length,
                      itemBuilder: (context, index) =>
                          InventoryAgentMessageBubble(message: messages[index]),
                    ),
            ),
            if (unavailable)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: const Color(0xFFFFF1F0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Inventory AI is temporarily unavailable.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: InventoryAgentComposer(
                controller: controller,
                sending: sending,
                onSend: onSend,
                compact: true,
              ),
            ),
            TextButton(
              onPressed: onOpenFull,
              child: const Text('Open full Manager Assistant'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementContext extends StatelessWidget {
  const _MovementContext({required this.movement});
  final StockMovement movement;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    color: const Color(0xFFF0F4FF),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          movement.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          '${movement.fromStore} → ${movement.toStore} · ${movement.status}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF5D6B82)),
        ),
      ],
    ),
  );
}
