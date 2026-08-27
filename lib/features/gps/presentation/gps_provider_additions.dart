// lib/features/gps/presentation/gps_provider_additions.dart
//
// ★ ADDITIONS À COLLER À LA FIN DE gps_provider.dart
//
// Contenu :
//   16. monthlyKmProvider       — Km ce mois par véhicule
//   17. speedTimelineProvider   — Timeline de vitesse (pour le graphique du panel)
//   18. vehicleContextProvider  — Contexte métier enrichi (location + km seuil)
//   19. geofenceCheckProvider   — Vérifie si un véhicule est actuellement dans une zone
//   20. fleetSummaryProvider    — Résumé condensé pour le widget home dashboard

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/gps_position.dart';
import '../domain/gps_geofence.dart';
import 'gps_provider.dart';

// ═══════════════════════════════════════════════════════════
// 16. Km parcourus ce mois par véhicule
// ═══════════════════════════════════════════════════════════

class MonthlyKmStats {
  final double kmThisMonth;
  final double kmLastMonth;    // pour comparer
  final double avgKmPerDay;
  final double projectedMonth; // extrapolation fin de mois

  const MonthlyKmStats({
    required this.kmThisMonth,
    required this.kmLastMonth,
    required this.avgKmPerDay,
    required this.projectedMonth,
  });

  static MonthlyKmStats empty() =>
      const MonthlyKmStats(kmThisMonth: 0, kmLastMonth: 0, avgKmPerDay: 0, projectedMonth: 0);

  /// Variation en % vs mois dernier (null si mois dernier = 0)
  double? get variationPct {
    if (kmLastMonth == 0) return null;
    return (kmThisMonth - kmLastMonth) / kmLastMonth * 100;
  }
}

final monthlyKmProvider =
    FutureProvider.autoDispose.family<MonthlyKmStats, String>(
  (ref, vehiculeId) async {
    final now = DateTime.now().toUtc();
    // Ce mois : 1er du mois courant → maintenant
    final thisMonthFrom = DateTime.utc(now.year, now.month, 1);
    // Mois dernier : 1er → dernier jour
    final lastMonthFrom = DateTime.utc(now.year, now.month - 1, 1);
    final lastMonthTo = thisMonthFrom.subtract(const Duration(seconds: 1));

    Future<double> calcKm(DateTime from, DateTime to) async {
      // ⚠️ Plafond dimensionné pour ~1 mois de ping continu (voir note dans
      // periodStatsProvider / getHistory) — sinon le mois est tronqué à sa
      // première tranche et le km est sous-évalué.
      final spanDays = to.difference(from).inDays.clamp(1, 62);
      final positions = await ref.watch(gpsRepositoryProvider)
          .getHistoryFromSupabase(
            vehiculeId: vehiculeId,
            from: from,
            to: to,
            limit: (spanDays * 5000).clamp(5000, 300000),
          );
      // On écarte les fix GPS non fiables, comme dans periodStatsProvider.
      final valid = positions
          .where((pos) => pos.gnssValid != false && pos.positionValid != false)
          .toList()
        ..sort((a, b) => a.fixTime.compareTo(b.fixTime));

      if (valid.length < 2) return 0;
      double km = 0;
      for (int i = 1; i < valid.length; i++) {
        final prev = valid[i - 1];
        final curr = valid[i];
        final gapSec = curr.fixTime.difference(prev.fixTime).inSeconds;
        if (gapSec <= 0) continue; // doublon / horodatage non croissant

        final segKm = _haversineKm(prev.latitude, prev.longitude, curr.latitude, curr.longitude);

        // Filtre bruit GPS à l'arrêt (véhicule immobile qui "dérive" de
        // quelques mètres entre deux fixes rapprochés).
        if (segKm < 0.015 && gapSec < 60) continue;

        km += segKm;
      }
      return km;
    }

    try {
      final results = await Future.wait([
        calcKm(thisMonthFrom, now),
        calcKm(lastMonthFrom, lastMonthTo),
      ]);

      final thisMonth = results[0];
      final lastMonth = results[1];
      final daysPassed = now.difference(thisMonthFrom).inHours / 24.0;
      final daysInMonth =
          DateTime.utc(now.year, now.month + 1, 1)
              .difference(thisMonthFrom)
              .inDays
              .toDouble();

      final avgPerDay = daysPassed > 0 ? thisMonth / daysPassed : 0.0;
      final projected = avgPerDay * daysInMonth;

      return MonthlyKmStats(
        kmThisMonth: thisMonth,
        kmLastMonth: lastMonth,
        avgKmPerDay: avgPerDay,
        projectedMonth: projected,
      );
    } catch (_) {
      return MonthlyKmStats.empty();
    }
  },
);

// ═══════════════════════════════════════════════════════════
// 17. Timeline de vitesse sur la journée (pour le graphique)
// ═══════════════════════════════════════════════════════════

/// Un point de la timeline : heure locale + vitesse km/h
class SpeedPoint {
  final DateTime time;
  final double speed;
  const SpeedPoint({required this.time, required this.speed});
}

/// Resampling : réduit à [maxPoints] en moyennant les tranches horaires.
/// Évite de planter fl_chart avec 2000 points.
List<SpeedPoint> _resample(List<GpsPosition> positions, {int maxPoints = 120}) {
  if (positions.isEmpty) return [];
  if (positions.length <= maxPoints) {
    return positions
        .where((p) => p.speed != null)
        // Ajout de .toDouble() ici
        .map((p) => SpeedPoint(time: p.fixTime.toLocal(), speed: p.speed!.toDouble()))
        .toList();
  }
  final bucketSize = (positions.length / maxPoints).ceil();
  final result = <SpeedPoint>[];
  for (int i = 0; i < positions.length; i += bucketSize) {
    final slice = positions.skip(i).take(bucketSize).where((p) => p.speed != null).toList();
    if (slice.isEmpty) continue;
    // On convertit chaque vitesse en double dès le map pour s'assurer que l'opération reste en double
    final avgSpeed = slice.map((p) => p.speed!.toDouble()).reduce((a, b) => a + b) / slice.length;
    result.add(SpeedPoint(time: slice.first.fixTime.toLocal(), speed: avgSpeed));
  }
  return result;
}
final speedTimelineProvider =
    FutureProvider.autoDispose.family<List<SpeedPoint>, String>(
  (ref, vehiculeId) async {
    // Réutilise dailyKmProvider si déjà chargé pour éviter double requête
    final daily = ref.watch(dailyKmProvider(vehiculeId));
    return daily.when(
      loading: () => <SpeedPoint>[],
      error: (_, __) => <SpeedPoint>[],
      data: (stats) => _resample(stats.positions),
    );
  },
);

// ═══════════════════════════════════════════════════════════
// 18. Contexte métier enrichi pour un véhicule GPS
//     Combine : position live + location active + seuil km + réparations en cours
// ═══════════════════════════════════════════════════════════

class VehicleGpsContext {
  final String vehiculeId;
  final String vehiculeNom;
  final String immatriculation;
  final int? kmAlerteSeuil;
  final int? kilometrageActuel;
  final bool isKmAlert;
  // Location active (si loué)
  final bool isRented;
  final String? clientNom;
  final String? dateFinPrevue;
  final String? locationId;
  // Réparation en cours
  final bool isInRepair;

  const VehicleGpsContext({
    required this.vehiculeId,
    required this.vehiculeNom,
    required this.immatriculation,
    this.kmAlerteSeuil,
    this.kilometrageActuel,
    required this.isKmAlert,
    required this.isRented,
    this.clientNom,
    this.dateFinPrevue,
    this.locationId,
    required this.isInRepair,
  });
}

final vehicleGpsContextProvider =
    FutureProvider.autoDispose.family<VehicleGpsContext, String>(
  (ref, vehiculeId) async {
    try {
      // Awaits séquentiels plutôt que Future.wait([...]) : .single() et
      // .maybeSingle() ont des types de retour différents (Map vs Map?),
      // ce qui casse l'inférence de type dans une liste littérale.
      final v = await Supabase.instance.client
          .from('vehicules')
          .select('marque, modele, immatriculation, km_alerte_seuil, kilometrage, statut')
          .eq('id', vehiculeId)
          .single();
      final l = await Supabase.instance.client
          .from('locations')
          .select('id, date_fin_prevue, clients(nom, prenom)')
          .eq('vehicule_id', vehiculeId)
          .eq('statut', 'en_cours')
          .maybeSingle();

      final seuil = v['km_alerte_seuil'] as int?;
      final kmActuel = v['kilometrage'] as int?;
      final isKmAlert = seuil != null && kmActuel != null && kmActuel >= seuil;

      final client = l?['clients'] as Map<String, dynamic>?;
      final clientNom = client != null
          ? '${client['prenom']} ${client['nom']}'
          : null;

      return VehicleGpsContext(
        vehiculeId: vehiculeId,
        vehiculeNom: '${v['marque']} ${v['modele']}',
        immatriculation: v['immatriculation'] as String? ?? '',
        kmAlerteSeuil: seuil,
        kilometrageActuel: kmActuel,
        isKmAlert: isKmAlert,
        isRented: l != null,
        clientNom: clientNom,
        dateFinPrevue: l?['date_fin_prevue'] as String?,
        locationId: l?['id'] as String?,
        isInRepair: v['statut'] == 'reparation',
      );
    } catch (_) {
      return VehicleGpsContext(
        vehiculeId: vehiculeId,
        vehiculeNom: 'Véhicule',
        immatriculation: '',
        isKmAlert: false,
        isRented: false,
        isInRepair: false,
      );
    }
  },
);

// ═══════════════════════════════════════════════════════════
// 19. Vérifie dans quelles géofences actives se trouve un véhicule
// ═══════════════════════════════════════════════════════════

/// Liste des noms de zones contenant actuellement le véhicule
final vehicleCurrentZonesProvider =
    Provider.autoDispose.family<List<GpsGeofence>, String>(
  (ref, vehiculeId) {
    final geofences = ref.watch(geofencesProvider).valueOrNull ?? [];
    final fleet = ref.watch(liveFleetProvider).valueOrNull ?? [];

    final item = fleet.where((f) {
      final v = f['vehicule'] as Map<String, dynamic>?;
      return v?['id'] == vehiculeId;
    }).firstOrNull;

    if (item == null) return [];

    final lat = item['lat'] as double?;
    final lon = item['lon'] as double?;
    if (lat == null || lon == null) return [];

    return geofences
        .where((g) => g.actif && g.contains(lat, lon))
        .toList();
  },
);

// ═══════════════════════════════════════════════════════════
// 20. Résumé flotte condensé — pour le widget home dashboard
//     Retourne max 5 véhicules triés par activité (en mouvement en premier)
// ═══════════════════════════════════════════════════════════

class FleetSummaryItem {
  final String vehiculeId;
  final String nom;
  final String immat;
  final double? latitude;
  final double? longitude;
  final double? speed;
  final double? heading;
  final bool isOnline;
  final bool isMoving;
  final bool isRented;

  const FleetSummaryItem({
    required this.vehiculeId,
    required this.nom,
    required this.immat,
    this.latitude,
    this.longitude,
    this.speed,
    this.heading,
    required this.isOnline,
    required this.isMoving,
    required this.isRented,
  });
}

final fleetSummaryProvider =
    Provider.autoDispose<List<FleetSummaryItem>>((ref) {
  final fleet = ref.watch(liveFleetProvider).valueOrNull ?? [];

  final items = fleet.map((item) {
  final v = item['vehicule'] as Map<String, dynamic>;
  final pos = item['position'] as GpsPosition?;
  final speed = (item['speed'] as num?)?.toDouble();
  final isOnline = item['isOnline'] as bool? ?? false;
  final isMoving = (speed ?? 0) > 2;

  return FleetSummaryItem(
    vehiculeId: v['id'] as String,
    nom: '${v['marque']} ${v['modele']}',
    immat: v['immatriculation'] as String? ?? '',
    // Conversion explicite en double au cas où GpsPosition utilise des 'num'
    latitude: pos?.latitude?.toDouble(),   
    longitude: pos?.longitude?.toDouble(), 
    speed: speed,
    heading: (item['heading'] as num?)?.toDouble(),
    isOnline: isOnline,
    isMoving: isMoving,
    isRented: v['statut'] == 'loue',
  );
}).toList();

  // Trier : en mouvement > arrêté > hors ligne
  items.sort((a, b) {
    int score(FleetSummaryItem i) {
      if (i.isMoving) return 2;
      if (i.isOnline) return 1;
      return 0;
    }
    return score(b).compareTo(score(a));
  });

  return items.take(10).toList(); // max 10 pour le widget
});

// ── Haversine (local — évite de dépendre du provider parent) ──

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
          sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}