import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../data/reparations_repository.dart';
import '../domain/reparation_model.dart';

final reparationsRepositoryProvider = Provider<ReparationsRepository>((ref) => ReparationsRepository(ref.watch(supabaseClientProvider)));

final reparationsProvider = FutureProvider.autoDispose<List<Reparation>>((ref) {
  return ref.watch(reparationsRepositoryProvider).getAll();
});

final reparationsVehiculeProvider =
    FutureProvider.autoDispose.family<List<Reparation>, String>((ref, vehiculeId) {
  return ref.watch(reparationsRepositoryProvider).getAll(vehiculeId: vehiculeId);
});
