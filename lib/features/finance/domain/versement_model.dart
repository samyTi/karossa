// lib/features/finance/domain/versement_model.dart

enum ModeVersement { especes, virement, cheque }

extension ModeVersementExtension on ModeVersement {
  String get label {
    switch (this) {
      case ModeVersement.especes: return 'Espèces';
      case ModeVersement.virement: return 'Virement';
      case ModeVersement.cheque: return 'Chèque';
    }
  }
}

/// Type de part financière consultée — correspond au CHECK constraint
/// `type_part` sur `location_repartitions` / `transaction_repartitions` /
/// `versements_proprietaires`. Un même profil peut cumuler les deux rôles
/// (ex. un gérant copropriétaire d'un véhicule) : chaque rôle a son écran
/// dédié et sa lecture de solde séparée.
enum TypePart {
  partProprietaire('part_proprietaire'),
  commissionGerant('commission_gerant');

  const TypePart(this.value);
  final String value;
}

/// Reconstruit un [TypePart] à partir de la valeur texte stockée en base.
/// Tolérant : une valeur absente ou inconnue retombe sur 'part_proprietaire'
/// (comportement historique, avant l'ajout de la colonne type_part).
TypePart _typePartFromValue(String? value) {
  switch (value) {
    case 'commission_gerant': return TypePart.commissionGerant;
    default: return TypePart.partProprietaire;
  }
}

class Versement {
  final String id;
  final String showroomId;
  final String proprietaireId;
  final double montant;
  final DateTime dateVersement;
  final ModeVersement? mode;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final TypePart typePart;

  const Versement({
    required this.id,
    required this.showroomId,
    required this.proprietaireId,
    required this.montant,
    required this.dateVersement,
    this.mode,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.typePart = TypePart.partProprietaire,
  });

  factory Versement.fromJson(Map<String, dynamic> json) => Versement(
        id: json['id'] as String,
        showroomId: json['showroom_id'] as String,
        proprietaireId: json['proprietaire_id'] as String,
        montant: (json['montant'] as num).toDouble(),
        dateVersement: DateTime.parse(json['date_versement'] as String),
        mode: json['mode'] != null
            ? ModeVersement.values.firstWhere(
                (m) => m.name == json['mode'],
                orElse: () => ModeVersement.especes,
              )
            : null,
        notes: json['notes'] as String?,
        createdBy: json['created_by'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        // Le champ peut être absent côté DB si la migration n'est pas encore
        // appliquée — on retombe sur 'part_proprietaire' (comportement
        // historique) plutôt que de planter.
        typePart: _typePartFromValue(json['type_part'] as String?),
      );

  Map<String, dynamic> toInsertJson() => {
        'showroom_id': showroomId,
        'proprietaire_id': proprietaireId,
        'montant': montant,
        'date_versement': dateVersement.toIso8601String().split('T').first,
        if (mode != null) 'mode': mode!.name,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'type_part': typePart.value,
      };
}