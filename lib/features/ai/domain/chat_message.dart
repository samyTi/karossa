// lib/features/ai/domain/chat_message.dart

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isLoading;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isLoading = false,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.user(String content) =>
      ChatMessage(role: 'user', content: content);

  factory ChatMessage.assistant(String content) =>
      ChatMessage(role: 'assistant', content: content);

  factory ChatMessage.loading() =>
      ChatMessage(role: 'assistant', content: '', isLoading: true);

  Map<String, dynamic> toMap() => {'role': role, 'content': content};
}