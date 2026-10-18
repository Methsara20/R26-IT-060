// Final-polish pass: aligns assistant chrome and panels with the shared system.
import 'package:flutter/material.dart';
import '../../core/auth/inventory_api_client.dart';
import '../../core/auth/inventory_auth_scope.dart';

import '../../core/theme/application_design_tokens.dart';
import '../../models/assistant/manager_chat.dart';
import '../../models/stock_movement/stock_movement.dart';
import '../../services/manager_assistant_api_service.dart';
import '../../services/stock_movement_api_service.dart';
import '../../core/widgets/application_page_layout.dart';
import '../../core/widgets/application_ui_components.dart';
import '../../core/widgets/application_feedback_components.dart';
import '../workflow/inventory_decision_workflow_controller.dart';
import '../workflow/active_workflow_banner.dart';
import 'widgets/inventory_agent_components.dart';
import 'inventory_assistant_suggestions.dart';

class ManagerAssistantScreen extends StatefulWidget {
  const ManagerAssistantScreen({
    required this.workflowController,
    this.initialMovementId,
    this.api,
    this.movementApi,
    super.key,
  });

  final InventoryDecisionWorkflowController workflowController;
  final String? initialMovementId;
  final ManagerAssistantApiService? api;
  final StockMovementApiService? movementApi;

  @override
  State<ManagerAssistantScreen> createState() => _ManagerAssistantScreenState();
}

class _ManagerAssistantScreenState extends State<ManagerAssistantScreen> {
  late final ManagerAssistantApiService _api;
  InventoryApiClient? _inventoryClient;
  late final StockMovementApiService _movementApi;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<ManagerChatSession> _sessions = const [];
  List<StockMovement> _movements = const [];
  List<ManagerChatMessage> _messages = const [];
  late String _sessionId;
  String? _movementId;
  String? _error;
  String? _failedQuestion;
  bool _loading = false;
  bool _sending = false;
  bool _refreshing = false;
  late bool _restoreSession;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ManagerAssistantApiService();
    if (widget.movementApi case final movementApi?) {
      _movementApi = movementApi;
    } else {
      _inventoryClient = InventoryApiClient(
        session: InventoryAuthScope.read(context),
      );
      _movementApi = StockMovementApiService(client: _inventoryClient!);
    }
    final storedSessionId = widget.workflowController.assistantSessionId;
    _restoreSession = storedSessionId != null;
    _sessionId = storedSessionId ?? _newSessionId();
    _movementId = widget.initialMovementId;
    _loadInitialData();
  }

  @override
  void dispose() {
    _inventoryClient?.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData({bool refresh = false}) async {
    if (_loading || _refreshing) return;
    setState(() {
      if (refresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
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
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
        _refreshing = false;
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
            contextLabel: 'INVENTORY AI',
            leadingIcon: Icons.auto_awesome_outlined,
            premium: true,
            title: 'Manager Assistant',
            subtitle:
                'Ask Inventory AI for decision support across your inventory network',
            contextual: const InventoryAgentStatus(compact: true),
            onRefresh: _loading ? null : () => _loadInitialData(refresh: true),
            refreshing: _refreshing,
            refreshTooltip: 'Refresh assistant context',
          ),
          const SizedBox(height: 24),
          if (workflow != null) ...[
            ActiveWorkflowBanner(workflow: workflow),
            const SizedBox(height: 14),
          ],
          SizedBox(
            height: (MediaQuery.sizeOf(context).height - 220).clamp(
              560.0,
              820.0,
            ),
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
                        refreshing: _refreshing,
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
                            ? () => _loadInitialData(
                                refresh: _messages.isNotEmpty,
                              )
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
                    final selected = session.sessionId == selectedSessionId;
                    final metadata = [
                      '${session.messageCount} messages',
                      if (session.mode != null) session.mode!,
                    ].join(' · ');
                    return Semantics(
                      selected: selected,
                      button: true,
                      child: Tooltip(
                        message: session.title,
                        child: ListTile(
                          selected: selected,
                          selectedColor: Theme.of(context).colorScheme.primary,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .08),
                          leading: Icon(
                            selected
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            size: 20,
                          ),
                          title: Text(
                            session.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(metadata),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () => onSelected(session),
                        ),
                      ),
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
    required this.refreshing,
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
  final bool refreshing;
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final identity = Row(
                children: [
                  if (showHistoryButton)
                    IconButton(
                      tooltip: 'Open conversation history',
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
                        Text('Grounded in verified inventory data'),
                        SizedBox(height: 3),
                        InventoryAgentStatus(compact: true),
                      ],
                    ),
                  ),
                ],
              );
              final selector = DropdownButtonFormField<String?>(
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
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [identity, const SizedBox(height: 12), selector],
                );
              }
              return Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 16),
                  SizedBox(width: 280, child: selector),
                ],
              );
            },
          ),
        ),
        if (refreshing) const LinearProgressIndicator(minHeight: 2),
        const Divider(height: 1),
        Expanded(
          child: loading
              ? const _AssistantLoadingState()
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: ApplicationInlineNotice(
              title: 'Inventory AI is temporarily unavailable',
              message: error,
              tone: ApplicationNoticeTone.danger,
              action: TextButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
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
          child: InventoryAgentComposer(
            controller: controller,
            sending: sending,
            enabled: !loading,
            onSend: onSend,
          ),
        ),
      ],
    ),
  );
}

class _AssistantLoadingState extends StatelessWidget {
  const _AssistantLoadingState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ApplicationLoadingSkeleton(height: 70, width: 360),
        SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: ApplicationLoadingSkeleton(height: 54, width: 260),
        ),
        SizedBox(height: 18),
        ApplicationLoadingSkeleton(height: 96, width: 480),
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
    child: SingleChildScrollView(
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
