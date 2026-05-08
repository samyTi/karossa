// lib/features/vehicules/domain/vehicule_financials.dart

class VehiculeFinancials {
  final String vehiculeId;
  final double prixAchat;
  final double totalReparations;
  final double totalEntretiens;
  final double totalDepenses;       // prix de revient
  final double revenusLocations;
  final double? revenusVente;
  final double revenusTotal;
  final double margeBrute;
  final double margePct;
  final int nbLocations;
  final int joursLoues;
  final int tauxOccupationPct;
  final double revenusParJour;      // rentabilité/jour

  const VehiculeFinancials({
    required this.vehiculeId,
    required this.prixAchat,
    required this.totalReparations,
    required this.totalEntretiens,
    required this.totalDepenses,
    required this.revenusLocations,
    this.revenusVente,
    required this.revenusTotal,
    required this.margeBrute,
    required this.margePct,
    required this.nbLocations,
    required this.joursLoues,
    required this.tauxOccupationPct,
    required this.revenusParJour,
  });

  bool get isRentable => margeBrute > 0;

  String get margePctLabel =>
      '${margePct > 0 ? '+' : ''}${margePct.toStringAsFixed(1)}%';

  String get tauxOccupationLabel => '$tauxOccupationPct%';

  /// Construit depuis la réponse JSON du backend Next.js
  factory VehiculeFinancials.fromJson(Map<String, dynamic> json) =>
      VehiculeFinancials(
        vehiculeId:        json['vehiculeId'] as String,
        prixAchat:         (json['prixAchat'] as num).toDouble(),
        totalReparations:  (json['totalReparations'] as num).toDouble(),
        totalEntretiens:   (json['totalEntretiens'] as num).toDouble(),
        totalDepenses:     (json['totalDepenses'] as num).toDouble(),
        revenusLocations:  (json['revenusLocations'] as num).toDouble(),
        revenusVente:      json['revenusVente'] != null
                             ? (json['revenusVente'] as num).toDouble() : null,
        revenusTotal:      (json['revenusTotal'] as num).toDouble(),
        margeBrute:        (json['margeBrute'] as num).toDouble(),
        margePct:          (json['margePct'] as num).toDouble(),
        nbLocations:       json['nbLocations'] as int,
        joursLoues:        json['joursLoues'] as int,
        tauxOccupationPct: json['tauxOccupationPct'] as int,
        revenusParJour:    (json['revenusParJour'] as num).toDouble(),
      );
}
