// lib/features/clients/presentation/clients_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/clients_repository.dart';
import '../domain/client_model.dart';

final clientsRepositoryProvider = Provider((_) => ClientsRepository());

final clientsProvider = FutureProvider.autoDispose<List<Client>>((ref) {
  return ref.watch(clientsRepositoryProvider).getAll();
});

final clientsByStatutProvider =
    FutureProvider.autoDispose.family<List<Client>, ClientStatut>((ref, statut) {
  return ref.watch(clientsRepositoryProvider).getByStatut(statut);
});
