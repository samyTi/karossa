// lib/features/gps/data/gps_geofence_source.dart
//
// Toutes les opérations Supabase liées aux géofences.
// Table : gps_geofences (voir migrations/gps_geofences_migration.sql)

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/gps_geofence.dart';

class GpsGeofenceSource {
  final SupabaseClient _supabase;
  final String showroomId;
  static const String _table = 'gps_geofences';

  const GpsGeofenceSource({
    required SupabaseClient supabase,
    required this.showroomId,
  }) : _supabase = supabase;

  // ── Lecture ───────────────────────────────────────────────

  /// Toutes les géofences du showroom actif, actives en premier.
  Future<List<GpsGeofence>> getGeofences() async {
    if (showroomId.isEmpty) return [];
    final rows = await _supabase
        .from(_table)
        .select()
        .eq('showroom_id', showroomId)
        .order('actif', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((r) => GpsGeofence.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ── Écriture ──────────────────────────────────────────────

  /// Crée une nouvelle géofence, retourne l'entité persistée (avec son id généré).
  Future<GpsGeofence> creerGeofence(GpsGeofence geofence) async {
    final payload = geofence.toJson()
      ..remove('id')
      ..['showroom_id'] = showroomId
      ..['created_by']  = _supabase.auth.currentUser?.id;

    final row = await _supabase.from(_table).insert(payload).select().single();
    return GpsGeofence.fromJson(row);
  }

  /// Met à jour une géofence existante.
  Future<void> mettreAJourGeofence(GpsGeofence geofence) async {
    final payload = geofence.toJson()..remove('id');
    await _supabase.from(_table).update(payload).eq('id', geofence.id);
  }

  /// Active/désactive rapidement une zone (toggle switch dans la liste).
  Future<void> toggleActif(String id, bool actif) async {
    await _supabase.from(_table).update({'actif': actif}).eq('id', id);
  }

  /// Supprime une géofence.
  Future<void> supprimerGeofence(String id) async {
    await _supabase.from(_table).delete().eq('id', id);
  }
}