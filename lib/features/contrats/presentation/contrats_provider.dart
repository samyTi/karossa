// lib/features/contrats/presentation/contrats_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/contrats_repository.dart';
import '../domain/contrat_template_model.dart';

final contratsRepositoryProvider = Provider((_) => ContratsRepository());

final showroomSettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(contratsRepositoryProvider).getShowroomSettings();
});

final contractTemplatesProvider = FutureProvider.autoDispose<List<ContratTemplate>>((ref) {
  return ref.watch(contratsRepositoryProvider).getTemplates();
});

final activeLocationTemplateProvider = FutureProvider.autoDispose<ContratTemplate?>((ref) {
  return ref.watch(contratsRepositoryProvider).getActiveTemplate('location');
});

final activeVenteTemplateProvider = FutureProvider.autoDispose<ContratTemplate?>((ref) {
  return ref.watch(contratsRepositoryProvider).getActiveTemplate('vente');
});
