// lib/core/services/pdf/contrat_orchestrator.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/ventes/domain/vente_model.dart';
import '../../../features/clients/domain/client_model.dart';
import '../../../features/vehicules/domain/vehicule_model.dart';
import '../../../features/ventes/domain/vente_dto_mapper.dart';
import '../../../features/contrats/data/contract_articles_repository.dart';

import 'contrat_location_pdf_generator.dart';
import 'contrat_location_classique_pdf_generator.dart';
import '../../../features/contrats/domain/contrat_location_dto.dart' show ContratLocationTemplate;
import 'contrat_vente_pdf_generator.dart';
import 'contrat_echange_pdf_generator.dart';
import 'facture_location_pdf_generator.dart';
import 'pdf_storage_service.dart';

import '../../../features/contrats/presentation/pdf_builders/achat_pdf_builder.dart';
import '../../../features/vehicules/domain/etat_carrosserie_model.dart';

class ContratOrchestrator {
  ContratOrchestrator(
    this._settingsProvider, {
    required SupabaseClient supabase,
    required String showroomId,
  })  : _supabase = supabase,
        _showroomId = showroomId;

  final Future<Map<String, dynamic>> Function() _settingsProvider;
  final SupabaseClient _supabase;
  final String _showroomId;

  // ── Helper privé : charge les articles depuis Supabase ───────────────────

  Future<({List<Map<String, String>> fr, List<Map<String, String>> ar})>
      _loadArticles(
    String contratType, {
    Map<String, dynamic> contextData = const {},
  }) async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📋 [Orchestrator] Chargement articles PDF');
    debugPrint('   type        : $contratType');
    debugPrint('   showroom_id : $_showroomId');

    if (_showroomId.isEmpty) {
      debugPrint('❌ [Orchestrator] showroomId vide — articles ignorés');
      return (fr: <Map<String, String>>[], ar: <Map<String, String>>[]);
    }

    try {
      final repo = ContractArticlesRepository(
        _supabase,
        showroomId: _showroomId,
      );

      final resolved = await repo.getArticlesResolusParLangue(
        contratType: contratType,
        contextData: contextData,
      );

      debugPrint('🎉 [Orchestrator] Articles chargés avec succès');
      debugPrint('   FR : ${resolved.fr.length} article(s)');
      debugPrint('   AR : ${resolved.ar.length} article(s)');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return (fr: resolved.fr, ar: resolved.ar);
    } catch (e, st) {
      debugPrint('❌ [Orchestrator] Erreur chargement articles ($contratType): $e');
      debugPrint(st.toString());
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return (fr: <Map<String, String>>[], ar: <Map<String, String>>[]);
    }
  }

  // ── Helper privé : télécharge le logo du showroom (settings['logo_url']) ─
  //
  // ⚠️ Ne doit jamais faire échouer la génération du contrat : si le
  // téléchargement échoue (URL vide, réseau, 404…), on continue simplement
  // sans logo plutôt que de bloquer tout le PDF.

  Future<Uint8List?> _loadLogoBytes(Map<String, dynamic> settings) async {
    final url = (settings['logo_url'] as String?)?.trim();
    if (url == null || url.isEmpty) return null;
    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        return resp.bodyBytes;
      }
      debugPrint('⚠️ [Orchestrator] Logo non téléchargé (HTTP ${resp.statusCode}) → $url');
      return null;
    } catch (e) {
      debugPrint('⚠️ [Orchestrator] Échec téléchargement logo: $e');
      return null;
    }
  }

  // ── 1. Contrat de Vente (objets typés) ───────────────────────────────────

  Future<void> generateAndShareVente({
    required Vente vente,
    required Client client,
    required Vehicule vehicule,
  }) async {
    debugPrint('📄 [Orchestrator] generateAndShareVente → id=${vente.id}');
    try {
      final settings = await _settingsProvider();
      final logoBytes = await _loadLogoBytes(settings);
      final articles = await _loadArticles(
        'vente',
        contextData: {'id': vente.id},
      );
      final dto = vente.toContratDto(
        client: client,
        vehicule: vehicule,
        settings: settings,
        articlesFr: articles.fr,
        articlesAr: articles.ar,
        logoBytes: logoBytes,
      );
      final bytes = await ContratVentePdfGenerator.buildBytes(dto);
      await PdfStorageService.saveAndShare(
        bytes: bytes,
        filename: 'contrat_vente_${_short(vente.id)}.pdf',
        subject: 'Contrat de vente — ${settings['nom'] ?? ''}',
      );
      debugPrint('✅ [Orchestrator] generateAndShareVente terminé');
    } catch (e, st) {
      debugPrint('❌ [Orchestrator] generateAndShareVente: $e\n$st');
      rethrow;
    }
  }

  // ── 1b. Contrat de Vente (Map brute) ─────────────────────────────────────

  Future<void> generateAndShareVenteFromMap({
    required Map<String, dynamic> venteMap,
  }) async {
    debugPrint('📄 [Orchestrator] generateAndShareVenteFromMap → id=${venteMap['id']}');
    try {
      final settings  = await _settingsProvider();
      final logoBytes = await _loadLogoBytes(settings);
      final articles  = await _loadArticles(
        'vente',
        contextData: venteMap,
      );
      final clientMap = venteMap['clients']   as Map<String, dynamic>? ?? {};
      final vehicMap  = venteMap['vehicules'] as Map<String, dynamic>? ?? {};

      final vente = Vente.fromJson(venteMap);
      final client = Client.fromJson({
        'id':         venteMap['client_id'] ?? '',
        'nom':        clientMap['nom']       ?? '',
        'prenom':     clientMap['prenom']    ?? '',
        'telephone':  clientMap['telephone'] ?? '',
        'email':      clientMap['email'],
        'adresse':    clientMap['adresse'],
        'num_permis': clientMap['num_permis'],
        'num_cni':    clientMap['num_cni'],
        'statut':     clientMap['statut']    ?? 'normal',
        'created_at': venteMap['created_at'] ?? DateTime.now().toIso8601String(),
      });
      final vehicule = Vehicule.fromJson({
        'id':              venteMap['vehicule_id'] ?? '',
        'marque':          vehicMap['marque']       ?? '',
        'modele':          vehicMap['modele']       ?? '',
        'annee':           vehicMap['annee']        ?? 0,
        'couleur':         vehicMap['couleur'],
        'immatriculation': vehicMap['immatriculation'],
        'carburant':       vehicMap['carburant'],
        'boite':           vehicMap['boite'],
        'kilometrage':     vehicMap['kilometrage']  ?? 0,
        'num_chassis':     vehicMap['num_chassis'],
        'etat_vehicule':   vehicMap['etat_vehicule'],
        'statut':          'vendu',
        'created_at':      venteMap['created_at'] ?? DateTime.now().toIso8601String(),
      });

      final dto = vente.toContratDto(
        client: client,
        vehicule: vehicule,
        settings: settings,
        articlesFr: articles.fr,
        articlesAr: articles.ar,
        logoBytes: logoBytes,
      );
      final bytes = await ContratVentePdfGenerator.buildBytes(dto);
      await PdfStorageService.saveAndShare(
        bytes: bytes,
        filename: 'contrat_vente_${_short(vente.id)}.pdf',
        subject: 'Contrat de vente — ${settings['nom'] ?? ''}',
      );
      debugPrint('✅ [Orchestrator] generateAndShareVenteFromMap terminé');
    } catch (e, st) {
      debugPrint('❌ [Orchestrator] generateAndShareVenteFromMap: $e\n$st');
      rethrow;
    }
  }

  // ── 2. Bon d'Achat ────────────────────────────────────────────────────────

  Future<void> generateAndShareAchat({
    required Map<String, dynamic> achatData,
  }) async {
    debugPrint('📄 [Orchestrator] generateAndShareAchat → id=${achatData['id']}');
    try {
      final settings = await _settingsProvider();
      final doc = AchatPdfBuilder.build(
        achatData: achatData,
        settings: settings,
      );
      final bytes = await doc.save();
      await PdfStorageService.saveAndShare(
        bytes: bytes,
        filename: 'bon_achat_${_short(achatData['id']?.toString() ?? 'x')}.pdf',
        subject: "Bon d'achat — ${settings['nom'] ?? ''}",
      );
      debugPrint('✅ [Orchestrator] generateAndShareAchat terminé');
    } catch (e, st) {
      debugPrint('❌ [Orchestrator] generateAndShareAchat: $e\n$st');
      rethrow;
    }
  }

  // ── 3. Contrat de Location ────────────────────────────────────────────────

  Future<void> generateAndShareLocation({
    required Map<String, dynamic> locationData,
    ContratLocationTemplate template = ContratLocationTemplate.standard,
  }) async {
    debugPrint('📄 [Orchestrator] generateAndShareLocation → id=${locationData['id']} template=$template');
    try {
      final settings = await _settingsProvider();
      final logoBytes = await _loadLogoBytes(settings);

      // ⚠️ FIX : 'location_classique' n'est géré par aucun écran d'admin
      // (contract_articles_admin_screen.dart ne propose que les onglets
      // location / vente / echange) — aucune clause n'est donc jamais
      // enregistrée sous ce type en BDD, et la requête retournait
      // systématiquement une liste vide pour le modèle classique, quelle
      // que soit la langue. Résultat : le PDF classique retombait toujours
      // sur les clauses par défaut codées en dur (_defaultArticlesFr/Ar),
      // jamais sur celles configurées par le showroom. On utilise donc le
      // même type 'location' que le modèle standard, qui est le seul
      // réellement configurable depuis l'admin.
      final articleType = 'location';

      final articles = await _loadArticles(
        articleType,
        contextData: locationData,
      );

      debugPrint('📎 [Orchestrator] Articles injectés dans le PDF → FR: ${articles.fr.length}, AR: ${articles.ar.length}');

      final dto  = _buildLocationDto(locationData, settings, logoBytes: logoBytes);

      final pair = template == ContratLocationTemplate.classique
          ? await ContratLocationClassiquePdfGenerator.buildBothAsync(
              dto,
              articlesFr: articles.fr,
              articlesAr: articles.ar,
            )
          : await ContratLocationPdfGenerator.buildBothAsync(
              dto,
              articlesFr: articles.fr,
              articlesAr: articles.ar,
            );

      final bytesFr = await pair.fr.save();
      final bytesAr = await pair.ar.save();
      final id8     = _short(locationData['id']?.toString() ?? 'x');
      final suffix  = template == ContratLocationTemplate.classique ? '_classique' : '';

      await PdfStorageService.saveAndShareMultiple(
        bytesList: [bytesFr, bytesAr],
        filenames: [
          'contrat_location${suffix}_${id8}_FR.pdf',
          'contrat_location${suffix}_${id8}_AR.pdf',
        ],
        subject: 'Contrat de location — ${settings['nom'] ?? ''}',
      );
      debugPrint('✅ [Orchestrator] generateAndShareLocation terminé');
    } catch (e, st) {
      debugPrint('❌ [Orchestrator] generateAndShareLocation: $e\n$st');
      rethrow;
    }
  }

  // ── 4. Contrat d'Échange ──────────────────────────────────────────────────

  Future<void> generateAndShareEchange({
    required Map<String, dynamic> echangeData,
  }) async {
    debugPrint('📄 [Orchestrator] generateAndShareEchange → id=${echangeData['id']}');
    try {
      final settings = await _settingsProvider();
      final logoBytes = await _loadLogoBytes(settings);

      final articles = await _loadArticles(
        'echange',
        contextData: echangeData,
      );

      debugPrint('📎 [Orchestrator] Articles injectés dans le PDF → FR: ${articles.fr.length}, AR: ${articles.ar.length}');

      final dto  = _buildEchangeDto(
        echangeData,
        settings,
        articlesFr: articles.fr,
        articlesAr: articles.ar,
        logoBytes: logoBytes,
      );
      final pair = await ContratEchangePdfGenerator.buildBothAsync(dto);

      final bytesFr = await pair.fr.save();
      final bytesAr = await pair.ar.save();
      final id8     = _short(echangeData['id']?.toString() ?? 'x');

      await PdfStorageService.saveAndShareMultiple(
        bytesList: [bytesFr, bytesAr],
        filenames: [
          'contrat_echange_${id8}_FR.pdf',
          'contrat_echange_${id8}_AR.pdf',
        ],
        subject: "Contrat d'échange — ${settings['nom'] ?? ''}",
      );
      debugPrint('✅ [Orchestrator] generateAndShareEchange terminé');
    } catch (e, st) {
      debugPrint('❌ [Orchestrator] generateAndShareEchange: $e\n$st');
      rethrow;
    }
  }

  // ── 5. Facture de Location (document client) ─────────────────────────────
  //
  // ⚠️ Volontairement séparée du contrat de location : c'est un document
  // comptable simple (désignation / montant / paiements / solde) destiné
  // au client. Il NE contient JAMAIS la répartition interne gérant /
  // propriétaire(s) — cette donnée reste interne au showroom (cf. l'écran
  // "Résumé" qui, lui, l'affiche).
  //
  // ⚠️ Contrairement aux autres méthodes ci-dessus, les erreurs ne sont PAS
  // avalées silencieusement : ici la génération est l'action principale
  // demandée par l'utilisateur (pas un effet de bord après un autre
  // enregistrement réussi), donc l'UI doit pouvoir afficher l'erreur.

  Future<void> generateAndShareFactureLocation({
    required Map<String, dynamic> locationData,
    List<Map<String, dynamic>> paiements = const [],
  }) async {
    debugPrint('📄 [Orchestrator] generateAndShareFactureLocation → id=${locationData['id']}');
    final settings = await _settingsProvider();
    final dto = _buildFactureLocationDto(locationData, settings, paiements);
    final doc = await FactureLocationPdfGenerator.build(dto);
    final bytes = await doc.save();
    final id8 = _short(locationData['id']?.toString() ?? 'x');

    await PdfStorageService.saveAndShare(
      bytes: bytes,
      filename: 'facture_location_$id8.pdf',
      subject: 'Facture location — ${settings['nom'] ?? ''}',
    );
    debugPrint('✅ [Orchestrator] generateAndShareFactureLocation terminé');
  }

  // ── Helpers privés ────────────────────────────────────────────────────────

  static String _short(String id) =>
      id.length >= 8 ? id.substring(0, 8) : id;

  static String _s(dynamic v) => v?.toString() ?? '';

  static ContratLocationDto _buildLocationDto(
    Map<String, dynamic> d,
    Map<String, dynamic> settings, {
    Uint8List? logoBytes,
  }) {
    final client   = d['clients']   as Map<String, dynamic>? ?? {};
    final vehicule = d['vehicules'] as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    return ContratLocationDto(
      contratId:               _s(d['id']),
      dateEtablissement:       DateTime.now(),
      agenceNom:               _s(settings['nom']),
      agenceAdresse:           _s(settings['adresse']),
      agenceTel:               _s(settings['tel']),
      agenceEmail:             settings['email']   as String?,
      agenceVille:             settings['ville']   as String?,
      agenceRc:                settings['rc']      as String?,
      agenceCouleurHex:        settings['couleur'] as String?,
      agenceLogoBytes:         logoBytes,
      locataireNom:            _s(client['nom']),
      locatairePrenom:         _s(client['prenom']),
      locataireTel:            _s(client['telephone']),
      locataireEmail:          client['email']      as String?,
      locataireAdresse:        client['adresse']    as String?,
      locataireNumPermis:      client['num_permis'] as String?,
      locatairePermisDate:     client['permis_date'] as String?,
      locataireCin:            client['num_cni']    as String?,
      locataireDateNaissance:  client['date_naissance'] as String?,
      conducteur2Nom:            d['conducteur2_nom']         as String?,
      conducteur2Prenom:         d['conducteur2_prenom']      as String?,
      conducteur2Tel:            d['conducteur2_tel']         as String?,
      conducteur2NumPermis:      d['conducteur2_num_permis']  as String?,
      conducteur2PermisDate:     d['conducteur2_permis_date'] as String?,
      conducteur2DateNaissance:  d['conducteur2_date_naissance'] as String?,
      vehiculeMarque:          _s(vehicule['marque']),
      vehiculeModele:          _s(vehicule['modele']),
      vehiculeCouleur:         vehicule['couleur']           as String?,
      vehiculeImmatriculation: vehicule['immatriculation']   as String?,
      vehiculeCarburant:       vehicule['carburant']         as String?,
      vehiculeBoite:           vehicule['boite']             as String?,
      vehiculeAssurance:       vehicule['assurance']         as String?,
      vehiculeCodeRadio:       vehicule['code_radio']        as String?,
      dateDepart:              parseDate(d['date_debut']),
      dateRetour:              parseDate(d['date_fin_prevue']),
      heureDepart:             d['heure_depart'] as String?,
      heureRetour:             d['heure_retour'] as String?,
      kmDepart:                (d['km_depart']  as num?)?.toInt() ?? 0,
      kmRetour:                (d['km_retour']  as num?)?.toInt(),
      prixJour:                (d['prix_jour']  as num?)?.toDouble() ?? 0,
      caution:                 (d['caution']    as num?)?.toDouble() ?? 0,
      observations:            d['notes_depart'] as String?,
      etatVehicule:            vehicule['etat_vehicule'] as String?,
      etatCarrosserie:         _parseEtatCarrosserie(d['etat_carrosserie_depart']),
      blueprintBytes:          d['blueprint_bytes'] as Uint8List?,
      agenceArtNo:             settings['art_no'] as String?,
      agentNom:                d['agent_nom'] as String? ?? settings['agent_nom'] as String?,
      agentTel:                d['agent_tel'] as String? ?? settings['agent_tel'] as String?,
      lieuDepart:              d['lieu_depart'] as String?,
      lieuRetour:              d['lieu_retour'] as String? ?? d['lieu_depart'] as String?,
      modePaiement:            d['mode_paiement'] as String?,
      optionsLocation:         (d['options'] as List?)?.whereType<String>().toList(),
      carburantNiveauDepart:   (d['carburant_niveau_depart'] as num?)?.toDouble(),
      remarquesDepart:         d['remarques_depart'] as String? ?? d['notes_depart'] as String?,
    );
  }

  /// Tente de parser l'état carrosserie depuis :
  ///   - un EtatCarrosserie déjà désérialisé (passé directement depuis le form)
  ///   - une String JSON (depuis la map locationData du form)
  ///   - une Map<String, dynamic> (jsonb Supabase déjà décodé)
  static EtatCarrosserie? _parseEtatCarrosserie(dynamic raw) {
    debugPrint('🔍 [Orchestrator] _parseEtatCarrosserie → type: ${raw?.runtimeType}, value: ${raw?.toString().substring(0, raw.toString().length.clamp(0, 120))}');
    if (raw == null) {
      debugPrint('⚠️ [Orchestrator] etat_carrosserie_depart est null');
      return null;
    }
    try {
      if (raw is EtatCarrosserie) {
        debugPrint('✅ [Orchestrator] EtatCarrosserie déjà typé — pins: ${raw.pins.length}');
        return raw;
      }
      if (raw is String && raw.isNotEmpty) {
        final result = EtatCarrosserie.fromJsonString(raw);
        debugPrint('✅ [Orchestrator] Parsé depuis String — pins: ${result.pins.length}');
        return result;
      }
      if (raw is Map<String, dynamic>) {
        final result = EtatCarrosserie.fromJsonString(jsonEncode(raw));
        debugPrint('✅ [Orchestrator] Parsé depuis Map — pins: ${result.pins.length}');
        return result;
      }
      debugPrint('⚠️ [Orchestrator] Type non reconnu: ${raw.runtimeType}');
    } catch (e) {
      debugPrint('❌ [Orchestrator] _parseEtatCarrosserie error: $e');
    }
    return null;
  }

  static ContratEchangeDto _buildEchangeDto(
    Map<String, dynamic> d,
    Map<String, dynamic> settings, {
    List<Map<String, String>>? articlesFr,
    List<Map<String, String>>? articlesAr,
    Uint8List? logoBytes,
  }) {
    final client   = d['clients']   as Map<String, dynamic>? ?? {};
    final vehicule = d['vehicules'] as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    final marqueRepris = _s(d['vehicule_reprise_marque']);
    final modeleRepris = _s(d['vehicule_reprise_modele']);
    final marqueCede   = _s(vehicule['marque']);
    final modeleCede   = _s(vehicule['modele']);
    final anneeCede    = vehicule['annee'] as int?;

    final cedeInfos = [marqueCede, modeleCede, anneeCede?.toString()]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' ');

    final reprisInfos = [
      marqueRepris,
      modeleRepris,
      (d['vehicule_reprise_annee'] as int?)?.toString(),
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ');

    return ContratEchangeDto(
      echangeId:             _s(d['id']),
      dateEtablissement:     DateTime.now(),
      dateEchange:           parseDate(d['date_echange'] ?? d['created_at']),
      agenceNom:             _s(settings['nom']),
      agenceAdresse:         _s(settings['adresse']),
      agenceTel:             _s(settings['tel']),
      agenceEmail:           _s(settings['email']),
      agenceRc:              _s(settings['rc']),
      agenceCouleurHex:      settings['couleur'] as String? ?? '#1A365D',
      agenceLogoBytes:       logoBytes,
      clientNom:             _s(client['nom']),
      clientPrenom:          _s(client['prenom']),
      clientTelephone:       _s(client['telephone']),
      clientAdresse:         client['adresse'] as String?,
      clientCin:             client['num_cni'] as String?,
      vehiculeCedeInfos:     cedeInfos,
      vehiculeCedeMarque:    marqueCede,
      vehiculeCedeModele:    modeleCede,
      vehiculeCedeAnnee:     anneeCede,
      vehiculeCedeImmat:     vehicule['immatriculation'] as String?,
      vehiculeCedeKm:        (d['vehicule_km']    as num?)?.toInt(),
      vehiculeCedeCouleur:   vehicule['couleur']  as String?,
      vehiculeCedeCarburant: vehicule['carburant'] as String?,
      vehiculeCedeBoite:     vehicule['boite']    as String?,
      vehiculeReprisInfos:   reprisInfos,
      vehiculeReprisMarque:  marqueRepris,
      vehiculeReprisModele:  modeleRepris,
      vehiculeReprisAnnee:   d['vehicule_reprise_annee'] as int?,
      vehiculeReprisImmat:   d['vehicule_reprise_immat'] as String?,
      vehiculeReprisKm:      (d['vehicule_reprise_km']  as num?)?.toInt(),
      valeurReprise:         (d['valeur_reprise']    as num?)?.toDouble() ?? 0,
      complementClient:      (d['complement_client'] as num?)?.toDouble() ?? 0,
      modePaiement:          d['mode_paiement'] as String?,
      articlesFr:            articlesFr ?? const [],
      articlesAr:            articlesAr ?? const [],
      notes:                 d['notes'] as String?,
    );
  }

  /// Construit le DTO de la facture client à partir de la map brute de la
  /// location (mêmes clés que celles utilisées pour le contrat) + des
  /// paiements associés.
  static FactureLocationDto _buildFactureLocationDto(
    Map<String, dynamic> d,
    Map<String, dynamic> settings,
    List<Map<String, dynamic>> paiements,
  ) {
    final client   = d['clients']   as Map<String, dynamic>? ?? {};
    final vehicule = d['vehicules'] as Map<String, dynamic>? ?? {};

    DateTime? parseDateNullable(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    DateTime parseDate(dynamic v) => parseDateNullable(v) ?? DateTime.now();

    final nbJours      = (d['nb_jours']     as num?)?.toInt() ?? 1;
    final prixJour     = (d['prix_jour']    as num?)?.toDouble() ?? 0;
    final montantBrut  = (d['montant_brut'] as num?)?.toDouble();
    final montantTotal = montantBrut ?? (prixJour * nbJours);

    final nomComplet = [client['prenom'], client['nom']]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' ');

    final vehiculeDesignation = [vehicule['marque'], vehicule['modele']]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' ');

    return FactureLocationDto(
      locationId:              _s(d['id']),
      dateEmission:            DateTime.now(),
      agenceNom:               _s(settings['nom']),
      agenceAdresse:           _s(settings['adresse']),
      agenceTel:               _s(settings['tel']),
      agenceEmail:             settings['email'] as String?,
      agenceRc:                settings['rc'] as String?,
      agenceCouleurHex:        settings['couleur'] as String? ?? '#2563EB',
      clientNomComplet:        nomComplet.isEmpty ? '—' : nomComplet,
      clientTel:               _s(client['telephone']),
      clientAdresse:           client['adresse'] as String?,
      vehiculeDesignation:     vehiculeDesignation.isEmpty ? '—' : vehiculeDesignation,
      vehiculeImmatriculation: vehicule['immatriculation'] as String?,
      vehiculeCouleur:         vehicule['couleur'] as String?,
      dateDebut:               parseDate(d['date_debut']),
      dateFinPrevue:           parseDateNullable(d['date_fin_prevue']),
      dateFinReelle:           parseDateNullable(d['date_fin_reelle']),
      nbJours:                 nbJours,
      prixJour:                prixJour,
      montantTotal:            montantTotal,
      caution:                 (d['caution']         as num?)?.toDouble() ?? 0,
      retenueCaution:          (d['retenue_caution']  as num?)?.toDouble() ?? 0,
      estTerminee:             d['statut'] == 'termine',
      paiements: paiements.map((p) => FacturePaiementLigne(
            date:    parseDate(p['date_paiement']),
            mode:    p['mode'] as String?,
            montant: (p['montant'] as num?)?.toDouble() ?? 0,
          )).toList(),
    );
  }
}