// lib/features/gps/presentation/gps_driving_score_provider.dart
//
// Provider qui calcule le score de conduite d'un véhicule sur une période.
// S'appuie sur l'historique déjà stocké dans Supabase (gps_positions) —
// aucun appel Flespi supplémentaire, donc aucun risque de rate-limit.
//
// Intégration : ajouter l'import dans gps_provider.dart n'est PAS
// nécessaire, ce fichier est autonome et importe gps_provider.dart pour
// réutiliser gpsRepositoryProvider.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/driving_score_calculator.dart';
import '../domain/driving_score.dart';
import 'gps_provider.dart';

typedef DrivingScoreParams = ({String vehiculeId, DateTime from, DateTime to});

final drivingScoreCalculatorProvider = Provider<DrivingScoreCalculator>((ref) {
  return const DrivingScoreCalculator();
});

/// Calcule le score de conduite pour un véhicule sur [from, to].
/// autoDispose : le calcul n'est gardé en mémoire que tant que l'écran
/// qui l'affiche est ouvert.
final drivingScoreProvider =
    FutureProvider.autoDispose.family<DrivingScoreResult, DrivingScoreParams>((ref, params) async {
  final positions = await ref.watch(gpsRepositoryProvider).getHistoryFromSupabase(
        vehiculeId: params.vehiculeId,
        from: params.from,
        to: params.to,
        limit: 5000,
      );

  final calculator = ref.watch(drivingScoreCalculatorProvider);
  return calculator.compute(
    vehiculeId: params.vehiculeId,
    positions: positions,
    periodeDebut: params.from,
    periodeFin: params.to,
  );
});
