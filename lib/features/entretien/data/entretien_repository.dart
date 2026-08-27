// lib/features/entretien/data/entretien_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/alerte_model.dart';
import '../../../core/utils/app_logger.dart';

class EntretienRepository {
  EntretienRepository(this._client, {required this.showroomId});

  final SupabaseClient _client;
  final String showroomId;

  // ── Lecture ────────────────────────────────────────────────────────────────

  Future<List<AlerteEntretien>> getActives() async {
    try {
      final data = await _client
          .from('alertes_entretien')
          .select('*, vehicules(marque, modele)')
          .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
          .eq('statut', 'active')
          .order('date_echeance');
      return data.map((j) => AlerteEntretien.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('EntretienRepository.getActives', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<AlerteEntretien>> getAll() async {
    try {
      final data = await _client
          .from('alertes_entretien')
          .select('*, vehicules(marque, modele)')
          .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
          .order('date_echeance');
      return data.map((j) => AlerteEntretien.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('EntretienRepository.getAll', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<AlerteEntretien>> getByVehicule(String vehiculeId) async {
    try {
      final data = await _client
          .from('alertes_entretien')
          .select('*, vehicules(marque, modele)')
          .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
          .eq('vehicule_id', vehiculeId)
          .order('date_echeance');
      return data.map((j) => AlerteEntretien.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('EntretienRepository.getByVehicule', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Création ───────────────────────────────────────────────────────────────

  Future<void> create(Map<String, dynamic> data) async {
    try {
      final payload = {
        ...data,
        'showroom_id': showroomId, // ✅ injection multi-tenant
      };
      await _client.from('alertes_entretien').insert(payload);
    } catch (e, st) {
      AppLogger.e('EntretienRepository.create', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Mise à jour ────────────────────────────────────────────────────────────

  Future<void> marquerFait(String id) async {
    try {
      await _client
          .from('alertes_entretien')
          .update({'statut': 'fait'})
          .eq('showroom_id', showroomId) // ✅ verrou anti cross-tenant dans le WHERE
          .eq('id', id);
    } catch (e, st) {
      AppLogger.e('EntretienRepository.marquerFait', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> marquerIgnoree(String id) async {
    try {
      await _client
          .from('alertes_entretien')
          .update({'statut': 'ignoree'})
          .eq('showroom_id', showroomId) // ✅ verrou anti cross-tenant
          .eq('id', id);
    } catch (e, st) {
      AppLogger.e('EntretienRepository.marquerIgnoree', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Suppression ────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    try {
      await _client
          .from('alertes_entretien')
          .delete()
          .eq('showroom_id', showroomId) // ✅ verrou anti cross-tenant
          .eq('id', id);
    } catch (e, st) {
      AppLogger.e('EntretienRepository.delete', error: e, stackTrace: st);
      rethrow;
    }
  }
}