// lib/features/achats/presentation/achats_provider.dart
//
// CHANGEMENT : le repository est maintenant instancié avec le client injecté.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../data/achats_repository.dart';
import '../domain/achat_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final achatsRepositoryProvider = Provider<AchatsRepository>((ref) {
  return AchatsRepository(ref.watch(supabaseClientProvider));
});

// ── Providers ─────────────────────────────────────────────────────────────────

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
