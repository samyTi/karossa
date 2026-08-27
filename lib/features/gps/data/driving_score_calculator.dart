// lib/features/gps/data/driving_score_calculator.dart
//
// Calcul pur (aucun appel réseau) du score de conduite d'un véhicule
// à partir de sa liste de GpsPosition (déjà triée ou non par fixTime).
//
// Approche : on ne dispose que de position + vitesse + horodatage (pas
// d'accéléromètre), donc on dérive l'accélération de la variation de
// vitesse entre deux points consécutifs. C'est une approximation
// raisonnable et suffisante pour un score comparatif entre véhicules —
// ce n'est pas un instrument de mesure certifié.

import 'dart:math' as math;

import '../domain/driving_score.dart';
import '../domain/gps_position.dart';

class DrivingScoreCalculator {
  /// Seuil de décélération considérée comme un freinage brusque (m/s²).
  final double seuilFreinageMs2;

  /// Seuil d'accélération considérée comme brusque (m/s²).
  final double seuilAccelerationMs2;

  /// Vitesse au-delà de laquelle on considère un excès de vitesse (km/h).
  final double limiteVitesseKmh;

  /// Écart de temps max entre deux points pour qu'on les considère comme
  /// un même trajet continu (au-delà : véhicule arrêté / coupé, on ignore
  /// le saut pour ne pas générer de fausses accélérations).
  final Duration ecartMaxContinu;

  const DrivingScoreCalculator({
    this.seuilFreinageMs2 = -3.0,
    this.seuilAccelerationMs2 = 2.5,
    this.limiteVitesseKmh = 120,
    this.ecartMaxContinu = const Duration(minutes: 5),
  });

  DrivingScoreResult compute({
    required String vehiculeId,
    required List<GpsPosition> positions,
    required DateTime periodeDebut,
    required DateTime periodeFin,
  }) {
    if (positions.length < 2) {
      return DrivingScoreResult.empty(vehiculeId, periodeDebut, periodeFin);
    }

    final sorted = [...positions]..sort((a, b) => a.fixTime.compareTo(b.fixTime));

    double distanceKm = 0;
    int secondesConduite = 0;
    int secondesRalenti = 0;
    double vitesseMax = 0;
    final events = <DrivingEvent>[];

    for (var i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      final dt = b.fixTime.difference(a.fixTime);

      if (dt <= Duration.zero || dt > ecartMaxContinu) {
        // Trou trop grand (véhicule éteint / hors ligne) : on ne relie pas
        // les deux points pour le calcul cinématique, mais on garde la
        // distance parcourue (négligeable) hors du calcul.
        continue;
      }

      final distSegmentKm = _haversineKm(a.latitude, a.longitude, b.latitude, b.longitude);
      distanceKm += distSegmentKm;

      final speedA = a.speed ?? 0;
      final speedB = b.speed ?? 0;
      vitesseMax = math.max(vitesseMax, math.max(speedA, speedB));

      final isMoving = speedB > 2 || speedA > 2;
      if (isMoving) {
        secondesConduite += dt.inSeconds;
      } else if (a.ignitionOn == true || b.ignitionOn == true) {
        secondesRalenti += dt.inSeconds;
      }

      // Accélération dérivée de la variation de vitesse (km/h → m/s).
      final dtSeconds = dt.inMilliseconds / 1000.0;
      if (dtSeconds > 0) {
        final vA = speedA * 1000 / 3600;
        final vB = speedB * 1000 / 3600;
        final accelMs2 = (vB - vA) / dtSeconds;

        if (accelMs2 <= seuilFreinageMs2) {
          events.add(DrivingEvent(
            dateHeure: b.fixTime,
            latitude: b.latitude,
            longitude: b.longitude,
            type: DrivingEventType.freinageBrusque,
            valeur: accelMs2,
          ));
        } else if (accelMs2 >= seuilAccelerationMs2) {
          events.add(DrivingEvent(
            dateHeure: b.fixTime,
            latitude: b.latitude,
            longitude: b.longitude,
            type: DrivingEventType.accelerationBrusque,
            valeur: accelMs2,
          ));
        }
      }

      if (speedB > limiteVitesseKmh) {
        events.add(DrivingEvent(
          dateHeure: b.fixTime,
          latitude: b.latitude,
          longitude: b.longitude,
          type: DrivingEventType.exces_vitesse,
          valeur: speedB,
        ));
      }
    }

    final nbFreinages = events.where((e) => e.type == DrivingEventType.freinageBrusque).length;
    final nbAccelerations = events.where((e) => e.type == DrivingEventType.accelerationBrusque).length;
    final nbExces = events.where((e) => e.type == DrivingEventType.exces_vitesse).length;

    final score = _scoreFrom(
      nbFreinages: nbFreinages,
      nbAccelerations: nbAccelerations,
      nbExces: nbExces,
      distanceKm: distanceKm,
      secondesRalenti: secondesRalenti,
    );

    return DrivingScoreResult(
      vehiculeId: vehiculeId,
      periodeDebut: periodeDebut,
      periodeFin: periodeFin,
      score: score,
      distanceKm: distanceKm,
      dureeConduiteMinutes: (secondesConduite / 60).round(),
      dureeRalentiMinutes: (secondesRalenti / 60).round(),
      nbFreinagesBrusques: nbFreinages,
      nbAccelerationsBrusques: nbAccelerations,
      nbExcesVitesse: nbExces,
      vitesseMax: vitesseMax,
      evenements: events,
    );
  }

  /// Score sur 100, pondéré par la distance parcourue pour ne pas pénaliser
  /// injustement un véhicule qui roule beaucoup (on regarde le nombre
  /// d'événements pour 100 km, pas le total brut).
  int _scoreFrom({
    required int nbFreinages,
    required int nbAccelerations,
    required int nbExces,
    required double distanceKm,
    required int secondesRalenti,
  }) {
    if (distanceKm < 1) return 100; // pas assez de trajet pour juger

    final per100km = 100 / distanceKm;
    final penaliteFreinages = nbFreinages * per100km * 4;
    final penaliteAccelerations = nbAccelerations * per100km * 3;
    final penaliteExces = nbExces * per100km * 5;
    final penaliteRalenti = math.min(10.0, secondesRalenti / 3600 * 5); // max -10 pts

    final score = 100 - penaliteFreinages - penaliteAccelerations - penaliteExces - penaliteRalenti;
    return score.clamp(0, 100).round();
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final la1 = lat1 * math.pi / 180;
    final la2 = lat2 * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }
}
