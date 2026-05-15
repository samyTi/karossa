// lib/features/locations/domain/location_model.dart

class LocationPaiement {
  final String id;
  final String locationId;
  final double montant;
  final DateTime datePaiement;
  final String? mode;
  final String? notes;

  const LocationPaiement({
    required this.id, required this.locationId,
    required this.montant, required this.datePaiement,
    this.mode, this.notes,
  });

  factory LocationPaiement.fromJson(Map<String, dynamic> json) => LocationPaiement(
    id:           json['id'],
    locationId:   json['location_id'],
    montant:      (json['montant'] as num).toDouble(),
    datePaiement: DateTime.parse(json['date_paiement']),
    mode:         json['mode'],
    notes:        json['notes'],
  );

  Map<String, dynamic> toJson() => {
    'location_id':   locationId,
    'montant':       montant,
    'date_paiement': datePaiement.toIso8601String().substring(0, 10),
    'mode':          mode,
    'notes':         notes,
  };
}
// ignore: constant_identifier_names
enum LocationStatut { en_cours, termine, annule, retard }

class LocationRepartition {
  final String beneficiaireId;
  final String beneficiaireNom;
  final String typePart;
  final double pourcentage;
  final double montant;

  const LocationRepartition({
    required this.beneficiaireId, required this.beneficiaireNom,
    required this.typePart, required this.pourcentage, required this.montant,
  });

  factory LocationRepartition.fromJson(Map<String, dynamic> json) =>
    LocationRepartition(
      beneficiaireId:  json['beneficiaire_id'],
      beneficiaireNom: json['profiles']?['prenom'] ?? '',
      typePart:        json['type_part'],
      pourcentage:     (json['pourcentage'] as num).toDouble(),
      montant:         (json['montant'] as num).toDouble(),
    );
}

class Location {
  final String id;
  final String vehiculeId;
  final String? vehiculeNom;
  final String clientId;
  final String? clientNom;
  final String? clientTel;
  final DateTime dateDebut;
  final DateTime dateFinPrevue;
  final DateTime? dateFinReelle;
  final int kmDepart;
  final int? kmRetour;
  final double prixJour;
  final int nbJours;
  final double? montantBrut;
  final double caution;
  final double retenueCaution;
  final LocationStatut statut;
  final String? notesDepart;
  final String? notesRetour;
  final List<LocationRepartition> repartitions;
  final DateTime createdAt;

  const Location({
    required this.id, required this.vehiculeId, this.vehiculeNom,
    required this.clientId, this.clientNom, this.clientTel,
    required this.dateDebut, required this.dateFinPrevue, this.dateFinReelle,
    required this.kmDepart, this.kmRetour, required this.prixJour,
    required this.nbJours, this.montantBrut, required this.caution,
    this.retenueCaution = 0, required this.statut,
    this.notesDepart, this.notesRetour,
    this.repartitions = const [], required this.createdAt,
  });

  bool get isOverdue =>
    statut == LocationStatut.en_cours &&
    DateTime.now().isAfter(dateFinPrevue);

  int get joursRetard =>
    isOverdue ? DateTime.now().difference(dateFinPrevue).inDays : 0;

  double get montantCalcule => prixJour * nbJours;

  factory Location.fromJson(Map<String, dynamic> json) => Location(
    id:            json['id'],
    vehiculeId:    json['vehicule_id'],
    vehiculeNom:   json['vehicules'] != null
                     ? '${json['vehicules']['marque']} ${json['vehicules']['modele']}'
                     : null,
    clientId:      json['client_id'],
    clientNom:     json['clients'] != null
                     ? '${json['clients']['prenom']} ${json['clients']['nom']}'
                     : null,
    clientTel:     json['clients']?['telephone'],
    dateDebut:     DateTime.parse(json['date_debut']),
    dateFinPrevue: DateTime.parse(json['date_fin_prevue']),
    dateFinReelle: json['date_fin_reelle'] != null
                     ? DateTime.parse(json['date_fin_reelle']) : null,
    kmDepart:      json['km_depart'] ?? 0,
    kmRetour:      json['km_retour'],
    prixJour:      (json['prix_jour'] as num).toDouble(),
    nbJours:       json['nb_jours'] ?? 1,
    montantBrut:   json['montant_brut'] != null
                     ? (json['montant_brut'] as num).toDouble() : null,
    caution:       (json['caution'] as num? ?? 0).toDouble(),
    retenueCaution:(json['retenue_caution'] as num? ?? 0).toDouble(),
    statut:        LocationStatut.values.firstWhere(
                     (s) => s.name == json['statut'],
                     orElse: () => LocationStatut.en_cours),
    notesDepart:   json['notes_depart'],
    notesRetour:   json['notes_retour'],
    repartitions:  (json['location_repartitions'] as List? ?? [])
                     .map((r) => LocationRepartition.fromJson(r)).toList(),
    createdAt:     DateTime.parse(json['created_at']),
  );
}
