// lib/features/echanges/presentation/echanges_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart'; // 🚀 Import du provider de showroom
import '../data/echanges_repository.dart';
import '../domain/echange_model.dart';

// ── Repository ──────────────────────────────────────────────────────────────

final echangesRepositoryProvider = Provider<EchangesRepository>((ref) {
  // 1. Récupération du showroom actif
  final showroomId = ref.watch(currentShowroomIdProvider);
  
  // 2. Sécurité : vérification que le showroom est bien défini
  if (showroomId == null) {
    throw Exception("EchangesRepository: Aucun showroom sélectionné.");
  }

  // 3. Injection du supabaseClient et du showroomId
  return EchangesRepository(
    ref.watch(supabaseClientProvider),
    showroomId: showroomId,
  );
});

// ── Provider de liste ────────────────────────────────────────────────────────

final echangesProvider = FutureProvider.autoDispose<List<Echange>>((ref) {
  // On surveille le repository (qui se mettra à jour automatiquement si le showroom change)
  return ref.watch(echangesRepositoryProvider).getAll();
});