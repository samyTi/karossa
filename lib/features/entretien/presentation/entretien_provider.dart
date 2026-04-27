import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/entretien_repository.dart';
import '../domain/alerte_model.dart';

final entretienRepositoryProvider = Provider((_) => EntretienRepository());

final alertesEntretienProvider =
    FutureProvider.autoDispose<List<AlerteEntretien>>((ref) {
  return ref.watch(entretienRepositoryProvider).getActives();
});
