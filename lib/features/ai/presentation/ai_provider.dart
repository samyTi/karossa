// lib/features/ai/presentation/ai_provider.dart

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/ai_repository.dart';
import '../domain/chat_message.dart';
import 'ai_data_context_provider.dart';

/// Provider gérant l'instanciation automatique du Repository selon le Showroom connecté
final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final showroomId = ref.watch(currentShowroomIdProvider);

  return AiRepository(client, showroomId: showroomId ?? '');
});

/// Provider d'état auto-disposable gérant le flux d'échange de messages
final chatMessagesProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(
    ref.watch(aiRepositoryProvider),
    ref,
  );
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final AiRepository _repo;
  final Ref _ref;

  ChatNotifier(this._repo, this._ref)
      : super([
          ChatMessage.assistant(
              'Bonjour ! Je suis KarossaAI 🚗\nVotre assistant showroom est opérationnel. Comment puis-je vous éclairer aujourd\'hui ?'),
        ]);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> sendMessage(String text, {Map<String, dynamic>? vehiculeContext}) async {
    if (text.trim().isEmpty || _isLoading) return;

    final dataCtx = _ref.read(aiDataContextProvider);

    // Injection immédiate du message de l'utilisateur et du composant de chargement
    state = [...state, ChatMessage.user(text)];
    _isLoading = true;
    state = [...state, ChatMessage.loading(toolTrace: '💭 KarossaAI réfléchit…')];

    try {
      final history = state.where((m) => !m.isLoading && m.content.isNotEmpty).toList();
      // Retire le message user qu'on vient d'ajouter : sendMessage(Stream) le
      // rajoute lui-même dans le buffer envoyé au modèle.
      if (history.isNotEmpty && history.last.role == 'user' && history.last.content == text) {
        history.removeLast();
      }

      final buffer = StringBuffer();

      await for (final delta in _repo.sendMessageStream(
        message: text,
        history: history,
        vehiculeContext: vehiculeContext,
        dataContext: dataCtx != null ? {'label': dataCtx.label, 'data': dataCtx.data} : null,
        onToolCall: (label) {
          state = [
            ...state.where((m) => !m.isLoading && !m.isStreaming),
            ChatMessage.loading(toolTrace: label),
          ];
        },
      )) {
        buffer.write(delta);
        state = [
          ...state.where((m) => !m.isLoading && !m.isStreaming),
          ChatMessage.streaming(content: buffer.toString()),
        ];
      }

      final finalText =
          buffer.toString().isEmpty ? 'KarossaAI n\'a pas pu formuler de réponse.' : buffer.toString();
      state = [
        ...state.where((m) => !m.isLoading && !m.isStreaming),
        ChatMessage.assistant(finalText),
      ];
    } catch (e) {
      state = [
        ...state.where((m) => !m.isLoading && !m.isStreaming),
        ChatMessage.assistant('❌ Une erreur technique est survenue.')
      ];
    } finally {
      _isLoading = false;
    }
  }

  /// Envoie une photo (constat de dommage, facture, carte grise...) avec un
  /// commentaire optionnel. Réponse non streamée (analyse image = un seul
  /// aller-retour), mais avec le même indicateur de progression.
  Future<void> sendImage(Uint8List imageBytes, {String mimeType = 'image/jpeg', String? caption}) async {
    if (_isLoading) return;

    final text = (caption == null || caption.trim().isEmpty)
        ? 'Analyse cette photo et donne-moi un diagnostic détaillé.'
        : caption.trim();

    state = [...state, ChatMessage.user(text, imageBytes: imageBytes)];
    _isLoading = true;
    state = [...state, ChatMessage.loading(toolTrace: '🔎 Analyse de la photo…')];

    try {
      final history = state.where((m) => !m.isLoading && m.content.isNotEmpty).toList();
      final response = await _repo.analyserPhoto(
        imageBytes: imageBytes,
        mimeType: mimeType,
        message: text,
        history: history,
      );
      state = [...state.where((m) => !m.isLoading), ChatMessage.assistant(response)];
    } catch (e) {
      state = [
        ...state.where((m) => !m.isLoading),
        ChatMessage.assistant('❌ Analyse de la photo impossible.'),
      ];
    } finally {
      _isLoading = false;
    }
  }

  void clearChat() {
    state = [ChatMessage.assistant('Discussion réinitialisée. En quoi puis-je vous être utile ?')];
  }
}
