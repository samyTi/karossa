// lib/features/contrats/data/contrat_model.dart

import 'dart:typed_data';

enum ContratType { vente, location, echange, achat }

extension ContratTypeExt on ContratType {
  String get label => switch (this) {
    ContratType.vente    => 'Vente',
    ContratType.location => 'Location',
    ContratType.echange  => 'Échange',
    ContratType.achat    => 'Achat',
  };

  String get value => name; // pour sérialisation BDD
}

class ContratModel {
  final String id;
  final ContratType type;
  final String clientNom;
  final String vehicule;
  final double prix;
  final Uint8List? pdfData;

  const ContratModel({
    required this.id,
    required this.type,
    required this.clientNom,
    required this.vehicule,
    required this.prix,
    this.pdfData,
  });

  factory ContratModel.fromJson(Map<String, dynamic> json) => ContratModel(
    id:        json['id'],
    type:      ContratType.values.firstWhere(
                 (t) => t.name == json['type'],
                 orElse: () => ContratType.vente,
               ),
    clientNom: json['client_nom'] ?? '',
    vehicule:  json['vehicule']   ?? '',
    prix:      (json['prix'] as num?)?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'id':         id,
    'type':       type.value,
    'client_nom': clientNom,
    'vehicule':   vehicule,
    'prix':       prix,
    // pdfData exclu volontairement — données binaires non persistées en JSON
  };

  ContratModel copyWith({
    String?     id,
    ContratType? type,
    String?     clientNom,
    String?     vehicule,
    double?     prix,
    Uint8List?  pdfData,
  }) => ContratModel(
    id:        id        ?? this.id,
    type:      type      ?? this.type,
    clientNom: clientNom ?? this.clientNom,
    vehicule:  vehicule  ?? this.vehicule,
    prix:      prix      ?? this.prix,
    pdfData:   pdfData   ?? this.pdfData,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContratModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ContratModel($type, $clientNom, $vehicule, $prix)';
}