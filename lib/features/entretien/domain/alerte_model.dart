class AlerteEntretien {
  final String id;
  final String vehiculeId;
  final String? vehiculeNom;
  final String typeAlerte;
  final DateTime? dateEcheance;
  final int? kmEcheance;
  final String? description;
  final String statut;

  const AlerteEntretien({
    required this.id, required this.vehiculeId, this.vehiculeNom,
    required this.typeAlerte, this.dateEcheance, this.kmEcheance,
    this.description, required this.statut,
  });

  bool get isUrgent =>
    dateEcheance != null &&
    dateEcheance!.difference(DateTime.now()).inDays <= 7;

  bool get isExpired =>
    dateEcheance != null && DateTime.now().isAfter(dateEcheance!);

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
    vehiculeNom:  json['vehicules'] != null
                    ? '${json["vehicules"]["marque"]} ${json["vehicules"]["modele"]}'
                    : null,
    typeAlerte:   json['type_alerte'],
    dateEcheance: json['date_echeance'] != null
                    ? DateTime.parse(json['date_echeance']) : null,
    kmEcheance:   json['km_echeance'],
    description:  json['description'],
    statut:       json['statut'] ?? 'active',
  );
}
