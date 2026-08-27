// lib/features/admin/presentation/showroom_settings_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/showroom_settings_model.dart';

// ── Provider lecture (FutureProvider) ────────────────────────────────────────
// Cible la table `showrooms` — c'est elle qui contient NOM, ADRESSE,
// COMMISSIONS, GPS, IA. Il n'existe pas de table `showroom_settings`.

final showroomSettingsTypedProvider =
    FutureProvider.autoDispose<ShowroomSettings>((ref) async {
  final showroomId = ref.watch(currentShowroomIdProvider);

  // Guard : profil pas encore chargé → defaults, pas de requête
  if (showroomId == null || showroomId.isEmpty) {
    return ShowroomSettings.defaults();
  }

  try {
    final data = await ref.watch(supabaseClientProvider)
        .from('showrooms')
        .select()
        .eq('id', showroomId)
        .single();

    return ShowroomSettings.fromJson(data);
  } catch (e) {
    AppLogger.w('showroomSettingsTypedProvider: fallback defaults', error: e);
    return ShowroomSettings.defaults();
  }
});

// ── Notifier lecture/écriture ─────────────────────────────────────────────────

class ShowroomSettingsNotifier extends AsyncNotifier<ShowroomSettings> {
  @override
  Future<ShowroomSettings> build() async {
    final showroomId = ref.watch(currentShowroomIdProvider);

    if (showroomId == null || showroomId.isEmpty) {
      return ShowroomSettings.defaults();
    }

    try {
      final data = await ref.watch(supabaseClientProvider)
          .from('showrooms')
          .select()
          .eq('id', showroomId)
          .single();

      return ShowroomSettings.fromJson(data);
    } catch (e) {
      AppLogger.w('ShowroomSettingsNotifier.build: fallback defaults', error: e);
      return ShowroomSettings.defaults();
    }
  }

  /// Met à jour les champs modifiables du showroom.
  /// Ne touche pas à l'id ni au nom du showroom (géré séparément).
  Future<void> save(ShowroomSettings settings) async {
    final showroomId = ref.read(currentShowroomIdProvider);
    if (showroomId == null || showroomId.isEmpty) {
      throw Exception('Impossible de sauvegarder : aucun showroom actif détecté.');
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Payload : on retire 'id' pour ne pas tenter de modifier la PK
      final payload = Map<String, dynamic>.from(settings.toJson())
        ..remove('id');

      await ref.read(supabaseClientProvider)
          .from('showrooms')
          .update(payload)
          .eq('id', showroomId);

      return settings;
    });
  }
}

final showroomSettingsNotifierProvider =
    AsyncNotifierProvider<ShowroomSettingsNotifier, ShowroomSettings>(
        ShowroomSettingsNotifier.new);