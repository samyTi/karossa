//lib/features/vehicules/domain/vehicule_model.dart
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
  /// 'proprietaire' ou 'associe' — statut porté par véhicule, pas par le profil.
  final String typeParticipation;

  const VehiculePropriete({
    required this.proprietaireId,
    required this.proprietaireNom,
    required this.partPct,
    this.typeParticipation = 'proprietaire',
  });

  bool get isAssocie => typeParticipation == 'associe';

  factory VehiculePropriete.fromJson(Map<String, dynamic> json) =>
    VehiculePropriete(
      proprietaireId:  json['proprietaire_id'],
      proprietaireNom: json['profiles']?['prenom'] ?? '',
      partPct:         (json['part_pct'] as num).toDouble(),
      typeParticipation: (json['type_participation'] as String?) ?? 'proprietaire',
    );
}

class Vehicule {
  final String id;
  final String marque;
  final String modele;
  final int annee;
  final String? couleur;
  final String? immatriculation;
  final String? numChassis;
  final String? assurance;
  final String? codeRadio;
  final String? carburant;
  final String? boite;
  final int kilometrage;
  final double? prixAchat;
  final double? prixVente;
  final double? prixLocationJour;
  final VehiculeStatut statut;
  final List<String> photos;
  final String? notes;
  final String? etatVehicule;
  final List<VehiculePropriete> proprietes;
  final DateTime createdAt;
  final int? flespiDeviceId;
  final int? kmAlerteSeuil;

  const Vehicule({
    required this.id, 
    required this.marque, 
    required this.modele,
    required this.annee, 
    this.couleur, 
    this.immatriculation,
    this.numChassis,
    this.assurance,
    this.codeRadio,
    this.carburant, 
    this.boite, 
    required this.kilometrage,
    this.prixAchat, 
    this.prixVente, 
    this.prixLocationJour,
    required this.statut, 
    this.photos = const [], 
    this.notes,
    this.etatVehicule,
    this.proprietes = const [], 
    required this.createdAt,
    this.flespiDeviceId, 
    this.kmAlerteSeuil,
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
    numChassis:      json['num_chassis'],
    assurance:       json['assurance'],
    codeRadio:       json['code_radio'],
    carburant:       json['carburant'],
    boite:           json['boite'],
    kilometrage:     (json['kilometrage'] as num?)?.toInt() ?? 0,
    prixAchat:       (json['prix_achat'] as num?)?.toDouble(),
    prixVente:       (json['prix_vente'] as num?)?.toDouble(),
    prixLocationJour: (json['prix_location_jour'] as num?)?.toDouble(),
    statut:          VehiculeStatut.values.firstWhere(
                       (s) => s.name == json['statut'],
                       orElse: () => VehiculeStatut.disponible),
    photos:          List<String>.from(json['photos'] ?? []),
    notes:           json['notes'],
    etatVehicule:    json['etat_vehicule'],
    proprietes:      (json['vehicule_proprietes'] as List? ?? [])
                       .map((p) => VehiculePropriete.fromJson(p)).toList(),
    createdAt:       DateTime.parse(json['created_at']),
    flespiDeviceId:  json['flespi_device_id'] != null ? (json['flespi_device_id'] as num).toInt() : null,
    kmAlerteSeuil:   (json['km_alerte_seuil'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'marque':             marque,
    'modele':             modele,
    'annee':              annee,
    'couleur':            couleur,
    'immatriculation':    immatriculation,
    'num_chassis':        numChassis,
    'assurance':          assurance,
    'code_radio':         codeRadio,
    'carburant':          carburant,
    'boite':              boite,
    'kilometrage':        kilometrage,
    'prix_achat':         prixAchat,
    'prix_vente':         prixVente,
    'prix_location_jour': prixLocationJour,
    'statut':             statut.name,
    'photos':             photos,
    'notes':              notes,
    'etat_vehicule':      etatVehicule,
    'km_alerte_seuil':    kmAlerteSeuil,
    'flespi_device_id':   flespiDeviceId,
  };
}