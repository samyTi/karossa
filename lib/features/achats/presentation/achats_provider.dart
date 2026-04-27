import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/achats_repository.dart';
import '../domain/achat_model.dart';

/// Provider pour le repository des achats
final achatsRepositoryProvider = Provider((ref) => AchatsRepository());

/// Provider pour la liste de tous les achats
final achatsProvider = FutureProvider.autoDispose<List<Achat>>((ref) {
  return ref.watch(achatsRepositoryProvider).getAchats();
});

/// Provider pour les achats en cours
final achatsEnCoursProvider = FutureProvider.autoDispose<List<Achat>>((ref) {
  return ref.watch(achatsRepositoryProvider).getAchatsByStatut(AchatStatut.en_cours);
});

/// Provider pour les achats validés
final achatsValidesProvider = FutureProvider.autoDispose<List<Achat>>((ref) {
  return ref.watch(achatsRepositoryProvider).getAchatsByStatut(AchatStatut.valide);
});

/// Provider pour les statistiques des achats
final statsAchatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(achatsRepositoryProvider).getStatsAchats();
});