// lib/features/ventes/data/ventes_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/vente_model.dart';
import '../../../core/utils/app_logger.dart';

class VentesRepository {
  // 🚀 Le constructeur exige le showroomId pour le cloisonnement SaaS
  VentesRepository(this._client, {required this.showroomId});

  final SupabaseClient _client;
  final String showroomId; // 🔥 Identifiant du showroom actif

  static const _ventesSelect =
      '*, vehicules(marque, modele, annee, immatriculation),'
      'clients(prenom, nom, telephone),'
      'vente_paiements(id, montant, date_paiement, mode)';

  Future<List<Vente>> getAll() async {
    try {
      final data = await _client
          .from('ventes')
          .select(_ventesSelect)
          .eq('showroom_id', showroomId) // 🚀 Isolation explicite des ventes
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
          .eq('showroom_id', showroomId) // 🚀 Protection de l'acte de vente
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
        ..remove('solde_restant')
        ..remove('commission_gerant_mnt'); // colonne calculée ou absente du schéma
      
      // 🚀 Injection automatique du showroom_id dans l'acte de vente
      final fullPayload = {
        ...payload,
        'showroom_id': showroomId,
      };

      final data = await _client
          .from('ventes')
          .insert(fullPayload)
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
        ..remove('solde_restant')
        ..remove('commission_gerant_mnt');
      
      // On conserve l'intégrité du verrou de cloisonnement
      final fullPayload = {
        ...payload,
        'showroom_id': showroomId,
      };

      await _client
          .from('ventes')
          .update(fullPayload)
          .eq('showroom_id', showroomId) // 🚀 Sécurité anti cross-tenant sur l'update
          .eq('id', id);
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
          .eq('showroom_id', showroomId) // 🚀 Isolation des flux de caisse
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
      // 🚀 Injection automatique du showroom_id dans le reçu de paiement de vente
      final payload = paiement.toJson()
        ..['showroom_id'] = showroomId;

      final data = await _client
          .from('vente_paiements')
          .insert(payload)
          .select()
          .single();
      return VentePaiement.fromJson(data);
    } catch (e, st) {
      AppLogger.e('VentesRepository.addPaiement', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deletePaiement(String id) async {
    await _client
        .from('vente_paiements')
        .delete()
        .eq('showroom_id', showroomId) // 🚀 Protection à la suppression
        .eq('id', id);
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async {
    try {
      // Filtrage explicite pour garantir des statistiques étanches
      final data = await _client
          .from('ventes')
          .select('id, prix_vente, statut_paiement, vente_paiements(montant)')
          .eq('showroom_id', showroomId); // 🚀 Chiffre d'affaires scopé au tenant
          
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