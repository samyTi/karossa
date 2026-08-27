// lib/features/locations/data/locations_repository.dart

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/location_model.dart';
import '../../../core/utils/app_logger.dart';

class LocationsRepository {
  LocationsRepository(this._client, {required this.showroomId});

  final SupabaseClient _client;
  final String showroomId;

  // Ajout de location_interruptions dans le select global
  static const _locationSelect =
      '*, vehicules(marque, modele, couleur, immatriculation, carburant, boite, etat_vehicule, assurance, code_radio),'
      'clients(prenom, nom, telephone, email, adresse, num_permis, permis_date, num_cni, date_naissance),'
      'location_repartitions(*, profiles(prenom)),'
      'location_interruptions(*)';   // ← NOUVEAU

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
          .eq('showroom_id', showroomId)
          .inFilter('statut', ['en_cours', 'retard'])
          .order('date_debut', ascending: false);
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
            'clients(prenom, nom, telephone),'
            'location_interruptions(*)',
          )
          .eq('showroom_id', showroomId)
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
          .eq('showroom_id', showroomId)
          .inFilter('statut', ['termine', 'annule'])
          .order('date_debut', ascending: false);
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
          .eq('showroom_id', showroomId)
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
            'location_paiements(id, montant, date_paiement, mode, notes)',
          )
          .eq('showroom_id', showroomId)
          .eq('id', id)
          .order('date_paiement', referencedTable: 'location_paiements', ascending: true)
          .single();
      return Location.fromJson(data);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.getById', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Création ──────────────────────────────────────────────────────────────

  Future<Location> create(Map<String, dynamic> locationData) async {
    try {
      _strip(locationData);
      final fullLocationData = {
        ...locationData,
        'showroom_id': showroomId,
      };
      final response = await _client
          .from('locations')
          .insert(fullLocationData)
          .select();
      if (response.isEmpty) {
        throw Exception('Erreur création location : réponse inattendue');
      }
      return Location.fromJson(response.first);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.create', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Location> createHistorique({
    required Map<String, dynamic> locationData,
    required List<Map<String, dynamic>> paiements,
    double? commissionGerantMnt,
    String? gerantId,
  }) async {
    try {
      _strip(locationData);
      final fullLocationData = {
        ...locationData,
        'showroom_id': showroomId,
      };
      final response = await _client
          .from('locations')
          .insert(fullLocationData)
          .select();
      if (response.isEmpty) {
        throw Exception('Erreur création location historique : réponse inattendue');
      }
      final location = Location.fromJson(response.first);

      if (paiements.isNotEmpty) {
        final paiementsAvecId = paiements
            .map((p) => {
                  ...p,
                  'location_id': location.id,
                  'showroom_id': showroomId,
                })
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
    } catch (e, st) {
      AppLogger.e('LocationsRepository.createHistorique', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Mise à jour ──────────────────────────────────────────────────────────

  Future<void> update(String id, Map<String, dynamic> data) async {
    AppLogger.d('update location repo');
    try {
      _strip(data);
      final fullData = {
        ...data,
        'showroom_id': showroomId,
      };
      AppLogger.d('LocationsRepository.update - Data: $fullData');
      await _client
          .from('locations')
          .update(fullData)
          .eq('showroom_id', showroomId)
          .eq('id', id);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.update', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Signature électronique ───────────────────────────────────────────────

  /// Upload une signature capturée (PNG) sur le bucket 'signatures' et
  /// retourne son URL publique. Voir migration_2026_07_wow_features.sql
  /// pour la création du bucket et des colonnes associées.
  Future<String?> uploadSignature({
    required String locationId,
    required Uint8List pngBytes,
    required String suffix, // 'depart' | 'retour'
  }) async {
    try {
      final path = '$showroomId/locations/$locationId/signature_$suffix.png';
      await _client.storage.from('signatures').uploadBinary(
            path,
            pngBytes,
            fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
          );
      return _client.storage.from('signatures').getPublicUrl(path);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.uploadSignature', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> cloturerLocation({
    required String locationId,
    required int kmRetour,
    required double retenueCaution,
    String? notesRetour,
    String? etatCarrosserieRetour,
    String? signatureClientRetourUrl,
  }) async {
    try {
      await _client
          .from('locations')
          .update({
            'statut':                   'termine',
            'date_fin_reelle':          DateTime.now().toIso8601String(),
            'km_retour':                kmRetour,
            'retenue_caution':          retenueCaution,
            'notes_retour':             notesRetour,
            'etat_carrosserie_retour':  etatCarrosserieRetour,
            if (signatureClientRetourUrl != null)
              'signature_client_retour_url': signatureClientRetourUrl,
          })
          .eq('showroom_id', showroomId)
          .eq('id', locationId);

      try {
        await _client.rpc(
          'calculer_repartition_location',
          params: {'p_location_id': locationId},
        );
      } catch (e) {
        AppLogger.w('LocationsRepository.cloturerLocation: RPC failed: $e');
      }
    } catch (e, st) {
      AppLogger.e('LocationsRepository.cloturerLocation', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Suppression ──────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    try {
      await _client.from('location_paiements').delete()
          .eq('showroom_id', showroomId)
          .eq('location_id', id);
      await _client.from('location_repartitions').delete()
          .eq('location_id', id);
      await _client.from('location_interruptions').delete()  // ← NOUVEAU
          .eq('location_id', id);
      await _client.from('locations').delete()
          .eq('showroom_id', showroomId)
          .eq('id', id);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.delete', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Paiements ─────────────────────────────────────────────────────────────

  Future<List<LocationPaiement>> getPaiements(String locationId) async {
    try {
      final data = await _client
          .from('location_paiements')
          .select()
          .eq('showroom_id', showroomId)
          .eq('location_id', locationId)
          .order('date_paiement', ascending: true);
      return data.map((j) => LocationPaiement.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('LocationsRepository.getPaiements', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<LocationPaiement?> addPaiement(LocationPaiement p) async {
    try {
      final payload = p.toJson()..['showroom_id'] = showroomId;
      final data = await _client
          .from('location_paiements')
          .insert(payload)
          .select()
          .single();
      return LocationPaiement.fromJson(data);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.addPaiement', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updatePaiement(String paiementId, {
    required double montant,
    required DateTime datePaiement,
    required String mode,
    String? notes,
  }) async {
    try {
      await _client
          .from('location_paiements')
          .update({
            'montant':       montant,
            'date_paiement': '${datePaiement.year}-${datePaiement.month.toString().padLeft(2,'0')}-${datePaiement.day.toString().padLeft(2,'0')}',
            'mode':          mode,
            'notes':         notes,
          })
          .eq('showroom_id', showroomId)
          .eq('id', paiementId);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.updatePaiement', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deletePaiement(String id) async {
    try {
      await _client
          .from('location_paiements')
          .delete()
          .eq('showroom_id', showroomId)
          .eq('id', id);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.deletePaiement', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Interruptions ─────────────────────────────────────────────────────────
  // NOUVEAU BLOC COMPLET

  /// Récupère toutes les interruptions d'une location
  Future<List<LocationInterruption>> getInterruptions(String locationId) async {
    try {
      final data = await _client
          .from('location_interruptions')
          .select()
          .eq('showroom_id', showroomId)
          .eq('location_id', locationId)
          .order('date_debut', ascending: true);
      return data.map((j) => LocationInterruption.fromJson(j)).toList();
    } catch (e, st) {
      AppLogger.e('LocationsRepository.getInterruptions', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Démarre une interruption : le véhicule est récupéré
  /// → met le véhicule en 'reparation' ou statut approprié
  Future<LocationInterruption> demarrerInterruption({
    required String locationId,
    required MotifInterruption motif,
    required DateTime dateDebut,
    String? notes,
    String? reparationId,
    String? createdById,
  }) async {
    try {
      // Vérifier qu'il n'y a pas déjà une interruption active
      final actives = await _client
          .from('location_interruptions')
          .select()
          .eq('location_id', locationId)
          .isFilter('date_fin', null);
      if (actives.isNotEmpty) {
        throw Exception(
          'Une interruption est déjà en cours pour cette location.',
        );
      }

      final payload = {
        'location_id':  locationId,
        'showroom_id':  showroomId,
        'date_debut':   dateDebut.toIso8601String().substring(0, 10),
        'date_fin':     null,
        'motif':        motif.name,
        'notes':        notes,
        'reparation_id': reparationId,
        'created_by':   createdById,
      };

      final response = await _client
          .from('location_interruptions')
          .insert(payload)
          .select()
          .single();

      return LocationInterruption.fromJson(response);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.demarrerInterruption', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Termine une interruption : le véhicule est restitué au client
  /// → remet le véhicule en 'loue'
  Future<LocationInterruption> terminerInterruption({
    required String interruptionId,
    required DateTime dateFin,
    String? notes,
  }) async {
    try {
      final updatePayload = <String, dynamic>{
        'date_fin': dateFin.toIso8601String().substring(0, 10),
      };
      if (notes != null) updatePayload['notes'] = notes;

      final response = await _client
          .from('location_interruptions')
          .update(updatePayload)
          .eq('showroom_id', showroomId)
          .eq('id', interruptionId)
          .select()
          .single();

      return LocationInterruption.fromJson(response);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.terminerInterruption', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Supprime une interruption (correction d'erreur)
  Future<void> deleteInterruption(String interruptionId) async {
    try {
      await _client
          .from('location_interruptions')
          .delete()
          .eq('showroom_id', showroomId)
          .eq('id', interruptionId);
    } catch (e, st) {
      AppLogger.e('LocationsRepository.deleteInterruption', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async {
    try {
      final data = await _client
          .from('locations')
          .select('id, prix_jour, nb_jours, montant_brut, statut, location_paiements(montant)')
          .eq('showroom_id', showroomId);

      final total     = data.length;
      final actives   = data.where((l) => l['statut'] == 'en_cours' || l['statut'] == 'retard').length;
      final terminees = data.where((l) => l['statut'] == 'termine').length;
      final annulees  = data.where((l) => l['statut'] == 'annule').length;

      final revenus = data.fold<double>(0, (s, l) {
        final brut = (l['montant_brut'] as num?)?.toDouble();
        if (brut != null) return s + brut;
        final prix  = (l['prix_jour'] as num?)?.toDouble() ?? 0;
        final jours = (l['nb_jours']  as num?)?.toDouble() ?? 1;
        return s + prix * jours;
      });

      final encaisse = data.fold<double>(0, (s, l) {
        final p = (l['location_paiements'] as List? ?? []);
        return s + p.fold<double>(0, (sp, x) => sp + ((x['montant'] as num?)?.toDouble() ?? 0));
      });

      return {
        'total':     total,
        'actives':   actives,
        'terminees': terminees,
        'annulees':  annulees,
        'retards':   data.where((l) => l['statut'] == 'retard').length,
        'revenus':   revenus,
        'encaisse':  encaisse,
        'moyen':     total > 0 ? revenus / total : 0.0,
      };
    } catch (e, st) {
      AppLogger.e('LocationsRepository.getStats', error: e, stackTrace: st);
      rethrow;
    }
  }
}