// lib/features/gps/data/gps_alerte_source.dart
//
// Toutes les opérations Supabase liées aux alertes GPS.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/gps_alerte.dart';

class GpsAlerteSource {
  final SupabaseClient _supabase;
  static const String _table = 'gps_alertes';

  const GpsAlerteSource({required SupabaseClient supabase})
      : _supabase = supabase;

  // ── Lecture ───────────────────────────────────────────────

  /// Toutes les alertes, triées par date décroissante.
  Future<List<GpsAlerte>> getToutesAlertes({int limit = 100}) async {
    final rows = await _supabase
        .from(_table)
        .select()
        .order('date_alerte', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map((r) => GpsAlerte.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Alertes non lues uniquement.
  Future<List<GpsAlerte>> getAlertesNonLues() async {
    final rows = await _supabase
        .from(_table)
        .select()
        .eq('lue', false)
        .order('date_alerte', ascending: false);

    return (rows as List<dynamic>)
        .map((r) => GpsAlerte.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Nombre d'alertes non lues (pour le badge).
  Future<int> getNombreNonLues() async {
    final resp = await _supabase
        .from(_table)
        .select('id')
        .eq('lue', false);

    return (resp as List<dynamic>).length;
  }

  // ── Écriture ──────────────────────────────────────────────

  /// Marque une alerte comme lue.
  Future<void> marquerAlerteLue(String alerteId) async {
    await _supabase
        .from(_table)
        .update({'lue': true})
        .eq('id', alerteId);
  }

  /// Marque toutes les alertes comme lues.
  Future<void> marquerToutesLues() async {
    await _supabase
        .from(_table)
        .update({'lue': true})
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
        .eq('lue', true)
        .lt('date_alerte', before.toIso8601String());
  }
}
