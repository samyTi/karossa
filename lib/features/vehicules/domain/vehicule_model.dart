import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum VehiculeStatut { disponible, loue, vendu, reparation, reserve }

extension VehiculeStatutExt on VehiculeStatut {
  String get label => switch (this) {
    VehiculeStatut.disponible  => 'Disponible',
    VehiculeStatut.loue        => 'Loué',
    VehiculeStatut.vendu       => 'Vendu',
    VehiculeStatut.reparation  => 'Réparation',
    VehiculeStatut.reserve     => 'Réservé',
  };
  Color get color => switch (this) {
    VehiculeStatut.disponible  => AppColors.disponible,
    VehiculeStatut.loue        => AppColors.loue,
    VehiculeStatut.vendu       => AppColors.vendu,
    VehiculeStatut.reparation  => AppColors.reparation,
    VehiculeStatut.reserve     => AppColors.reserve,
  };
}

class VehiculePropriete {
  final String proprietaireId;
  final String proprietaireNom;
  final double partPct;

  const VehiculePropriete({
    required this.proprietaireId,
    required this.proprietaireNom,
    required this.partPct,
  });

  factory VehiculePropriete.fromJson(Map<String, dynamic> json) =>
    VehiculePropriete(
      proprietaireId:  json['proprietaire_id'],
      proprietaireNom: json['profiles']?['prenom'] ?? '',
      partPct:         (json['part_pct'] as num).toDouble(),
    );
}

class Vehicule {
  final String id;
  final String marque;
  final String modele;
  final int annee;
  final String? couleur;
  final String? immatriculation;
  final String? carburant;
  final String? boite;
  final int kilometrage;
  final double? prixAchat;
  final double? prixVente;
  final double? prixLocationJour;
  final VehiculeStatut statut;
  final List<String> photos;
  final String? notes;
  /// Décrit les dommages, rayures, pannes et tout ce qui ne fonctionne pas
  /// sur le véhicule. Affiché dans le contrat de location/vente.
  final String? etatVehicule;
  final List<VehiculePropriete> proprietes;
  final DateTime createdAt;
  // GPS — Device ID du tracker sur la plateforme Flespi
  final int? flespiDeviceId;
  final int? kmAlerteSeuil;

  const Vehicule({
    required this.id, required this.marque, required this.modele,
    required this.annee, this.couleur, this.immatriculation,
    this.carburant, this.boite, required this.kilometrage,
    this.prixAchat, this.prixVente, this.prixLocationJour,
    required this.statut, this.photos = const [], this.notes,
    this.etatVehicule,
    this.proprietes = const [], required this.createdAt,
    this.flespiDeviceId, this.kmAlerteSeuil,
  });

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is Vehicule && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  String get displayName => '$marque $modele $annee';

  double get prixRevientEstime => prixAchat ?? 0.0;

  bool get kmCritique {
    if (kmAlerteSeuil == null) return false;
    return kilometrage >= kmAlerteSeuil!;
  }

  factory Vehicule.fromJson(Map<String, dynamic> json) => Vehicule(
    id:              json['id'],
    marque:          json['marque'],
    modele:          json['modele'],
    annee:           json['annee'],
    couleur:         json['couleur'],
    immatriculation: json['immatriculation'],
    carburant:       json['carburant'],
    boite:           json['boite'],
    kilometrage:     json['kilometrage'] ?? 0,
    prixAchat:       json['prix_achat'] != null
                       ? (json['prix_achat'] as num).toDouble() : null,
    prixVente:       json['prix_vente'] != null
                       ? (json['prix_vente'] as num).toDouble() : null,
    prixLocationJour: json['prix_location_jour'] != null
                       ? (json['prix_location_jour'] as num).toDouble() : null,
    statut:          VehiculeStatut.values.firstWhere(
                       (s) => s.name == json['statut'],
                       orElse: () => VehiculeStatut.disponible),
    photos:          List<String>.from(json['photos'] ?? []),
    notes:           json['notes'],
    etatVehicule:    json['etat_vehicule'],
    proprietes:      (json['vehicule_proprietes'] as List? ?? [])
                       .map((p) => VehiculePropriete.fromJson(p)).toList(),
    createdAt:       DateTime.parse(json['created_at']),
    // Lit les deux colonnes pour compatibilité avec les anciennes données
    flespiDeviceId:  json['flespi_device_id'] ?? json['flespi_device_id'],
    kmAlerteSeuil:   json['km_alerte_seuil'],
  );

  Map<String, dynamic> toJson() => {
    'marque':            marque,
    'modele':            modele,
    'annee':             annee,
    'couleur':           couleur,
    'immatriculation':   immatriculation,
    'carburant':         carburant,
    'boite':             boite,
    'kilometrage':       kilometrage,
    'prix_achat':        prixAchat,
    'prix_vente':        prixVente,
    'prix_location_jour': prixLocationJour,
    'statut':            statut.name,
    'photos':            photos,
    'notes':             notes,
    'etat_vehicule':     etatVehicule,
    'km_alerte_seuil':   kmAlerteSeuil,
    'flespi_device_id':  flespiDeviceId,
  };
}