// lib/features/gps/data/gps_route_gap_filler.dart
//
// ★ NOUVEAU — Comble les trous GPS dans un trajet playback.
//
// Problème : sur autoroute (tunnel, zone d'ombre), le tracker peut perdre le
// signal ~20-60s. Entre le dernier point avant coupure et le premier point
// après, une simple ligne droite est fausse (elle peut couper à travers un
// terrain, un rond-point, etc.).
//
// Solution : quand on détecte un trou "suspect" (durée + distance
// significatives, vitesse implicite plausible pour un déplacement routier),
// on demande à `RouteMatchingService` le chemin routier le plus probable
// entre les deux points, puis on ré-échantillonne ce chemin en points
// GpsPosition synthétiques (`isInterpolated = true`), avec un horodatage et
// un cap (heading) interpolés le long de la route réelle.
//
// Ces points ne sont JAMAIS écrits en base — générés en mémoire uniquement
// pour l'affichage playback (trace + curseur animé).

import 'dart:math' as math;

import '../domain/gps_position.dart';
import 'route_matching_service.dart';

double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0; // mètres
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _bearing(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = lat1 * math.pi / 180, phi2 = lat2 * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final y = math.sin(dLon) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Comble les trous d'un trajet en le rendant "route-aware".
///
/// - [gapThreshold] : durée minimale entre 2 points pour être considérée
///   comme un trou GPS (par défaut 20s — un tracker normal émet toutes les
///   5-15s, donc 20s+ = signal perdu, pas juste un cycle d'émission lent).
/// - [minGapDistanceMeters] : en dessous, le véhicule était probablement à
///   l'arrêt (parking, feu rouge) → pas la peine d'appeler le routing.
/// - [maxCallsPerLoad] : garde-fou pour éviter de spammer le service de
///   routing sur un trajet avec beaucoup de coupures (ex: zone rurale).
Future<List<GpsPosition>> fillRoadGaps(
  List<GpsPosition> positions, {
  required RouteMatchingService routing,
  Duration gapThreshold = const Duration(seconds: 20),
  double minGapDistanceMeters = 60,
  int maxCallsPerLoad = 25,
}) async {
  if (positions.length < 2) return positions;

  final result = <GpsPosition>[positions.first];
  int calls = 0;

  for (int i = 1; i < positions.length; i++) {
    final prev = positions[i - 1];
    final curr = positions[i];
    final gap  = curr.fixTime.difference(prev.fixTime);
    final distM = _haversineMeters(prev.latitude, prev.longitude, curr.latitude, curr.longitude);

    final qualifies = calls < maxCallsPerLoad &&
        gap >= gapThreshold &&
        distM >= minGapDistanceMeters;

    if (qualifies) {
      final gapHours = gap.inMilliseconds / 3600000;
      final impliedKmh = gapHours > 0 ? (distM / 1000) / gapHours : 0;

      // Garde-fou de plausibilité : entre 3 et 180 km/h. En dehors de cette
      // fourchette c'est probablement un mauvais fix GPS (saut/teleport), pas
      // un vrai trajet routier → on laisse la ligne droite par défaut.
      if (impliedKmh >= 3 && impliedKmh <= 180) {
        calls++;
        try {
          final path = await routing.getRoadPath(
            fromLat: prev.latitude, fromLon: prev.longitude,
            toLat:   curr.latitude, toLon:   curr.longitude,
          );
          if (path != null && path.length > 2) {
            result.addAll(_synthesizeAlongPath(prev, curr, path));
          }
        } catch (_) {
          // silencieux : on retombe simplement sur la ligne droite existante
        }
      }
    }

    result.add(curr);
  }

  return result;
}

List<GpsPosition> _synthesizeAlongPath(
  GpsPosition a,
  GpsPosition b,
  List<List<double>> path, {
  int maxSyntheticPoints = 40,
}) {
  final cumDist = <double>[0];
  for (int i = 1; i < path.length; i++) {
    cumDist.add(cumDist.last +
        _haversineMeters(path[i - 1][0], path[i - 1][1], path[i][0], path[i][1]));
  }
  final totalDist = cumDist.last;
  if (totalDist <= 0) return [];

  final totalMs   = b.fixTime.difference(a.fixTime).inMilliseconds;
  final avgSpeedKmh = totalMs > 0 ? (totalDist / 1000) / (totalMs / 3600000) : null;

  final step = math.max(1, (path.length / maxSyntheticPoints).ceil());
  final out = <GpsPosition>[];

  for (int i = step; i < path.length - 1; i += step) {
    final frac = cumDist[i] / totalDist;
    final t    = a.fixTime.add(Duration(milliseconds: (totalMs * frac).round()));
    final prevIdx = math.max(0, i - step);
    final heading = _bearing(
      path[prevIdx][0], path[prevIdx][1],
      path[i][0], path[i][1],
    );

    out.add(GpsPosition(
      vehiculeId:     a.vehiculeId,
      latitude:       path[i][0],
      longitude:      path[i][1],
      speed:          avgSpeedKmh,
      altitude:       null,
      heading:        heading,
      fixTime:        t,
      serverTime:     t,
      ignitionOn:     b.ignitionOn ?? a.ignitionOn,
      batteryLevel:   null,
      fuelLevel:      null,
      doorOpen:       null,
      gnssValid:      false, // reconstitué, pas un vrai fix
      positionValid:  true,
      isOnline:       b.isOnline,
      isInterpolated: true,
    ));
  }
  return out;
}

/// Recale CHAQUE point GPS réel sur le réseau routier (map matching, OSRM
/// `/match`), puis comble les vrais trous de signal via [fillRoadGaps].
///
/// Pourquoi c'est nécessaire en plus de [fillRoadGaps] : celui-ci ne
/// reconstruit que les GROS trous (≥ 20s d'écart entre deux points). Sur un
/// historique dense (un fix toutes les 20-45s, cf. fréquence réelle du
/// tracker), la quasi-totalité des segments sont désormais trop courts pour
/// déclencher ce comblement — la dérive GPS "normale" de chaque point
/// (5-20m, davantage en zone urbaine dense) n'est donc jamais corrigée, et
/// le tracé peut visiblement couper à travers un pâté de maisons ou changer
/// de côté de route. [snapTraceToRoads] corrige ça en calant la position de
/// chaque point réel sur la route la plus probable (son horodatage/vitesse
/// d'origine ne changent pas), avant de traiter les vrais trous comme avant.
///
/// L'API `/match` a une limite pratique de points par requête : on découpe
/// donc la trace en lots de [batchSize] avec un léger chevauchement pour ne
/// pas casser la continuité aux frontières de lot.
Future<List<GpsPosition>> snapTraceToRoads(
  List<GpsPosition> positions, {
  required RouteMatchingService routing,
  int batchSize = 80,
  double accuracyRadiusMeters = 30,
}) async {
  if (positions.length < 2) return fillRoadGaps(positions, routing: routing);

  final sorted  = [...positions]..sort((a, b) => a.fixTime.compareTo(b.fixTime));
  final snapped = List<GpsPosition>.from(sorted);

  for (int start = 0; start < sorted.length; start += batchSize) {
    final end = math.min(start + batchSize, sorted.length);
    final chunk = sorted.sublist(start, end);
    if (chunk.length < 2) continue;

    List<List<double>?>? matches;
    try {
      matches = await routing.matchTrace(
        chunk.map((p) => (lat: p.latitude, lon: p.longitude, time: p.fixTime)).toList(),
        radiusMeters: accuracyRadiusMeters,
      );
    } catch (_) {
      matches = null;
    }
    if (matches == null) continue; // repli silencieux : positions brutes conservées pour ce lot

    for (int i = 0; i < chunk.length; i++) {
      final m = matches[i];
      if (m == null) continue; // non apparié avec confiance : position brute conservée
      final orig = chunk[i];
      snapped[start + i] = GpsPosition(
        vehiculeId:     orig.vehiculeId,
        latitude:       m[0],
        longitude:      m[1],
        speed:          orig.speed,
        altitude:       orig.altitude,
        heading:        orig.heading,
        fixTime:        orig.fixTime,
        serverTime:     orig.serverTime,
        ignitionOn:     orig.ignitionOn,
        batteryLevel:   orig.batteryLevel,
        fuelLevel:      orig.fuelLevel,
        doorOpen:       orig.doorOpen,
        gnssValid:      orig.gnssValid,
        positionValid:  orig.positionValid,
        isOnline:       orig.isOnline,
        isInterpolated: orig.isInterpolated,
      );
    }
  }

  // Une fois les points réels calés sur la route, on comble les VRAIS trous
  // de signal (aucune donnée pendant N secondes) — logique déjà existante.
  return fillRoadGaps(snapped, routing: routing);
}
