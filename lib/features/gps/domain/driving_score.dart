// lib/features/gps/domain/driving_score.dart
//
// Score de conduite calculé à partir de l'historique GPS d'un véhicule
// sur une période donnée. Aucune nouvelle table Supabase requise :
// tout est recalculé à la volée depuis `gps_positions`.

class DrivingEvent {
  final DateTime dateHeure;
  final double latitude;
  final double longitude;
  final DrivingEventType type;
  /// Valeur contextuelle : km/h pour un excès de vitesse,
  /// m/s² pour un freinage/accélération brusque.
  final double valeur;

  const DrivingEvent({
    required this.dateHeure,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.valeur,
  });
}

enum DrivingEventType { freinageBrusque, accelerationBrusque, exces_vitesse }

extension DrivingEventTypeLabel on DrivingEventType {
  String get label => switch (this) {
        DrivingEventType.freinageBrusque => 'Freinage brusque',
        DrivingEventType.accelerationBrusque => 'Accélération brusque',
        DrivingEventType.exces_vitesse => 'Excès de vitesse',
      };
}

/// Résultat agrégé du calcul de score pour un véhicule sur une période.
class DrivingScoreResult {
  final String vehiculeId;
  final DateTime periodeDebut;
  final DateTime periodeFin;

  /// Score sur 100 (100 = conduite exemplaire).
  final int score;

  final double distanceKm;
  final int dureeConduiteMinutes;
  final int dureeRalentiMinutes;

  final int nbFreinagesBrusques;
  final int nbAccelerationsBrusques;
  final int nbExcesVitesse;
  final double vitesseMax;

  final List<DrivingEvent> evenements;

  const DrivingScoreResult({
    required this.vehiculeId,
    required this.periodeDebut,
    required this.periodeFin,
    required this.score,
    required this.distanceKm,
    required this.dureeConduiteMinutes,
    required this.dureeRalentiMinutes,
    required this.nbFreinagesBrusques,
    required this.nbAccelerationsBrusques,
    required this.nbExcesVitesse,
    required this.vitesseMax,
    required this.evenements,
  });

  factory DrivingScoreResult.empty(String vehiculeId, DateTime from, DateTime to) =>
      DrivingScoreResult(
        vehiculeId: vehiculeId,
        periodeDebut: from,
        periodeFin: to,
        score: 100,
        distanceKm: 0,
        dureeConduiteMinutes: 0,
        dureeRalentiMinutes: 0,
        nbFreinagesBrusques: 0,
        nbAccelerationsBrusques: 0,
        nbExcesVitesse: 0,
        vitesseMax: 0,
        evenements: const [],
      );

  /// Libellé qualitatif affiché dans l'UI.
  String get label {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Bon';
    if (score >= 55) return 'Moyen';
    return 'À risque';
  }

  int get totalEvenements =>
      nbFreinagesBrusques + nbAccelerationsBrusques + nbExcesVitesse;
}
