// lib/features/reparations/presentation/reparations_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart'; // 🚀 Import requis
import '../data/reparations_repository.dart';
import '../domain/reparation_model.dart';

// ── Repository ──────────────────────────────────────────────────────────────

final reparationsRepositoryProvider = Provider<ReparationsRepository>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  
  if (showroomId == null) {
    throw Exception("ReparationsRepository: Aucun showroom sélectionné.");
  }

  return ReparationsRepository(
    ref.watch(supabaseClientProvider),
    showroomId: showroomId,
  );
});

// ── Providers de liste ───────────────────────────────────────────────────────

final reparationsProvider = FutureProvider.autoDispose<List<Reparation>>((ref) {
  return ref.watch(reparationsRepositoryProvider).getAll();
});

final reparationsVehiculeProvider =
    FutureProvider.autoDispose.family<List<Reparation>, String>((ref, vehiculeId) {
  return ref.watch(reparationsRepositoryProvider).getAll(vehiculeId: vehiculeId);
});