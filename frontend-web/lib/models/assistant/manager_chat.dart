// Assistant response parsing removes provider reasoning envelopes before any
// full-page or floating chat widget can render them.
class ManagerChatSession {
  const ManagerChatSession({
    required this.sessionId,
    required this.title,
    required this.messageCount,
    this.movementId,
    this.mode,
    this.lastQuestion,
    this.updatedAt,
  });

  factory ManagerChatSession.fromJson(Map<String, dynamic> json) {
    final sessionId = json['session_id']?.toString();
    if (sessionId == null || sessionId.isEmpty) {
      throw const FormatException('Missing chat session ID.');
    }
    return ManagerChatSession(
      sessionId: sessionId,
      title: json['title']?.toString() ?? 'Manager conversation',
      messageCount: _int(json['message_count']),
      movementId: json['movement_id']?.toString(),
      mode: json['mode']?.toString(),
      lastQuestion: json['last_question']?.toString(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  final String sessionId;
  final String title;
  final int messageCount;
  final String? movementId;
  final String? mode;
  final String? lastQuestion;
  final DateTime? updatedAt;
}

class ManagerChatMessage {
  const ManagerChatMessage({
    required this.role,
    required this.content,
    this.messageId,
    this.answerSource,
    this.aiModel,
    this.createdAt,
  });

  factory ManagerChatMessage.fromJson(Map<String, dynamic> json) {
    final role = json['role']?.toString() ?? 'assistant';
    final rawContent = json['content']?.toString() ?? '';
    return ManagerChatMessage(
      messageId: json['message_id']?.toString(),
      role: role,
      content: role.toLowerCase() == 'user'
          ? rawContent
          : _safeAssistantContent(rawContent),
      answerSource: json['answer_source']?.toString(),
      aiModel: json['ai_model']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  final String? messageId;
  final String role;
  final String content;
  final String? answerSource;
  final String? aiModel;
  final DateTime? createdAt;
  bool get isManager => role.toLowerCase() == 'user';
}

class ManagerChatReply {
  const ManagerChatReply({
    required this.sessionId,
    required this.answer,
    required this.intent,
    required this.category,
    required this.answerSource,
    this.movementId,
    this.movementStatus,
    this.aiModel,
    this.errorCode,
  });

  factory ManagerChatReply.fromJson(Map<String, dynamic> json) =>
      ManagerChatReply(
        sessionId: json['session_id']?.toString(),
        answer: _safeAssistantContent(
          json['answer']?.toString() ?? 'No answer was returned.',
        ),
        intent: json['intent']?.toString() ?? 'unknown',
        category: json['category']?.toString() ?? 'unknown',
        answerSource: json['answer_source']?.toString() ?? 'UNKNOWN',
        movementId: json['movement_id']?.toString(),
        movementStatus: json['movement_status']?.toString(),
        aiModel: json['ai_model']?.toString(),
        errorCode: json['error_code']?.toString(),
      );

  final String? sessionId;
  final String answer;
  final String intent;
  final String category;
  final String answerSource;
  final String? movementId;
  final String? movementStatus;
  final String? aiModel;
  final String? errorCode;
}

class ManagerChatHistory {
  const ManagerChatHistory({
    required this.sessionId,
    required this.title,
    required this.messages,
    this.movementId,
  });

  factory ManagerChatHistory.fromJson(Map<String, dynamic> json) {
    final items = json['messages'];
    if (items is! List) throw const FormatException('Missing chat messages.');
    return ManagerChatHistory(
      sessionId: json['session_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Manager conversation',
      movementId: json['movement_id']?.toString(),
      messages: items
          .map(
            (item) => ManagerChatMessage.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  final String sessionId;
  final String title;
  final String? movementId;
  final List<ManagerChatMessage> messages;
}

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

String _safeAssistantContent(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'No answer was returned.';

  // Reasoning-capable providers may wrap private chain-of-thought in these
  // envelopes. Only content outside complete envelopes is user-facing.
  final withoutReasoning = trimmed
      .replaceAll(
        RegExp(
          r'<(?:think|analysis)\b[^>]*>[\s\S]*?</(?:think|analysis)>',
          caseSensitive: false,
        ),
        '',
      )
      .trim();

  // An unterminated envelope is unsafe to show because there is no reliable
  // boundary between internal reasoning and the final answer.
  if (RegExp(
    r'<(?:think|analysis)\b',
    caseSensitive: false,
  ).hasMatch(withoutReasoning)) {
    final recovered = _recoverMarkedFinalAnswer(withoutReasoning);
    if (recovered != null) return recovered;
    return 'The assistant response could not be displayed safely. Please try again.';
  }

  return withoutReasoning.isEmpty
      ? 'The assistant did not return a final answer. Please try again.'
      : withoutReasoning;
}

String? _recoverMarkedFinalAnswer(String reasoningEnvelope) {
  final markers = RegExp(
    r'(?:^|\n)\s*(?:\d+\.\s*)?(?:\*\*)?(?:draft|final answer|final response)(?:\*\*)?\s*:\s*',
    caseSensitive: false,
  ).allMatches(reasoningEnvelope);
  if (markers.isEmpty) return null;

  var answer = reasoningEnvelope.substring(markers.last.end);
  final boundary = RegExp(
    r'\n\s*(?:\d+\.\s*)?(?:\*\*)?(?:check|verify|validation|proceed|rules applied)\b',
    caseSensitive: false,
  ).firstMatch(answer);
  if (boundary != null) answer = answer.substring(0, boundary.start);

  answer = answer.trim();
  if (answer.length >= 2 &&
      ((answer.startsWith('"') && answer.endsWith('"')) ||
          (answer.startsWith("'") && answer.endsWith("'")))) {
    answer = answer.substring(1, answer.length - 1).trim();
  }
  return answer.isEmpty ? null : answer;
}
