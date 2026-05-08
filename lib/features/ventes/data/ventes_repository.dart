// lib/features/ventes/data/ventes_repository.dart
//
// CHANGEMENT : SupabaseClient injecté en constructeur — plus d'import main.dart.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/vente_model.dart';
import '../../../core/utils/app_logger.dart';

class VentesRepository {
  VentesRepository(this._client);

  final SupabaseClient _client;

  static const _ventesSelect =
      '*, vehicules(marque, modele, annee, immatriculation),'
      'clients(prenom, nom, telephone),'
      'vente_paiements(id, montant, date_paiement, mode)';

  Future<List<Vente>> getAll() async {
    try {
      final data = await _client
          .from('ventes')
          .select(_ventesSelect)
          .order('created_at', ascending: false);
      return data.map((j) => Vente.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('VentesRepository.getAll', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Vente?> getById(String id) async {
    try {
      final data = await _client
          .from('ventes')
          .select(
            '*, vehicules(marque, modele, annee),'
            'clients(prenom, nom),'
            'vente_paiements(id, montant, date_paiement, mode, notes)',
          )
          .eq('id', id)
          .single();
      return Vente.fromJson(data);
    } catch (e, st) {
      AppLogger.e('VentesRepository.getById', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Vente?> create(Map<String, dynamic> payload) async {
    try {
      payload
        ..remove('acompte')
        ..remove('solde_restant');
      final data = await _client
          .from('ventes')
          .insert(payload)
          .select()
          .single();
      return Vente.fromJson(data);
    } catch (e, st) {
      AppLogger.e('VentesRepository.create', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    try {
      payload
        ..remove('acompte')
        ..remove('solde_restant');
      await _client.from('ventes').update(payload).eq('id', id);
    } catch (e, st) {
      AppLogger.e('VentesRepository.update', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Paiements ──────────────────────────────────────────────────────────────

  Future<List<VentePaiement>> getPaiements(String venteId) async {
    try {
      final data = await _client
          .from('vente_paiements')
          .select()
          .eq('vente_id', venteId)
          .order('date_paiement', ascending: false);
      return data.map((j) => VentePaiement.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('VentesRepository.getPaiements', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<VentePaiement?> addPaiement(VentePaiement paiement) async {
    try {
      final data = await _client
          .from('vente_paiements')
          .insert(paiement.toJson())
          .select()
          .single();
      return VentePaiement.fromJson(data);
    } catch (e, st) {
      AppLogger.e('VentesRepository.addPaiement', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deletePaiement(String id) async {
    await _client.from('vente_paiements').delete().eq('id', id);
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async {
    try {
      final data = await _client
          .from('ventes')
          .select('id, prix_vente, statut_paiement, vente_paiements(montant)');
      final total = data.length;
      final revenu = data.fold<double>(
          0, (s, v) => s + ((v['prix_vente'] as num?)?.toDouble() ?? 0));
      final encaisse = data.fold<double>(0, (s, v) {
        final p = (v['vente_paiements'] as List? ?? []);
        return s +
            p.fold<double>(
                0, (sp, x) => sp + ((x['montant'] as num?)?.toDouble() ?? 0));
      });
      return {
        'total': total,
        'revenu': revenu,
        'encaisse': encaisse,
        'moyen': total > 0 ? revenu / total : 0.0,
      };
    } catch (e, st) {
      AppLogger.e('VentesRepository.getStats', error: e, stackTrace: st);
      rethrow;
    }
  }
}
