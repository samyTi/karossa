// lib/features/achats/presentation/achats_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart'; // 🚀 NOUVEAU : Nécessaire pour surveiller le showroom actif
import '../data/achats_repository.dart';
import '../domain/achat_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

// 🚀 MODIFICATION : Injection dynamique du showroomId actif dans le Repository
final achatsRepositoryProvider = Provider<AchatsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final showroomId = ref.watch(currentShowroomIdProvider);
  
  return AchatsRepository(client, showroomId: showroomId ?? '');
});

// ── Providers ─────────────────────────────────────────────────────────────────
// ✅ Ces listes et statistiques s'auto-adaptent au showroom courant sans toucher à leur code !

final achatsProvider = FutureProvider.autoDispose<List<Achat>>((ref) {
  return ref.watch(achatsRepositoryProvider).getAchats();
});

final achatsEnCoursProvider = FutureProvider.autoDispose<List<Achat>>((ref) {
  return ref
      .watch(achatsRepositoryProvider)
      .getAchatsByStatut(AchatStatut.en_cours);
});

final achatsValidesProvider = FutureProvider.autoDispose<List<Achat>>((ref) {
  return ref
      .watch(achatsRepositoryProvider)
      .getAchatsByStatut(AchatStatut.valide);
});

final statsAchatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(achatsRepositoryProvider).getStatsAchats();
});