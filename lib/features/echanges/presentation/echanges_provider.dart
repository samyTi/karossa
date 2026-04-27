// lib/features/echanges/presentation/echanges_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/echanges_repository.dart';
import '../domain/echange_model.dart';

final echangesRepositoryProvider = Provider((_) => EchangesRepository());

final echangesProvider = FutureProvider.autoDispose<List<Echange>>((ref) {
  return ref.watch(echangesRepositoryProvider).getAll();
});
