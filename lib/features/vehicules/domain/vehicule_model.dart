import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

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
  final double? prixVente;
  final double? prixLocationJour;
  final VehiculeStatut statut;
  final List<String> photos;
  final String? notes;
  final List<VehiculePropriete> proprietes;
  final DateTime createdAt;

  const Vehicule({
    required this.id, required this.marque, required this.modele,
    required this.annee, this.couleur, this.immatriculation,
    this.carburant, this.boite, required this.kilometrage,
    this.prixVente, this.prixLocationJour, required this.statut,
    this.photos = const [], this.notes, this.proprietes = const [],
    required this.createdAt,
  });

  String get displayName => '$marque $modele $annee';

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
    prixVente:       json['prix_vente'] != null
                       ? (json['prix_vente'] as num).toDouble() : null,
    prixLocationJour: json['prix_location_jour'] != null
                       ? (json['prix_location_jour'] as num).toDouble() : null,
    statut:          VehiculeStatut.values.firstWhere(
                       (s) => s.name == json['statut'],
                       orElse: () => VehiculeStatut.disponible),
    photos:          List<String>.from(json['photos'] ?? []),
    notes:           json['notes'],
    proprietes:      (json['vehicule_proprietes'] as List? ?? [])
                       .map((p) => VehiculePropriete.fromJson(p)).toList(),
    createdAt:       DateTime.parse(json['created_at']),
  );
}
