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
  /// ⚠️ [limit] est un plafond de sécurité, pas une "vraie" limite métier :
  /// la pagination interne (voir GpsLocalSource.getHistory) va chercher
  /// TOUTES les lignes de la période jusqu'à ce plafond, pour ne pas biaiser
  /// le calcul de km/vitesse vers la partie la plus ancienne de la période.
  Future<List<GpsPosition>> getHistoryFromSupabase({
    required String vehiculeId,
    required DateTime from,
    required DateTime to,
    int limit = 20000,
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
  Future<List<GpsPosition>> getFleetHistoryForPeriod({
    required DateTime from,
    required DateTime to,
    int limitPerVehicle = 1000,
  });

  // ── Nettoyage / rétention ─────────────────────────────────

  /// Supprime définitivement TOUTES les positions d'un véhicule (ou de toute
  /// la flotte du showroom si [vehiculeId] est null) comprises dans
  /// [from]..[to]. Retourne le nombre de lignes supprimées.
  Future<int> deletePositionsInRange({
    String? vehiculeId,
    required DateTime from,
    required DateTime to,
  });

  /// Réduit la densité des enregistrements sur [from]..[to] en ne conservant
  /// qu'un seul point toutes les [intervalMinutes] minutes (le plus ancien de
  /// chaque tranche). Si [vehiculeId] est null, s'applique à toute la flotte
  /// du showroom. Retourne le nombre de lignes supprimées.
  Future<int> decimatePositions({
    String? vehiculeId,
    required DateTime from,
    required DateTime to,
    required int intervalMinutes,
  });
}
