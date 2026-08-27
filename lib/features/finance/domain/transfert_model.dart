// lib/features/finance/domain/transfert_model.dart

/// Un virement d'argent d'un utilisateur vers un autre (ex: un associé qui
/// dépanne le gérant, ou l'inverse), saisi depuis l'écran Caisse.
///
/// ⚠️ N'impacte JAMAIS la caisse réelle du showroom (voir `CaisseOperation`) :
/// c'est un solde purement entre deux personnes.
/// - [remboursable] == true  → une créance : le bénéficiaire doit rendre
///   l'argent au payeur. [rembourse] suit si c'est déjà réglé.
/// - [remboursable] == false → un don / apport définitif, gardé pour
///   historique uniquement, sans effet sur aucun solde.
class TransfertUtilisateur {
  final String id;
  final String payeurId;
  final String? payeurNom;
  final String beneficiaireId;
  final String? beneficiaireNom;
  final double montant;
  final String motif;
  final bool remboursable;
  final bool rembourse;
  final DateTime? dateRembourse;
  final String? notes;
  final DateTime dateTransfert;
  final String? createdBy;

  const TransfertUtilisateur({
    required this.id,
    required this.payeurId,
    this.payeurNom,
    required this.beneficiaireId,
    this.beneficiaireNom,
    required this.montant,
    required this.motif,
    this.remboursable = false,
    this.rembourse = false,
    this.dateRembourse,
    this.notes,
    required this.dateTransfert,
    this.createdBy,
  });

  /// true si c'est une créance encore due (remboursable et pas déjà réglée).
  bool get enAttenteRemboursement => remboursable && !rembourse;

  factory TransfertUtilisateur.fromJson(Map<String, dynamic> json) =>
      TransfertUtilisateur(
        id: json['id'] as String,
        payeurId: json['payeur_id'] as String,
        payeurNom: json['payeur'] != null
            ? '${json['payeur']['prenom'] ?? ''} ${json['payeur']['nom'] ?? ''}'.trim()
            : null,
        beneficiaireId: json['beneficiaire_id'] as String,
        beneficiaireNom: json['beneficiaire'] != null
            ? '${json['beneficiaire']['prenom'] ?? ''} ${json['beneficiaire']['nom'] ?? ''}'.trim()
            : null,
        montant: (json['montant'] as num).toDouble(),
        motif: json['motif'] as String,
        remboursable: json['remboursable'] as bool? ?? false,
        rembourse: json['rembourse'] as bool? ?? false,
        dateRembourse: json['date_rembourse'] != null
            ? DateTime.tryParse(json['date_rembourse'] as String)
            : null,
        notes: json['notes'] as String?,
        dateTransfert: DateTime.parse(json['date_transfert'] as String),
        createdBy: json['created_by'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'payeur_id': payeurId,
        'beneficiaire_id': beneficiaireId,
        'montant': montant,
        'motif': motif,
        'remboursable': remboursable,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'date_transfert': dateTransfert.toIso8601String().split('T').first,
      };
}