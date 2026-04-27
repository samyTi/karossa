import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

enum ClientStatut { normal, fiable, risque, blacklist }

extension ClientStatutExt on ClientStatut {
  String get label => switch (this) {
    ClientStatut.normal    => 'Normal',
    ClientStatut.fiable    => 'Fiable',
    ClientStatut.risque    => 'À risque',
    ClientStatut.blacklist => 'Liste noire',
  };
  Color get color => switch (this) {
    ClientStatut.normal    => AppColors.textSecondary,
    ClientStatut.fiable    => AppColors.secondary,
    ClientStatut.risque    => AppColors.accent,
    ClientStatut.blacklist => AppColors.retard,
  };
}

class Client {
  final String id;
  final String nom;
  final String prenom;
  final String telephone;
  final String? email;
  final String? adresse;
  final String? numPermis;
  final String? numCni;
  final ClientStatut statut;
  final String? noteInterne;
  final DateTime createdAt;

  const Client({
    required this.id, required this.nom, required this.prenom,
    required this.telephone, this.email, this.adresse,
    this.numPermis, this.numCni, required this.statut,
    this.noteInterne, required this.createdAt,
  });

  String get fullName => '$prenom $nom';
  String get initials =>
    '${prenom.isNotEmpty ? prenom[0] : ""}${nom.isNotEmpty ? nom[0] : ""}'.toUpperCase();

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id:          json['id'],
    nom:         json['nom'],
    prenom:      json['prenom'],
    telephone:   json['telephone'],
    email:       json['email'],
    adresse:     json['adresse'],
    numPermis:   json['num_permis'],
    numCni:      json['num_cni'],
    statut:      ClientStatut.values.firstWhere(
                   (s) => s.name == json['statut'],
                   orElse: () => ClientStatut.normal),
    noteInterne: json['note_interne'],
    createdAt:   DateTime.parse(json['created_at']),
  );
}
