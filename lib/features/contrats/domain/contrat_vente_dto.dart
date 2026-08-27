// lib/features/contrats/domain/contrat_vente_dto.dart

import 'dart:typed_data';

class ContratVenteDto {
  final String venteId;
  final DateTime dateEtablissement;

  // ── Agence (Showroom) ──────────────────────────────────────
  final String  agenceNom;
  final String  agenceAdresse;
  final String  agenceTel;
  final String? agenceEmail;
  final String? agenceVille;
  final String? agenceRc;
  final String? agenceCouleurHex;
  final String? agenceLogoUrl;    // ✅ ajout — nécessaire pour l'en-tête PDF
  final Uint8List? agenceLogoBytes; // ✅ image déjà téléchargée, prête pour pw.MemoryImage

  // ── Acheteur ───────────────────────────────────────────────
  final String  acheteurNom;
  final String  acheteurPrenom;
  final String  acheteurTel;
  final String? acheteurEmail;
  final String? acheteurAdresse;
  final String? acheteurCin;
  final String? acheteurNumPermis;

  // ── Véhicule ───────────────────────────────────────────────
  final String  vehiculeMarque;
  final String  vehiculeModele;
  final int?    vehiculeAnnee;
  final String? vehiculeCouleur;
  final String? vehiculeImmatriculation;
  final String? vehiculeCarburant;
  final String? vehiculeBoite;
  final int?    vehiculeKilometrage;
  final String? vehiculeNumChassis;
  final String? vehiculeEtat;     // ✅ ajout — état carrosserie au moment de la vente

  // ── Financier ──────────────────────────────────────────────
  final double  prixVente;
  final double  acompteVerse;
  final double  soldeRestant;
  final String  modePaiement;
  final String  statutPaiement;
  final String? notes;

  // ── Articles du contrat (bilingue) ────────────────────────
  final List<Map<String, String>> articlesFr; // ✅ ajout — cohérence avec ContratEchangeDto
  final List<Map<String, String>> articlesAr;

  const ContratVenteDto({
    required this.venteId,
    required this.dateEtablissement,
    // Agence
    required this.agenceNom,
    required this.agenceAdresse,
    required this.agenceTel,
    this.agenceEmail,
    this.agenceVille,
    this.agenceRc,
    this.agenceCouleurHex,
    this.agenceLogoUrl,
    this.agenceLogoBytes,
    // Acheteur
    required this.acheteurNom,
    required this.acheteurPrenom,
    required this.acheteurTel,
    this.acheteurEmail,
    this.acheteurAdresse,
    this.acheteurCin,
    this.acheteurNumPermis,
    // Véhicule
    required this.vehiculeMarque,
    required this.vehiculeModele,
    this.vehiculeAnnee,
    this.vehiculeCouleur,
    this.vehiculeImmatriculation,
    this.vehiculeCarburant,
    this.vehiculeBoite,
    this.vehiculeKilometrage,
    this.vehiculeNumChassis,
    this.vehiculeEtat,
    // Financier
    required this.prixVente,
    required this.acompteVerse,
    required this.soldeRestant,
    required this.modePaiement,
    required this.statutPaiement,
    this.notes,
    // Articles
    this.articlesFr = const [],
    this.articlesAr = const [],
  });

  // ── Getters utilitaires ────────────────────────────────────

  /// Nom complet de l'acheteur.
  String get acheteurNomComplet => '$acheteurPrenom $acheteurNom'.trim();

  /// Ligne résumée du véhicule.
  String get vehiculeInfos {
    final annee = vehiculeAnnee != null ? ' $vehiculeAnnee' : '';
    return '$vehiculeMarque $vehiculeModele$annee';
  }

  /// Vrai si la vente est entièrement soldée.
  bool get estSolde => soldeRestant <= 0;

  /// Vrai si un acompte a été versé.
  bool get hasAcompte => acompteVerse > 0;

  bool get hasArticlesFr => articlesFr.isNotEmpty;
  bool get hasArticlesAr => articlesAr.isNotEmpty;

  // ── Contexte de résolution des {{variables}} ───────────────

  /// Construit le contexte pour la résolution des {{variables}}
  /// dans les articles dynamiques et les templates PDF.
  Map<String, String> toVariablesContext() => {
    'vente_id':               venteId,
    'date':                   _formatDate(dateEtablissement),
    // Agence
    'agence_nom':             agenceNom,
    'agence_adresse':         agenceAdresse,
    'agence_tel':             agenceTel,
    'agence_email':           agenceEmail       ?? '',
    'agence_ville':           agenceVille       ?? '',
    'agence_rc':              agenceRc          ?? '',
    'agence_logo':            agenceLogoUrl     ?? '',
    // Acheteur
    'acheteur_nom':           acheteurNom,
    'acheteur_prenom':        acheteurPrenom,
    'acheteur_nom_complet':   acheteurNomComplet,
    'acheteur_tel':           acheteurTel,
    'acheteur_email':         acheteurEmail     ?? '',
    'acheteur_adresse':       acheteurAdresse   ?? '',
    'acheteur_cin':           acheteurCin       ?? '',
    'acheteur_num_permis':    acheteurNumPermis ?? '',
    // Véhicule
    'vehicule_marque':        vehiculeMarque,
    'vehicule_modele':        vehiculeModele,
    'vehicule_annee':         vehiculeAnnee?.toString()       ?? '',
    'vehicule_infos':         vehiculeInfos,
    'vehicule_couleur':       vehiculeCouleur                 ?? '',
    'vehicule_immat':         vehiculeImmatriculation         ?? '',
    'vehicule_carburant':     vehiculeCarburant               ?? '',
    'vehicule_boite':         vehiculeBoite                   ?? '',
    'vehicule_km':            vehiculeKilometrage?.toString() ?? '',
    'vehicule_chassis':       vehiculeNumChassis              ?? '',
    'vehicule_etat':          vehiculeEtat                    ?? '',
    // Financier
    'prix_vente':             _formatMontant(prixVente),
    'acompte_verse':          _formatMontant(acompteVerse),
    'solde_restant':          _formatMontant(soldeRestant),
    'mode_paiement':          modePaiement,
    'statut_paiement':        statutPaiement,
    'notes':                  notes ?? '',
  };

  // ── Helpers privés ─────────────────────────────────────────

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  static String _formatMontant(double m) =>
      '${m.toStringAsFixed(2).replaceAll('.', ',')} DA';

  // ── Égalité & debug ────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContratVenteDto &&
          runtimeType == other.runtimeType &&
          venteId == other.venteId;

  @override
  int get hashCode => venteId.hashCode;

  @override
  String toString() =>
      'ContratVenteDto($venteId, $acheteurNomComplet, '
      '$vehiculeInfos, prix: $prixVente)';
}