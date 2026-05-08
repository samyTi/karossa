// lib/features/ai/presentation/ai_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../data/ai_repository.dart';
import '../domain/chat_message.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) => AiRepository(ref.watch(supabaseClientProvider)));

// État du chat : liste de messages
final chatMessagesProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref.watch(aiRepositoryProvider));
});

// Véhicule contexte courant (optionnel)
final aiVehiculeContextProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final AiRepository _repo;

  ChatNotifier(this._repo)
      : super([
          ChatMessage.assistant(
            'Bonjour ! Je suis KarossaAI 🚗\nComment puis-je vous aider avec votre showroom ?',
          ),
        ]);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> sendMessage(
    String text, {
    Map<String, dynamic>? vehiculeContext,
  }) async {
    if (text.trim().isEmpty || _isLoading) return;

    // Ajouter le message utilisateur
    state = [...state, ChatMessage.user(text)];

    // Ajouter indicateur de chargement
    _isLoading = true;
    state = [...state, ChatMessage.loading()];

    try {
      // Historique sans le message loading
      final history = state
          .where((m) => !m.isLoading && m.content.isNotEmpty)
          .toList()
        ..removeLast(); // enlever le dernier message user qu'on vient d'ajouter

      final response = await _repo.sendMessage(
        message: text,
        history: history,
        vehiculeContext: vehiculeContext,
      );

      // Remplacer le loading par la vraie réponse
      state = [
        ...state.where((m) => !m.isLoading),
        ChatMessage.assistant(response),
      ];
    } catch (e) {
      state = [
        ...state.where((m) => !m.isLoading),
        ChatMessage.assistant('❌ Erreur: $e'),
      ];
    } finally {
      _isLoading = false;
    }
  }

  void clearChat() {
    state = [
      ChatMessage.assistant(
        'Conversation réinitialisée. Comment puis-je vous aider ?',
      ),
    ];
  }
}