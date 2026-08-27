// lib/features/gps/data/gps_local_source.dart
//
// Source locale GPS — toutes les opérations Supabase sont ici.
// GpsRepositoryImpl l'utilise pour séparer la logique HTTP (FlespiService)
// de la persistance (Supabase).
//
// ⚠️  MIGRATION SQL REQUISE avant d'utiliser cette version.
//     Voir : gps_positions_migration.sql

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/gps_position.dart';

class GpsLocalSource {
  final SupabaseClient _supabase;
  static const String _table = 'gps_positions';

  const GpsLocalSource({required SupabaseClient supabase})
      : _supabase = supabase;

  // ── Écriture ─────────────────────────────────────────────────────────────

  Future<void> upsertPosition(GpsPosition position) async {
    await _supabase
        .from(_table)
        .upsert(_toRow(position), onConflict: 'vehicule_id,fix_time');
  }

  Future<void> upsertPositions(List<GpsPosition> positions) async {
    if (positions.isEmpty) return;
    await _supabase
        .from(_table)
        .upsert(positions.map(_toRow).toList(), onConflict: 'vehicule_id,fix_time');
  }

  // ── Lecture — historique ──────────────────────────────────────────────────
  //
  // ⚠️ CORRECTIF IMPORTANT — un seul appel `.limit(n)` trié par fix_time
  // ASCENDANT ne renvoie que les n plus ANCIENS points de la période : si le
  // véhicule génère plus de `n` positions avant même d'avoir roulé (le
  // traceur envoie un ping en continu, à l'arrêt comme en mouvement), le
  // trajet réel — souvent plus tard dans la période — n'est JAMAIS récupéré.
  // C'est ce qui causait "0 km / aucune donnée aujourd'hui" et un
  // kilométrage hebdomadaire très sous-évalué alors que Flespi avait bien
  // toutes les données.
  //
  // On pagine désormais avec `.range()` jusqu'à épuisement ou jusqu'à un
  // plafond de sécurité (`hardCap`), pour ne plus jamais couper une période
  // en tronquant sur sa partie la plus ancienne.

  static const int _pageSize = 1000;

  Future<List<GpsPosition>> getHistory({
    required String   vehiculeId,
    required DateTime from,
    required DateTime to,
    int               limit = 20000, // plafond de sécurité, plus une "vraie" limite métier
  }) async {
    final all = <Map<String, dynamic>>[];
    int offset = 0;

    while (all.length < limit) {
      final pageLimit = (limit - all.length) < _pageSize ? (limit - all.length) : _pageSize;
      final rows = await _supabase
          .from(_table)
          .select()
          .eq('vehicule_id', vehiculeId)
          .gte('fix_time', from.toIso8601String())
          .lte('fix_time', to.toIso8601String())
          .order('fix_time', ascending: true)
          .range(offset, offset + pageLimit - 1);

      final page = (rows as List<dynamic>).cast<Map<String, dynamic>>();
      all.addAll(page);

      if (page.length < pageLimit) break; // dernière page atteinte
      offset += pageLimit;
    }

    return all.map(_fromRow).toList();
  }

  // ── Lecture — dernière position connue ────────────────────────────────────

  Future<GpsPosition?> getLastKnownPosition(String vehiculeId) async {
    final rows = await _supabase
        .from(_table)
        .select()
        .eq('vehicule_id', vehiculeId)
        .order('fix_time', ascending: false)
        .limit(1);

    final list = rows as List<dynamic>;
    if (list.isEmpty) return null;
    return _fromRow(list.first as Map<String, dynamic>);
  }

  // ── Lecture — dernière position de plusieurs véhicules ────────────────────

  Future<Map<String, GpsPosition>> getLastKnownPositions(
    List<String> vehiculeIds,
  ) async {
    if (vehiculeIds.isEmpty) return {};
    final futures = vehiculeIds.map((id) async {
      final pos = await getLastKnownPosition(id);
      return (id, pos);
    });
    final results = await Future.wait(futures);
    final map = <String, GpsPosition>{};
    for (final (id, pos) in results) {
      if (pos != null) map[id] = pos;
    }
    return map;
  }

  // ── Lecture — historique multi-véhicules (heat map) ───────────────────────

  Future<List<GpsPosition>> getHistoryForVehicles({
    required List<String> vehiculeIds,
    required DateTime     from,
    required DateTime     to,
    int                   limit = 50000,
  }) async {
    if (vehiculeIds.isEmpty) return [];

    final all = <Map<String, dynamic>>[];
    int offset = 0;

    while (all.length < limit) {
      final pageLimit = (limit - all.length) < _pageSize ? (limit - all.length) : _pageSize;
      final rows = await _supabase
          .from(_table)
          .select()
          .inFilter('vehicule_id', vehiculeIds)
          .gte('fix_time', from.toIso8601String())
          .lte('fix_time', to.toIso8601String())
          .order('fix_time', ascending: true)
          .range(offset, offset + pageLimit - 1);

      final page = (rows as List<dynamic>).cast<Map<String, dynamic>>();
      all.addAll(page);

      if (page.length < pageLimit) break;
      offset += pageLimit;
    }

    return all.map(_fromRow).toList();
  }

  // ── Nettoyage ─────────────────────────────────────────────────────────────

  Future<int> deleteOldPositions({
    required String   vehiculeId,
    required DateTime before,
  }) async {
    final response = await _supabase
        .from(_table)
        .delete()
        .eq('vehicule_id', vehiculeId)
        .lt('fix_time', before.toIso8601String())
        .select('id');
    return (response as List<dynamic>).length;
  }

  Future<void> deleteAllPositions(String vehiculeId) async {
    await _supabase.from(_table).delete().eq('vehicule_id', vehiculeId);
  }

  /// Suppression pure sur un intervalle — délègue au RPC SQL
  /// `gps_positions_delete_range` (voir migration
  /// `gps_positions_cleanup.sql`) qui vérifie côté serveur que
  /// l'utilisateur est gérant/propriétaire du showroom concerné.
  Future<int> deletePositionsInRange({
    required String    showroomId,
    String?             vehiculeId,
    required DateTime   from,
    required DateTime   to,
  }) async {
    final result = await _supabase.rpc('gps_positions_delete_range', params: {
      'p_showroom_id': showroomId,
      'p_vehicule_id': vehiculeId,
      'p_from':        from.toUtc().toIso8601String(),
      'p_to':          to.toUtc().toIso8601String(),
    });
    return (result as num?)?.toInt() ?? 0;
  }

  /// Décimation — ne garde qu'un point toutes les [intervalMinutes] minutes
  /// sur l'intervalle donné. Délègue au RPC SQL `gps_positions_decimate`.
  Future<int> decimatePositions({
    required String    showroomId,
    String?             vehiculeId,
    required DateTime   from,
    required DateTime   to,
    required int        intervalMinutes,
  }) async {
    final result = await _supabase.rpc('gps_positions_decimate', params: {
      'p_showroom_id':       showroomId,
      'p_vehicule_id':       vehiculeId,
      'p_from':              from.toUtc().toIso8601String(),
      'p_to':                to.toUtc().toIso8601String(),
      'p_interval_minutes':  intervalMinutes,
    });
    return (result as num?)?.toInt() ?? 0;
  }

  // ── Conversion ────────────────────────────────────────────────────────────

  Map<String, dynamic> _toRow(GpsPosition p) => {
    'vehicule_id':    p.vehiculeId,
    'latitude':       p.latitude,
    'longitude':      p.longitude,
    'speed':          p.speed,
    'altitude':       p.altitude,
    'cap':            p.heading,
    'fix_time':       p.fixTime.toIso8601String(),
    'server_time':    p.serverTime.toIso8601String(),
    // Télémétrie enrichie
    'ignition_on':    p.ignitionOn,
    'battery_level':  p.batteryLevel,
    'fuel_level':     p.fuelLevel,
    'door_open':      p.doorOpen,
    'gnss_valid':     p.gnssValid,
    'position_valid': p.positionValid,
  };

  GpsPosition _fromRow(Map<String, dynamic> row) {
    final serverTime = DateTime.parse(row['server_time'] as String).toUtc();
    final fixTime    = DateTime.parse(row['fix_time']    as String).toUtc();
    final now        = DateTime.now().toUtc();
    final ignitionOn = row['ignition_on'] as bool?;

    return GpsPosition(
      vehiculeId:    row['vehicule_id']   as String,
      latitude:     (row['latitude']      as num).toDouble(),
      longitude:    (row['longitude']     as num).toDouble(),
      speed:        (row['speed']         as num?)?.toDouble(),
      altitude:     (row['altitude']      as num?)?.toDouble(),
      heading:      (row['cap']           as num?)?.toDouble(),
      fixTime:       fixTime,
      serverTime:    serverTime,
      ignitionOn:    ignitionOn,
      batteryLevel:  row['battery_level'] as int?,
      fuelLevel:     row['fuel_level']    as int?,
      doorOpen:      row['door_open']     as bool?,
      gnssValid:     row['gnss_valid']    as bool?,
      positionValid: row['position_valid'] as bool?,
      // 30 min sur server_time (pas fix_time) — fiable même à l'arrêt
      isOnline: now.difference(serverTime).inMinutes < 30 || (ignitionOn ?? false),
    );
  }
}