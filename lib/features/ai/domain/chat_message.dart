// lib/features/ai/domain/chat_message.dart

import 'dart:typed_data';

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isLoading;

  /// Libellé de l'étape en cours pendant que l'IA "réfléchit"
  /// (ex: "🔍 Consultation des locations en retard…"). Non null
  /// uniquement pendant [isLoading] ; affiché à la place du typing indicator
  /// classique pour rendre visible le raisonnement multi-outils.
  final String? toolTrace;

  /// true tant que la réponse arrive encore token par token (voir
  /// AiRepository.sendMessageStream). Permet d'afficher un curseur
  /// clignotant en fin de bulle pour un effet "machine à écrire".
  final bool isStreaming;

  /// Photo jointe par l'utilisateur (constat de dommage, facture, carte
  /// grise...) affichée en miniature dans la bulle. Jamais persistée :
  /// vit uniquement en mémoire le temps de la session de chat.
  final Uint8List? imageBytes;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isLoading = false,
    this.toolTrace,
    this.isStreaming = false,
    this.imageBytes,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.user(String content, {Uint8List? imageBytes}) =>
      ChatMessage(role: 'user', content: content, imageBytes: imageBytes);

  factory ChatMessage.assistant(String content) =>
      ChatMessage(role: 'assistant', content: content);

  factory ChatMessage.loading({String? toolTrace}) =>
      ChatMessage(role: 'assistant', content: '', isLoading: true, toolTrace: toolTrace);

  factory ChatMessage.streaming({String content = ''}) =>
      ChatMessage(role: 'assistant', content: content, isStreaming: true);

  ChatMessage copyWith({
    String? role,
    String? content,
    DateTime? timestamp,
    bool? isLoading,
    String? toolTrace,
    bool? isStreaming,
    Uint8List? imageBytes,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
      toolTrace: toolTrace ?? this.toolTrace,
      isStreaming: isStreaming ?? this.isStreaming,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }

  Map<String, dynamic> toMap() => {'role': role, 'content': content};
}
