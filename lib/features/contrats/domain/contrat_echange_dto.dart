// lib/features/contrats/domain/contrat_echange_dto.dart

import 'dart:typed_data';

class ContratEchangeDto {
  final String echangeId;
  final DateTime dateEtablissement;
  final DateTime dateEchange; // Ajouté pour correspondre à la bdd et au PDF

  // ── Agence / Showroom ─────────────────────────────────────
  final String agenceNom;
  final String agenceAdresse;
  final String agenceTel;
  final String agenceEmail;
  final String agenceRc;
  final String? agenceLogoUrl;
  final Uint8List? agenceLogoBytes; // ✅ image déjà téléchargée, prête pour pw.MemoryImage
  final String agenceCouleurHex; // Ajouté pour le thème dynamique du PDF

  // ── Client ────────────────────────────────────────────────
  final String clientNom;
  final String clientPrenom; // Séparé pour le PDF
  final String clientTelephone;
  final String? clientAdresse;
  final String? clientCin; // Ajouté (num_cni dans ta base de données)

  // ── Véhicule cédé (celui du garage) ───────────────────────
  final String vehiculeCedeInfos; // Ligne résumée ex: "Toyota Corolla 2020"
  final String vehiculeCedeMarque; // Ajouté pour le tableau du PDF
  final String vehiculeCedeModele; // Ajouté pour le tableau du PDF
  final int? vehiculeCedeAnnee; // Ajouté
  final String? vehiculeCedeImmat;
  final String? vehiculeCedeNumChassis;
  final int? vehiculeCedeKm;
  final String? vehiculeCedeCouleur;
  final String? vehiculeCedeCarburant;
  final String? vehiculeCedeBoite;
  final double? prixVehiculeCede;

  // ── Véhicule repris (celui du client) ─────────────────────
  final String vehiculeReprisInfos; // Ligne résumée
  final String vehiculeReprisMarque; // Ajouté pour le tableau du PDF
  final String vehiculeReprisModele; // Ajouté pour le tableau du PDF
  final int? vehiculeReprisAnnee; // Ajouté
  final String? vehiculeReprisImmat;
  final int? vehiculeReprisKm;
  final String? vehiculeReprisCouleur;
  final String? vehiculeReprisCarburant;
  final String? vehiculeReprisBoite;

  // ── Financier ─────────────────────────────────────────────
  final double valeurReprise;
  final double complementClient;
  final String? modePaiement;
  final double? commissionGerantPct;

  // ── Articles du contrat (bilingue) ────────────────────────
  final List<Map<String, String>> articlesFr;
  final List<Map<String, String>> articlesAr;

  // ── Notes ─────────────────────────────────────────────────
  final String? notes;

  const ContratEchangeDto({
    required this.echangeId,
    required this.dateEtablissement,
    required this.dateEchange,
    // Agence
    required this.agenceNom,
    this.agenceAdresse = '',
    this.agenceTel = '',
    this.agenceEmail = '',
    this.agenceRc = '',
    this.agenceLogoUrl,
    this.agenceLogoBytes,
    this.agenceCouleurHex = '#1A365D', // Bleu foncé par défaut
    // Client
    required this.clientNom,
    required this.clientPrenom,
    this.clientTelephone = '',
    this.clientAdresse,
    this.clientCin,
    // Véhicule cédé
    required this.vehiculeCedeInfos,
    required this.vehiculeCedeMarque,
    required this.vehiculeCedeModele,
    this.vehiculeCedeAnnee,
    this.vehiculeCedeImmat,
    this.vehiculeCedeNumChassis,
    this.vehiculeCedeKm,
    this.vehiculeCedeCouleur,
    this.vehiculeCedeCarburant,
    this.vehiculeCedeBoite,
    this.prixVehiculeCede,
    // Véhicule repris
    required this.vehiculeReprisInfos,
    required this.vehiculeReprisMarque,
    required this.vehiculeReprisModele,
    this.vehiculeReprisAnnee,
    this.vehiculeReprisImmat,
    this.vehiculeReprisKm,
    this.vehiculeReprisCouleur,
    this.vehiculeReprisCarburant,
    this.vehiculeReprisBoite,
    // Financier
    required this.valeurReprise,
    required this.complementClient,
    this.modePaiement,
    this.commissionGerantPct,
    // Articles
    this.articlesFr = const [],
    this.articlesAr = const [],
    // Notes
    this.notes,
  });

  double get montantTotal => valeurReprise + complementClient;
  bool get hasComplement => complementClient > 0;
  bool get hasArticlesFr => articlesFr.isNotEmpty;
  bool get hasArticlesAr => articlesAr.isNotEmpty;

  // Alias pratique pour le générateur PDF qui appelle .clientTel au lieu de .clientTelephone
  String get clientTel => clientTelephone;

  Map<String, String> toVariablesContext() => {
        'echange_id': echangeId,
        'date': _formatDate(dateEtablissement),
        'date_echange': _formatDate(dateEchange),
        'agence_nom': agenceNom,
        'agence_adresse': agenceAdresse,
        'agence_tel': agenceTel,
        'agence_email': agenceEmail,
        'agence_rc': agenceRc,
        'client_nom': clientNom,
        'client_prenom': clientPrenom,
        'client_telephone': clientTelephone,
        'client_adresse': clientAdresse ?? '',
        'client_cin': clientCin ?? '',
        'vehicule_cede': vehiculeCedeInfos,
        'vehicule_cede_marque': vehiculeCedeMarque,
        'vehicule_cede_modele': vehiculeCedeModele,
        'vehicule_cede_immat': vehiculeCedeImmat ?? '',
        'vehicule_cede_chassis': vehiculeCedeNumChassis ?? '',
        'vehicule_cede_km': vehiculeCedeKm?.toString() ?? '',
        'vehicule_cede_couleur': vehiculeCedeCouleur ?? '',
        'prix_vehicule_cede': _formatMontant(prixVehiculeCede ?? 0),
        'vehicule_repris': vehiculeReprisInfos,
        'vehicule_repris_marque': vehiculeReprisMarque,
        'vehicule_repris_modele': vehiculeReprisModele,
        'vehicule_repris_immat': vehiculeReprisImmat ?? '',
        'vehicule_repris_km': vehiculeReprisKm?.toString() ?? '',
        'vehicule_repris_couleur': vehiculeReprisCouleur ?? '',
        'valeur_reprise': _formatMontant(valeurReprise),
        'complement_client': _formatMontant(complementClient),
        'montant_total': _formatMontant(montantTotal),
        'mode_paiement': modePaiement ?? '',
        'notes': notes ?? '',
      };

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _formatMontant(double m) =>
      '${m.toStringAsFixed(2).replaceAll('.', ',')} DA';
}