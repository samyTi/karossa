// lib/features/admin/presentation/showroom_settings_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/showroom_settings_model.dart';

/// Provider qui retourne un [ShowroomSettings] typé (au lieu d'un Map brut).
/// Utilisé par les form screens pour pré-remplir les commissions par défaut.
final showroomSettingsTypedProvider =
    FutureProvider.autoDispose<ShowroomSettings>((ref) async {
  try {
    final client = ref.watch(supabaseClientProvider);
    final data = await client.from('showroom_settings').select().single();
    return ShowroomSettings.fromJson(data);
  } catch (e) {
    AppLogger.w('showroomSettingsTypedProvider fallback', error: e);
    return ShowroomSettings.defaults();
  }
});

/// Notifier pour éditer et sauvegarder les paramètres du showroom.
class ShowroomSettingsNotifier
    extends AsyncNotifier<ShowroomSettings> {
  @override
  Future<ShowroomSettings> build() async {
    try {
      final client = ref.watch(supabaseClientProvider);
      final data = await client.from('showroom_settings').select().single();
      return ShowroomSettings.fromJson(data);
    } catch (e) {
      AppLogger.w('ShowroomSettingsNotifier.build fallback', error: e);
      return ShowroomSettings.defaults();
    }
  }

  Future<void> save(ShowroomSettings settings) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(supabaseClientProvider);
      final payload = settings.toJson()..remove('id');
      final existing =
          await client.from('showroom_settings').select('id');
      if ((existing as List).isNotEmpty) {
        await client
            .from('showroom_settings')
            .update(payload)
            .eq('id', existing.first['id']);
      } else {
        await client.from('showroom_settings').insert(payload);
      }
      return settings;
    });
  }
}

final showroomSettingsNotifierProvider =
    AsyncNotifierProvider<ShowroomSettingsNotifier, ShowroomSettings>(
        ShowroomSettingsNotifier.new);