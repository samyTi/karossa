import 'package:flutter/material.dart';

class CaisseOperation {
  final String id;
  final String type; // 'entree' | 'sortie'
  final String categorie;
  final double montant;
  final String description;
  final String? vehiculeId;
  final String? locationId;
  final String? venteId;
  final String? reparationId;
  final String? echangeId;
  final DateTime dateOp;
  final String? photoFactureUrl;
  final String? createdBy;
  final DateTime? createdAt;

  // Relations jointes (objets récupérés via SQL JOIN)
  final Map<String, dynamic>? vehicule;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? vente;
  final Map<String, dynamic>? reparation;
  final Map<String, dynamic>? echange;

  const CaisseOperation({
    required this.id,
    required this.type,
    required this.categorie,
    required this.montant,
    required this.description,
    this.vehiculeId,
    this.locationId,
    this.venteId,
    this.reparationId,
    this.echangeId,
    required this.dateOp,
    this.photoFactureUrl,
    this.createdBy,
    this.createdAt,
    this.vehicule,
    this.location,
    this.vente,
    this.reparation,
    this.echange,
  });

  bool get isEntree => type == 'entree';

  /// Retourne le label de catégorie lisible (ex: "Lavage" au lieu de "lavage")
  String get categorieLabel => categorieLabels[categorie] ?? categorie;

  static const categorieLabels = {
    'loyer_location': 'Loyer / Location',
    'vente_vehicule': 'Vente véhicule',
    'echange': 'Échange',
    'reparation': 'Réparation',
    'entretien': 'Entretien',
    'carburant': 'Carburant',
    'assurance': 'Assurance',
    'controle_technique': 'Contrôle technique',
    'lavage': 'Lavage',
    'autre': 'Autre',
  };

  static const allCategories = [
    'loyer_location',
    'vente_vehicule',
    'echange',
    'reparation',
    'entretien',
    'carburant',
    'assurance',
    'controle_technique',
    'lavage',
    'autre',
  ];

  /// ✅ Indispensable pour l'exportation CSV dans caisse_screen.dart
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': '${dateOp.day.toString().padLeft(2, '0')}/${dateOp.month.toString().padLeft(2, '0')}/${dateOp.year}',
      'type': isEntree ? 'Entrée' : 'Sortie',
      'categorie': categorieLabel,
      'montant': montant,
      'description': description,
      'vehicule': vehicule != null ? '${vehicule!['marque']} ${vehicule!['modele']}' : '',
      'auteur': createdBy ?? '',
    };
  }

  /// Pour l'insertion dans Supabase
  Map<String, dynamic> toInsertMap() => {
    'type': type,
    'categorie': categorie,
    'montant': montant,
    'description': description,
    if (vehiculeId != null) 'vehicule_id': vehiculeId,
    if (locationId != null) 'location_id': locationId,
    if (venteId != null) 'vente_id': venteId,
    if (reparationId != null) 'reparation_id': reparationId,
    if (echangeId != null) 'echange_id': echangeId,
    'date_op': dateOp.toIso8601String(),
    if (photoFactureUrl != null) 'photo_facture_url': photoFactureUrl,
  };

  factory CaisseOperation.fromMap(Map<String, dynamic> m) {
    return CaisseOperation(
      id: m['id']?.toString() ?? '',
      type: m['type'] as String? ?? 'sortie',
      categorie: m['categorie'] as String? ?? 'autre',
      montant: (m['montant'] as num?)?.toDouble() ?? 0.0,
      description: m['description'] as String? ?? '',
      vehiculeId: m['vehicule_id'] as String?,
      locationId: m['location_id'] as String?,
      venteId: m['vente_id'] as String?,
      reparationId: m['reparation_id'] as String?,
      echangeId: m['echange_id'] as String?,
      dateOp: DateTime.tryParse(m['date_op']?.toString() ?? '') ?? DateTime.now(),
      photoFactureUrl: m['photo_facture_url'] as String?,
      createdBy: m['created_by'] as String?,
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) : null,
      vehicule: m['vehicules'] as Map<String, dynamic>?,
      location: m['locations'] as Map<String, dynamic>?,
      vente: m['ventes'] as Map<String, dynamic>?,
      reparation: m['reparations'] as Map<String, dynamic>?,
      echange: m['echanges'] as Map<String, dynamic>?,
    );
  }

  CaisseOperation copyWith({
    String? type,
    String? categorie,
    double? montant,
    String? description,
    String? vehiculeId,
    String? locationId,
    String? venteId,
    String? reparationId,
    String? echangeId,
    DateTime? dateOp,
    String? photoFactureUrl,
  }) => CaisseOperation(
    id: id,
    type: type ?? this.type,
    categorie: categorie ?? this.categorie,
    montant: montant ?? this.montant,
    description: description ?? this.description,
    vehiculeId: vehiculeId ?? this.vehiculeId,
    locationId: locationId ?? this.locationId,
    venteId: venteId ?? this.venteId,
    reparationId: reparationId ?? this.reparationId,
    echangeId: echangeId ?? this.echangeId,
    dateOp: dateOp ?? this.dateOp,
    photoFactureUrl: photoFactureUrl ?? this.photoFactureUrl,
    createdBy: createdBy,
    createdAt: createdAt,
    vehicule: vehicule,
    location: location,
    vente: vente,
    reparation: reparation,
    echange: echange,
  );
}

// ─── Modèles utilitaires pour l'interface ────────────────────────────────────

class CaisseStats {
  final double totalEntrees;
  final double totalSorties;
  final Map<String, double> parCategorie;

  const CaisseStats({
    required this.totalEntrees,
    required this.totalSorties,
    required this.parCategorie,
  });

  double get solde => totalEntrees - totalSorties;

  factory CaisseStats.fromOperations(List<CaisseOperation> ops) {
    double entrees = 0, sorties = 0;
    final Map<String, double> parCat = {};
    for (final op in ops) {
      if (op.isEntree) {
        entrees += op.montant;
      } else {
        sorties += op.montant;
      }
      parCat[op.categorie] = (parCat[op.categorie] ?? 0) + op.montant;
    }
    return CaisseStats(
      totalEntrees: entrees,
      totalSorties: sorties,
      parCategorie: parCat,
    );
  }

  static const empty = CaisseStats(
    totalEntrees: 0,
    totalSorties: 0,
    parCategorie: {},
  );
}

class CaisseFilter {
  final String? type;
  final String? categorie;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final int? mois;
  final int? annee;

  const CaisseFilter({
    this.type,
    this.categorie,
    this.dateDebut,
    this.dateFin,
    this.mois,
    this.annee,
  });

  const CaisseFilter.empty()
      : type = null,
        categorie = null,
        dateDebut = null,
        dateFin = null,
        mois = null,
        annee = null;

  bool get hasActiveFilter =>
      type != null || categorie != null || dateDebut != null || dateFin != null;

  CaisseFilter copyWith({
    Object? type = _sentinel,
    Object? categorie = _sentinel,
    Object? dateDebut = _sentinel,
    Object? dateFin = _sentinel,
    Object? mois = _sentinel,
    Object? annee = _sentinel,
  }) => CaisseFilter(
    type: type == _sentinel ? this.type : type as String?,
    categorie: categorie == _sentinel ? this.categorie : categorie as String?,
    dateDebut: dateDebut == _sentinel ? this.dateDebut : dateDebut as DateTime?,
    dateFin: dateFin == _sentinel ? this.dateFin : dateFin as DateTime?,
    mois: mois == _sentinel ? this.mois : mois as int?,
    annee: annee == _sentinel ? this.annee : annee as int?,
  );

  static const _sentinel = Object();
}