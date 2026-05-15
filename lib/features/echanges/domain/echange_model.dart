// lib/features/echanges/domain/echange_model.dart
//
// CORRECTION ligne 40 : interpolation ternaire avec guillemets doubles
// imbriqués dans une string délimitée par des guillemets simples.
// Solution : utiliser une string adjacent au lieu du ternaire inline.

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

  // CORRECTION : extraire le suffixe année dans une variable locale
  // pour éviter l'interpolation ternaire avec guillemets doubles imbriqués.
  String get vehiculeReprisNom {
    final annee = vehiculeReprisAnnee != null ? ' $vehiculeReprisAnnee' : '';
    return '$vehiculeReprisMarque $vehiculeReprisModele$annee';
  }

  factory Echange.fromJson(Map<String, dynamic> json) {
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
          ? '${json["clients"]["prenom"]} ${json["clients"]["nom"]}' : null,
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
