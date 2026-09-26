// AI-facing primitives use the reserved AI accent and shared live-state motion.
import 'package:flutter/material.dart';

import '../../../core/theme/application_design_tokens.dart';
import '../../../core/widgets/application_ui_components.dart';
import '../../../models/assistant/manager_chat.dart';

class InventoryAgentIcon extends StatelessWidget {
  const InventoryAgentIcon({this.size = 42, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: ApplicationColors.ai(context).withValues(alpha: .10),
      borderRadius: BorderRadius.circular(size * .28),
    ),
    child: Icon(
      Icons.auto_awesome_outlined,
      size: size * .52,
      color: ApplicationColors.ai(context),
    ),
  );
}

class InventoryAgentStatus extends StatelessWidget {
  const InventoryAgentStatus({this.compact = false, super.key});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const ApplicationLivePulse(),
      const SizedBox(width: 6),
      Text(
        compact ? 'Ready' : 'Inventory AI Agent · Ready',
        style: TextStyle(
          fontSize: 12,
          color: ApplicationColors.ai(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class InventoryAgentMessageBubble extends StatelessWidget {
  const InventoryAgentMessageBubble({required this.message, super.key});
  final ManagerChatMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.isManager;
    final bodyColor = user
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user ? 'YOU' : 'INVENTORY AI',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: user
                ? Colors.white.withValues(alpha: .82)
                : ApplicationColors.ai(context),
            fontWeight: FontWeight.w800,
            letterSpacing: .55,
          ),
        ),
        const SizedBox(height: 6),
        _ReadableMessageText(content: message.content, color: bodyColor),
        if (!user && message.answerSource != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ApplicationColors.ai(context).withValues(alpha: .09),
              borderRadius: BorderRadius.circular(ApplicationRadii.pill),
            ),
            child: Text(
              'Source · ${message.answerSource}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ApplicationColors.ai(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!user) ...[
            const InventoryAgentIcon(size: 34),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: user
                ? Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15),
                        bottomLeft: Radius.circular(user ? 15 : 4),
                        bottomRight: Radius.circular(user ? 4 : 15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .16),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: content,
                  )
                : Container(
                    constraints: const BoxConstraints(maxWidth: 680),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ApplicationAiPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: content,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReadableMessageText extends StatelessWidget {
  const _ReadableMessageText({required this.content, required this.color});

  final String content;
  final Color color;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(children: _boldSpans(content)),
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: color,
      fontSize: 15,
      height: 1.55,
      letterSpacing: .05,
    ),
  );

  List<InlineSpan> _boldSpans(String value) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
    var cursor = 0;
    for (final match in pattern.allMatches(value)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: value.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      cursor = match.end;
    }
    if (cursor < value.length) {
      spans.add(TextSpan(text: value.substring(cursor)));
    }
    return spans.isEmpty ? [TextSpan(text: value)] : spans;
  }
}

class InventoryAgentSuggestions extends StatelessWidget {
  const InventoryAgentSuggestions({
    required this.suggestions,
    required this.onSelected,
    this.centered = false,
    super.key,
  });
  final List<String> suggestions;
  final ValueChanged<String> onSelected;
  final bool centered;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: centered ? WrapAlignment.center : WrapAlignment.start,
    children: [
      for (final suggestion in suggestions)
        ActionChip(
          avatar: const Icon(Icons.auto_awesome_outlined, size: 15),
          label: Text(suggestion),
          onPressed: () => onSelected(suggestion),
        ),
    ],
  );
}

class InventoryAgentComposer extends StatelessWidget {
  const InventoryAgentComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
    this.compact = false,
    super.key,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 10 : 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: const Color(0xFFD8DFEA)),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A101828),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !sending,
            minLines: 1,
            maxLines: compact ? 3 : 5,
            maxLength: 500,
            textInputAction: TextInputAction.send,
            decoration: const InputDecoration(
              hintText: 'Ask Inventory AI...',
              border: InputBorder.none,
              counterText: '',
              isDense: true,
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Send message',
          onPressed: sending ? null : onSend,
          icon: sending
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_upward, size: 19),
        ),
      ],
    ),
  );
}
