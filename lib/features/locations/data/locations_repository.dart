// lib/features/locations/data/locations_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/location_model.dart';
import '../../../core/utils/app_logger.dart';

class LocationsRepository {
  LocationsRepository(this._client);

  final SupabaseClient _client;

  static const _locationSelect =
      '*, vehicules(marque, modele, couleur, immatriculation, carburant, boite, etat_vehicule),'
      'clients(prenom, nom, telephone),'
      'location_repartitions(*, profiles(prenom))';

  // Champs calculés ou inexistants en base — jamais envoyés dans un INSERT/UPDATE
  static const _fieldsToStrip = [
    'nb_jours',
    'montant_brut',
    'commission_gerant_mnt',
    'commission_gerant_pct',
  ];

  Map<String, dynamic> _strip(Map<String, dynamic> data) {
    for (final f in _fieldsToStrip) {
      data.remove(f);
    }
    return data;
  }

  // ── Lecture ──────────────────────────────────────────────────────────────

  Future<List<Location>> getActives() async {
    try {
      final data = await _client
          .from('locations')
          .select(_locationSelect)
          .inFilter('statut', ['en_cours', 'retard']).order('date_fin_prevue');
      return data.map((j) => Location.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('LocationsRepository.getActives', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Location>> getRetards() async {
    try {
      final now = DateTime.now().toIso8601String();
      final data = await _client
          .from('locations')
          .select(
            '*, vehicules(marque, modele, couleur, immatriculation, carburant, boite, etat_vehicule),'
            'clients(prenom, nom, telephone)',
          )
          .eq('statut', 'en_cours')
          .lt('date_fin_prevue', now);
      return data.map((j) => Location.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('LocationsRepository.getRetards', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Location>> getHistorique() async {
    try {
      final data = await _client
          .from('locations')
          .select(_locationSelect)
          .inFilter('statut', ['termine', 'annule']).order('date_debut',
              ascending: false);
      return data.map((j) => Location.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('LocationsRepository.getHistorique', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Location>> getAll() async {
    try {
      final data = await _client
          .from('locations')
          .select(_locationSelect)
          .order('created_at', ascending: false);
      return data.map((j) => Location.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('LocationsRepository.getAll', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Location?> getById(String id) async {
    try {
      final data = await _client
          .from('locations')
          .select(
            '$_locationSelect,'
            'location_paiements(id, montant, date_paiement, mode)',
          )
          .eq('id', id)
          .single();
      return Location.fromJson(data);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.getById', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Création ──────────────────────────────────────────────────────────────

  Future<Location> create(Map<String, dynamic> locationData) async {
    _strip(locationData);
    final response = await _client
        .from('locations')
        .insert(locationData)
        .select();
    if (response.isEmpty) {
      throw Exception('Erreur création location : réponse inattendue');
    }
    return Location.fromJson(response.first);
  }

  Future<Location> createHistorique({
    required Map<String, dynamic> locationData,
    required List<Map<String, dynamic>> paiements,
    double? commissionGerantMnt,
    String? gerantId,
  }) async {
    _strip(locationData);

    final response = await _client
        .from('locations')
        .insert(locationData)
        .select();
    if (response.isEmpty) {
      throw Exception('Erreur création location historique : réponse inattendue');
    }
    final location = Location.fromJson(response.first);

    if (paiements.isNotEmpty) {
      final paiementsAvecId = paiements
          .map((p) => {...p, 'location_id': location.id})
          .toList();
      await _client.from('location_paiements').insert(paiementsAvecId);
    }

    try {
      await _client.rpc(
        'calculer_repartition_location',
        params: {'p_location_id': location.id},
      );
    } catch (e) {
      AppLogger.w('LocationsRepository.createHistorique: RPC repartition failed: $e');
    }

    return location;
  }

  // ── Mise à jour ──────────────────────────────────────────────────────────

  Future<void> update(String id, Map<String, dynamic> data) async {
    try {
      _strip(data);
      await _client.from('locations').update(data).eq('id', id);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.update', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> cloturerLocation({
    required String locationId,
    required int kmRetour,
    required double retenueCaution,
    String? notesRetour,
  }) async {
    await _client.from('locations').update({
      'statut': 'termine',
      'date_fin_reelle': DateTime.now().toIso8601String(),
      'km_retour': kmRetour,
      'retenue_caution': retenueCaution,
      'notes_retour': notesRetour,
    }).eq('id', locationId);
    try {
      await _client.rpc(
        'calculer_repartition_location',
        params: {'p_location_id': locationId},
      );
    } catch (e) {
      AppLogger.w('LocationsRepository.cloturerLocation: RPC failed: $e');
    }
  }

  // ── Suppression ──────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    try {
      // Supprimer d'abord les paiements liés
      await _client.from('location_paiements').delete().eq('location_id', id);
      // Supprimer les répartitions liées
      await _client.from('location_repartitions').delete().eq('location_id', id);
      // Supprimer la location
      await _client.from('locations').delete().eq('id', id);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.delete', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Paiements ──────────────────────────────────────────────────────────────

  Future<List<LocationPaiement>> getPaiements(String locationId) async {
    try {
      final data = await _client
          .from('location_paiements')
          .select()
          .eq('location_id', locationId)
          .order('date_paiement', ascending: false);
      return data.map((j) => LocationPaiement.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('LocationsRepository.getPaiements', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<LocationPaiement?> addPaiement(LocationPaiement p) async {
    try {
      final data = await _client
          .from('location_paiements')
          .insert(p.toJson())
          .select()
          .single();
      return LocationPaiement.fromJson(data);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.addPaiement', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deletePaiement(String id) async {
    await _client.from('location_paiements').delete().eq('id', id);
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async {
    try {
      final data = await _client
          .from('locations')
          .select('id, prix_jour, nb_jours, montant_brut, statut, location_paiements(montant)');

      final total = data.length;
      final actives = data.where((l) => l['statut'] == 'en_cours' || l['statut'] == 'retard').length;
      final terminees = data.where((l) => l['statut'] == 'termine').length;
      final annulees = data.where((l) => l['statut'] == 'annule').length;
      final retards = data.where((l) {
        if (l['statut'] != 'en_cours') return false;
        // vérifie si en retard via date_fin_prevue — pas dispo ici, approx via statut
        return false;
      }).length;

      final revenus = data.fold<double>(0, (s, l) {
        final brut = (l['montant_brut'] as num?)?.toDouble();
        if (brut != null) return s + brut;
        final prix = (l['prix_jour'] as num?)?.toDouble() ?? 0;
        final jours = (l['nb_jours'] as num?)?.toDouble() ?? 1;
        return s + prix * jours;
      });

      final encaisse = data.fold<double>(0, (s, l) {
        final p = (l['location_paiements'] as List? ?? []);
        return s + p.fold<double>(0, (sp, x) => sp + ((x['montant'] as num?)?.toDouble() ?? 0));
      });

      return {
        'total': total,
        'actives': actives,
        'terminees': terminees,
        'annulees': annulees,
        'retards': retards,
        'revenus': revenus,
        'encaisse': encaisse,
        'moyen': total > 0 ? revenus / total : 0.0,
      };
    } catch (e, st) {
      AppLogger.e('LocationsRepository.getStats', error: e, stackTrace: st);
      rethrow;
    }
  }
}