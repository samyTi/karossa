// lib/features/gps/data/gps_local_source.dart
//
// Source locale GPS — toutes les opérations Supabase sont ici.
// GpsRepositoryImpl l'utilise pour séparer la logique HTTP (FlespiService)
// de la persistance (Supabase).
//
// Table Supabase requise :
//
//   create table gps_positions (
//     id           uuid        default gen_random_uuid() primary key,
//     vehicule_id  text        not null references vehicules(id) on delete cascade,
//     latitude     float8      not null,
//     longitude    float8      not null,
//     speed        float8,
//     altitude     float8,
//     cap          float8,
//     fix_time     timestamptz not null,
//     server_time  timestamptz not null default now(),
//     created_at   timestamptz not null default now(),
//     unique (vehicule_id, fix_time)
//   );
//
//   -- Index pour les requêtes fréquentes
//   create index on gps_positions (vehicule_id, fix_time desc);

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/gps_position.dart';

class GpsLocalSource {
  final SupabaseClient _supabase;

  static const String _table = 'gps_positions';

  const GpsLocalSource({required SupabaseClient supabase})
      : _supabase = supabase;

  // ── Écriture ─────────────────────────────────────────────

  /// Insère ou met à jour une position (upsert sur vehicule_id + fix_time).
  Future<void> upsertPosition(GpsPosition position) async {
    await _supabase
        .from(_table)
        .upsert(
          _toRow(position),
          onConflict: 'vehicule_id,fix_time',
        );
  }

  /// Insère ou met à jour un lot de positions en une seule requête.
  Future<void> upsertPositions(List<GpsPosition> positions) async {
    if (positions.isEmpty) return;
    await _supabase
        .from(_table)
        .upsert(
          positions.map(_toRow).toList(),
          onConflict: 'vehicule_id,fix_time',
        );
  }

  // ── Lecture — historique ──────────────────────────────────

  /// Historique trié par date croissante, limité à [limit] points.
  Future<List<GpsPosition>> getHistory({
    required String vehiculeId,
    required DateTime from,
    required DateTime to,
    int limit = 500,
  }) async {
    final rows = await _supabase
        .from(_table)
        .select()
        .eq('vehicule_id', vehiculeId)
        .gte('fix_time', from.toIso8601String())
        .lte('fix_time', to.toIso8601String())
        .order('fix_time', ascending: true)
        .limit(limit);

    return (rows as List<dynamic>)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  // ── Lecture — dernière position connue ────────────────────

  /// Retourne la dernière position enregistrée pour un véhicule.
  /// Utile en fallback si Flespi est inaccessible.
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

  // ── Lecture — dernière position de chaque véhicule ────────

  /// Pour chaque vehicule_id de la liste, retourne sa dernière position.
  /// Utilisé par getLiveFleet comme fallback Supabase.
  Future<Map<String, GpsPosition>> getLastKnownPositions(
    List<String> vehiculeIds,
  ) async {
    if (vehiculeIds.isEmpty) return {};

    // Supabase ne supporte pas nativement "DISTINCT ON" en client Flutter,
    // on fait une requête par véhicule en parallèle (list courte en pratique).
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

  // ── Nettoyage ─────────────────────────────────────────────

  /// Supprime les points antérieurs à [before] pour un véhicule donné.
  /// Appelable depuis un job de maintenance.
  Future<int> deleteOldPositions({
    required String vehiculeId,
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

  /// Supprime TOUT l'historique d'un véhicule (ex. lors d'une vente).
  Future<void> deleteAllPositions(String vehiculeId) async {
    await _supabase
        .from(_table)
        .delete()
        .eq('vehicule_id', vehiculeId);
  }

  // ── Conversion ────────────────────────────────────────────

  Map<String, dynamic> _toRow(GpsPosition p) => {
        'vehicule_id': p.vehiculeId,
        'latitude':    p.latitude,
        'longitude':   p.longitude,
        'speed':       p.speed,
        'altitude':    p.altitude,
        'cap':         p.heading,
        'fix_time':    p.fixTime.toIso8601String(),
        'server_time': p.serverTime.toIso8601String(),
      };

  GpsPosition _fromRow(Map<String, dynamic> row) {
    final fixTime = DateTime.parse(row['fix_time'] as String);
    return GpsPosition(
      vehiculeId:  row['vehicule_id'] as String,
      latitude:    (row['latitude']   as num).toDouble(),
      longitude:   (row['longitude']  as num).toDouble(),
      speed:       (row['speed']      as num?)?.toDouble(),
      altitude:    (row['altitude']   as num?)?.toDouble(),
      heading:     (row['cap']        as num?)?.toDouble(),
      fixTime:     fixTime,
      serverTime:  DateTime.parse(row['server_time'] as String),
      isOnline:    DateTime.now().toUtc().difference(fixTime).inMinutes < 5,
    );
  }
}
