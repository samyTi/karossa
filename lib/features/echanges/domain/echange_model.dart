class Echange {
  final String id;
  final String vehiculeCedeId;
  final String? vehiculeCedeNom;
  final String clientId;
  final String? clientNom;
  final String vehiculeReprisMarque;
  final String vehiculeReprisModele;
  final int? vehiculeReprisAnnee;
  final int? vehiculeReprisKm;
  final String? vehiculeReprisImmat;
  final double valeurReprise;
  final double complementClient;
  final double? commissionGerantPct;
  final double? commissionGerantMnt;
  final DateTime dateEchange;
  final String? notes;

  const Echange({
    required this.id,
    required this.vehiculeCedeId,
    this.vehiculeCedeNom,
    required this.clientId,
    this.clientNom,
    required this.vehiculeReprisMarque,
    required this.vehiculeReprisModele,
    this.vehiculeReprisAnnee,
    this.vehiculeReprisKm,
    this.vehiculeReprisImmat,
    required this.valeurReprise,
    required this.complementClient,
    this.commissionGerantPct,
    this.commissionGerantMnt,
    required this.dateEchange,
    this.notes,
  });

  String get vehiculeReprisNom =>
    '$vehiculeReprisMarque $vehiculeReprisModele'
    '${vehiculeReprisAnnee != null ? " $vehiculeReprisAnnee" : ""}';

  factory Echange.fromJson(Map<String, dynamic> json) {
    // La jointure peut arriver sous la clé avec ou sans le suffixe fkey
    final vehData =
      json['vehicules!echanges_vehicule_cede_id_fkey'] ??
      json['vehicules'];

    return Echange(
      id:                   json['id'],
      vehiculeCedeId:       json['vehicule_cede_id'],
      vehiculeCedeNom:      vehData != null
        ? '${vehData["marque"]} ${vehData["modele"]}' : null,
      clientId:             json['client_id'],
      clientNom:            json['clients'] != null
        ? '${json["clients"]["prenom"]} ${json["clients"]["nom"]}'
        : null,
      vehiculeReprisMarque: json['vehicule_reprise_marque'],
      vehiculeReprisModele: json['vehicule_reprise_modele'],
      vehiculeReprisAnnee:  json['vehicule_reprise_annee'],
      vehiculeReprisKm:     json['vehicule_reprise_km'],
      vehiculeReprisImmat:  json['vehicule_reprise_immat'],
      valeurReprise:        (json['valeur_reprise'] as num).toDouble(),
      complementClient:     (json['complement_client'] as num? ?? 0).toDouble(),
      commissionGerantPct:  json['commission_gerant_pct'] != null
        ? (json['commission_gerant_pct'] as num).toDouble() : null,
      commissionGerantMnt:  json['commission_gerant_mnt'] != null
        ? (json['commission_gerant_mnt'] as num).toDouble() : null,
      dateEchange:          DateTime.parse(json['date_echange']),
      notes:                json['notes'],
    );
  }
}
