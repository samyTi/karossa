// lib/features/gps/domain/gps_repository.dart
//
// Contrat abstrait du repository GPS.
// La couche data l'implémente ; la couche presentation ne connaît que cette interface.
//
// Utilise le type Either-like via (GpsFailure?, GpsPosition?) pour rester
// sans dépendance supplémentaire (fpdart / dartz optionnel).

import 'gps_position.dart';
import 'gps_failure.dart';

abstract interface class GpsRepository {
  // ── Position live ────────────────────────────────────────

  /// Récupère la dernière position d'un device Flespi ET la stocke dans Supabase.
  Future<({GpsPosition? position, GpsFailure? failure})> fetchAndStoreLivePosition({
    required int flespiDeviceId,
    required String vehiculeId,
  });

  /// Récupère la dernière position sans stocker (lecture seule).
  Future<({GpsPosition? position, GpsFailure? failure})> getLivePosition(
    int flespiDeviceId,
    String vehiculeId,
  );

  // ── Flotte complète ──────────────────────────────────────

  /// Retourne les positions actuelles de tous les véhicules GPS actifs.
  /// Chaque entrée : {'vehicule': Map, 'position': GpsPosition?}
  Future<List<Map<String, dynamic>>> getLiveFleet();

  // ── Historique ───────────────────────────────────────────

  /// Historique depuis Supabase (rapide, offline-friendly).
  Future<List<GpsPosition>> getHistoryFromSupabase({
    required String vehiculeId,
    required DateTime from,
    required DateTime to,
    int limit = 500,
  });

  /// Synchronise l'historique Flespi → Supabase et retourne le nombre de points.
  Future<int> syncHistoryToSupabase({
    required int flespiDeviceId,
    required String vehiculeId,
    required DateTime from,
    required DateTime to,
  });

  /// Historique direct depuis Flespi (pour forcer une synchro).
  Future<List<GpsPosition>> getHistoryFromFlespi({
    required int flespiDeviceId,
    required String vehiculeId,
    required DateTime from,
    required DateTime to,
  });
}
