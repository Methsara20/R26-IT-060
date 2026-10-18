import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/models/assistant/manager_chat.dart';

void main() {
  test('removes provider reasoning from a new assistant reply', () {
    final reply = ManagerChatReply.fromJson({
      'answer': '<think>private reasoning</think>Final manager answer.',
      'answer_source': 'GROQ',
    });

    expect(reply.answer, 'Final manager answer.');
    expect(reply.answer, isNot(contains('private reasoning')));
  });

  test('removes provider reasoning from stored assistant history', () {
    final message = ManagerChatMessage.fromJson({
      'role': 'assistant',
      'content': '<analysis>hidden steps</analysis>Stored final answer.',
    });

    expect(message.content, 'Stored final answer.');
  });

  test('preserves user text even when it mentions a reasoning tag', () {
    final message = ManagerChatMessage.fromJson({
      'role': 'user',
      'content': 'What does <think> mean?',
    });

    expect(message.content, 'What does <think> mean?');
  });

  test('does not expose an unterminated reasoning envelope', () {
    final reply = ManagerChatReply.fromJson({
      'answer': '<think>private reasoning without a final boundary',
      'answer_source': 'GROQ',
    });

    expect(reply.answer, contains('could not be displayed safely'));
    expect(reply.answer, isNot(contains('private reasoning')));
  });

  test('recovers a marked final answer from unclosed reasoning', () {
    final reply = ManagerChatReply.fromJson({
      'answer': '''<think>
Private product analysis for P0100.
Draft:
Product P0100 currently requires a stock-level review.
Check constraints:
- Uses stored context only.''',
      'answer_source': 'GROQ',
    });

    expect(
      reply.answer,
      'Product P0100 currently requires a stock-level review.',
    );
    expect(reply.answer, isNot(contains('Private product analysis')));
    expect(reply.answer, isNot(contains('Check constraints')));
  });

  test('preserves clean final content after a closed reasoning block', () {
    final reply = ManagerChatReply.fromJson({
      'answer':
          '<think>hidden forecast reasoning</think>Explain the stored forecast.',
      'answer_source': 'GROQ',
    });

    expect(reply.answer, 'Explain the stored forecast.');
  });
}
