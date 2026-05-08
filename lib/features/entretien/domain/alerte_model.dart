// lib/features/entretien/domain/alerte_model.dart
// Ajout reparation_id — lien vers la réparation qui a résolu l'alerte.

class AlerteEntretien {
  final String id;
  final String vehiculeId;
  final String? vehiculeNom;
  final String typeAlerte;
  final DateTime? dateEcheance;
  final int? kmEcheance;
  final String? description;
  final String statut;
  final String? reparationId;

  const AlerteEntretien({
    required this.id, required this.vehiculeId, this.vehiculeNom,
    required this.typeAlerte, this.dateEcheance, this.kmEcheance,
    this.description, required this.statut, this.reparationId,
  });

  bool get isUrgent =>
    dateEcheance != null &&
    dateEcheance!.difference(DateTime.now()).inDays <= 7;

  bool get isExpired =>
    dateEcheance != null && DateTime.now().isAfter(dateEcheance!);

  bool get isFait => statut == 'fait';

  String get typeLabel => switch (typeAlerte) {
    'vidange'            => 'Vidange',
    'controle_technique' => 'Contrôle technique',
    'assurance'          => 'Assurance',
    'vignette'           => 'Vignette',
    'pneus'              => 'Pneus',
    _                    => 'Autre',
  };

  factory AlerteEntretien.fromJson(Map<String, dynamic> json) => AlerteEntretien(
    id:           json['id'],
    vehiculeId:   json['vehicule_id'],
    vehiculeNom: json['vehicules'] != null ? '${json['vehicules']['marque']} ${json['vehicules']['modele']}' : null,
    typeAlerte:   json['type_alerte'],
    dateEcheance: json['date_echeance'] != null ? DateTime.parse(json['date_echeance']) : null,
    kmEcheance:   json['km_echeance'],
    description:  json['description'],
    statut:       json['statut'] ?? 'active',
    reparationId: json['reparation_id'],
  );

  Map<String, dynamic> toJson() => {
    'vehicule_id':  vehiculeId,
    'type_alerte':  typeAlerte,
    'date_echeance': dateEcheance?.toIso8601String().substring(0, 10),
    'km_echeance':  kmEcheance,
    'description':  description,
    'statut':       statut,
    if (reparationId != null) 'reparation_id': reparationId,
  };
}
