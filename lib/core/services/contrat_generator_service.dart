// lib/core/services/contrat_generator_service.dart
//
// Service façade unifié — génère et partage les contrats PDF
// pour les locations, ventes, échanges et achats.
//
// DÉPENDANCES pubspec.yaml (déjà présentes) :
//   pdf: ^3.11.0
//   path_provider: ^2.1.0
//   share_plus: ^7.0.0
//   intl: ^0.19.0
//   web: ^1.0.0          ← AJOUTER si absent (remplace dart:html)

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

// Imports conditionnels : dart:io uniquement sur mobile/desktop
import 'dart:io' if (dart.library.html) 'dart:io';
import 'package:path_provider/path_provider.dart'
    if (dart.library.html) 'package:path_provider/path_provider.dart';

// package:web + dart:js_interop pour le téléchargement navigateur
import 'package:web/web.dart' as web;
import 'dart:js_interop';

import '../../features/clients/domain/client_model.dart';
import '../../features/echanges/domain/echange_model.dart';
import '../../features/locations/domain/location_model.dart';
import '../../features/vehicules/domain/vehicule_model.dart';
import '../../features/ventes/domain/vente_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/contrats/data/contrats_repository.dart';
import '../../features/contrats/presentation/contrat_location_pdf_generator.dart';
import '../../features/contrats/data/contract_articles_repository.dart';
import '../../features/contrats/presentation/contrat_vente_pdf_generator.dart';
import '../providers/supabase_provider.dart';
import '../utils/app_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS INTERNES
// ─────────────────────────────────────────────────────────────────────────────

class ContratGeneratorService {
  ContratGeneratorService._();

  // ── Récupère les paramètres du showroom ───────────────────
  static Future<Map<String, dynamic>> _settings() async {
    AppLogger.d('[PDF][Settings] ► Chargement des paramètres showroom…');
    final s = await ContratsRepository(Supabase.instance.client).getShowroomSettings();
    AppLogger.d('[PDF][Settings] ✔ nom=${s["nom"]} adresse=${s["adresse"]} '
    'tel=${s["tel"]} email=${s["email"]} rc=${s["rc"]} couleur=${s["couleur"]}');
    return s;
  }

  // ── Sauvegarde les bytes ──────────────────────────────────
  //
  // • Sur Web   → déclenche un téléchargement via <a download> (package:web)
  //               retourne null (File n'existe pas sur Web)
  // • Sur mobile/desktop → écrit dans getApplicationDocumentsDirectory()
  static Future<File?> _saveBytes(List<int> bytes, String filename) async {
    AppLogger.d('[PDF][Save] ► Sauvegarde "$filename" (${bytes.length} bytes)…');

    if (kIsWeb) {
      _downloadOnWeb(Uint8List.fromList(bytes), filename);
      AppLogger.d('[PDF][Save] ✔ Téléchargement déclenché (Web)');
      return null;
    }

    // Mobile / Desktop
    final dir  = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    AppLogger.d('[PDF][Save] ✔ Fichier écrit → ${file.path}');
    return file;
  }

  /// Déclenche un téléchargement fichier dans le navigateur.
  /// Utilise package:web + dart:js_interop (remplace dart:html obsolète).
  static void _downloadOnWeb(Uint8List bytes, String filename) {
    // bytes.buffer.toJS donne un JSArrayBuffer — c'est le seul type
    // que le constructeur Blob accepte correctement pour des données binaires.
    // Passer un JSArray<JSNumber> produit un Blob corrompu.
    final blob = web.Blob(
      [bytes.buffer.toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    anchor.click();

    // Libère l'URL objet après un court délai
    Future.delayed(const Duration(seconds: 1), () {
      web.URL.revokeObjectURL(url);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  LOCATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Génère un contrat de location à partir d'une Map Supabase.
  /// [locationData] doit contenir les clés standards de la table `locations`
  /// ainsi que les relations imbriquées `clients` et `vehicules`.
  static Future<File?> genererLocation({
    required Map<String, dynamic> locationData,
  }) async {
    final locationId = locationData['id'] ?? '?';
    AppLogger.d('[PDF][Location] ════════════════════════════════════');
    AppLogger.d('[PDF][Location] ► Début génération — id=$locationId');
    AppLogger.d('[PDF][Location] ► Données brutes reçues : ${locationData.keys.toList()}');
    try {
      final s = await _settings();

      final clientMap   = locationData['clients']   as Map<String, dynamic>? ?? {};
      final vehiculeMap = locationData['vehicules']  as Map<String, dynamic>? ?? {};
      AppLogger.d('[PDF][Location] ► Client   : nom=${clientMap["nom"]} prenom=${clientMap["prenom"]} '
    'tel=${clientMap["telephone"]} permis=${clientMap["num_permis"]}');
      AppLogger.d('[PDF][Location] ► Véhicule : ${vehiculeMap['marque']} ${vehiculeMap['modele']} '
          'immat="${vehiculeMap['immatriculation']}"');

      final dateDepart  = DateTime.parse(locationData['date_debut'] as String);
      final dateRetour  = DateTime.parse(locationData['date_fin_prevue'] as String);
      AppLogger.d('[PDF][Location] ► Période  : $dateDepart → $dateRetour');
      AppLogger.d('[PDF][Location] ► Financier: prixJour=${locationData['prix_jour']} '
          'caution=${locationData['caution']} kmDepart=${locationData['km_depart']}');

      final dto = ContratLocationDto(
        contratId:            locationData['id'] as String? ?? '',
        dateEtablissement:    DateTime.now(),

        // Agence
        agenceNom:            s['nom']      as String? ?? 'Garage Auto',
        agenceAdresse:        s['adresse']  as String? ?? '',
        agenceTel:            s['tel']      as String? ?? '',
        agenceEmail:          s['email']    as String?,
        agenceVille:          s['ville']    as String?,
        agenceRc:             s['rc']       as String?,
        agenceCouleurHex:     s['couleur']  as String?,

        // Locataire
        locataireNom:         clientMap['nom']       as String? ?? '',
        locatairePrenom:      clientMap['prenom']    as String? ?? '',
        locataireTel:         clientMap['telephone'] as String? ?? '',
        locataireEmail:       clientMap['email']     as String?,
        locataireAdresse:     clientMap['adresse']   as String?,
        locataireNumPermis:   clientMap['num_permis'] as String?,
        locataireCin:         clientMap['num_cni']   as String?,

        // Véhicule
        vehiculeMarque:        vehiculeMap['marque']         as String? ?? '',
        vehiculeModele:        vehiculeMap['modele']         as String? ?? '',
        vehiculeCouleur:       vehiculeMap['couleur']        as String?,
        vehiculeImmatriculation: vehiculeMap['immatriculation'] as String?,
        vehiculeAssurance:     vehiculeMap['assurance']      as String?,
        vehiculeCarburant:     vehiculeMap['carburant']      as String?,
        vehiculeBoite:         vehiculeMap['boite']          as String?,

        // Location
        dateDepart:  dateDepart,
        dateRetour:  dateRetour,
        kmDepart:    (locationData['km_depart'] as num?)?.toInt() ?? 0,
        prixJour:    (locationData['prix_jour'] as num?)?.toDouble() ?? 0,
        caution:     (locationData['caution']   as num?)?.toDouble() ?? 0,
        observations: locationData['notes_depart'] as String?,
        etatVehicule: vehiculeMap['etat_vehicule'] as String?,
      );

      AppLogger.d('[PDF][Location] ► Construction du document PDF…');
      // Charger les articles dynamiques (fallback silencieux si table vide)
      final articlesRepo = ContractArticlesRepository(Supabase.instance.client);
      final articlesGeneraux = await articlesRepo.getArticlesResolus(
        contratType: 'location',
        contextData: {
          'client_nom':     clientMap['nom']            ?? '',
          'client_prenom':  clientMap['prenom']         ?? '',
          'client_cni':     clientMap['num_cni']        ?? '',
          'client_tel':     clientMap['telephone']      ?? '',
          'vehicule_marque':vehiculeMap['marque']       ?? '',
          'vehicule_modele':vehiculeMap['modele']       ?? '',
          'vehicule_immat': vehiculeMap['immatriculation'] ?? '',
          'date_debut':     locationData['date_debut']  ?? '',
          'date_fin':       locationData['date_fin_prevue'] ?? '',
          'prix_jour':      locationData['prix_jour']?.toString() ?? '',
          'nb_jours':       locationData['nb_jours']?.toString()  ?? '',
          'montant_total':  locationData['montant_brut']?.toString() ?? '',
          'caution':        locationData['caution']?.toString()   ?? '',
          'showroom_nom':   s['nom']     ?? '',
          'showroom_adresse': s['adresse'] ?? '',
          'showroom_tel':   s['tel']     ?? '',
        },
      );

      final doc = await ContratLocationPdfGenerator.buildAsync(
        dto,
        articlesGeneraux: articlesGeneraux,
      );
      final bytes = await doc.save();
      AppLogger.d('[PDF][Location] ✔ PDF généré : ${bytes.length} bytes');
      final id    = (locationData['id'] as String? ?? 'loc').substring(0, 8);
      final file  = await _saveBytes(bytes, 'contrat_location_$id.pdf');
      AppLogger.d('[PDF][Location] ✔ Génération terminée${file != null ? ' → ${file.path}' : ' (Web)'}');
      AppLogger.d('[PDF][Location] ════════════════════════════════════');
      return file;
    } catch (e, st) {
      AppLogger.d('[PDF][Location] ✖ ERREUR : $e');
      AppLogger.d('[PDF][Location] StackTrace : $st');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  VENTE
  // ─────────────────────────────────────────────────────────────────────────

  /// Génère un contrat de vente à partir des objets domaine.
  static Future<File?> genererVente({
    required Vente    vente,
    required Client   client,
    required Vehicule vehicule,
  }) async {
    AppLogger.d('[PDF][Vente] ════════════════════════════════════');
    AppLogger.d('[PDF][Vente] ► Début génération (objets domaine) — venteId=${vente.id}');
    try {
      final s = await _settings();

      final acompte      = vente.paiements.fold<double>(0, (sum, p) => sum + p.montant);
      final solde        = (vente.prixVente - acompte).clamp(0.0, double.infinity);
      final statutPaie   = solde < 1 ? 'complet' : 'partiel';
      final modePaiement = vente.paiements.isNotEmpty
          ? (vente.paiements.first.mode ?? 'especes')
          : 'especes';

      AppLogger.d('[PDF][Vente] ► Client   : ${client.prenom} ${client.nom} tel=${client.telephone}');
      AppLogger.d('[PDF][Vente] ► Véhicule : ${vehicule.marque} ${vehicule.modele} '
          'immat="${vehicule.immatriculation}" km=${vehicule.kilometrage}');
      AppLogger.d('[PDF][Vente] ► Financier: prixVente=${vente.prixVente} '
          'acompte=$acompte solde=$solde statut=$statutPaie mode=$modePaiement');
      AppLogger.d('[PDF][Vente] ► Paiements (${vente.paiements.length}) : '
          '${vente.paiements.map((p) => '${p.montant} ${p.mode}').toList()}');

      final dto = ContratVenteDto(
        venteId:               vente.id,
        dateEtablissement:     DateTime.now(),

        // Agence
        agenceNom:             s['nom']     as String? ?? 'Garage Auto',
        agenceAdresse:         s['adresse'] as String? ?? '',
        agenceTel:             s['tel']     as String? ?? '',
        agenceEmail:           s['email']   as String?,
        agenceVille:           s['ville']   as String?,
        agenceRc:              s['rc']      as String?,
        agenceCouleurHex:      s['couleur'] as String?,

        // Acheteur
        acheteurNom:           client.nom,
        acheteurPrenom:        client.prenom,
        acheteurTel:           client.telephone,
        acheteurEmail:         client.email,
        acheteurAdresse:       client.adresse,
        acheteurCin:           client.numCni,
        acheteurNumPermis:     client.numPermis,

        // Véhicule
        vehiculeMarque:        vehicule.marque,
        vehiculeModele:        vehicule.modele,
        vehiculeAnnee:         vehicule.annee,
        vehiculeCouleur:       vehicule.couleur,
        vehiculeImmatriculation: vehicule.immatriculation,
        vehiculeCarburant:     vehicule.carburant,
        vehiculeBoite:         vehicule.boite,
        vehiculeKilometrage:   vehicule.kilometrage,

        // Financier
        prixVente:       vente.prixVente,
        acompteVerse:    acompte,
        soldeRestant:    solde,
        modePaiement:    modePaiement,
        statutPaiement:  statutPaie,
        notes:           vente.notes,
      );

      AppLogger.d('[PDF][Vente] ► Construction du document PDF…');
      final doc   = ContratVentePdfGenerator.build(dto);
      final bytes = await ContratVentePdfGenerator.saveBytes(doc);
      AppLogger.d('[PDF][Vente] ✔ PDF généré : ${bytes.length} bytes');
      final id    = vente.id.length >= 8 ? vente.id.substring(0, 8) : vente.id;
      final file  = await _saveBytes(bytes, 'contrat_vente_$id.pdf');
      AppLogger.d('[PDF][Vente] ✔ Génération terminée${file != null ? ' → ${file.path}' : ' (Web)'}');
      AppLogger.d('[PDF][Vente] ════════════════════════════════════');
      return file;
    } catch (e, st) {
      AppLogger.d('[PDF][Vente] ✖ ERREUR : $e');
      AppLogger.d('[PDF][Vente] StackTrace : $st');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ÉCHANGE
  // ─────────────────────────────────────────────────────────────────────────

  /// Génère un contrat d'échange (reprise + cession) en PDF.
  static Future<File?> genererEchange({
    required Echange  echange,
    required Client   client,
    required Vehicule vehiculeCede,
  }) async {
    AppLogger.d('[PDF][Echange] ════════════════════════════════════');
    AppLogger.d('[PDF][Echange] ► Début génération (objets domaine) — echangeId=${echange.id}');
    try {
      final s = await _settings();

      final agenceNom     = s['nom']     as String? ?? 'Garage Auto';
      final agenceAdresse = s['adresse'] as String? ?? '';
      final agenceTel     = s['tel']     as String? ?? '';
      final agenceEmail   = s['email']   as String?;
      final agenceRc      = s['rc']      as String?;
      final couleurHex    = s['couleur'] as String?;

      AppLogger.d('[PDF][Echange] ► Client         : ${client.prenom} ${client.nom} tel=${client.telephone}');
      AppLogger.d('[PDF][Echange] ► Véhicule cédé  : ${vehiculeCede.marque} ${vehiculeCede.modele} '
          'immat="${vehiculeCede.immatriculation}" km=${vehiculeCede.kilometrage}');
      AppLogger.d('[PDF][Echange] ► Véhicule repris: ${echange.vehiculeReprisMarque} ${echange.vehiculeReprisModele} '
          'immat="${echange.vehiculeReprisImmat}" km=${echange.vehiculeReprisKm}');
      AppLogger.d('[PDF][Echange] ► Financier: valeurReprise=${echange.valeurReprise} '
          'complementClient=${echange.complementClient} '
          'dateEchange=${echange.dateEchange}');

      AppLogger.d('[PDF][Echange] ► Construction du document PDF…');
      final pdf = await _buildEchangePdf(
        echange:        echange,
        client:         client,
        vehiculeCede:   vehiculeCede,
        agenceNom:      agenceNom,
        agenceAdresse:  agenceAdresse,
        agenceTel:      agenceTel,
        agenceEmail:    agenceEmail,
        agenceRc:       agenceRc,
        couleurHex:     couleurHex,
      );

      AppLogger.d('[PDF][Echange] ✔ PDF généré : ${pdf.length} bytes');
      final id   = echange.id.length >= 8 ? echange.id.substring(0, 8) : echange.id;
      final file = await _saveBytes(pdf, 'contrat_echange_$id.pdf');
      AppLogger.d('[PDF][Echange] ✔ Génération terminée${file != null ? ' → ${file.path}' : ' (Web)'}');
      AppLogger.d('[PDF][Echange] ════════════════════════════════════');
      return file;
    } catch (e, st) {
      AppLogger.d('[PDF][Echange] ✖ ERREUR : $e');
      AppLogger.d('[PDF][Echange] StackTrace : $st');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ACHAT / REPRISE
  // ─────────────────────────────────────────────────────────────────────────

  /// Génère un bon d'achat / reprise véhicule en PDF.
  static Future<File?> genererAchat({
    required Map<String, dynamic> achatData,
  }) async {
    final achatId = achatData['id'] ?? '?';
    AppLogger.d('[PDF][Achat] ════════════════════════════════════');
    AppLogger.d('[PDF][Achat] ► Début génération — id=$achatId');
    AppLogger.d('[PDF][Achat] ► Données reçues : ${achatData.keys.toList()}');
    // Corrected version:
    AppLogger.d('[PDF][generateAndShareLocation] ► Reconstruction Map depuis Location id=${achatData['id']}');
    AppLogger.d('[PDF][Achat] ► Véhicule : ${achatData['vehicule_marque']} ${achatData['vehicule_modele']} '
        '${achatData['vehicule_annee']} immat="${achatData['vehicule_immat']}" km=${achatData['vehicule_km']}');
    AppLogger.d('[PDF][Achat] ► Prix achat: ${achatData['prix_achat']} — date: ${achatData['date_achat']}');
    try {
      final s = await _settings();

      AppLogger.d('[PDF][Achat] ► Construction du document PDF…');
      final pdf = await _buildAchatPdf(achatData: achatData, settings: s);
      AppLogger.d('[PDF][Achat] ✔ PDF généré : ${pdf.length} bytes');
      final rawId = achatData['id']?.toString() ?? 'achat';
      final id    = rawId.length >= 8 ? rawId.substring(0, 8) : rawId;
      final file  = await _saveBytes(pdf, 'bon_achat_$id.pdf');
      AppLogger.d('[PDF][Achat] ✔ Génération terminée${file != null ? ' → ${file.path}' : ' (Web)'}');
      AppLogger.d('[PDF][Achat] ════════════════════════════════════');
      return file;
    } catch (e, st) {
      AppLogger.d('[PDF][Achat] ✖ ERREUR : $e');
      AppLogger.d('[PDF][Achat] StackTrace : $st');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CONTRATS SCREEN (Map-based overloads)
  // ─────────────────────────────────────────────────────────────────────────

  /// Variante Map pour `contrats_screen.dart` qui passe une Map complète.
  static Future<File?> genererVenteFromMap({
    required Map<String, dynamic> venteData,
  }) async {
    final venteId = venteData['id'] ?? '?';
    AppLogger.d('[PDF][Vente/Map] ════════════════════════════════════');
    AppLogger.d('[PDF][Vente/Map] ► Début génération (Map) — venteId=$venteId');
    AppLogger.d('[PDF][Vente/Map] ► Clés reçues : ${venteData.keys.toList()}');
    try {
      final s = await _settings();

      final clientMap   = venteData['clients']   as Map<String, dynamic>? ?? {};
      final vehiculeMap = venteData['vehicules']  as Map<String, dynamic>? ?? {};
      final paiements   = (venteData['vente_paiements'] as List<dynamic>? ?? []);

      final prixVente  = (venteData['prix_vente'] as num?)?.toDouble() ?? 0;
      final acompte    = paiements.fold<double>(
        0, (sum, p) => sum + ((p['montant'] as num?)?.toDouble() ?? 0));
      final solde      = (prixVente - acompte).clamp(0.0, double.infinity);
      final statut     = solde < 1 ? 'complet' : 'partiel';
      final mode       = paiements.isNotEmpty
          ? (paiements.first['mode'] as String? ?? 'especes')
          : 'especes';

      AppLogger.d('[PDF][Vente/Map] ► Client   : "${clientMap['nom']}' '${clientMap['prenom']}" '
          'tel="${clientMap['telephone']}"');
      AppLogger.d('[PDF][Vente/Map] ► Véhicule : ${vehiculeMap['marque']} ${vehiculeMap['modele']} '
          'immat="${vehiculeMap['immatriculation']}" km=${vehiculeMap['kilometrage']}');
      AppLogger.d('[PDF][Vente/Map] ► Financier: prixVente=$prixVente acompte=$acompte '
          'solde=$solde statut=$statut mode=$mode');
      AppLogger.d('[PDF][Vente/Map] ► Paiements (${paiements.length}) : '
          '${paiements.map((p) => '${p['montant']} ${p['mode']}').toList()}');

      final dto = ContratVenteDto(
        venteId:              venteData['id'] as String? ?? '',
        dateEtablissement:    DateTime.now(),
        agenceNom:            s['nom']     as String? ?? 'Garage Auto',
        agenceAdresse:        s['adresse'] as String? ?? '',
        agenceTel:            s['tel']     as String? ?? '',
        agenceEmail:          s['email']   as String?,
        agenceVille:          s['ville']   as String?,
        agenceRc:             s['rc']      as String?,
        agenceCouleurHex:     s['couleur'] as String?,
        acheteurNom:          clientMap['nom']       as String? ?? '',
        acheteurPrenom:       clientMap['prenom']    as String? ?? '',
        acheteurTel:          clientMap['telephone'] as String? ?? '',
        acheteurEmail:        clientMap['email']     as String?,
        acheteurAdresse:      clientMap['adresse']   as String?,
        acheteurCin:          clientMap['num_cni']   as String?,
        acheteurNumPermis:    clientMap['num_permis'] as String?,
        vehiculeMarque:       vehiculeMap['marque']  as String? ?? '',
        vehiculeModele:       vehiculeMap['modele']  as String? ?? '',
        vehiculeAnnee:        (vehiculeMap['annee']  as num?)?.toInt(),
        vehiculeCouleur:      vehiculeMap['couleur'] as String?,
        vehiculeImmatriculation: vehiculeMap['immatriculation'] as String?,
        vehiculeCarburant:    vehiculeMap['carburant'] as String?,
        vehiculeBoite:        vehiculeMap['boite']    as String?,
        vehiculeKilometrage:  (vehiculeMap['kilometrage'] as num?)?.toInt(),
        prixVente:            prixVente,
        acompteVerse:         acompte,
        soldeRestant:         solde,
        modePaiement:         mode,
        statutPaiement:       statut,
        notes:                venteData['notes'] as String?,
      );

      AppLogger.d('[PDF][Vente/Map] ► Construction du document PDF…');
      final doc   = ContratVentePdfGenerator.build(dto);
      final bytes = await ContratVentePdfGenerator.saveBytes(doc);
      AppLogger.d('[PDF][Vente/Map] ✔ PDF généré : ${bytes.length} bytes');
      final rawId = venteData['id']?.toString() ?? 'vente';
      final id    = rawId.length >= 8 ? rawId.substring(0, 8) : rawId;
      final file  = await _saveBytes(bytes, 'contrat_vente_$id.pdf');
      AppLogger.d('[PDF][Vente/Map] ✔ Génération terminée${file != null ? ' → ${file.path}' : ' (Web)'}');
      AppLogger.d('[PDF][Vente/Map] ════════════════════════════════════');
      return file;
    } catch (e, st) {
      AppLogger.d('[PDF][Vente/Map] ✖ ERREUR : $e');
      AppLogger.d('[PDF][Vente/Map] StackTrace : $st');
      return null;
    }
  }

  /// Variante Map pour `contrats_screen.dart` qui passe une Map complète.
  static Future<File?> genererEchangeFromMap({
    required Map<String, dynamic> echangeData,
  }) async {
    final echangeId = echangeData['id'] ?? '?';
    AppLogger.d('[PDF][Echange/Map] ════════════════════════════════════');
    AppLogger.d('[PDF][Echange/Map] ► Début génération (Map) — echangeId=$echangeId');
    AppLogger.d('[PDF][Echange/Map] ► Clés reçues : ${echangeData.keys.toList()}');
    try {
      final s = await _settings();

      final agenceNom     = s['nom']     as String? ?? 'Garage Auto';
      final agenceAdresse = s['adresse'] as String? ?? '';
      final agenceTel     = s['tel']     as String? ?? '';
      final agenceEmail   = s['email']   as String?;
      final agenceRc      = s['rc']      as String?;
      final couleurHex    = s['couleur'] as String?;

      AppLogger.d('[PDF][Echange/Map] ► Désérialisation Echange depuis Map…');
      final echange      = Echange.fromJson(echangeData);
      AppLogger.d('[PDF][Echange/Map] ► Echange : reprise="${echange.vehiculeReprisMarque} ${echange.vehiculeReprisModele}" '
          'valeurReprise=${echange.valeurReprise} complement=${echange.complementClient}');

      final clientRaw = echangeData['clients'] as Map<String, dynamic>? ?? {};
      AppLogger.d('[PDF][Echange/Map] ► Client Map : ${clientRaw.keys.toList()}');
      final client       = Client.fromJson(clientRaw);
      AppLogger.d('[PDF][Echange/Map] ► Client : ${client.prenom} ${client.nom} tel=${client.telephone}');

      final vehiculeRaw = (echangeData['vehicules!echanges_vehicule_cede_id_fkey'] ??
           echangeData['vehicules']) as Map<String, dynamic>? ?? {};
      AppLogger.d('[PDF][Echange/Map] ► Véhicule cédé Map : ${vehiculeRaw.keys.toList()}');
      final vehiculeCede = Vehicule.fromJson(vehiculeRaw);
      AppLogger.d('[PDF][Echange/Map] ► Véhicule cédé : ${vehiculeCede.marque} ${vehiculeCede.modele} '
          'immat="${vehiculeCede.immatriculation}" km=${vehiculeCede.kilometrage}');

      AppLogger.d('[PDF][Echange/Map] ► Construction du document PDF…');
      final pdf = await _buildEchangePdf(
        echange:       echange,
        client:        client,
        vehiculeCede:  vehiculeCede,
        agenceNom:     agenceNom,
        agenceAdresse: agenceAdresse,
        agenceTel:     agenceTel,
        agenceEmail:   agenceEmail,
        agenceRc:      agenceRc,
        couleurHex:    couleurHex,
      );

      AppLogger.d('[PDF][Echange/Map] ✔ PDF généré : ${pdf.length} bytes');
      final rawId = echangeData['id']?.toString() ?? 'echange';
      final id    = rawId.length >= 8 ? rawId.substring(0, 8) : rawId;
      final file  = await _saveBytes(pdf, 'contrat_echange_$id.pdf');
      AppLogger.d('[PDF][Echange/Map] ✔ Génération terminée${file != null ? ' → ${file.path}' : ' (Web)'}');
      AppLogger.d('[PDF][Echange/Map] ════════════════════════════════════');
      return file;
    } catch (e, st) {
      AppLogger.d('[PDF][Echange/Map] ✖ ERREUR : $e');
      AppLogger.d('[PDF][Echange/Map] StackTrace : $st');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PARTAGE
  // ─────────────────────────────────────────────────────────────────────────
  //  GENERATE & SHARE — méthodes de commodité pour contrats_screen
  // ─────────────────────────────────────────────────────────────────────────

  /// Génère le contrat de location depuis un objet [Location] (issu d'un
  /// `fromJson` avec jointures) et ouvre la feuille de partage.
  static Future<void> generateAndShareLocation({
    required Location location,
    required WidgetRef ref,
  }) async {
    AppLogger.d('[PDF][generateAndShareLocation] ► Reconstruction Map depuis Location id=${location.id}');
    // Re-fetch the raw map is not needed: rebuild a compatible map from the domain object.
    // genererLocation() only needs the flat fields + embedded client/vehicule maps.
    // The Location object carries clientNom/clientTel from the joined query,
    // but not all client fields. We reconstruct minimal maps sufficient for the PDF.
    final client = ref.read(supabaseClientProvider);
    final full = await client
        .from('locations')
        .select(
            '*, vehicules(marque, modele, annee, couleur, immatriculation, carburant, boite, etat_vehicule, num_chassis),'
            'clients(prenom, nom, telephone, adresse, num_cni, num_permis),'
            'location_repartitions(*, profiles(prenom))')
        .eq('id', location.id)
        .single();
    final file = await genererLocation(locationData: full);
    await _shareFile(file);
  }

  /// Génère le contrat de vente depuis un objet [Vente] et ouvre le partage.
  static Future<void> generateAndShareVente({
    required Vente vente,
    required WidgetRef ref,
  }) async {
    AppLogger.d('[PDF][generateAndShareVente] ► Re-fetch complet pour vente id=${vente.id}');
    final client = ref.read(supabaseClientProvider);
    final full = await client
        .from('ventes')
        .select(
            '*, vehicules(marque, modele, annee, couleur, immatriculation, carburant, boite, num_chassis, kilometrage),'
            'clients(prenom, nom, telephone, adresse, num_cni, num_permis),'
            'vente_paiements(id, montant, date_paiement, mode)')
        .eq('id', vente.id)
        .single();
    final file = await genererVenteFromMap(venteData: full);
    await _shareFile(file);
  }

  /// Génère le contrat d'échange depuis un objet [Echange] et ouvre le partage.
  static Future<void> generateAndShareEchange({
    required Echange echange,
    required WidgetRef ref,
  }) async {
    AppLogger.d('[PDF][generateAndShareEchange] ► Re-fetch complet pour echange id=${echange.id}');
    final client = ref.read(supabaseClientProvider);
    final full = await client
        .from('echanges')
        .select(
            '*, vehicules!echanges_vehicule_cede_id_fkey(marque, modele, annee, couleur, immatriculation, kilometrage),'
            'clients(prenom, nom, telephone, adresse, num_cni, num_permis)')
        .eq('id', echange.id)
        .single();
    final file = await genererEchangeFromMap(echangeData: full);
    await _shareFile(file);
  }

  /// Partage interne sans BuildContext (SharePlus ne l'utilise pas réellement).
  static Future<void> _shareFile(File? file) async {
    if (file == null) return; // Web : téléchargement déjà déclenché par _saveBytes
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Contrat PDF — Garage Auto',
        ),
      );
    } catch (e) {
      AppLogger.d('[ContratGeneratorService] _shareFile error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  /// Ouvre la feuille de partage système pour le fichier PDF.
  /// Sur Web, le PDF est déjà téléchargé — cette méthode est un no-op.
  static Future<void> partager(BuildContext context, File? pdfFile) async {
    if (pdfFile == null) {
      // Sur Web le fichier a déjà été téléchargé via _downloadOnWeb()
      AppLogger.d('[ContratGeneratorService] partager: Web — fichier déjà téléchargé');
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfFile.path, mimeType: 'application/pdf')],
          subject: 'Contrat PDF — Garage Auto',
        ),
      );
    } catch (e) {
      AppLogger.d('[ContratGeneratorService] partager error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PDF BUILDERS INTERNES
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Échange ──────────────────────────────────────────────────────────────

  static Future<List<int>> _buildEchangePdf({
    required Echange  echange,
    required Client   client,
    required Vehicule vehiculeCede,
    required String   agenceNom,
    required String   agenceAdresse,
    required String   agenceTel,
    String?           agenceEmail,
    String?           agenceRc,
    String?           couleurHex,
  }) async {
    final pdf = _EchangePdfBuilder.build(
      echange:       echange,
      client:        client,
      vehiculeCede:  vehiculeCede,
      agenceNom:     agenceNom,
      agenceAdresse: agenceAdresse,
      agenceTel:     agenceTel,
      agenceEmail:   agenceEmail,
      agenceRc:      agenceRc,
      couleurHex:    couleurHex,
    );
    return await pdf.save();
  }

  // ── Achat ────────────────────────────────────────────────────────────────

  static Future<List<int>> _buildAchatPdf({
    required Map<String, dynamic> achatData,
    required Map<String, dynamic> settings,
  }) async {
    final pdf = _AchatPdfBuilder.build(achatData: achatData, settings: settings);
    return await pdf.save();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _EchangePdfBuilder — PDF contrat d'échange
// ═══════════════════════════════════════════════════════════════════════════

class _EchangePdfBuilder {
  _EchangePdfBuilder._();

  // Getter au lieu de static final pour éviter le crash si la locale
  // n'est pas encore initialisée au moment du chargement de la classe.
  static NumberFormat get _moneyFmt => NumberFormat('#,###', 'fr');

  static pw.Document build({
    required Echange  echange,
    required Client   client,
    required Vehicule vehiculeCede,
    required String   agenceNom,
    required String   agenceAdresse,
    required String   agenceTel,
    String?           agenceEmail,
    String?           agenceRc,
    String?           couleurHex,
  }) {
    final doc   = pw.Document();
    final color = _hexColor(couleurHex);
    final light = PdfColor(color.red, color.green, color.blue, 0.10);
    final shortId = echange.id.length >= 8
        ? echange.id.substring(0, 8).toUpperCase()
        : echange.id.toUpperCase();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      header: (_) => _header(
        agenceNom: agenceNom, agenceAdresse: agenceAdresse,
        agenceTel: agenceTel, agenceEmail: agenceEmail,
        agenceRc: agenceRc, color: color, shortId: shortId,
        date: echange.dateEchange,
      ),
      footer: (ctx) => _footer(agenceNom: agenceNom, agenceTel: agenceTel, ctx: ctx),
      build: (_) => [
        _section('PARTIES DE L\'ÉCHANGE', color),
        pw.SizedBox(height: 4),
        _twoCol(
          left: [
            ['Showroom',  agenceNom],
            ['Tél',       agenceTel],
            if ((agenceRc ?? '').isNotEmpty) ['RC', agenceRc!],
          ],
          right: [
            ['Client',    '${client.prenom} ${client.nom}'],
            ['Téléphone', client.telephone],
            if ((client.email ?? '').isNotEmpty) ['Email', client.email!],
          ],
          color: color, light: light,
        ),
        pw.SizedBox(height: 10),

        _section('VÉHICULE CÉDÉ PAR LE SHOWROOM', color),
        pw.SizedBox(height: 4),
        _twoCol(
          left: [
            ['Marque',   vehiculeCede.marque],
            ['Modèle',   vehiculeCede.modele],
            ['Année',    vehiculeCede.annee.toString()],
          ],
          right: [
            ['Immatriculation', vehiculeCede.immatriculation ?? '-'],
            ['Kilométrage', '${_moneyFmt.format(vehiculeCede.kilometrage)} km'],
            ['Couleur', vehiculeCede.couleur ?? '-'],
          ],
          color: color, light: light,
        ),
        pw.SizedBox(height: 10),

        _section('VÉHICULE REPRIS DU CLIENT', color),
        pw.SizedBox(height: 4),
        _twoCol(
          left: [
            ['Marque',  echange.vehiculeReprisMarque],
            ['Modèle',  echange.vehiculeReprisModele],
            if (echange.vehiculeReprisAnnee != null)
              ['Année', echange.vehiculeReprisAnnee.toString()],
          ],
          right: [
            ['Immatriculation', echange.vehiculeReprisImmat ?? '-'],
            ['Kilométrage',
              echange.vehiculeReprisKm != null
                ? '${_moneyFmt.format(echange.vehiculeReprisKm!)} km'
                : '-'],
          ],
          color: color, light: light,
        ),
        pw.SizedBox(height: 10),

        _section('DÉTAILS FINANCIERS', color),
        pw.SizedBox(height: 4),
        _financialTable(echange, color, light),
        pw.SizedBox(height: 10),

        _section('CONDITIONS', color),
        pw.SizedBox(height: 4),
        _conditions(),
        pw.SizedBox(height: 14),

        _signatures(client: client, agenceNom: agenceNom, color: color, light: light),
      ],
    ));

    return doc;
  }

  // ── Widgets ───────────────────────────────────────────────

  static pw.Widget _header({
    required String   agenceNom,
    required String   agenceAdresse,
    required String   agenceTel,
    required PdfColor color,
    required String   shortId,
    required DateTime date,
    String?           agenceEmail,
    String?           agenceRc,
  }) => pw.Column(children: [
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(agenceNom,
              style: pw.TextStyle(color: PdfColors.white, fontSize: 14,
                fontWeight: pw.FontWeight.bold)),
            if (agenceAdresse.isNotEmpty)
              pw.Text(agenceAdresse,
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
            pw.Text(
              [
                if (agenceTel.isNotEmpty) 'Tél : $agenceTel',
                if ((agenceEmail ?? '').isNotEmpty) agenceEmail!,
              ].join('  |  '),
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 8),
            ),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('CONTRAT D\'ÉCHANGE',
              style: pw.TextStyle(color: PdfColors.white, fontSize: 14,
                fontWeight: pw.FontWeight.bold)),
            pw.Text('N° $shortId',
              style: pw.TextStyle(color: PdfColors.white, fontSize: 11,
                fontWeight: pw.FontWeight.bold)),
            pw.Text(DateFormat('dd/MM/yyyy', 'fr').format(date),
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
          ]),
        ],
      ),
    ),
    pw.SizedBox(height: 10),
  ]);

  static pw.Widget _footer({
    required String     agenceNom,
    required String     agenceTel,
    required pw.Context ctx,
  }) => pw.Column(children: [
    pw.Divider(color: PdfColors.grey300, thickness: 0.5),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('$agenceNom${agenceTel.isNotEmpty ? '  |  Tél : $agenceTel' : ''}',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        pw.Text(
          'Page ${ctx.pageNumber}/${ctx.pagesCount}  -  '
          'Généré le ${DateFormat('dd/MM/yyyy', 'fr').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      ],
    ),
  ]);

  static pw.Widget _section(String title, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Text(title,
      style: pw.TextStyle(color: PdfColors.white, fontSize: 9,
        fontWeight: pw.FontWeight.bold)),
  );

  static pw.Widget _twoCol({
    required List<List<String>> left,
    required List<List<String>> right,
    required PdfColor color,
    required PdfColor light,
  }) {
    pw.Widget cell(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Row(children: [
        pw.SizedBox(width: 80,
          child: pw.Text(label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700))),
        pw.Flexible(child: pw.Text(value.isEmpty ? '-' : value,
          style: const pw.TextStyle(fontSize: 9))),
      ]),
    );

    pw.Widget col(List<List<String>> rows) => pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows.map((r) => cell(r[0], r[1])).toList()),
    );

    return pw.Row(children: [
      pw.Expanded(child: col(left)),
      pw.SizedBox(width: 6),
      pw.Expanded(child: col(right)),
    ]);
  }

  static pw.Widget _financialTable(
      Echange echange, PdfColor color, PdfColor light) {
    final moneyFmt = NumberFormat('#,###', 'fr');

    pw.Widget hCell(String t) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      color: color,
      child: pw.Center(child: pw.Text(t,
        style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5,
          fontWeight: pw.FontWeight.bold))),
    );

    pw.Widget dCell(String t, {bool isLabel = false}) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      color: isLabel ? light : PdfColors.white,
      child: pw.Center(child: pw.Text(t,
        style: pw.TextStyle(fontSize: 9,
          fontWeight: isLabel ? pw.FontWeight.bold : null,
          color: isLabel ? color : PdfColors.black))),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(140),
        1: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(children: [hCell('POSTE'), hCell('MONTANT')]),
        pw.TableRow(children: [
          dCell('Valeur de reprise (véhicule client)', isLabel: true),
          dCell('${moneyFmt.format(echange.valeurReprise)} DA'),
        ]),
        pw.TableRow(children: [
          dCell('Complément réglé par le client', isLabel: true),
          dCell('${moneyFmt.format(echange.complementClient)} DA'),
        ]),
        if ((echange.commissionGerantMnt ?? 0) > 0)
          pw.TableRow(children: [
            dCell('Commission gérant (${echange.commissionGerantPct?.toStringAsFixed(1) ?? 0} %)', isLabel: true),
            dCell('${moneyFmt.format(echange.commissionGerantMnt!)} DA'),
          ]),
      ],
    );
  }

  static pw.Widget _conditions() => pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      borderRadius: pw.BorderRadius.circular(3),
      color: const PdfColor(0.98, 0.98, 0.99),
    ),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      for (final clause in [
        '1. Les deux parties déclarent accepter les véhicules en l\'état au moment de l\'échange.',
        '2. Le transfert de propriété est effectif dès la signature du présent contrat et le règlement du complément.',
        '3. Chaque partie remet à l\'autre les documents de propriété barrés ainsi que les clés.',
        '4. Tout litige sera soumis aux tribunaux compétents du lieu de signature.',
      ])
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(clause,
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
            textAlign: pw.TextAlign.justify),
        ),
    ]),
  );

  static pw.Widget _signatures({
    required Client   client,
    required String   agenceNom,
    required PdfColor color,
    required PdfColor light,
  }) {
    pw.Widget box(String label, String name) => pw.Expanded(child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
        color: light,
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
            color: color)),
        pw.Text('Lu et approuvé - $name',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 40),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        pw.Text('Date : _______________',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ]),
    ));

    return pw.Row(children: [
      box('Signature du client', '${client.prenom} ${client.nom}'),
      pw.SizedBox(width: 10),
      box('Signature du showroom', agenceNom),
    ]);
  }

  static PdfColor _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return const PdfColor(0.10, 0.44, 0.83);
    final h = hex.replaceAll('#', '');
    if (h.length != 6) return const PdfColor(0.10, 0.44, 0.83);
    return PdfColor(
      int.parse(h.substring(0, 2), radix: 16) / 255,
      int.parse(h.substring(2, 4), radix: 16) / 255,
      int.parse(h.substring(4, 6), radix: 16) / 255,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _AchatPdfBuilder — Bon d'achat / reprise véhicule
// ═══════════════════════════════════════════════════════════════════════════

class _AchatPdfBuilder {
  _AchatPdfBuilder._();

  static NumberFormat get _moneyFmt => NumberFormat('#,###', 'fr');

  static pw.Document build({
    required Map<String, dynamic> achatData,
    required Map<String, dynamic> settings,
  }) {
    final doc       = pw.Document();
    final couleurHex = settings['couleur'] as String?;
    final color      = _hexColor(couleurHex);
    final light      = PdfColor(color.red, color.green, color.blue, 0.10);
    final agenceNom  = settings['nom']     as String? ?? 'Garage Auto';
    final agenceAdr  = settings['adresse'] as String? ?? '';
    final agenceTel  = settings['tel']     as String? ?? '';
    final agenceEmail = settings['email']  as String?;
    final agenceRc   = settings['rc']      as String?;

    final rawId   = achatData['id']?.toString() ?? '';
    final shortId = rawId.length >= 8 ? rawId.substring(0, 8).toUpperCase() : rawId.toUpperCase();

    final dateAchat = achatData['date_achat'] != null
        ? DateTime.tryParse(achatData['date_achat'] as String) ?? DateTime.now()
        : DateTime.now();

    final prixAchat   = (achatData['prix_achat']   as num?)?.toDouble() ?? 0;
    final prixPropose = (achatData['prix_propose']  as num?)?.toDouble();
    final eco         = prixPropose != null ? prixPropose - prixAchat : null;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      header: (_) => pw.Column(children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(
            color: color, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(agenceNom,
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 14,
                    fontWeight: pw.FontWeight.bold)),
                if (agenceAdr.isNotEmpty)
                  pw.Text(agenceAdr,
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
                pw.Text(
                  [
                    if (agenceTel.isNotEmpty)   'Tél : $agenceTel',
                    if ((agenceEmail ?? '').isNotEmpty) agenceEmail!,
                  ].join('  |  '),
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 8),
                ),
                if ((agenceRc ?? '').isNotEmpty)
                  pw.Text('RC : $agenceRc',
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('BON D\'ACHAT / REPRISE',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 13,
                    fontWeight: pw.FontWeight.bold)),
                pw.Text('N° $shortId',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 11,
                    fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd/MM/yyyy', 'fr').format(dateAchat),
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
      ]),
      footer: (ctx) => pw.Column(children: [
        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$agenceNom${agenceTel.isNotEmpty ? '  |  Tél : $agenceTel' : ''}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            pw.Text(
              'Page ${ctx.pageNumber}/${ctx.pagesCount}  -  '
              'Généré le ${DateFormat('dd/MM/yyyy', 'fr').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
      ]),
      build: (_) => [
        // -- Vendeur --
        _section('INFORMATIONS VENDEUR', color),
        pw.SizedBox(height: 4),
        _infoTable([
          ['Nom',       achatData['vendeur_nom']?.toString() ?? '-'],
          ['Téléphone', achatData['vendeur_tel']?.toString() ?? '-'],
          if ((achatData['vendeur_email']?.toString() ?? '').isNotEmpty)
            ['Email', achatData['vendeur_email'].toString()],
        ], color, light),
        pw.SizedBox(height: 10),

        // -- Véhicule --
        _section('VÉHICULE ACQUIS', color),
        pw.SizedBox(height: 4),
        _twoColRaw(
          left: [
            ['Marque',  achatData['vehicule_marque']?.toString() ?? '-'],
            ['Modèle',  achatData['vehicule_modele']?.toString() ?? '-'],
            ['Année',   achatData['vehicule_annee']?.toString() ?? '-'],
          ],
          right: [
            ['Immatriculation', achatData['vehicule_immat']?.toString() ?? '-'],
            ['Kilométrage',
              achatData['vehicule_km'] != null
                ? '${_moneyFmt.format(achatData['vehicule_km'])} km'
                : '-'],
          ],
          color: color, light: light,
        ),
        pw.SizedBox(height: 10),

        // -- Prix --
        _section('NÉGOCIATION & PRIX', color),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(150),
            1: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(children: [
              _hCell('POSTE', color),
              _hCell('MONTANT', color),
            ]),
            if (prixPropose != null)
              pw.TableRow(children: [
                _dCell('Prix demandé', isLabel: true, color: color, light: light),
                _dCell('${_moneyFmt.format(prixPropose)} DA'),
              ]),
            pw.TableRow(children: [
              _dCell('Prix accordé (achat)', isLabel: true, color: color, light: light),
              _dCell('${_moneyFmt.format(prixAchat)} DA'),
            ]),
            if (eco != null && eco > 0)
              pw.TableRow(children: [
                _dCell('Économie négociée', isLabel: true, color: color, light: light),
                _dCell('${_moneyFmt.format(eco)} DA'),
              ]),
          ],
        ),
        pw.SizedBox(height: 10),

        // -- Notes --
        if ((achatData['notes']?.toString() ?? '').isNotEmpty) ...[
          _section('OBSERVATIONS', color),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(achatData['notes'].toString(),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
          ),
          pw.SizedBox(height: 10),
        ],

        // -- Signatures --
        pw.Row(children: [
          _sigBox('Signature du vendeur', achatData['vendeur_nom']?.toString() ?? '', color, light),
          pw.SizedBox(width: 10),
          _sigBox('Signature du showroom', agenceNom, color, light),
        ]),
      ],
    ));

    return doc;
  }

  static pw.Widget _section(String t, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: pw.BoxDecoration(
      color: color, borderRadius: pw.BorderRadius.circular(3)),
    child: pw.Text(t,
      style: pw.TextStyle(color: PdfColors.white, fontSize: 9,
        fontWeight: pw.FontWeight.bold)),
  );

  static pw.Widget _infoTable(
      List<List<String>> rows, PdfColor color, PdfColor light) =>
    pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows.map((r) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Row(children: [
            pw.SizedBox(width: 90,
              child: pw.Text(r[0],
                style: pw.TextStyle(fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700))),
            pw.Flexible(child: pw.Text(r[1],
              style: const pw.TextStyle(fontSize: 9))),
          ]),
        )).toList(),
      ),
    );

  static pw.Widget _twoColRaw({
    required List<List<String>> left,
    required List<List<String>> right,
    required PdfColor color,
    required PdfColor light,
  }) {
    pw.Widget cell(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Row(children: [
        pw.SizedBox(width: 80,
          child: pw.Text(label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700))),
        pw.Flexible(child: pw.Text(value.isEmpty ? '-' : value,
          style: const pw.TextStyle(fontSize: 9))),
      ]),
    );

    pw.Widget col(List<List<String>> rows) => pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows.map((r) => cell(r[0], r[1])).toList()),
    );

    return pw.Row(children: [
      pw.Expanded(child: col(left)),
      pw.SizedBox(width: 6),
      pw.Expanded(child: col(right)),
    ]);
  }

  static pw.Widget _hCell(String t, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
    color: color,
    child: pw.Center(child: pw.Text(t,
      style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5,
        fontWeight: pw.FontWeight.bold))),
  );

  static pw.Widget _dCell(String t, {
    bool isLabel = false,
    PdfColor? color,
    PdfColor? light,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
    color: isLabel ? light : PdfColors.white,
    child: pw.Center(child: pw.Text(t,
      style: pw.TextStyle(fontSize: 9,
        fontWeight: isLabel ? pw.FontWeight.bold : null,
        color: isLabel ? color : PdfColors.black))),
  );

  static pw.Widget _sigBox(
      String label, String name, PdfColor color, PdfColor light) =>
    pw.Expanded(child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
        color: light,
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
            color: color)),
        pw.Text('Lu et approuvé - $name',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 40),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        pw.Text('Date : _______________',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ]),
    ));

  static PdfColor _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return const PdfColor(0.10, 0.44, 0.83);
    final h = hex.replaceAll('#', '');
    if (h.length != 6) return const PdfColor(0.10, 0.44, 0.83);
    return PdfColor(
      int.parse(h.substring(0, 2), radix: 16) / 255,
      int.parse(h.substring(2, 4), radix: 16) / 255,
      int.parse(h.substring(4, 6), radix: 16) / 255,
    );
  }
}