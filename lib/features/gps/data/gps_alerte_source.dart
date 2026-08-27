// lib/features/gps/data/gps_alerte_source.dart
//
// Toutes les opérations Supabase liées aux alertes GPS.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/gps_alerte.dart';

class GpsAlerteSource {
  final SupabaseClient _supabase;
  final String showroomId;
  static const String _table = 'gps_alertes';

  const GpsAlerteSource({
    required SupabaseClient supabase,
    required this.showroomId,
  }) : _supabase = supabase;

  // ── Lecture ───────────────────────────────────────────────

  /// Toutes les alertes du showroom actif, triées par date décroissante.
  Future<List<GpsAlerte>> getToutesAlertes({int limit = 100}) async {
    if (showroomId.isEmpty) return [];
    final rows = await _supabase
        .from(_table)
        .select()
        .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
        .order('date_alerte', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map((r) => GpsAlerte.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Alertes non lues uniquement.
  Future<List<GpsAlerte>> getAlertesNonLues() async {
    if (showroomId.isEmpty) return [];
    final rows = await _supabase
        .from(_table)
        .select()
        .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
        .eq('lue', false)
        .order('date_alerte', ascending: false);

    return (rows as List<dynamic>)
        .map((r) => GpsAlerte.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Nombre d'alertes non lues (pour le badge).
  Future<int> getNombreNonLues() async {
    if (showroomId.isEmpty) return 0;
    final resp = await _supabase
        .from(_table)
        .select('id')
        .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
        .eq('lue', false);

    return (resp as List<dynamic>).length;
  }

  // ── Écriture ──────────────────────────────────────────────

  /// Marque une alerte comme lue.
  Future<void> marquerAlerteLue(String alerteId) async {
    await _supabase
        .from(_table)
        .update({'lue': true})
        .eq('id', alerteId)
        .eq('showroom_id', showroomId); // ✅ verrou anti cross-tenant
  }

  /// Marque toutes les alertes comme lues.
  Future<void> marquerToutesLues() async {
    await _supabase
        .from(_table)
        .update({'lue': true})
        .eq('showroom_id', showroomId) // ✅ verrou anti cross-tenant
        .eq('lue', false);
  }

  /// Crée une nouvelle alerte (appelé par le service de monitoring).
  Future<void> creerAlerte({
    required String vehiculeId,
    required String vehiculeNom,
    required String type,
    required String message,
  }) async {
    await _supabase.from(_table).insert({
      'showroom_id':  showroomId, // ✅ injection multi-tenant
      'vehicule_id':  vehiculeId,
      'vehicule_nom': vehiculeNom,
      'type':         type,
      'message':      message,
      'lue':          false,
      'date_alerte':  DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Supprime les alertes lues antérieures à [before].
  Future<void> purgerAlertesLues({required DateTime before}) async {
    await _supabase
        .from(_table)
        .delete()
        .eq('showroom_id', showroomId) // ✅ verrou anti cross-tenant
        .eq('lue', true)
        .lt('date_alerte', before.toIso8601String());
  }
}