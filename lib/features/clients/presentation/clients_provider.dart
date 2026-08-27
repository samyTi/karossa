// lib/features/clients/presentation/clients_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart'; // 🚀 Import du provider de showroom
import '../data/clients_repository.dart';
import '../domain/client_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  // 1. Récupération du showroom actif
  final showroomId = ref.watch(currentShowroomIdProvider);
  
  if (showroomId == null) {
    throw Exception("ClientsRepository: Aucun showroom sélectionné.");
  }

  // 2. Injection du showroomId au repository
  return ClientsRepository(
    ref.watch(supabaseClientProvider),
    showroomId: showroomId,
  );
});

// ── Providers de liste ────────────────────────────────────────────────────────

final clientsProvider = FutureProvider.autoDispose<List<Client>>((ref) {
  return ref.watch(clientsRepositoryProvider).getAll();
});

final clientsByStatutProvider =
    FutureProvider.autoDispose.family<List<Client>, ClientStatut>((ref, statut) {
  return ref.watch(clientsRepositoryProvider).getByStatut(statut);
});

// ── Provider de détail ────────────────────────────────────────────────────────

final clientDetailProvider =
    FutureProvider.autoDispose.family<Client?, String>((ref, id) {
  return ref.watch(clientsRepositoryProvider).getById(id);
});