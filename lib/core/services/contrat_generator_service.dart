// lib/core/services/contrat_generator_service.dart
//
// Service façade unifié — génère et partage les contrats PDF
// pour les locations, ventes, échanges et achats.
//
// CORRECTIONS v3 (Web) :
//  ✅ Fonctionne sur Web — téléchargement navigateur via dart:html
//  ✅ Sur Mobile/Desktop — share_plus + path_provider (inchangé)
//  ✅ Upload Supabase Storage fonctionne sur toutes les plateformes
//  ✅ generateAndShareLocation / Vente / Echange — deux PDFs séparés FR + AR
//
// DÉPENDANCES pubspec.yaml :
//   pdf: ^3.11.0
//   path_provider: ^2.1.0
//   share_plus: ^7.0.0
//   intl: ^0.19.0
//   http: ^1.2.0

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Mobile/Desktop uniquement (ignoré sur Web par le compilateur)
import 'dart:io' if (dart.library.html) 'dart:io';
import 'package:path_provider/path_provider.dart'
    if (dart.library.html) 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'
    if (dart.library.html) 'package:share_plus/share_plus.dart';

// Téléchargement Web — import conditionnel stub/real
import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_real.dart';

import '../../features/clients/domain/client_model.dart';
import '../../features/echanges/domain/echange_model.dart';
import '../../features/locations/domain/location_model.dart';
import '../../features/vehicules/domain/vehicule_model.dart';
import '../../features/ventes/domain/vente_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/contrats/data/contrats_repository.dart';
import '../../features/contrats/data/contract_articles_repository.dart';
import '../../features/contrats/presentation/contrat_location_pdf_generator.dart';
import '../../features/contrats/presentation/contrat_vente_pdf_generator.dart';
import '../../features/contrats/presentation/contrat_echange_pdf_generator.dart';
import '../../features/contrats/presentation/contrats_provider.dart';
import '../../features/contrats/presentation/contract_articles_provider.dart';
import '../providers/supabase_provider.dart';
import '../utils/app_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SERVICE FAÇADE
// ─────────────────────────────────────────────────────────────────────────────

class ContratGeneratorService {
  ContratGeneratorService._();

  // ── Récupère les paramètres du showroom ───────────────────────────────────

  static Future<Map<String, dynamic>> _settings() async {
    AppLogger.d('[PDF][Settings] ► Chargement des paramètres showroom…');
    final s = await ContratsRepository(Supabase.instance.client)
        .getShowroomSettings();
    AppLogger.d('[PDF][Settings] ✔ nom=${s["nom"]} adresse=${s["adresse"]} '
        'tel=${s["tel"]} email=${s["email"]} rc=${s["rc"]} couleur=${s["couleur"]}');
    return s;
  }

  // ── Télécharge le logo depuis une URL ─────────────────────────────────────

  static Future<Uint8List?> _fetchLogo(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) return resp.bodyBytes;
    } catch (e) {
      AppLogger.d('[PDF][Logo] Impossible de télécharger : $e');
    }
    return null;
  }

  // ── Sauvegarde locale des bytes ───────────────────────────────────────────
  //
  // • Sur Web   → déclenche un téléchargement via <a download>
  //               retourne null (File n'existe pas sur Web)
  // • Sur mobile/desktop → écrit dans getApplicationDocumentsDirectory()

  static Future<File?> _saveBytes(List<int> bytes, String filename) async {
    AppLogger.d('[PDF][Save] ► Sauvegarde "$filename" (\${bytes.length} bytes)…');

    if (kIsWeb) {
      _downloadWeb(bytes, filename);
      return null;
    }

    final dir  = await getApplicationDocumentsDirectory();
    final file = File('\${dir.path}/\$filename');
    await file.writeAsBytes(bytes);
    AppLogger.d('[PDF][Save] ✔ Fichier écrit → \${file.path}');
    return file;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  GENERATE & SHARE — méthodes appelées depuis contrats_screen.dart
  //  Signature : (BuildContext context, WidgetRef ref, String id)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Génère + partage le contrat de location à partir de son [id] Supabase.
  /// Re-fetche toutes les données nécessaires depuis la base.
  static Future<void> generateAndShareLocation(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    AppLogger.d('[PDF][generateAndShareLocation] ► id=$id');
    try {
      // 1. Re-fetch complet depuis Supabase
      final supabase = ref.read(supabaseClientProvider);
      final data = await supabase
          .from('locations')
          .select(
            '*, '
            'vehicules(marque, modele, annee, couleur, immatriculation, '
            '         carburant, boite, etat_vehicule, kilometrage), '
            'clients(prenom, nom, telephone, adresse, num_cni, num_permis, email)',
          )
          .eq('id', id)
          .single();

      // 2. Paramètres showroom + logo
      final settings = await ref
          .read(contratsRepositoryProvider)
          .getShowroomSettings();
      final logoBytes = await _fetchLogo(settings['logo_url'] as String?);

      // 3. Articles dynamiques séparés par langue
      final articlesRepo = ref.read(contractArticlesRepositoryProvider);
      final clientMap    = data['clients']   as Map<String, dynamic>? ?? {};
      final vehiculeMap  = data['vehicules'] as Map<String, dynamic>? ?? {};

      final contextData = {
        'client_nom':      clientMap['nom']              ?? '',
        'client_prenom':   clientMap['prenom']           ?? '',
        'client_cni':      clientMap['num_cni']          ?? '',
        'client_tel':      clientMap['telephone']        ?? '',
        'vehicule_marque': vehiculeMap['marque']         ?? '',
        'vehicule_modele': vehiculeMap['modele']         ?? '',
        'vehicule_immat':  vehiculeMap['immatriculation'] ?? '',
        'date_debut':      data['date_debut']            ?? '',
        'date_fin':        data['date_fin_prevue']       ?? '',
        'prix_jour':       data['prix_jour']?.toString() ?? '',
        'nb_jours':        data['nb_jours']?.toString()  ?? '',
        'montant_total':   data['montant_brut']?.toString() ?? '',
        'caution':         data['caution']?.toString()   ?? '',
        'showroom_nom':    settings['nom']               ?? '',
        'showroom_adresse': settings['adresse']          ?? '',
        'showroom_tel':    settings['tel']               ?? '',
      };

      final resolved = await articlesRepo.getArticlesResolusParLangue(
        contratType: 'location',
        contextData: contextData,
      );

      // 4. Construire le DTO
      final dateDepart = DateTime.parse(data['date_debut'] as String);
      final dateRetour = DateTime.parse(data['date_fin_prevue'] as String);

      final dto = ContratLocationDto(
        contratId:               data['id'] as String? ?? id,
        dateEtablissement:       DateTime.now(),
        agenceNom:               settings['nom']      as String? ?? 'Garage Auto',
        agenceAdresse:           settings['adresse']  as String? ?? '',
        agenceTel:               settings['tel']      as String? ?? '',
        agenceEmail:             settings['email']    as String?,
        agenceVille:             settings['ville']    as String?,
        agenceRc:                settings['rc']       as String?,
        agenceCouleurHex:        settings['couleur']  as String?,
        agenceLogoBytes:         logoBytes,
        locataireNom:            clientMap['nom']       as String? ?? '',
        locatairePrenom:         clientMap['prenom']    as String? ?? '',
        locataireTel:            clientMap['telephone'] as String? ?? '',
        locataireEmail:          clientMap['email']     as String?,
        locataireAdresse:        clientMap['adresse']   as String?,
        locataireNumPermis:      clientMap['num_permis'] as String?,
        locataireCin:            clientMap['num_cni']   as String?,
        vehiculeMarque:          vehiculeMap['marque']         as String? ?? '',
        vehiculeModele:          vehiculeMap['modele']         as String? ?? '',
        vehiculeCouleur:         vehiculeMap['couleur']        as String?,
        vehiculeImmatriculation: vehiculeMap['immatriculation'] as String?,
        vehiculeCarburant:       vehiculeMap['carburant']      as String?,
        vehiculeBoite:           vehiculeMap['boite']          as String?,
        dateDepart:              dateDepart,
        dateRetour:              dateRetour,
        kmDepart:                (data['km_depart']  as num?)?.toInt() ?? 0,
        prixJour:                (data['prix_jour']  as num?)?.toDouble() ?? 0,
        caution:                 (data['caution']    as num?)?.toDouble() ?? 0,
        observations:            data['notes_depart'] as String?,
        etatVehicule:            vehiculeMap['etat_vehicule'] as String?,
      );

      // 5. Générer les deux PDFs (FR + AR) en mémoire
      final pair = await ContratLocationPdfGenerator.buildBothAsync(
        dto,
        articlesGeneraux: resolved.fr,
        articlesAr:       resolved.ar,
      );

      final bytesFr = await pair.fr.save();
      final bytesAr = await pair.ar.save();

      final id8 = id.substring(0, 8).toUpperCase();
      final nameFr = 'contrat_location_${id8}_FR.pdf';
      final nameAr = 'contrat_location_${id8}_AR.pdf';

      // 6. Télécharger / partager selon la plateforme
      if (kIsWeb) {
        // Web : deux téléchargements navigateur successifs
        _downloadWeb(bytesFr, nameFr);
        await Future.delayed(const Duration(milliseconds: 400));
        _downloadWeb(bytesAr, nameAr);
      } else {
        // Mobile / Desktop : enregistrer puis share_plus
        final dir   = await getApplicationDocumentsDirectory();
        final fileFr = File('${dir.path}/$nameFr')..writeAsBytesSync(bytesFr);
        final fileAr = File('${dir.path}/$nameAr')..writeAsBytesSync(bytesAr);
        final marque = vehiculeMap['marque'] as String? ?? '';
        final modele = vehiculeMap['modele'] as String? ?? '';
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(fileFr.path, mimeType: 'application/pdf'),
              XFile(fileAr.path, mimeType: 'application/pdf'),
            ],
            subject: 'Contrat de location — $marque $modele',
          ),
        );
      }

      // 7. Upload Supabase Storage + lien dans la table
      final repo  = ref.read(contratsRepositoryProvider);
      final urlFr = await repo.savePdfToStorage(
        fileName: nameFr,
        pdfBytes: Uint8List.fromList(bytesFr),
        folder:   'locations',
      );
      if (urlFr != null) {
        await repo.linkContratToLocation(id, urlFr);
      }
      await repo.savePdfToStorage(
        fileName: nameAr,
        pdfBytes: Uint8List.fromList(bytesAr),
        folder:   'locations',
      );

      AppLogger.d('[PDF][generateAndShareLocation] ✔ Terminé');
    } catch (e, st) {
      AppLogger.d('[PDF][generateAndShareLocation] ✖ ERREUR : $e\n$st');
      rethrow;
    }
  }

  /// Génère + partage le contrat de vente à partir de son [id] Supabase.
  static Future<void> generateAndShareVente(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    AppLogger.d('[PDF][generateAndShareVente] ► id=$id');
    try {
      // 1. Re-fetch complet
      final supabase = ref.read(supabaseClientProvider);
      final data = await supabase
          .from('ventes')
          .select(
            '*, '
            'vehicules(marque, modele, annee, couleur, immatriculation, '
            '         carburant, boite, num_chassis, kilometrage), '
            'clients(prenom, nom, telephone, adresse, num_cni, num_permis, email), '
            'vente_paiements(id, montant, date_paiement, mode)',
          )
          .eq('id', id)
          .single();

      // 2. Paramètres showroom
      final settings = await ref
          .read(contratsRepositoryProvider)
          .getShowroomSettings();

      // 3. Construire le DTO
      final clientMap   = data['clients']   as Map<String, dynamic>? ?? {};
      final vehiculeMap = data['vehicules'] as Map<String, dynamic>? ?? {};
      final paiements   = (data['vente_paiements'] as List<dynamic>? ?? []);

      final prixVente = (data['prix_vente'] as num?)?.toDouble() ?? 0;
      final acompte   = paiements.fold<double>(
        0, (sum, p) => sum + ((p['montant'] as num?)?.toDouble() ?? 0));
      final solde     = (prixVente - acompte).clamp(0.0, double.infinity);
      final statut    = solde < 1 ? 'complet' : 'partiel';
      final mode      = paiements.isNotEmpty
          ? (paiements.first['mode'] as String? ?? 'especes')
          : 'especes';

      AppLogger.d('[PDF][generateAndShareVente] ► prixVente=$prixVente '
          'acompte=$acompte solde=$solde statut=$statut');

      final dto = ContratVenteDto(
        venteId:               id,
        dateEtablissement:     DateTime.now(),
        agenceNom:             settings['nom']     as String? ?? 'Garage Auto',
        agenceAdresse:         settings['adresse'] as String? ?? '',
        agenceTel:             settings['tel']     as String? ?? '',
        agenceEmail:           settings['email']   as String?,
        agenceVille:           settings['ville']   as String?,
        agenceRc:              settings['rc']      as String?,
        agenceCouleurHex:      settings['couleur'] as String?,
        acheteurNom:           clientMap['nom']       as String? ?? '',
        acheteurPrenom:        clientMap['prenom']    as String? ?? '',
        acheteurTel:           clientMap['telephone'] as String? ?? '',
        acheteurEmail:         clientMap['email']     as String?,
        acheteurAdresse:       clientMap['adresse']   as String?,
        acheteurCin:           clientMap['num_cni']   as String?,
        acheteurNumPermis:     clientMap['num_permis'] as String?,
        vehiculeMarque:        vehiculeMap['marque']         as String? ?? '',
        vehiculeModele:        vehiculeMap['modele']         as String? ?? '',
        vehiculeAnnee:         (vehiculeMap['annee']         as num?)?.toInt(),
        vehiculeCouleur:       vehiculeMap['couleur']        as String?,
        vehiculeImmatriculation: vehiculeMap['immatriculation'] as String?,
        vehiculeCarburant:     vehiculeMap['carburant']      as String?,
        vehiculeBoite:         vehiculeMap['boite']          as String?,
        vehiculeKilometrage:   (vehiculeMap['kilometrage']   as num?)?.toInt(),
        vehiculeNumChassis:    vehiculeMap['num_chassis']    as String?,
        prixVente:             prixVente,
        acompteVerse:          acompte,
        soldeRestant:          solde,
        modePaiement:          mode,
        statutPaiement:        statut,
        notes:                 data['notes'] as String?,
      );

      // 4. Générer le PDF
      final doc   = ContratVentePdfGenerator.build(dto);
      final bytes = await ContratVentePdfGenerator.saveBytes(doc);
      final id8   = id.length >= 8 ? id.substring(0, 8) : id;
      final file  = await _saveBytes(bytes, 'contrat_vente_$id8.pdf');

      // 5. Partager
      await _shareFile(file);

      // 6. Upload Supabase Storage + lien
      final repo = ref.read(contratsRepositoryProvider);
      final url  = await repo.savePdfToStorage(
        fileName: 'contrat_vente_$id8.pdf',
        pdfBytes: Uint8List.fromList(bytes),
        folder:   'ventes',
      );
      if (url != null) {
        await repo.linkContratToVente(id, url);
      }

      AppLogger.d('[PDF][generateAndShareVente] ✔ Terminé');
    } catch (e, st) {
      AppLogger.d('[PDF][generateAndShareVente] ✖ ERREUR : $e\n$st');
      rethrow;
    }
  }

  /// Génère + partage le contrat d'échange à partir de son [id] Supabase.
  static Future<void> generateAndShareEchange(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    AppLogger.d('[PDF][generateAndShareEchange] ► id=$id');
    try {
      // 1. Re-fetch complet
      final supabase = ref.read(supabaseClientProvider);
      final data = await supabase
          .from('echanges')
          .select(
            '*, '
            'vehicules!echanges_vehicule_cede_id_fkey('
            '  marque, modele, annee, couleur, immatriculation, kilometrage), '
            'clients(prenom, nom, telephone, adresse, num_cni, num_permis, email)',
          )
          .eq('id', id)
          .single();

      // 2. Paramètres showroom
      final settings = await ref
          .read(contratsRepositoryProvider)
          .getShowroomSettings();

      // 3. Articles dynamiques pour échange
      final articlesRepo = ref.read(contractArticlesRepositoryProvider);
      final clientMap    = data['clients']   as Map<String, dynamic>? ?? {};
      final vehiculeMap  = (data['vehicules!echanges_vehicule_cede_id_fkey']
                         ?? data['vehicules']) as Map<String, dynamic>? ?? {};

      final contextData = {
        'client_nom':       clientMap['nom']              ?? '',
        'client_prenom':    clientMap['prenom']           ?? '',
        'vehicule_marque':  vehiculeMap['marque']         ?? '',
        'vehicule_modele':  vehiculeMap['modele']         ?? '',
        'vehicule_immat':   vehiculeMap['immatriculation'] ?? '',
        'reprise_marque':   data['vehicule_reprise_marque'] ?? '',
        'reprise_modele':   data['vehicule_reprise_modele'] ?? '',
        'valeur_reprise':   data['valeur_reprise']?.toString() ?? '',
        'complement':       data['complement_client']?.toString() ?? '',
        'showroom_nom':     settings['nom']               ?? '',
        'showroom_tel':     settings['tel']               ?? '',
      };

      final resolved = await articlesRepo.getArticlesResolusParLangue(
        contratType: 'echange',
        contextData: contextData,
      );

      // 4. Construire le DTO
      final dto = ContratEchangeDto(
        echangeId:              id,
        dateEtablissement:      DateTime.now(),
        dateEchange:            data['date_echange'] != null
            ? DateTime.parse(data['date_echange'] as String)
            : DateTime.now(),
        // Agence
        agenceNom:              settings['nom']      as String? ?? 'Garage Auto',
        agenceAdresse:          settings['adresse']  as String? ?? '',
        agenceTel:              settings['tel']      as String? ?? '',
        agenceEmail:            settings['email']    as String?,
        agenceRc:               settings['rc']       as String?,
        agenceCouleurHex:       settings['couleur']  as String?,
        // Client
        clientNom:              clientMap['nom']       as String? ?? '',
        clientPrenom:           clientMap['prenom']    as String? ?? '',
        clientTel:              clientMap['telephone'] as String? ?? '',
        clientEmail:            clientMap['email']     as String?,
        clientAdresse:          clientMap['adresse']   as String?,
        clientCin:              clientMap['num_cni']   as String?,
        // Véhicule cédé (showroom → client)
        vehiculeCedeMarque:     vehiculeMap['marque']         as String? ?? '',
        vehiculeCedeModele:     vehiculeMap['modele']         as String? ?? '',
        vehiculeCedeAnnee:      (vehiculeMap['annee']         as num?)?.toInt(),
        vehiculeCedeCouleur:    vehiculeMap['couleur']        as String?,
        vehiculeCedeImmat:      vehiculeMap['immatriculation'] as String?,
        vehiculeCedeKm:         (vehiculeMap['kilometrage']   as num?)?.toInt(),
        // Véhicule repris (client → showroom)
        vehiculeReprisMarque:   data['vehicule_reprise_marque'] as String? ?? '',
        vehiculeReprisModele:   data['vehicule_reprise_modele'] as String? ?? '',
        vehiculeReprisAnnee:    (data['vehicule_reprise_annee'] as num?)?.toInt(),
        vehiculeReprisImmat:    data['vehicule_reprise_immat']  as String?,
        vehiculeReprisKm:       (data['vehicule_reprise_km']   as num?)?.toInt(),
        // Financier
        valeurReprise:          (data['valeur_reprise']       as num?)?.toDouble() ?? 0,
        complementClient:       (data['complement_client']    as num?)?.toDouble() ?? 0,
        commissionGerantPct:    (data['commission_gerant_pct'] as num?)?.toDouble(),
        commissionGerantMnt:    (data['commission_gerant_mnt'] as num?)?.toDouble(),
        notes:                  data['notes'] as String?,
        // Articles dynamiques
        articlesFr:             resolved.fr,
        articlesAr:             resolved.ar,
      );

      // 5. Générer les deux PDFs (FR + AR) en mémoire
      final pair    = await ContratEchangePdfGenerator.buildBothAsync(dto);
      final bytesFr = await pair.fr.save();
      final bytesAr = await pair.ar.save();

      final id8    = id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
      final nameFr = 'contrat_echange_${id8}_FR.pdf';
      final nameAr = 'contrat_echange_${id8}_AR.pdf';

      // 6. Télécharger / partager selon la plateforme
      if (kIsWeb) {
        _downloadWeb(bytesFr, nameFr);
        await Future.delayed(const Duration(milliseconds: 400));
        _downloadWeb(bytesAr, nameAr);
      } else {
        final dir    = await getApplicationDocumentsDirectory();
        final fileFr = File('${dir.path}/$nameFr')..writeAsBytesSync(bytesFr);
        final fileAr = File('${dir.path}/$nameAr')..writeAsBytesSync(bytesAr);
        final marque = vehiculeMap['marque'] as String? ?? '';
        final modele = vehiculeMap['modele'] as String? ?? '';
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(fileFr.path, mimeType: 'application/pdf'),
              XFile(fileAr.path, mimeType: 'application/pdf'),
            ],
            subject: "Contrat d'échange — $marque $modele",
          ),
        );
      }

      // 7. Upload Supabase Storage + lien
      final repo   = ref.read(contratsRepositoryProvider);
      final urlFr  = await repo.savePdfToStorage(
        fileName: nameFr,
        pdfBytes: Uint8List.fromList(bytesFr),
        folder:   'echanges',
      );
      if (urlFr != null) {
        await repo.linkContratToEchange(id, urlFr);
      }
      await repo.savePdfToStorage(
        fileName: nameAr,
        pdfBytes: Uint8List.fromList(bytesAr),
        folder:   'echanges',
      );

      AppLogger.d('[PDF][generateAndShareEchange] ✔ Terminé');
    } catch (e, st) {
      AppLogger.d('[PDF][generateAndShareEchange] ✖ ERREUR : $e\n$st');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MÉTHODES DE GÉNÉRATION DIRECTE (objets domaine)
  //  Utilisées depuis les écrans détail (location_detail, vente_detail…)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Génère un contrat de location à partir d'une Map Supabase complète.
  static Future<File?> genererLocation({
    required Map<String, dynamic> locationData,
  }) async {
    final locationId = locationData['id'] ?? '?';
    AppLogger.d('[PDF][Location] ► Début génération — id=$locationId');
    try {
      final s           = await _settings();
      final clientMap   = locationData['clients']   as Map<String, dynamic>? ?? {};
      final vehiculeMap = locationData['vehicules'] as Map<String, dynamic>? ?? {};
      final logoBytes   = await _fetchLogo(s['logo_url'] as String?);

      final dateDepart = DateTime.parse(locationData['date_debut'] as String);
      final dateRetour = DateTime.parse(locationData['date_fin_prevue'] as String);

      final dto = ContratLocationDto(
        contratId:               locationData['id'] as String? ?? '',
        dateEtablissement:       DateTime.now(),
        agenceNom:               s['nom']      as String? ?? 'Garage Auto',
        agenceAdresse:           s['adresse']  as String? ?? '',
        agenceTel:               s['tel']      as String? ?? '',
        agenceEmail:             s['email']    as String?,
        agenceVille:             s['ville']    as String?,
        agenceRc:                s['rc']       as String?,
        agenceCouleurHex:        s['couleur']  as String?,
        agenceLogoBytes:         logoBytes,
        locataireNom:            clientMap['nom']       as String? ?? '',
        locatairePrenom:         clientMap['prenom']    as String? ?? '',
        locataireTel:            clientMap['telephone'] as String? ?? '',
        locataireEmail:          clientMap['email']     as String?,
        locataireAdresse:        clientMap['adresse']   as String?,
        locataireNumPermis:      clientMap['num_permis'] as String?,
        locataireCin:            clientMap['num_cni']   as String?,
        vehiculeMarque:          vehiculeMap['marque']         as String? ?? '',
        vehiculeModele:          vehiculeMap['modele']         as String? ?? '',
        vehiculeCouleur:         vehiculeMap['couleur']        as String?,
        vehiculeImmatriculation: vehiculeMap['immatriculation'] as String?,
        vehiculeCarburant:       vehiculeMap['carburant']      as String?,
        vehiculeBoite:           vehiculeMap['boite']          as String?,
        dateDepart:              dateDepart,
        dateRetour:              dateRetour,
        kmDepart:                (locationData['km_depart']  as num?)?.toInt() ?? 0,
        prixJour:                (locationData['prix_jour']  as num?)?.toDouble() ?? 0,
        caution:                 (locationData['caution']    as num?)?.toDouble() ?? 0,
        observations:            locationData['notes_depart'] as String?,
        etatVehicule:            vehiculeMap['etat_vehicule']  as String?,
      );

      final articlesRepo = ContractArticlesRepository(Supabase.instance.client);
      final resolved = await articlesRepo.getArticlesResolusParLangue(
        contratType: 'location',
        contextData: {
          'client_nom':      clientMap['nom']     ?? '',
          'client_prenom':   clientMap['prenom']  ?? '',
          'vehicule_marque': vehiculeMap['marque'] ?? '',
          'vehicule_modele': vehiculeMap['modele'] ?? '',
          'vehicule_immat':  vehiculeMap['immatriculation'] ?? '',
          'date_debut':      locationData['date_debut']  ?? '',
          'date_fin':        locationData['date_fin_prevue'] ?? '',
          'prix_jour':       locationData['prix_jour']?.toString() ?? '',
          'nb_jours':        locationData['nb_jours']?.toString() ?? '',
          'montant_total':   locationData['montant_brut']?.toString() ?? '',
          'caution':         locationData['caution']?.toString() ?? '',
          'showroom_nom':    s['nom']     ?? '',
          'showroom_adresse': s['adresse'] ?? '',
          'showroom_tel':    s['tel']     ?? '',
        },
      );

      final doc = await ContratLocationPdfGenerator.buildAsync(
        dto,
        articlesGeneraux: resolved.fr,
        articlesAr:       resolved.ar,
      );
      final bytes = await doc.save();
      final id8   = (locationData['id'] as String? ?? 'loc').substring(0, 8);
      return await _saveBytes(bytes, 'contrat_location_$id8.pdf');
    } catch (e, st) {
      AppLogger.d('[PDF][Location] ✖ ERREUR : $e\n$st');
      return null;
    }
  }

  /// Génère un contrat de vente à partir des objets domaine.
  static Future<File?> genererVente({
    required Vente    vente,
    required Client   client,
    required Vehicule vehicule,
  }) async {
    AppLogger.d('[PDF][Vente] ► Début génération — venteId=${vente.id}');
    try {
      final s         = await _settings();
      final acompte   = vente.paiements.fold<double>(0, (sum, p) => sum + p.montant);
      final solde     = (vente.prixVente - acompte).clamp(0.0, double.infinity);
      final statut    = solde < 1 ? 'complet' : 'partiel';
      final mode      = vente.paiements.isNotEmpty
          ? (vente.paiements.first.mode ?? 'especes')
          : 'especes';

      final dto = ContratVenteDto(
        venteId:               vente.id,
        dateEtablissement:     DateTime.now(),
        agenceNom:             s['nom']     as String? ?? 'Garage Auto',
        agenceAdresse:         s['adresse'] as String? ?? '',
        agenceTel:             s['tel']     as String? ?? '',
        agenceEmail:           s['email']   as String?,
        agenceVille:           s['ville']   as String?,
        agenceRc:              s['rc']      as String?,
        agenceCouleurHex:      s['couleur'] as String?,
        acheteurNom:           client.nom,
        acheteurPrenom:        client.prenom,
        acheteurTel:           client.telephone,
        acheteurEmail:         client.email,
        acheteurAdresse:       client.adresse,
        acheteurCin:           client.numCni,
        acheteurNumPermis:     client.numPermis,
        vehiculeMarque:        vehicule.marque,
        vehiculeModele:        vehicule.modele,
        vehiculeAnnee:         vehicule.annee,
        vehiculeCouleur:       vehicule.couleur,
        vehiculeImmatriculation: vehicule.immatriculation,
        vehiculeCarburant:     vehicule.carburant,
        vehiculeBoite:         vehicule.boite,
        vehiculeKilometrage:   vehicule.kilometrage,
        prixVente:             vente.prixVente,
        acompteVerse:          acompte,
        soldeRestant:          solde,
        modePaiement:          mode,
        statutPaiement:        statut,
        notes:                 vente.notes,
      );

      final doc   = ContratVentePdfGenerator.build(dto);
      final bytes = await ContratVentePdfGenerator.saveBytes(doc);
      final id8   = vente.id.length >= 8 ? vente.id.substring(0, 8) : vente.id;
      return await _saveBytes(bytes, 'contrat_vente_$id8.pdf');
    } catch (e, st) {
      AppLogger.d('[PDF][Vente] ✖ ERREUR : $e\n$st');
      return null;
    }
  }

  /// Génère un contrat d'échange à partir des objets domaine.
  static Future<File?> genererEchange({
    required Echange  echange,
    required Client   client,
    required Vehicule vehiculeCede,
  }) async {
    AppLogger.d('[PDF][Echange] ► Début génération — echangeId=${echange.id}');
    try {
      final s = await _settings();

      final dto = ContratEchangeDto(
        echangeId:              echange.id,
        dateEtablissement:      DateTime.now(),
        dateEchange:            echange.dateEchange,
        agenceNom:              s['nom']     as String? ?? 'Garage Auto',
        agenceAdresse:          s['adresse'] as String? ?? '',
        agenceTel:              s['tel']     as String? ?? '',
        agenceEmail:            s['email']   as String?,
        agenceRc:               s['rc']      as String?,
        agenceCouleurHex:       s['couleur'] as String?,
        clientNom:              client.nom,
        clientPrenom:           client.prenom,
        clientTel:              client.telephone,
        clientEmail:            client.email,
        clientAdresse:          client.adresse,
        clientCin:              client.numCni,
        vehiculeCedeMarque:     vehiculeCede.marque,
        vehiculeCedeModele:     vehiculeCede.modele,
        vehiculeCedeAnnee:      vehiculeCede.annee,
        vehiculeCedeCouleur:    vehiculeCede.couleur,
        vehiculeCedeImmat:      vehiculeCede.immatriculation,
        vehiculeCedeKm:         vehiculeCede.kilometrage,
        vehiculeReprisMarque:   echange.vehiculeReprisMarque,
        vehiculeReprisModele:   echange.vehiculeReprisModele,
        vehiculeReprisAnnee:    echange.vehiculeReprisAnnee,
        vehiculeReprisImmat:    echange.vehiculeReprisImmat,
        vehiculeReprisKm:       echange.vehiculeReprisKm,
        valeurReprise:          echange.valeurReprise,
        complementClient:       echange.complementClient,
        commissionGerantPct:    echange.commissionGerantPct,
        commissionGerantMnt:    echange.commissionGerantMnt,
        notes:                  echange.notes,
      );

      final pair  = await ContratEchangePdfGenerator.buildBothAsync(dto);
      final bytes = await pair.fr.save();
      final id8   = echange.id.length >= 8 ? echange.id.substring(0, 8) : echange.id;
      return await _saveBytes(bytes, 'contrat_echange_$id8.pdf');
    } catch (e, st) {
      AppLogger.d('[PDF][Echange] ✖ ERREUR : $e\n$st');
      return null;
    }
  }

  /// Génère un bon d'achat / reprise véhicule en PDF.
  static Future<File?> genererAchat({
    required Map<String, dynamic> achatData,
  }) async {
    final achatId = achatData['id'] ?? '?';
    AppLogger.d('[PDF][Achat] ► Début génération — id=$achatId');
    try {
      final s   = await _settings();
      final pdf = await _buildAchatPdf(achatData: achatData, settings: s);
      final rawId = achatData['id']?.toString() ?? 'achat';
      final id8   = rawId.length >= 8 ? rawId.substring(0, 8) : rawId;
      return await _saveBytes(pdf, 'bon_achat_$id8.pdf');
    } catch (e, st) {
      AppLogger.d('[PDF][Achat] ✖ ERREUR : $e\n$st');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  VARIANTES MAP (compatibilité contrats_screen ancienne version)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<File?> genererVenteFromMap({
    required Map<String, dynamic> venteData,
  }) async {
    final clientMap   = venteData['clients']   as Map<String, dynamic>? ?? {};
    final vehiculeMap = venteData['vehicules'] as Map<String, dynamic>? ?? {};
    final paiements   = (venteData['vente_paiements'] as List<dynamic>? ?? []);
    final s           = await _settings();

    final prixVente = (venteData['prix_vente'] as num?)?.toDouble() ?? 0;
    final acompte   = paiements.fold<double>(
        0, (sum, p) => sum + ((p['montant'] as num?)?.toDouble() ?? 0));
    final solde     = (prixVente - acompte).clamp(0.0, double.infinity);
    final statut    = solde < 1 ? 'complet' : 'partiel';
    final mode      = paiements.isNotEmpty
        ? (paiements.first['mode'] as String? ?? 'especes')
        : 'especes';

    final dto = ContratVenteDto(
      venteId:               venteData['id'] as String? ?? '',
      dateEtablissement:     DateTime.now(),
      agenceNom:             s['nom']     as String? ?? 'Garage Auto',
      agenceAdresse:         s['adresse'] as String? ?? '',
      agenceTel:             s['tel']     as String? ?? '',
      agenceEmail:           s['email']   as String?,
      agenceVille:           s['ville']   as String?,
      agenceRc:              s['rc']      as String?,
      agenceCouleurHex:      s['couleur'] as String?,
      acheteurNom:           clientMap['nom']       as String? ?? '',
      acheteurPrenom:        clientMap['prenom']    as String? ?? '',
      acheteurTel:           clientMap['telephone'] as String? ?? '',
      acheteurEmail:         clientMap['email']     as String?,
      acheteurAdresse:       clientMap['adresse']   as String?,
      acheteurCin:           clientMap['num_cni']   as String?,
      acheteurNumPermis:     clientMap['num_permis'] as String?,
      vehiculeMarque:        vehiculeMap['marque']         as String? ?? '',
      vehiculeModele:        vehiculeMap['modele']         as String? ?? '',
      vehiculeAnnee:         (vehiculeMap['annee']         as num?)?.toInt(),
      vehiculeCouleur:       vehiculeMap['couleur']        as String?,
      vehiculeImmatriculation: vehiculeMap['immatriculation'] as String?,
      vehiculeCarburant:     vehiculeMap['carburant']      as String?,
      vehiculeBoite:         vehiculeMap['boite']          as String?,
      vehiculeKilometrage:   (vehiculeMap['kilometrage']   as num?)?.toInt(),
      vehiculeNumChassis:    vehiculeMap['num_chassis']    as String?,
      prixVente:             prixVente,
      acompteVerse:          acompte,
      soldeRestant:          solde,
      modePaiement:          mode,
      statutPaiement:        statut,
      notes:                 venteData['notes'] as String?,
    );

    final doc   = ContratVentePdfGenerator.build(dto);
    final bytes = await ContratVentePdfGenerator.saveBytes(doc);
    final rawId = venteData['id']?.toString() ?? 'vente';
    final id8   = rawId.length >= 8 ? rawId.substring(0, 8) : rawId;
    return await _saveBytes(bytes, 'contrat_vente_$id8.pdf');
  }

  static Future<File?> genererEchangeFromMap({
    required Map<String, dynamic> echangeData,
  }) async {
    final s           = await _settings();
    final clientRaw   = echangeData['clients'] as Map<String, dynamic>? ?? {};
    final vehiculeRaw = (echangeData['vehicules!echanges_vehicule_cede_id_fkey']
                       ?? echangeData['vehicules']) as Map<String, dynamic>? ?? {};

    final articlesRepo = ContractArticlesRepository(Supabase.instance.client);
    final resolved = await articlesRepo.getArticlesResolusParLangue(
      contratType: 'echange',
      contextData: {
        'client_nom':      clientRaw['nom']    ?? '',
        'client_prenom':   clientRaw['prenom'] ?? '',
        'vehicule_marque': vehiculeRaw['marque'] ?? '',
        'vehicule_modele': vehiculeRaw['modele'] ?? '',
        'reprise_marque':  echangeData['vehicule_reprise_marque'] ?? '',
        'reprise_modele':  echangeData['vehicule_reprise_modele'] ?? '',
        'valeur_reprise':  echangeData['valeur_reprise']?.toString() ?? '',
        'showroom_nom':    s['nom'] ?? '',
        'showroom_tel':    s['tel'] ?? '',
      },
    );

    final dto = ContratEchangeDto(
      echangeId:            echangeData['id'] as String? ?? '',
      dateEtablissement:    DateTime.now(),
      dateEchange:          echangeData['date_echange'] != null
          ? DateTime.parse(echangeData['date_echange'] as String)
          : DateTime.now(),
      agenceNom:            s['nom']     as String? ?? 'Garage Auto',
      agenceAdresse:        s['adresse'] as String? ?? '',
      agenceTel:            s['tel']     as String? ?? '',
      agenceEmail:          s['email']   as String?,
      agenceRc:             s['rc']      as String?,
      agenceCouleurHex:     s['couleur'] as String?,
      clientNom:            clientRaw['nom']       as String? ?? '',
      clientPrenom:         clientRaw['prenom']    as String? ?? '',
      clientTel:            clientRaw['telephone'] as String? ?? '',
      clientEmail:          clientRaw['email']     as String?,
      clientAdresse:        clientRaw['adresse']   as String?,
      clientCin:            clientRaw['num_cni']   as String?,
      vehiculeCedeMarque:   vehiculeRaw['marque']         as String? ?? '',
      vehiculeCedeModele:   vehiculeRaw['modele']         as String? ?? '',
      vehiculeCedeAnnee:    (vehiculeRaw['annee']         as num?)?.toInt(),
      vehiculeCedeCouleur:  vehiculeRaw['couleur']        as String?,
      vehiculeCedeImmat:    vehiculeRaw['immatriculation'] as String?,
      vehiculeCedeKm:       (vehiculeRaw['kilometrage']   as num?)?.toInt(),
      vehiculeReprisMarque: echangeData['vehicule_reprise_marque'] as String? ?? '',
      vehiculeReprisModele: echangeData['vehicule_reprise_modele'] as String? ?? '',
      vehiculeReprisAnnee:  (echangeData['vehicule_reprise_annee'] as num?)?.toInt(),
      vehiculeReprisImmat:  echangeData['vehicule_reprise_immat']  as String?,
      vehiculeReprisKm:     (echangeData['vehicule_reprise_km']    as num?)?.toInt(),
      valeurReprise:        (echangeData['valeur_reprise']         as num?)?.toDouble() ?? 0,
      complementClient:     (echangeData['complement_client']      as num?)?.toDouble() ?? 0,
      commissionGerantPct:  (echangeData['commission_gerant_pct']  as num?)?.toDouble(),
      commissionGerantMnt:  (echangeData['commission_gerant_mnt']  as num?)?.toDouble(),
      notes:                echangeData['notes'] as String?,
      articlesFr:           resolved.fr,
      articlesAr:           resolved.ar,
    );

    final pair  = await ContratEchangePdfGenerator.buildBothAsync(dto);
    final bytes = await pair.fr.save();
    final rawId = echangeData['id']?.toString() ?? 'echange';
    final id8   = rawId.length >= 8 ? rawId.substring(0, 8) : rawId;
    return await _saveBytes(bytes, 'contrat_echange_$id8.pdf');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PARTAGE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Ouvre la feuille de partage système pour un fichier PDF.
  static Future<void> partager(BuildContext context, File? pdfFile) async {
    if (pdfFile == null) {
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

  static Future<void> _shareFile(File? file) async {
    if (file == null) return;
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILDERS PRIVÉS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<int>> _buildAchatPdf({
    required Map<String, dynamic> achatData,
    required Map<String, dynamic> settings,
  }) async {
    final pdf = _AchatPdfBuilder.build(achatData: achatData, settings: settings);
    return await pdf.save();
  }

  // ── Téléchargement Web ───────────────────────────────────────────────────

  static void _downloadWeb(List<int> bytes, String filename) {
    if (!kIsWeb) return;
    downloadFileOnWeb(Uint8List.fromList(bytes), filename);
  }
}


// ═══════════════════════════════════════════════════════════════════════════
//  _AchatPdfBuilder — Bon d'achat / reprise véhicule
// ═══════════════════════════════════════════════════════════════════════════

class _AchatPdfBuilder {
  _AchatPdfBuilder._();

  static NumberFormat get _moneyFmt => NumberFormat('#,###', 'fr');

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

  static pw.Document build({
    required Map<String, dynamic> achatData,
    required Map<String, dynamic> settings,
  }) {
    final doc        = pw.Document();
    final color      = _hexColor(settings['couleur'] as String?);
    final light      = PdfColor(color.red, color.green, color.blue, 0.10);
    final agenceNom  = settings['nom']     as String? ?? 'Garage Auto';
    final agenceAdr  = settings['adresse'] as String? ?? '';
    final agenceTel  = settings['tel']     as String? ?? '';
    final agenceEmail = settings['email']  as String?;
    final agenceRc   = settings['rc']      as String?;

    final rawId   = achatData['id']?.toString() ?? '';
    final shortId = rawId.length >= 8
        ? rawId.substring(0, 8).toUpperCase()
        : rawId.toUpperCase();

    final dateAchat = achatData['date_achat'] != null
        ? DateTime.tryParse(achatData['date_achat'] as String) ?? DateTime.now()
        : DateTime.now();

    final prixAchat   = (achatData['prix_achat']  as num?)?.toDouble() ?? 0;
    final prixPropose = (achatData['prix_propose'] as num?)?.toDouble();
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
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
                if (agenceAdr.isNotEmpty)
                  pw.Text(agenceAdr,
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 8)),
                pw.Text(
                  [
                    if (agenceTel.isNotEmpty) 'Tél : $agenceTel',
                    if ((agenceEmail ?? '').isNotEmpty) agenceEmail!,
                  ].join('  |  '),
                  style:
                      const pw.TextStyle(color: PdfColors.white, fontSize: 8),
                ),
                if ((agenceRc ?? '').isNotEmpty)
                  pw.Text('RC : $agenceRc',
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 8)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text("BON D'ACHAT / REPRISE",
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 13,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('N° $shortId',
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    DateFormat('dd/MM/yyyy', 'fr').format(dateAchat),
                    style:
                        const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
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
            pw.Text(
                '$agenceNom${agenceTel.isNotEmpty ? '  |  Tél : $agenceTel' : ''}',
                style: const pw.TextStyle(
                    fontSize: 7, color: PdfColors.grey600)),
            pw.Text(
                'Page ${ctx.pageNumber}/${ctx.pagesCount}  -  '
                'Généré le ${DateFormat('dd/MM/yyyy', 'fr').format(DateTime.now())}',
                style: const pw.TextStyle(
                    fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
      ]),
      build: (_) => [
        _section('INFORMATIONS VENDEUR', color),
        pw.SizedBox(height: 4),
        _infoTable([
          ['Nom',       achatData['vendeur_nom']?.toString() ?? '-'],
          ['Téléphone', achatData['vendeur_tel']?.toString() ?? '-'],
          if ((achatData['vendeur_email']?.toString() ?? '').isNotEmpty)
            ['Email', achatData['vendeur_email'].toString()],
        ], color, light),
        pw.SizedBox(height: 10),

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
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey800)),
          ),
          pw.SizedBox(height: 10),
        ],

        pw.Row(children: [
          _sigBox('Signature du vendeur',
              achatData['vendeur_nom']?.toString() ?? '', color, light),
          pw.SizedBox(width: 10),
          _sigBox('Signature du showroom', agenceNom, color, light),
        ]),
      ],
    ));

    return doc;
  }

  static pw.Widget _section(String t, PdfColor color) => pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: pw.BoxDecoration(
            color: color, borderRadius: pw.BorderRadius.circular(3)),
        child: pw.Text(t,
            style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
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
          children: rows
              .map((r) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: pw.Row(children: [
                      pw.SizedBox(
                          width: 90,
                          child: pw.Text(r[0],
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey700))),
                      pw.Flexible(
                          child: pw.Text(r[1],
                              style:
                                  const pw.TextStyle(fontSize: 9))),
                    ]),
                  ))
              .toList(),
        ),
      );

  static pw.Widget _twoColRaw({
    required List<List<String>> left,
    required List<List<String>> right,
    required PdfColor color,
    required PdfColor light,
  }) {
    pw.Widget cell(String label, String value) => pw.Padding(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 80,
                child: pw.Text(label,
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700))),
            pw.Flexible(
                child: pw.Text(value.isEmpty ? '-' : value,
                    style: const pw.TextStyle(fontSize: 9))),
          ]),
        );

    pw.Widget col(List<List<String>> rows) => pw.Container(
          decoration: pw.BoxDecoration(
            border:
                pw.Border.all(color: PdfColors.grey300, width: 0.5),
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
        padding:
            const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        color: color,
        child: pw.Center(
            child: pw.Text(t,
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold))),
      );

  static pw.Widget _dCell(
    String t, {
    bool isLabel = false,
    PdfColor? color,
    PdfColor? light,
  }) =>
      pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        color: isLabel ? light : PdfColors.white,
        child: pw.Center(
            child: pw.Text(t,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight:
                        isLabel ? pw.FontWeight.bold : null,
                    color: isLabel ? color : PdfColors.black))),
      );

  static pw.Widget _sigBox(
          String label, String name, PdfColor color, PdfColor light) =>
      pw.Expanded(
          child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border:
              pw.Border.all(color: PdfColors.grey300, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
          color: light,
        ),
        child:
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
          pw.Text('Lu et approuvé - $name',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.Text('Date : _______________',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey500)),
        ]),
      ));
}