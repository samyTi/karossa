/// Qui a réellement payé la dépense.
/// - [showroom] : payée depuis la caisse du showroom → déduite du solde du
///   ou des propriétaires du véhicule, au prorata de leur part_pct.
/// - [proprietaire] : avancée de la poche d'un propriétaire → le showroom
///   lui doit un remboursement intégral (voir [proprietairePayeurId]).
enum PayeePar {
  showroom('showroom'),
  proprietaire('proprietaire');

  const PayeePar(this.value);
  final String value;

  static PayeePar fromValue(String? v) =>
      v == 'proprietaire' ? PayeePar.proprietaire : PayeePar.showroom;
}

/// Une ligne de paiement : qui a payé quelle part de la réparation.
/// - [payeePar] == showroom : cette part sort de la caisse du showroom
///   (déduite ensuite au prorata des parts des propriétaires).
/// - [payeePar] == proprietaire : cette part a été avancée par
///   [proprietaireId], à lui rembourser intégralement.
class ReparationPaiement {
  final String? id;
  final PayeePar payeePar;
  final String? proprietaireId;
  final String? proprietaireNom;
  final double montant;
  // Qui doit réellement supporter ce coût. null = prorata des
  // copropriétaires du véhicule (comportement par défaut).
  final String? debiteurId;
  final String? debiteurNom;

  const ReparationPaiement({
    this.id,
    required this.payeePar,
    this.proprietaireId,
    this.proprietaireNom,
    required this.montant,
    this.debiteurId,
    this.debiteurNom,
  });

  factory ReparationPaiement.fromJson(Map<String, dynamic> json) =>
      ReparationPaiement(
        id: json['id'] as String?,
        payeePar: PayeePar.fromValue(json['payeur_type'] as String?),
        proprietaireId: json['proprietaire_id'] as String?,
        proprietaireNom: json['profiles'] != null
            ? '${json['profiles']['prenom'] ?? ''} ${json['profiles']['nom'] ?? ''}'.trim()
            : null,
        montant: (json['montant'] as num).toDouble(),
        debiteurId: json['debiteur_id'] as String?,
        debiteurNom: json['debiteur'] != null
            ? '${json['debiteur']['prenom'] ?? ''} ${json['debiteur']['nom'] ?? ''}'.trim()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'payeur_type': payeePar.value,
        'proprietaire_id': payeePar == PayeePar.proprietaire ? proprietaireId : null,
        'montant': montant,
        'debiteur_id': debiteurId,
      };
}

class Reparation {
  final String id;
  final String vehiculeId;
  final String? vehiculeNom;
  final String typeRep;
  final String description;
  final String? prestataire;
  final double cout;
  final DateTime dateRep;
  final int? kmAuMoment;
  final String? photoFactureUrl;
  final bool deductible;
  final PayeePar payeePar;
  final String? proprietairePayeurId;
  final String? proprietairePayeurNom;
  final List<ReparationPaiement> paiements;

  const Reparation({
    required this.id, required this.vehiculeId, this.vehiculeNom,
    required this.typeRep, required this.description, this.prestataire,
    required this.cout, required this.dateRep, this.kmAuMoment,
    this.photoFactureUrl, required this.deductible,
    this.payeePar = PayeePar.showroom,
    this.proprietairePayeurId,
    this.proprietairePayeurNom,
    this.paiements = const [],
  });

  /// true si le coût a été réparti entre plusieurs payeurs.
  bool get paiementMultiple => paiements.length > 1;

  /// Libellé court résumant qui a payé, pour l'affichage en liste.
  String get payeurResume {
    if (paiements.isEmpty) {
      return payeePar == PayeePar.showroom
          ? 'Showroom'
          : (proprietairePayeurNom?.isNotEmpty == true
              ? proprietairePayeurNom!
              : 'Propriétaire');
    }
    if (paiements.length == 1) {
      final p = paiements.first;
      return p.payeePar == PayeePar.showroom
          ? 'Showroom'
          : (p.proprietaireNom?.isNotEmpty == true ? p.proprietaireNom! : 'Propriétaire');
    }
    return '${paiements.length} payeurs';
  }

  /// true si au moins une ligne désigne un responsable différent du payeur
  /// (transfert : le débiteur est déduit, le payeur est remboursé).
  bool get aUnResponsableDistinct => paiements.any((p) =>
      p.debiteurId != null &&
      p.debiteurId != (p.payeePar == PayeePar.proprietaire ? p.proprietaireId : null));

  /// Libellé résumant qui doit réellement supporter le coût, pour l'affichage.
  String? get responsableResume {
    final specifiques = paiements.where((p) => p.debiteurId != null).toList();
    if (specifiques.isEmpty) return null;
    if (specifiques.length == 1) {
      final d = specifiques.first.debiteurNom;
      return d?.isNotEmpty == true ? d! : 'Responsable désigné';
    }
    return '${specifiques.length} responsables désignés';
  }

  String get typeLabel => switch (typeRep) {
    'mecanique'   => 'Mécanique',
    'carrosserie' => 'Carrosserie',
    'electrique'  => 'Électrique',
    'pneus'       => 'Pneus',
    _             => 'Autre',
  };

  factory Reparation.fromJson(Map<String, dynamic> json) => Reparation(
    id:             json['id'],
    vehiculeId:     json['vehicule_id'],
    vehiculeNom:    json['vehicules'] != null
                      ? '${json['vehicules']['marque']} ${json['vehicules']['modele']}'
                      : null,
    typeRep:        json['type_rep'],
    description:    json['description'],
    prestataire:    json['prestataire'],
    cout:           (json['cout'] as num).toDouble(),
    dateRep:        DateTime.parse(json['date_rep']),
    kmAuMoment:     json['km_au_moment'],
    photoFactureUrl: json['photo_facture_url'],
    deductible:     json['deductible'] ?? true,
    payeePar:       PayeePar.fromValue(json['payee_par'] as String?),
    proprietairePayeurId: json['proprietaire_payeur_id'] as String?,
    proprietairePayeurNom: json['profiles'] != null
                      ? '${json['profiles']['prenom'] ?? ''} ${json['profiles']['nom'] ?? ''}'.trim()
                      : null,
    paiements:      (json['reparation_paiements'] as List<dynamic>?)
                      ?.map((p) => ReparationPaiement.fromJson(p as Map<String, dynamic>))
                      .toList() ?? const [],
  );
}
