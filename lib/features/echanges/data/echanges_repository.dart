// lib/features/echanges/data/echanges_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/echange_model.dart';
import '../../../core/utils/app_logger.dart';

class EchangesRepository {
  EchangesRepository(this._client, {required this.showroomId});

  final SupabaseClient _client;
  final String showroomId;

  static const _echangeSelect =
      '*, '
      'vehicules!echanges_vehicule_cede_id_fkey(marque, modele, annee), '
      'clients(prenom, nom)';

  /// Récupère tous les échanges du showroom actif
  Future<List<Echange>> getAll() async {
    try {
      final data = await _client
          .from('echanges')
          .select(_echangeSelect)
          .eq('showroom_id', showroomId) // ✅ CORRECTION : filtre multi-tenant
          .order('created_at', ascending: false);
      return data.map((j) => Echange.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('EchangesRepository.getAll', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Récupère les échanges pour un véhicule donné, dans le showroom actif
  Future<List<Echange>> getByVehiculeId(String vehiculeId) async {
    try {
      final data = await _client
          .from('echanges')
          .select(_echangeSelect)
          .eq('showroom_id', showroomId) // ✅ CORRECTION : filtre multi-tenant
          .eq('vehicule_cede_id', vehiculeId)
          .order('created_at', ascending: false);
      return data.map((j) => Echange.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('EchangesRepository.getByVehiculeId', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Récupère un échange par son ID, en vérifiant l'appartenance au showroom
  Future<Echange?> getById(String echangeId) async {
    try {
      final data = await _client
          .from('echanges')
          .select(_echangeSelect)
          .eq('showroom_id', showroomId) // ✅ CORRECTION : filtre multi-tenant
          .eq('id', echangeId)
          .maybeSingle();
      if (data == null) return null;
      return Echange.fromJson(data);
    } catch (e, st) {
      AppLogger.e('EchangesRepository.getById', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Crée un nouvel échange et met à jour le statut du véhicule cédé
  Future<Echange> create(Map<String, dynamic> data) async {
    try {
      // commission_gerant_mnt est une colonne calculée — ne pas insérer
      data.remove('commission_gerant_mnt');

      final vehiculeCedeId = data['vehicule_cede_id'] as String;

      final fullPayload = {
        ...data,
        'showroom_id': showroomId,
      };

      final result = await _client
          .from('echanges')
          .insert(fullPayload)
          .select(_echangeSelect)
          .single();

      // Mise à jour du statut du véhicule cédé, avec verrou showroom
      await _client
          .from('vehicules')
          .update({'statut': 'vendu'})
          .eq('showroom_id', showroomId) // ✅ CORRECTION : sécurité cross-tenant sur l'update
          .eq('id', vehiculeCedeId);

      return Echange.fromJson(result);
    } catch (e, st) {
      AppLogger.e('EchangesRepository.create', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Suppression ────────────────────────────────────────────────────────────

  /// Supprime un échange. Échoue si des opérations de caisse sont encore
  /// liées à cet échange.
  Future<void> delete(String id) async {
    try {
      await _client
          .from('transaction_repartitions')
          .delete()
          .eq('transaction_type', 'echange')
          .eq('transaction_id', id);
      await _client
          .from('echanges')
          .delete()
          .eq('showroom_id', showroomId) // ✅ verrou anti cross-tenant
          .eq('id', id);
    } catch (e, st) {
      AppLogger.e('EchangesRepository.delete', error: e, stackTrace: st);
      rethrow;
    }
  }
}