// lib/features/locations/presentation/locations_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/locations_repository.dart';
import '../domain/location_model.dart';

// ── Repository ──────────────────────────────────────────────────────────────

final locationsRepositoryProvider = Provider<LocationsRepository>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  return LocationsRepository(
    ref.watch(supabaseClientProvider),
    showroomId: showroomId ?? '',
  );
});

// ── Providers de liste ───────────────────────────────────────────────────────

final locationsActivesProvider =
    FutureProvider.autoDispose<List<Location>>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null || showroomId.isEmpty) return [];
  return ref.watch(locationsRepositoryProvider).getActives();
});

final locationsRetardProvider =
    FutureProvider.autoDispose<List<Location>>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null || showroomId.isEmpty) return [];
  return ref.watch(locationsRepositoryProvider).getRetards();
});

final locationsHistoriqueProvider =
    FutureProvider.autoDispose<List<Location>>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null || showroomId.isEmpty) return [];
  return ref.watch(locationsRepositoryProvider).getHistorique();
});

final locationsAllProvider =
    FutureProvider.autoDispose<List<Location>>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null || showroomId.isEmpty) return [];
  return ref.watch(locationsRepositoryProvider).getAll();
});

// ── Stats ────────────────────────────────────────────────────────────────────

final locationsStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null || showroomId.isEmpty) return {};
  return ref.watch(locationsRepositoryProvider).getStats();
});

// ── Detail ───────────────────────────────────────────────────────────────────

final locationDetailProvider =
    FutureProvider.autoDispose.family<Location?, String>((ref, id) {
  return ref.watch(locationsRepositoryProvider).getById(id);
});

final locationPaiementsProvider =
    FutureProvider.autoDispose.family<List<LocationPaiement>, String>((ref, id) {
  return ref.watch(locationsRepositoryProvider).getPaiements(id);
});

// ── Interruptions ─────────────────────────────────────────────────────────────
// NOUVEAU

final locationInterruptionsProvider =
    FutureProvider.autoDispose.family<List<LocationInterruption>, String>(
        (ref, locationId) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null || showroomId.isEmpty) return [];
  return ref
      .watch(locationsRepositoryProvider)
      .getInterruptions(locationId);
});

// ── Recherche / filtre local ─────────────────────────────────────────────────

final locationsSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final locationsStatutFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

final locationsHistoriqueFiltreesProvider =
    Provider.autoDispose<AsyncValue<List<Location>>>((ref) {
  final historique = ref.watch(locationsHistoriqueProvider);
  final search = ref.watch(locationsSearchProvider).toLowerCase().trim();
  final statut = ref.watch(locationsStatutFilterProvider);

  return historique.whenData((list) {
    return list.where((l) {
      if (statut != null && l.statut.name != statut) return false;
      if (search.isEmpty) return true;
      return (l.vehiculeNom?.toLowerCase().contains(search) ?? false) ||
          (l.clientNom?.toLowerCase().contains(search) ?? false);
    }).toList();
  });
});