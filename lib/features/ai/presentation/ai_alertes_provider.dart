// lib/features/ai/presentation/ai_alertes_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart';

class AiAlerte {
  final String id;
  final String type;
  final String titre;
  final String message;
  final String severite; // info | attention | urgent
  final bool lue;
  final DateTime createdAt;

  AiAlerte({
    required this.id,
    required this.type,
    required this.titre,
    required this.message,
    required this.severite,
    required this.lue,
    required this.createdAt,
  });

  factory AiAlerte.fromMap(Map<String, dynamic> m) => AiAlerte(
        id: m['id'] as String,
        type: m['type'] as String? ?? 'autre',
        titre: m['titre'] as String? ?? '',
        message: m['message'] as String? ?? '',
        severite: m['severite'] as String? ?? 'info',
        lue: m['lue'] as bool? ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Alertes non lues du showroom courant, les plus récentes en premier.
/// `autoDispose` : se recharge à chaque entrée sur l'écran qui l'utilise.
final aiAlertesNonLuesProvider =
    FutureProvider.autoDispose<List<AiAlerte>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null) return [];

  final data = await client
      .from('ai_alertes')
      .select('id, type, titre, message, severite, lue, created_at')
      .eq('showroom_id', showroomId)
      .eq('lue', false)
      .order('created_at', ascending: false)
      .limit(10);

  return (data as List).map((m) => AiAlerte.fromMap(m as Map<String, dynamic>)).toList();
});

final aiAlertesActionsProvider = Provider<AiAlertesActions>((ref) {
  return AiAlertesActions(ref.watch(supabaseClientProvider), ref);
});

class AiAlertesActions {
  final SupabaseClient _client;
  final Ref _ref;
  AiAlertesActions(this._client, this._ref);

  Future<void> marquerCommeLue(String alerteId) async {
    await _client.from('ai_alertes').update({'lue': true}).eq('id', alerteId);
    _ref.invalidate(aiAlertesNonLuesProvider);
  }

  Future<void> toutMarquerCommeLu(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from('ai_alertes').update({'lue': true}).inFilter('id', ids);
    _ref.invalidate(aiAlertesNonLuesProvider);
  }
}