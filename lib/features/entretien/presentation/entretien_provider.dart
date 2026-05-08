import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../data/entretien_repository.dart';
import '../domain/alerte_model.dart';

final entretienRepositoryProvider = Provider<EntretienRepository>((ref) => EntretienRepository(ref.watch(supabaseClientProvider)));

final alertesEntretienProvider =
    FutureProvider.autoDispose<List<AlerteEntretien>>((ref) {
  return ref.watch(entretienRepositoryProvider).getActives();
});
