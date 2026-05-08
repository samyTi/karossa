// lib/features/locations/data/locations_repository.dart
//
// CHANGEMENT : SupabaseClient injecté en constructeur — plus d'import main.dart.

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

  Future<List<Location>> getActives() async {
    try {
      final data = await _client
          .from('locations')
          .select(_locationSelect)
          .inFilter('statut', ['en_cours', 'retard'])
          .order('date_fin_prevue');
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

  Future<Location> create(Map<String, dynamic> locationData) async {
    // Colonnes GENERATED ALWAYS AS STORED — Postgres refuse l'écriture.
    locationData
      ..remove('nb_jours')
      ..remove('montant_brut');
    final response = await _client
        .from('locations')
        .insert(locationData)
        .select();
    if (response.isEmpty) {
      throw Exception('Erreur création location : réponse inattendue');
    }
    return Location.fromJson(response.first);
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
    await _client.rpc(
      'calculer_repartition_location',
      params: {'p_location_id': locationId},
    );
  }

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
}
