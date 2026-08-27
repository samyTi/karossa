// lib/features/contrats/presentation/contrats_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/contrats_repository.dart';
import '../domain/contrat_template_model.dart';

final contratsRepositoryProvider = Provider<ContratsRepository>((ref) {
  final client     = ref.watch(supabaseClientProvider);
  final showroomId = ref.watch(currentShowroomIdProvider);
  // On passe null explicitement si non chargé — le repo refuse d'agir sur ''
  return ContratsRepository(client, showroomId: showroomId);
});

/// Settings showroom depuis la table `showrooms` (schéma réel).
/// Guard : retourne les defaults si showroomId pas encore disponible.
final showroomSettingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null || showroomId.isEmpty) {
    return Future.value({
      'nom': 'Garage Auto', 'adresse': '', 'tel': '',
      'email': '', 'rc': '', 'logo_url': null,
    });
  }
  return ref.watch(contratsRepositoryProvider).getShowroomSettings();
});

final contractTemplatesProvider =
    FutureProvider.autoDispose<List<ContratTemplate>>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null || showroomId.isEmpty) return Future.value([]);
  return ref.watch(contratsRepositoryProvider).getTemplates();
});

final activeLocationTemplateProvider =
    FutureProvider.autoDispose<ContratTemplate?>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null || showroomId.isEmpty) return Future.value(null);
  return ref.watch(contratsRepositoryProvider).getActiveTemplate('location');
});

final activeVenteTemplateProvider =
    FutureProvider.autoDispose<ContratTemplate?>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null || showroomId.isEmpty) return Future.value(null);
  return ref.watch(contratsRepositoryProvider).getActiveTemplate('vente');
});