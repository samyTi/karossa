// lib/features/clients/presentation/clients_provider.dart
//
// CHANGEMENTS :
//   1. clientsRepositoryProvider injecte le client via supabaseClientProvider
//   2. clientDetailProvider utilise getById() au lieu de charger toute la liste

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../data/clients_repository.dart';
import '../domain/client_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  return ClientsRepository(ref.watch(supabaseClientProvider));
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

// ✅ CORRIGÉ : utilise getById() directement — ne charge plus toute la liste.
final clientDetailProvider =
    FutureProvider.autoDispose.family<Client?, String>((ref, id) {
  return ref.watch(clientsRepositoryProvider).getById(id);
});
