// Final-polish pass: aligns assistant chrome and panels with the shared system.
import 'package:flutter/material.dart';

import '../../core/theme/application_design_tokens.dart';
import '../../models/assistant/manager_chat.dart';
import '../../models/stock_movement/stock_movement.dart';
import '../../services/manager_assistant_api_service.dart';
import '../../services/stock_movement_api_service.dart';
import '../../core/widgets/application_page_layout.dart';
import '../../core/widgets/application_ui_components.dart';
import '../workflow/inventory_decision_workflow_controller.dart';
import '../workflow/active_workflow_banner.dart';
import 'widgets/inventory_agent_components.dart';
import 'inventory_assistant_suggestions.dart';

class ManagerAssistantScreen extends StatefulWidget {
  const ManagerAssistantScreen({
    required this.workflowController,
    this.initialMovementId,
    super.key,
  });

  final InventoryDecisionWorkflowController workflowController;
  final String? initialMovementId;

  @override
  State<ManagerAssistantScreen> createState() => _ManagerAssistantScreenState();
}

class _ManagerAssistantScreenState extends State<ManagerAssistantScreen> {
  final _api = ManagerAssistantApiService();
  final _movementApi = StockMovementApiService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<ManagerChatSession> _sessions = const [];
  List<StockMovement> _movements = const [];
  List<ManagerChatMessage> _messages = const [];
  late String _sessionId;
  String? _movementId;
  String? _error;
  String? _failedQuestion;
  bool _loading = true;
  bool _sending = false;
  late bool _restoreSession;

  @override
  void initState() {
    super.initState();
    final storedSessionId = widget.workflowController.assistantSessionId;
    _restoreSession = storedSessionId != null;
    _sessionId = storedSessionId ?? _newSessionId();
    _movementId = widget.initialMovementId;
    _loadInitialData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activeMovement = widget.workflowController.current?.movement;
      final sessionsFuture = _api.getSessions();
      final historyFuture = !_restoreSession
          ? null
          : _api.getHistory(_sessionId);
      final movementsFuture = activeMovement == null
          ? _movementApi.getMovements()
          : null;
      final sessions = await sessionsFuture;
      final history = historyFuture == null ? null : await historyFuture;
      final movements = activeMovement == null
          ? await movementsFuture!
          : <StockMovement>[activeMovement];
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _movements = movements;
        if (history != null) {
          _movementId = history.movementId ?? _movementId;
          _messages = history.messages;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _newConversation() {
    final sessionId = _newSessionId();
    _restoreSession = false;
    setState(() {
      _sessionId = sessionId;
      _movementId = widget.workflowController.movementId;
      _messages = const [];
      _error = null;
    });
  }

  Future<void> _openSession(ManagerChatSession session) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await _api.getHistory(session.sessionId);
      if (!mounted) return;
      setState(() {
        _sessionId = history.sessionId;
        _movementId = history.movementId;
        _messages = history.messages;
        _loading = false;
      });
      widget.workflowController.setAssistantSession(history.sessionId);
      _scrollToEnd();
    } on ManagerAssistantApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final question = _messageController.text.trim();
    if (question.isEmpty || _sending) return;
    _messageController.clear();
    setState(() {
      _sending = true;
      _error = null;
      _failedQuestion = question;
      _messages = [
        ..._messages,
        ManagerChatMessage(role: 'user', content: question),
      ];
    });
    _scrollToEnd();
    try {
      final reply = await _api.sendMessage(
        message: question,
        sessionId: _sessionId,
        movementId: _movementId,
      );
      if (!mounted) return;
      setState(() {
        _sessionId = reply.sessionId ?? _sessionId;
        _movementId = reply.movementId ?? _movementId;
        _messages = [
          ..._messages,
          ManagerChatMessage(
            role: 'assistant',
            content: reply.answer,
            answerSource: reply.answerSource,
            aiModel: reply.aiModel,
          ),
        ];
        _sending = false;
        _failedQuestion = null;
      });
      widget.workflowController.setAssistantSession(_sessionId);
      _scrollToEnd();
      // Refresh session titles and message counts after the backend saves a turn.
      final sessions = await _api.getSessions();
      if (mounted) setState(() => _sessions = sessions);
    } on ManagerAssistantApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.message;
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final workflow = widget.workflowController.current;
    final assistantContext = resolveInventoryAssistantContext(
      workflow: workflow,
      movementId: _movementId,
      messages: _messages,
    );
    return ApplicationPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ApplicationPageHeader(
            title: 'Manager Assistant',
            subtitle:
                'Ask Inventory AI for decision support across your inventory network',
            contextual: const InventoryAgentStatus(compact: true),
            onRefresh: _loading ? null : _loadInitialData,
            refreshTooltip: 'Refresh assistant context',
          ),
          const SizedBox(height: 24),
          if (workflow != null) ...[
            ActiveWorkflowBanner(workflow: workflow),
            const SizedBox(height: 14),
          ],
          SizedBox(
            height: 690,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showHistory = constraints.maxWidth >= 820;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHistory) ...[
                      SizedBox(
                        width: 280,
                        child: _HistoryPanel(
                          sessions: _sessions,
                          selectedSessionId: _sessionId,
                          onNew: _newConversation,
                          onSelected: _openSession,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: _ChatPanel(
                        messages: _messages,
                        movements: _movements,
                        movementId: _movementId,
                        controller: _messageController,
                        scrollController: _scrollController,
                        loading: _loading,
                        sending: _sending,
                        error: _error,
                        suggestedQuestions: inventoryAssistantSuggestions(
                          assistantContext,
                        ),
                        showHistoryButton: !showHistory,
                        onMovementChanged: (value) =>
                            setState(() => _movementId = value),
                        onSuggestedQuestion: (question) {
                          _messageController.text = question;
                          _send();
                        },
                        onSend: _send,
                        onRetry: _failedQuestion == null
                            ? _loadInitialData
                            : _retryFailedQuestion,
                        onShowHistory: () => _showMobileHistory(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showMobileHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: _HistoryPanel(
            sessions: _sessions,
            selectedSessionId: _sessionId,
            onNew: () {
              Navigator.pop(context);
              _newConversation();
            },
            onSelected: (session) {
              Navigator.pop(context);
              _openSession(session);
            },
          ),
        ),
      ),
    );
  }

  void _retryFailedQuestion() {
    final question = _failedQuestion;
    if (question == null || _sending) return;
    if (_messages.isNotEmpty && _messages.last.isManager) {
      _messages = _messages.sublist(0, _messages.length - 1);
    }
    _messageController.text = question;
    _send();
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.sessions,
    required this.selectedSessionId,
    required this.onNew,
    required this.onSelected,
  });
  final List<ManagerChatSession> sessions;
  final String selectedSessionId;
  final VoidCallback onNew;
  final ValueChanged<ManagerChatSession> onSelected;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add),
            label: const Text('New conversation'),
          ),
        ),
        const Divider(height: 1),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            'Recent chats',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: sessions.isEmpty
              ? const Center(child: Text('No saved conversations yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return ListTile(
                      selected: session.sessionId == selectedSessionId,
                      leading: const Icon(Icons.chat_bubble_outline, size: 20),
                      title: Text(
                        session.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${session.messageCount} messages'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      onTap: () => onSelected(session),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.messages,
    required this.movements,
    required this.movementId,
    required this.controller,
    required this.scrollController,
    required this.loading,
    required this.sending,
    required this.error,
    required this.suggestedQuestions,
    required this.showHistoryButton,
    required this.onMovementChanged,
    required this.onSuggestedQuestion,
    required this.onSend,
    required this.onRetry,
    required this.onShowHistory,
  });
  final List<ManagerChatMessage> messages;
  final List<StockMovement> movements;
  final String? movementId;
  final TextEditingController controller;
  final ScrollController scrollController;
  final bool loading;
  final bool sending;
  final String? error;
  final List<String> suggestedQuestions;
  final bool showHistoryButton;
  final ValueChanged<String?> onMovementChanged;
  final ValueChanged<String> onSuggestedQuestion;
  final VoidCallback onSend;
  final VoidCallback onRetry;
  final VoidCallback onShowHistory;

  @override
  Widget build(BuildContext context) => ApplicationAiPanel(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (showHistoryButton)
                IconButton(
                  onPressed: onShowHistory,
                  icon: const Icon(Icons.history),
                ),
              CircleAvatar(
                backgroundColor: ApplicationColors.ai(
                  context,
                ).withValues(alpha: .12),
                foregroundColor: ApplicationColors.ai(context),
                child: const Icon(Icons.auto_awesome),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory AI Agent',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Grounded in verified inventory data',
                      style: TextStyle(fontSize: 12, color: Color(0xFF68758C)),
                    ),
                    SizedBox(height: 3),
                    InventoryAgentStatus(compact: true),
                  ],
                ),
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String?>(
                  initialValue:
                      movements.any((item) => item.movementId == movementId)
                      ? movementId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Movement context',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('General questions'),
                    ),
                    for (final movement in movements)
                      DropdownMenuItem<String?>(
                        value: movement.movementId,
                        child: Text(
                          '${movement.productName} • ${movement.status}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: sending ? null : onMovementChanged,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
              ? _WelcomePanel(
                  suggestedQuestions: suggestedQuestions,
                  onSelected: onSuggestedQuestion,
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _MessageBubble(message: messages[index]),
                ),
        ),
        if (error != null)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFECEC),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(error ?? 'Inventory AI is temporarily unavailable.'),
                ),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        if (messages.isNotEmpty && suggestedQuestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: InventoryAgentSuggestions(
              suggestions: suggestedQuestions,
              onSelected: onSuggestedQuestion,
            ),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !loading && !sending,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Ask Inventory AI...',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Send message',
                onPressed: loading || sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({
    required this.suggestedQuestions,
    required this.onSelected,
  });

  final List<String> suggestedQuestions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const InventoryAgentIcon(size: 54),
          const SizedBox(height: 14),
          const Text(
            'What can I help you analyze?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask about inventory health, forecasts, recommendations or stock-flow decisions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF68758C)),
          ),
          if (suggestedQuestions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final question in suggestedQuestions)
                  ActionChip(
                    avatar: const Icon(Icons.help_outline, size: 17),
                    label: Text(question),
                    onPressed: () => onSelected(question),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ManagerChatMessage message;

  @override
  Widget build(BuildContext context) =>
      InventoryAgentMessageBubble(message: message);
}

String _newSessionId() => 'CHAT-WEB-${DateTime.now().microsecondsSinceEpoch}';
