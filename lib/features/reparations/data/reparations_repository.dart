// lib/features/reparations/data/reparations_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/reparation_model.dart';
import '../../../core/utils/app_logger.dart';

class ReparationsRepository {
  ReparationsRepository(this._client, {required this.showroomId});

  final SupabaseClient _client;
  final String showroomId;

  static const _reparationsSelect =
      '*, vehicules(marque, modele), '
      'profiles!reparations_proprietaire_payeur_id_fkey(nom, prenom), '
      'reparation_paiements(id, payeur_type, proprietaire_id, montant, debiteur_id, '
      'profiles!reparation_paiements_proprietaire_id_fkey(nom, prenom), '
      'debiteur:profiles!reparation_paiements_debiteur_id_fkey(nom, prenom))';

  // ── Lecture ────────────────────────────────────────────────────────────────

  Future<List<Reparation>> getAll({String? vehiculeId}) async {
    try {
      var query = _client
          .from('reparations')
          .select(_reparationsSelect)
          .eq('showroom_id', showroomId); // ✅ filtre multi-tenant

      if (vehiculeId != null) {
        query = query.eq('vehicule_id', vehiculeId);
      }

      final data = await query.order('date_rep', ascending: false);
      return data.map((j) => Reparation.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('ReparationsRepository.getAll', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<double> getTotalByVehicule(String vehiculeId) async {
    try {
      final data = await _client
          .from('reparations')
          .select('cout')
          .eq('showroom_id', showroomId) // ✅ filtre multi-tenant
          .eq('vehicule_id', vehiculeId)
          .eq('deductible', true);

      return data.fold<double>(
        0, (total, r) => total + ((r['cout'] as num?)?.toDouble() ?? 0),
      );
    } catch (e, st) {
      AppLogger.e('ReparationsRepository.getTotalByVehicule', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Création ───────────────────────────────────────────────────────────────

  Future<void> create(Map<String, dynamic> data, {
    List<Map<String, dynamic>>? paiements,
    String? createdBy,
  }) async {
    try {
      final vehiculeId   = data['vehicule_id'] as String;
      final changerStatut = data.remove('statut_vehicule') as bool? ?? false;

      final payload = {
        ...data,
        'showroom_id': showroomId, // ✅ injection multi-tenant
      };

      final inserted = await _client
          .from('reparations')
          .insert(payload)
          .select('id')
          .single();

      if (paiements != null && paiements.isNotEmpty) {
        await _client.from('reparation_paiements').insert([
          for (final p in paiements)
            {
              ...p,
              'reparation_id': inserted['id'],
              'showroom_id': showroomId, // ✅ injection multi-tenant
              if (createdBy != null) 'created_by': createdBy,
            },
        ]);
      }

      if (changerStatut) {
        // ✅ verrou showroom_id sur l'update du véhicule
        await _client
            .from('vehicules')
            .update({'statut': 'reparation'})
            .eq('showroom_id', showroomId)
            .eq('id', vehiculeId);
      }
    } catch (e, st) {
      AppLogger.e('ReparationsRepository.create', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Modification ───────────────────────────────────────────────────────────

  Future<void> update(String id, Map<String, dynamic> data, {
    List<Map<String, dynamic>>? paiements,
    String? createdBy,
  }) async {
    try {
      final vehiculeId    = data['vehicule_id'] as String?;
      final changerStatut = data.remove('statut_vehicule') as bool? ?? false;

      await _client
          .from('reparations')
          .update(data)
          .eq('showroom_id', showroomId) // ✅ verrou anti cross-tenant
          .eq('id', id);

      if (paiements != null) {
        // Remplace intégralement la répartition (simple et sans conflit
        // d'ids côté client : on supprime puis on réinsère).
        await _client.from('reparation_paiements').delete().eq('reparation_id', id);
        if (paiements.isNotEmpty) {
          await _client.from('reparation_paiements').insert([
            for (final p in paiements)
              {
                ...p,
                'reparation_id': id,
                'showroom_id': showroomId, // ✅ injection multi-tenant
                if (createdBy != null) 'created_by': createdBy,
              },
          ]);
        }
      }

      if (changerStatut && vehiculeId != null) {
        await _client
            .from('vehicules')
            .update({'statut': 'reparation'})
            .eq('showroom_id', showroomId)
            .eq('id', vehiculeId);
      }
    } catch (e, st) {
      AppLogger.e('ReparationsRepository.update', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Suppression ────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    try {
      await _client
          .from('reparations')
          .delete()
          .eq('showroom_id', showroomId) // ✅ verrou anti cross-tenant
          .eq('id', id);
    } catch (e, st) {
      AppLogger.e('ReparationsRepository.delete', error: e, stackTrace: st);
      rethrow;
    }
  }
}