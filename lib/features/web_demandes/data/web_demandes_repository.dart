// lib/features/web_demandes/data/web_demandes_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/web_demande_model.dart';

// ignore_for_file: avoid_print

class WebDemandesRepository {
  final SupabaseClient _supabase;

  WebDemandesRepository(this._supabase);

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
  /// À appeler depuis l'écran pour diagnostiquer les problèmes de RLS.
  /// Affiche dans la console Flutter toutes les infos nécessaires.
  Future<void> diagnosticRLS() async {
    debugPrint('╔══════════════════════════════════════════════════════╗');
    debugPrint('║              DIAGNOSTIC RLS / AUTH                    ║');
    debugPrint('╚══════════════════════════════════════════════════════╝');

    final user    = _supabase.auth.currentUser;
    final session = _supabase.auth.currentSession;
    debugPrint('│  currentUser id    : ${user?.id ?? "NULL → non connecté !"}');
    debugPrint('│  currentUser email : ${user?.email}');
    debugPrint('│  currentUser role  : ${user?.role}');
    debugPrint('│  session valide    : ${session != null}');
    if (session != null) {
      final token = session.accessToken;
      debugPrint('│  access_token (60c): ${token.length >= 60 ? token.substring(0, 60) : token}...');
    }

    for (final table in ['reservations_web', 'propositions_vente', 'demandes_devis']) {
      debugPrint('│');
      debugPrint('│  ── $table ──');
      try {
        // count sans aucun filtre — si RLS bloque on obtient 0
        final resAll = await _supabase
            .from(table)
            .select('id')
            .count(CountOption.exact);
        debugPrint('│    count(*) sans filtre  : ${resAll.count}');

        final resEA = await _supabase
            .from(table)
            .select('id')
            .eq('statut', 'en_attente')
            .count(CountOption.exact);
        debugPrint('│    count en_attente      : ${resEA.count}');

        // lecture brute — on voit la 1ère ligne ou rien si RLS bloque
        final raw = await _supabase.from(table).select('*').limit(1);
        final rows = raw as List;
        if (rows.isEmpty) {
          debugPrint('│    select * limit 1      : ⚠️  VIDE — RLS bloque probablement');
        } else {
          debugPrint('│    select * limit 1      : ✅ OK');
          debugPrint('│    1ère ligne keys       : ${rows.first.keys.toList()}');
        }
      } catch (e) {
        debugPrint('│    ❌ EXCEPTION          : $e');
      }
    }

    // Contrôle : profiles est accessible si l'auth fonctionne
    debugPrint('│');
    debugPrint('│  ── profiles (table de référence) ──');
    try {
      final p = await _supabase.from('profiles').select('id, role').limit(1);
      final rows = p as List;
      debugPrint('│    select id,role limit 1 : ${rows.isEmpty ? "VIDE" : rows.first}');
    } catch (e) {
      debugPrint('│    ❌ EXCEPTION : $e');
    }

    debugPrint('└───────────────────────────────────────────────────────');
    debugPrint('  💡 Si count(*) = 0 sur toutes les tables :');
    debugPrint('     → Vérifie les politiques RLS sur ces tables dans Supabase.');
    debugPrint('     → Vérifie que l\'utilisateur connecté a le bon rôle (gerant/associe).');
    debugPrint('     → Ou désactive temporairement RLS sur ces tables pour tester.');
  }

  Future<int> _countTable(String table) async {
    final res = await _supabase
        .from(table)
        .select('id')
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
    await _supabase.from(table).update({'statut': statutDb}).eq('id', id);
    debugPrint('[WebDemandes] updateStatut OK');
  }

  Future<void> deleteDemande(String id, DemandeWebType type) async {
    final table = _tableFor(type);
    debugPrint('[WebDemandes] deleteDemande → table=$table  id=$id');
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
    debugPrint('[WebDemandes]   véhicule km_depart=$kmDepart  prix_jour=$prixJour');

    String clientId;
    if (demande.clientId != null) {
      clientId = demande.clientId!;
      debugPrint('[WebDemandes]   client existant id=$clientId');
    } else {
      debugPrint('[WebDemandes]   création client anonyme…');
      final clientRes = await _supabase.from('clients').insert({
        'nom':       demande.clientNom ?? 'ANONYME',
        'prenom':    demande.clientPrenom ?? 'Client Web',
        'telephone': demande.telephone ?? '0000000000',
      }).select('id').single();
      clientId = clientRes['id'] as String;
      debugPrint('[WebDemandes]   client créé id=$clientId');
    }

    final nbJours    = demande.dateFin!.difference(demande.dateDebut!).inDays;
    final montantBrut = prixJour * nbJours;
    debugPrint('[WebDemandes]   nb_jours=$nbJours  montant_brut=$montantBrut');

    final locationRes = await _supabase.from('locations').insert({
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
    debugPrint('[WebDemandes]   location créée id=$locationId');

    await updateStatut(demande.id, demande.type, DemandeWebStatut.approuve);
    await _supabase.from('vehicules').update({'statut': 'loue'}).eq('id', demande.vehiculeId!);

    debugPrint('[WebDemandes] convertirEnLocation ✅ locationId=$locationId');
    return locationId;
  }

  Future<String> convertirEnVehiculeStock(WebDemande demande) async {
    debugPrint('[WebDemandes] convertirEnVehiculeStock → proposition id=${demande.id}');

    String clientId;
    if (demande.clientId != null) {
      clientId = demande.clientId!;
      debugPrint('[WebDemandes]   client existant id=$clientId');
    } else {
      final clientRes = await _supabase.from('clients').insert({
        'nom':       demande.clientNom ?? 'ANONYME',
        'prenom':    demande.clientPrenom ?? 'Client Web',
        'telephone': demande.telephone ?? '0000000000',
      }).select('id').single();
      clientId = clientRes['id'] as String;
      debugPrint('[WebDemandes]   client créé id=$clientId');
    }

    final vehiculeRes = await _supabase.from('vehicules').insert({
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
    debugPrint('[WebDemandes]   véhicule créé id=$vehiculeId');

    await _supabase.from('vehicule_proprietes').insert({
      'vehicule_id':     vehiculeId,
      'proprietaire_id': clientId,
      'part_pct':        100,
    });

    await updateStatut(demande.id, demande.type, DemandeWebStatut.approuve);
    debugPrint('[WebDemandes] convertirEnVehiculeStock ✅ vehiculeId=$vehiculeId');
    return vehiculeId;
  }

  // ── Fetch par table ───────────────────────────────────────────────────────

  Future<List<WebDemande>> _fetchReservationsWeb() async {
    debugPrint('┌─ _fetchReservationsWeb ──────────────────────────────');
    try {
      final data = await _supabase
          .from('reservations_web')
          .select(
            '*, '
            'clients(nom, prenom, telephone), '
            'vehicules(marque, modele, immatriculation, prix_location_jour)',
          )
          .order('created_at', ascending: false);

      final rows = data as List;
      debugPrint('│  Supabase a retourné ${rows.length} ligne(s)');

      final result = <WebDemande>[];
      for (var i = 0; i < rows.length; i++) {
        final json = rows[i] as Map<String, dynamic>;
        debugPrint('│');
        debugPrint('│  [reservations_web #$i]');
        debugPrint('│    id                : ${json['id']}');
        debugPrint('│    vehicule_id       : ${json['vehicule_id']}');
        debugPrint('│    client_id         : ${json['client_id']}');
        debugPrint('│    clients join      : ${json['clients']}');
        debugPrint('│    vehicules join    : ${json['vehicules']}');
        debugPrint('│    date_debut        : ${json['date_debut']}');
        debugPrint('│    date_fin          : ${json['date_fin']}');
        debugPrint('│    montant_estime    : ${json['montant_estime']}');
        debugPrint('│    telephone_contact : ${json['telephone_contact']}');
        debugPrint('│    notes             : ${json['notes']}');
        debugPrint('│    statut            : ${json['statut']}');

        try {
          final demande = WebDemande.fromReservationWeb(json);
          debugPrint('│    ✅ parsé → clientFullName="${demande.clientFullName}"'
              '  vehicule="${demande.vehiculeMarque} ${demande.vehiculeModele}"'
              '  montantEstimeCalcule=${demande.montantEstimeCalcule}');
          result.add(demande);
        } catch (e, st) {
          debugPrint('│    ❌ ERREUR parsing ligne #$i: $e');
          debugPrint('$st');
        }
      }

      debugPrint('└─ _fetchReservationsWeb: ${result.length} demande(s) parsée(s)');
      return result;
    } catch (e, st) {
      debugPrint('└─ _fetchReservationsWeb ERREUR Supabase: $e\n$st');
      rethrow;
    }
  }

  Future<List<WebDemande>> _fetchPropositionsVente() async {
    debugPrint('┌─ _fetchPropositionsVente ────────────────────────────');
    try {
      final data = await _supabase
          .from('propositions_vente')
          .select('*, clients(nom, prenom, telephone)')
          .order('created_at', ascending: false);

      final rows = data as List;
      debugPrint('│  Supabase a retourné ${rows.length} ligne(s)');

      final result = <WebDemande>[];
      for (var i = 0; i < rows.length; i++) {
        final json = rows[i] as Map<String, dynamic>;
        debugPrint('│');
        debugPrint('│  [propositions_vente #$i]');
        debugPrint('│    id             : ${json['id']}');
        debugPrint('│    client_id      : ${json['client_id']}');
        debugPrint('│    clients join   : ${json['clients']}');
        debugPrint('│    marque         : ${json['marque']}');
        debugPrint('│    modele         : ${json['modele']}');
        debugPrint('│    annee          : ${json['annee']}');
        debugPrint('│    kilometrage    : ${json['kilometrage']}');
        // ⚠️ Deux noms possibles selon la version du site web
        debugPrint('│    prix_demande   : ${json['prix_demande']}   ← colonne schéma BDD');
        debugPrint('│    prix_souhaite  : ${json['prix_souhaite']}  ← colonne site web (alias possible)');
        debugPrint('│    photos         : ${json['photos']}');
        debugPrint('│    description    : ${json['description']}');
        debugPrint('│    statut         : ${json['statut']}');

        try {
          final demande = WebDemande.fromPropositionVente(json);
          debugPrint('│    ✅ parsé → clientFullName="${demande.clientFullName}"'
              '  propVehicule="${demande.propMarque} ${demande.propModele}"'
              '  propPrixDemande=${demande.propPrixDemande}');
          result.add(demande);
        } catch (e, st) {
          debugPrint('│    ❌ ERREUR parsing ligne #$i: $e');
          debugPrint('$st');
        }
      }

      debugPrint('└─ _fetchPropositionsVente: ${result.length} demande(s) parsée(s)');
      return result;
    } catch (e, st) {
      debugPrint('└─ _fetchPropositionsVente ERREUR Supabase: $e\n$st');
      rethrow;
    }
  }

  Future<List<WebDemande>> _fetchDemandesDevis() async {
    debugPrint('┌─ _fetchDemandesDevis ────────────────────────────────');
    try {
      final data = await _supabase
          .from('demandes_devis')
          .select(
            '*, '
            'clients(nom, prenom, telephone), '
            'vehicules(marque, modele, immatriculation, prix_vente)',
          )
          .order('created_at', ascending: false);

      final rows = data as List;
      debugPrint('│  Supabase a retourné ${rows.length} ligne(s)');

      final result = <WebDemande>[];
      for (var i = 0; i < rows.length; i++) {
        final json = rows[i] as Map<String, dynamic>;
        debugPrint('│');
        debugPrint('│  [demandes_devis #$i]');
        debugPrint('│    id            : ${json['id']}');
        debugPrint('│    client_id     : ${json['client_id']}');
        debugPrint('│    vehicule_id   : ${json['vehicule_id']}');
        debugPrint('│    clients join  : ${json['clients']}');
        debugPrint('│    vehicules join: ${json['vehicules']}');
        debugPrint('│    type          : ${json['type']}');
        debugPrint('│    message       : ${json['message']}');
        debugPrint('│    budget_max    : ${json['budget_max']}');
        debugPrint('│    statut        : ${json['statut']}');

        try {
          final demande = WebDemande.fromDemandeDevis(json);
          debugPrint('│    ✅ parsé → clientFullName="${demande.clientFullName}"'
              '  devisType=${demande.devisType}');
          result.add(demande);
        } catch (e, st) {
          debugPrint('│    ❌ ERREUR parsing ligne #$i: $e');
          debugPrint('$st');
        }
      }

      debugPrint('└─ _fetchDemandesDevis: ${result.length} demande(s) parsée(s)');
      return result;
    } catch (e, st) {
      debugPrint('└─ _fetchDemandesDevis ERREUR Supabase: $e\n$st');
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