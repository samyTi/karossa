// lib/features/web_demandes/data/web_demandes_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/web_demande_model.dart';

// ignore_for_file: avoid_print

class WebDemandesRepository {
  final SupabaseClient _supabase;
  final String showroomId; // 🔥 NOUVEAU : Identifiant du showroom actif

  WebDemandesRepository(this._supabase, {required this.showroomId});

  // ── Lecture ───────────────────────────────────────────────────────────────

  Future<List<WebDemande>> fetchAllWebDemandes() async {
    debugPrint('╔══════════════════════════════════════════════════════╗');
    debugPrint('║       WebDemandesRepository.fetchAllWebDemandes       ║');
    debugPrint('╚══════════════════════════════════════════════════════╝');

    try {
      final results = await Future.wait([
        _fetchReservationsWeb(),
        _fetchPropositionsVente(),
        _fetchDemandesDevis(),
      ]);

      final reservations = results[0];
      final propositions = results[1];
      final devis        = results[2];

      debugPrint('┌─ Récapitulatif fetch ─────────────────────────────────');
      debugPrint('│  reservations_web    : ${reservations.length} ligne(s)');
      debugPrint('│  propositions_vente  : ${propositions.length} ligne(s)');
      debugPrint('│  demandes_devis      : ${devis.length} ligne(s)');

      final unified = results.expand((list) => list).toList()
        ..sort((a, b) {
          final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });

      debugPrint('│  TOTAL unifié        : ${unified.length} ligne(s)');
      debugPrint('└───────────────────────────────────────────────────────');

      return unified;
    } catch (e, st) {
      debugPrint('❌ fetchAllWebDemandes ERREUR: $e');
      debugPrint('$st');
      Error.throwWithStackTrace(Exception('Erreur fetchAllWebDemandes: $e'), st);
    }
  }

  Future<int> countEnAttente() async {
    try {
      final counts = await Future.wait([
        _countTable('reservations_web'),
        _countTable('propositions_vente'),
        _countTable('demandes_devis'),
      ]);
      final total = counts.reduce((a, b) => a + b);
      debugPrint('[WebDemandes] countEnAttente → $total');
      return total;
    } catch (e) {
      debugPrint('[WebDemandes] countEnAttente ERREUR: $e');
      return 0;
    }
  }

  // ── Diagnostic RLS ───────────────────────────────────────────────────────
  Future<void> diagnosticRLS() async {
    debugPrint('╔══════════════════════════════════════════════════════╗');
    debugPrint('║              DIAGNOSTIC RLS / AUTH                    ║');
    debugPrint('╚══════════════════════════════════════════════════════╝');

    final user    = _supabase.auth.currentUser;
    final session = _supabase.auth.currentSession;
    debugPrint('│  currentUser id    : ${user?.id ?? "NULL → non connecté !"}');
    debugPrint('│  currentUser email : ${user?.email}');
    debugPrint('│  currentUser role  : ${user?.role}');
    debugPrint('│  showroom_id actif : $showroomId'); // 🚀 Tracé du multi-tenant actif
    debugPrint('│  session valide    : ${session != null}');
    if (session != null) {
      final token = session.accessToken;
      debugPrint('│  access_token (60c): ${token.length >= 60 ? token.substring(0, 60) : token}...');
    }

    for (final table in ['reservations_web', 'propositions_vente', 'demandes_devis']) {
      debugPrint('│');
      debugPrint('│  ── $table ──');
      try {
        final resAll = await _supabase
            .from(table)
            .select('id')
            .eq('showroom_id', showroomId) // Filtre de vérification
            .count(CountOption.exact);
        debugPrint('│    count(*) filtré showroom : ${resAll.count}');

        final resEA = await _supabase
            .from(table)
            .select('id')
            .eq('showroom_id', showroomId)
            .eq('statut', 'en_attente')
            .count(CountOption.exact);
        debugPrint('│    count en_attente filtré  : ${resEA.count}');

        final raw = await _supabase.from(table).select('*').eq('showroom_id', showroomId).limit(1);
        final rows = raw as List;
        if (rows.isEmpty) {
          debugPrint('│    select * limit 1 tenant : ⚠️  VIDE — RLS ou absence de données');
        } else {
          debugPrint('│    select * limit 1 tenant : ✅ OK');
          debugPrint('│    1ère ligne keys         : ${rows.first.keys.toList()}');
        }
      } catch (e) {
        debugPrint('│    ❌ EXCEPTION          : $e');
      }
    }

    debugPrint('└───────────────────────────────────────────────────────');
  }

  Future<int> _countTable(String table) async {
    final res = await _supabase
        .from(table)
        .select('id')
        .eq('showroom_id', showroomId) // 🚀 Isolation du count par showroom
        .eq('statut', 'en_attente')
        .count(CountOption.exact);
    return res.count ?? 0;
  }

  // ── Mise à jour ───────────────────────────────────────────────────────────

  Future<void> updateStatut(
    String id,
    DemandeWebType type,
    DemandeWebStatut statut,
  ) async {
    final table    = _tableFor(type);
    final statutDb = _statutToDb(statut);
    debugPrint('[WebDemandes] updateStatut → table=$table  id=$id  statut=$statutDb');
    
    await _supabase
        .from(table)
        .update({
          'statut': statutDb,
          'showroom_id': showroomId, // Sécurisation du contexte d'écriture
        })
        .eq('id', id);
    debugPrint('[WebDemandes] updateStatut OK');
  }

  Future<void> deleteDemande(String id, DemandeWebType type) async {
    final table = _tableFor(type);
    debugPrint('[WebDemandes] deleteDemande → table=$table  id=$id');
    
    // RLS prend le relais sur la concordance du showroom_id
    await _supabase.from(table).delete().eq('id', id);
    debugPrint('[WebDemandes] deleteDemande OK');
  }

  // ── Conversions ───────────────────────────────────────────────────────────

  Future<String> convertirEnLocation(WebDemande demande) async {
    debugPrint('[WebDemandes] convertirEnLocation → reservation id=${demande.id}');

    if (demande.vehiculeId == null) throw Exception('Aucun véhicule associé à cette réservation.');
    if (demande.dateDebut == null || demande.dateFin == null) throw Exception('Dates de réservation manquantes.');

    final vehiculeData = await _supabase
        .from('vehicules')
        .select('kilometrage, prix_location_jour')
        .eq('id', demande.vehiculeId!)
        .single();

    final kmDepart = vehiculeData['kilometrage'] as int? ?? 0;
    final prixJour = (vehiculeData['prix_location_jour'] as num?)?.toDouble() ?? 0.0;

    String clientId;
    if (demande.clientId != null) {
      clientId = demande.clientId!;
    } else {
      debugPrint('[WebDemandes]   création client anonyme avec showroom_id…');
      final clientRes = await _supabase.from('clients').insert({
        'showroom_id': showroomId, // 🚀 Assure le rattachement multi-tenant du prospect
        'nom':       demande.clientNom ?? 'ANONYME',
        'prenom':    demande.clientPrenom ?? 'Client Web',
        'telephone': demande.telephone ?? '0000000000',
      }).select('id').single();
      clientId = clientRes['id'] as String;
    }

    final nbJours    = demande.dateFin!.difference(demande.dateDebut!).inDays;
    final montantBrut = prixJour * nbJours;

    final locationRes = await _supabase.from('locations').insert({
      'showroom_id':     showroomId, // 🚀 Injection impérative
      'vehicule_id':     demande.vehiculeId,
      'client_id':       clientId,
      'date_debut':      demande.dateDebut!.toIso8601String().split('T').first,
      'date_fin_prevue': demande.dateFin!.toIso8601String().split('T').first,
      'km_depart':       kmDepart,
      'prix_jour':       prixJour,
      'caution':         0,
      'statut':          'en_cours',
      'notes_depart':    'Converti depuis réservation web #${demande.id}',
      'nb_jours':        nbJours,
      'montant_brut':    montantBrut,
    }).select('id').single();

    final locationId = locationRes['id'] as String;

    await updateStatut(demande.id, demande.type, DemandeWebStatut.approuve);
    await _supabase.from('vehicules').update({'statut': 'loue'}).eq('id', demande.vehiculeId!);

    return locationId;
  }

  Future<String> convertirEnVehiculeStock(WebDemande demande) async {
    debugPrint('[WebDemandes] convertirEnVehiculeStock → proposition id=${demande.id}');

    String clientId;
    if (demande.clientId != null) {
      clientId = demande.clientId!;
    } else {
      final clientRes = await _supabase.from('clients').insert({
        'showroom_id': showroomId, // 🚀 Cloisonnement du client créé pour la reprise
        'nom':       demande.clientNom ?? 'ANONYME',
        'prenom':    demande.clientPrenom ?? 'Client Web',
        'telephone': demande.telephone ?? '0000000000',
      }).select('id').single();
      clientId = clientRes['id'] as String;
    }

    final vehiculeRes = await _supabase.from('vehicules').insert({
      'showroom_id':  showroomId, // 🚀 Cloisonnement du nouveau véhicule d'occasion inséré
      'marque':      demande.propMarque ?? 'INCONNU',
      'modele':      demande.propModele ?? 'INCONNU',
      'annee':       demande.propAnnee ?? DateTime.now().year,
      'kilometrage': demande.propKm ?? 0,
      'prix_achat':  demande.propPrixDemande,
      'statut':      'disponible',
      'notes':       'Reprise web — propriétaire : ${demande.clientFullName}\nDemande #${demande.id}',
      'photos':      demande.propPhotos,
    }).select('id').single();

    final vehiculeId = vehiculeRes['id'] as String;

    await _supabase.from('vehicule_proprietes').insert({
      'showroom_id':     showroomId, // 🚀 Cloisonnement de la table d'association d'actionnaires / investisseurs
      'vehicule_id':     vehiculeId,
      'proprietaire_id': clientId,
      'part_pct':        100,
    });

    await updateStatut(demande.id, demande.type, DemandeWebStatut.approuve);
    return vehiculeId;
  }

  // ── Fetch par table (Filtrage explicite additionnel) ───────────────────────

  Future<List<WebDemande>> _fetchReservationsWeb() async {
    try {
      final data = await _supabase
          .from('reservations_web')
          .select(
            '*, '
            'clients(nom, prenom, telephone), '
            'vehicules(marque, modele, immatriculation, prix_location_jour)',
          )
          .eq('showroom_id', showroomId) // 🚀 Isolation
          .order('created_at', ascending: false);

      final rows = data as List;
      final result = <WebDemande>[];
      for (var i = 0; i < rows.length; i++) {
        try {
          result.add(WebDemande.fromReservationWeb(rows[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('│    ❌ ERREUR parsing reservation_web #$i: $e');
        }
      }
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<WebDemande>> _fetchPropositionsVente() async {
    try {
      final data = await _supabase
          .from('propositions_vente')
          .select('*, clients(nom, prenom, telephone)')
          .eq('showroom_id', showroomId) // 🚀 Isolation
          .order('created_at', ascending: false);

      final rows = data as List;
      final result = <WebDemande>[];
      for (var i = 0; i < rows.length; i++) {
        try {
          result.add(WebDemande.fromPropositionVente(rows[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('│    ❌ ERREUR parsing proposition_vente #$i: $e');
        }
      }
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<WebDemande>> _fetchDemandesDevis() async {
    try {
      final data = await _supabase
          .from('demandes_devis')
          .select(
            '*, '
            'clients(nom, prenom, telephone), '
            'vehicules(marque, modele, immatriculation, prix_vente)',
          )
          .eq('showroom_id', showroomId) // 🚀 Isolation
          .order('created_at', ascending: false);

      final rows = data as List;
      final result = <WebDemande>[];
      for (var i = 0; i < rows.length; i++) {
        try {
          result.add(WebDemande.fromDemandeDevis(rows[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('│    ❌ ERREUR parsing demande_devis #$i: $e');
        }
      }
      return result;
    } catch (e) {
      rethrow;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _tableFor(DemandeWebType type) => switch (type) {
        DemandeWebType.location         => 'reservations_web',
        DemandeWebType.propositionVente => 'propositions_vente',
        DemandeWebType.demandeDevis     => 'demandes_devis',
      };

  String _statutToDb(DemandeWebStatut s) => switch (s) {
        DemandeWebStatut.enAttente => 'en_attente',
        DemandeWebStatut.approuve  => 'approuve',
        DemandeWebStatut.rejete    => 'rejete',
      };
}