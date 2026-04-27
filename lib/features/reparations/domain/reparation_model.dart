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

  const Reparation({
    required this.id, required this.vehiculeId, this.vehiculeNom,
    required this.typeRep, required this.description, this.prestataire,
    required this.cout, required this.dateRep, this.kmAuMoment,
    this.photoFactureUrl, required this.deductible,
  });

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
                      ? '${json["vehicules"]["marque"]} ${json["vehicules"]["modele"]}'
                      : null,
    typeRep:        json['type_rep'],
    description:    json['description'],
    prestataire:    json['prestataire'],
    cout:           (json['cout'] as num).toDouble(),
    dateRep:        DateTime.parse(json['date_rep']),
    kmAuMoment:     json['km_au_moment'],
    photoFactureUrl: json['photo_facture_url'],
    deductible:     json['deductible'] ?? true,
  );
}
