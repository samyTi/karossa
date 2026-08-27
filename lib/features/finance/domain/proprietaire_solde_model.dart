// lib/features/finance/domain/proprietaire_solde_model.dart

import 'versement_model.dart';
import 'transfert_model.dart';

/// Une ligne de gain (part issue d'une location, vente ou échange).
class LigneGain {
  final String id;
  final String typeOperation; // 'location' | 'vente' | 'echange'
  final String vehiculeLabel;
  final double pourcentage;
  final double montant;
  final DateTime date;

  const LigneGain({
    required this.id,
    required this.typeOperation,
    required this.vehiculeLabel,
    required this.pourcentage,
    required this.montant,
    required this.date,
  });
}

/// Une dépense (réparation, entretien, carburant, assurance...) impactant
/// le solde d'un propriétaire sur un véhicule qu'il détient.
///
/// Deux cas de figure (choisis à la saisie de la dépense) :
/// - [aRembourser] == false : le showroom a payé depuis sa caisse → la part
///   du propriétaire (au prorata de [partPct]) est déduite de ses gains.
/// - [aRembourser] == true : le propriétaire a payé de sa poche → le
///   showroom lui doit un remboursement intégral ([montant] == coût total).
class LigneDepense {
  final String id;
  final String categorie; // type_rep (reparation) ou categorie (caisse)
  final String vehiculeLabel;
  final double coutTotal;
  final double partPct;
  final double montant; // montant réellement imputé à ce propriétaire
  final DateTime date;
  final bool aRembourser;

  const LigneDepense({
    required this.id,
    required this.categorie,
    required this.vehiculeLabel,
    required this.coutTotal,
    required this.partPct,
    required this.montant,
    required this.date,
    required this.aRembourser,
  });
}

/// Un véhicule détenu (en tout ou partie) par le propriétaire.
class VehiculePart {
  final String vehiculeId;
  final String label; // "Marque Modele (Immat)"
  final double partPct;
  final String statut;

  const VehiculePart({
    required this.vehiculeId,
    required this.label,
    required this.partPct,
    required this.statut,
  });
}

/// Vue financière consolidée d'un propriétaire/associé.
class ProprietaireSolde {
  final String proprietaireId;
  final List<VehiculePart> vehicules;
  final List<LigneGain> gains;
  final List<Versement> versements;
  final List<LigneDepense> depenses;
  // Transferts d'argent avec d'autres utilisateurs (pas le showroom) :
  // n'affectent jamais [solde], qui reste strictement showroom ↔ personne.
  final List<TransfertUtilisateur> transfertsEnvoyes; // il a payé
  final List<TransfertUtilisateur> transfertsRecus; // il a reçu

  const ProprietaireSolde({
    required this.proprietaireId,
    required this.vehicules,
    required this.gains,
    required this.versements,
    this.depenses = const [],
    this.transfertsEnvoyes = const [],
    this.transfertsRecus = const [],
  });

  double get totalGainsLocations => gains
      .where((g) => g.typeOperation == 'location')
      .fold(0.0, (s, g) => s + g.montant);

  double get totalGainsVentes => gains
      .where((g) => g.typeOperation == 'vente')
      .fold(0.0, (s, g) => s + g.montant);

  double get totalGainsEchanges => gains
      .where((g) => g.typeOperation == 'echange')
      .fold(0.0, (s, g) => s + g.montant);

  double get totalGains => gains.fold(0.0, (s, g) => s + g.montant);

  double get totalVerse => versements.fold(0.0, (s, v) => s + v.montant);

  /// Dépenses payées par le showroom sur ses véhicules → déduites de ses gains.
  double get totalDepensesDeduites => depenses
      .where((d) => !d.aRembourser)
      .fold(0.0, (s, d) => s + d.montant);

  /// Dépenses avancées par le propriétaire lui-même → à lui rembourser.
  double get totalRemboursementsDus => depenses
      .where((d) => d.aRembourser)
      .fold(0.0, (s, d) => s + d.montant);

  /// Ce qu'il reste à verser au propriétaire (peut être négatif si trop-versé).
  double get solde =>
      totalGains - totalDepensesDeduites + totalRemboursementsDus - totalVerse;

  bool get aDejaTropPercu => solde < 0;

  // ── Transferts entre utilisateurs (indépendants du solde showroom) ────────

  /// Ce que d'autres utilisateurs lui doivent (transferts remboursables
  /// qu'il a payés, pas encore remboursés).
  double get totalOnLuiDoit => transfertsEnvoyes
      .where((t) => t.enAttenteRemboursement)
      .fold(0.0, (s, t) => s + t.montant);

  /// Ce qu'il doit à d'autres utilisateurs (transferts remboursables qu'il
  /// a reçus, pas encore remboursés).
  double get totalIlDoit => transfertsRecus
      .where((t) => t.enAttenteRemboursement)
      .fold(0.0, (s, t) => s + t.montant);

  bool get aDesTransferts =>
      transfertsEnvoyes.isNotEmpty || transfertsRecus.isNotEmpty;

  /// Montant total des transferts qu'il a payés et qui sont encore
  /// "actifs" pour le calcul du solde ajusté : un don définitif l'est pour
  /// toujours (jamais marqué remboursé), un transfert remboursable l'est
  /// tant qu'il n'a pas été marqué comme remboursé.
  double get totalTransfertsEnvoyesActifs => transfertsEnvoyes
      .where((t) => !t.rembourse)
      .fold(0.0, (s, t) => s + t.montant);

  /// Montant total des transferts qu'il a reçus et qui sont encore actifs
  /// (même logique que ci-dessus).
  double get totalTransfertsRecusActifs => transfertsRecus
      .where((t) => !t.rembourse)
      .fold(0.0, (s, t) => s + t.montant);

  /// Solde "réel" pour cette personne une fois les transferts entre
  /// utilisateurs pris en compte : TOUS les transferts (remboursables et
  /// définitifs) comptent tant qu'ils n'ont pas été marqués remboursés —
  /// un don définitif n'est donc jamais marqué remboursé et reste toujours
  /// actif ; un transfert remboursable, lui, cesse de compter une fois
  /// réglé.
  /// Ex: le showroom doit 10 000 DA à Mahrez ; Mahrez a transféré 500 DA à
  /// Samy → Mahrez a "avancé" ce paiement pour le compte du showroom, donc
  /// le showroom lui doit ces 500 DA en plus (10 500 DA), et Samy est
  /// considéré comme déjà payé d'autant, donc son solde en est diminué.
  double get soldeAjuste =>
      solde + totalTransfertsEnvoyesActifs - totalTransfertsRecusActifs;

  bool get soldeAjusteDiffere => soldeAjuste != solde;
}