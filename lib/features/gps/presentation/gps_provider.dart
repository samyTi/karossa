// lib/features/gps/presentation/gps_provider.dart
// UPDATED — Ajout : FleetStats, Playback, Analytics, Géofences, Alertes unifiées

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/flespi_service.dart';
import '../data/gps_alerte_source.dart';
import '../data/gps_geofence_source.dart';
import '../data/gps_local_source.dart';
import '../data/gps_repository_impl.dart';
import '../data/gps_route_gap_filler.dart';
import '../data/route_matching_service.dart';
import '../domain/gps_alerte.dart';
import '../domain/gps_failure.dart';
import '../domain/gps_geofence.dart';
import '../domain/gps_position.dart';
import '../domain/gps_repository.dart';
import '../../../core/providers/locale_provider.dart';
import 'package:garage_auto/l10n/app_localizations.dart';

// ═══════════════════════════════════════════════════════════
// 1. Config Flespi
// ═══════════════════════════════════════════════════════════

class FlespiConfig {
  final String token;
  const FlespiConfig({required this.token});
  bool get isConfigured => token.isNotEmpty;
}

final flespiConfigProvider = FutureProvider<FlespiConfig>((ref) async {
  final showroomId = ref.watch(currentShowroomIdProvider);
  debugPrint('[GPS-DEBUG] flespiConfigProvider → currentShowroomIdProvider = "$showroomId"');
  if (showroomId == null || showroomId.isEmpty) {
    debugPrint('[GPS-DEBUG] ⚠️ Aucun showroomId disponible (profil non chargé ou '
        'utilisateur sans showroom_id) → impossible de charger le token Flespi.');
    return const FlespiConfig(token: '');
  }
  try {
    final row = await Supabase.instance.client
        .from('showrooms')
        .select('flespi_token')
        .eq('id', showroomId)
        .maybeSingle();
    final token = (row?['flespi_token'] as String?) ?? '';
    debugPrint('[GPS-DEBUG] Ligne showrooms trouvée : ${row != null}. '
        'flespi_token : ${token.isEmpty ? "❌ VIDE ou colonne NULL" : "✅ présent (${token.length} car.)"}');
    return FlespiConfig(token: token);
  } catch (e) {
    debugPrint('[GPS-DEBUG] ✗ Erreur lecture showrooms.flespi_token → $e');
    return const FlespiConfig(token: '');
  }
});

// ═══════════════════════════════════════════════════════════
// 2. Service & Repository
// ═══════════════════════════════════════════════════════════

final flespiServiceProvider = Provider<FlespiService>((ref) {
  final configAsync = ref.watch(flespiConfigProvider);
  final token = configAsync.valueOrNull?.token ?? '';
  final showroomId = ref.watch(currentShowroomIdProvider) ?? '';
  final service = FlespiService(token: token, showroomId: showroomId);
  //ref.onDispose(service.dispose);
  return service;
});

final gpsLocalSourceProvider = Provider<GpsLocalSource>((ref) {
  return GpsLocalSource(supabase: Supabase.instance.client);
});

final gpsRepositoryProvider = Provider<GpsRepository>((ref) {
  final flespi    = ref.watch(flespiServiceProvider);
  final local     = ref.watch(gpsLocalSourceProvider);
  final showroomId = ref.watch(currentShowroomIdProvider);
  return GpsRepositoryImpl(
    flespiService: flespi,
    localSource:  local,
    showroomId:   showroomId ?? '',
  );
});

// ═══════════════════════════════════════════════════════════
// 3. Flotte live
// ═══════════════════════════════════════════════════════════

final liveFleetProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(gpsRepositoryProvider).getLiveFleet();
});

// ═══════════════════════════════════════════════════════════
// 4. ★ NOUVEAU — Statistiques de flotte calculées
// ═══════════════════════════════════════════════════════════

class FleetStats {
  final int total;
  final int online;
  final int moving;
  final int stopped;
  final int offline;
  final DateTime lastRefresh;

  const FleetStats({
    required this.total,
    required this.online,
    required this.moving,
    required this.stopped,
    required this.offline,
    required this.lastRefresh,
  });

  static FleetStats empty() => FleetStats(
        total: 0, online: 0, moving: 0, stopped: 0, offline: 0,
        lastRefresh: DateTime.now(),
      );
}

final fleetStatsProvider = Provider.autoDispose<FleetStats>((ref) {
  final fleetAsync = ref.watch(liveFleetProvider);
  return fleetAsync.when(
    loading: FleetStats.empty,
    error:   (_, __) => FleetStats.empty(),
    data: (fleet) {
      int online = 0, moving = 0;
      for (final item in fleet) {
        final pos = item['position'] as GpsPosition?;
        if (pos?.isOnline == true) {
          online++;
          if ((pos!.speed ?? 0) > 2) moving++;
        }
      }
      return FleetStats(
        total:       fleet.length,
        online:      online,
        moving:      moving,
        stopped:     online - moving,
        offline:     fleet.length - online,
        lastRefresh: DateTime.now(),
      );
    },
  );
});

// ═══════════════════════════════════════════════════════════
// 5. ★ NOUVEAU — Véhicule sélectionné (sync carte ↔ liste)
// ═══════════════════════════════════════════════════════════

final selectedVehicleIdProvider = StateProvider<String?>((ref) => null);

// ═══════════════════════════════════════════════════════════
// 6. ★ NOUVEAU — Location active pour un véhicule (contexte métier)
// ═══════════════════════════════════════════════════════════

final vehicleActiveLocationProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, vehiculeId) async {
    try {
      final data = await Supabase.instance.client
          .from('locations')
          .select('id, date_debut, date_fin_prevue, statut, clients(nom, prenom, telephone)')
          .eq('vehicule_id', vehiculeId)
          .eq('statut', 'en_cours')
          .maybeSingle();
      return data;
    } catch (_) {
      return null;
    }
  },
);

// ═══════════════════════════════════════════════════════════
// 7. ★ NOUVEAU — Statistiques journalières par véhicule
// ═══════════════════════════════════════════════════════════

class DailyKmStats {
  final double kmToday;
  final double avgSpeed;
  final double maxSpeed;
  final int    movingMinutes;
  final int    stoppedMinutes;
  final List<GpsPosition> positions;

  const DailyKmStats({
    required this.kmToday,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.movingMinutes,
    required this.stoppedMinutes,
    required this.positions,
  });

  static DailyKmStats empty() => const DailyKmStats(
    kmToday: 0, avgSpeed: 0, maxSpeed: 0,
    movingMinutes: 0, stoppedMinutes: 0, positions: [],
  );
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
          sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

final dailyKmProvider = FutureProvider.autoDispose.family<DailyKmStats, String>(
  (ref, vehiculeId) async {
    // ⚠️ Bornes "aujourd'hui" en heure LOCALE (pas UTC) : sinon minuit local
    // se retrouve mal placé dans la journée UTC (décalage d'~1h en Algérie,
    // voire mauvais jour entre 23h et minuit local).
    final localNow = DateTime.now();
    final from = DateTime(localNow.year, localNow.month, localNow.day).toUtc();
    final now = localNow.toUtc();
    try {
      // ⚠️ Plafond explicite et généreux : le device peut envoyer plusieurs
      // milliers de positions par jour (ping continu, à l'arrêt comme en
      // mouvement). Sans ce paramètre, l'ancien défaut (500, triés du plus
      // ancien) coupait la journée AVANT que le trajet réel n'apparaisse,
      // d'où "aucune donnée aujourd'hui" alors que Flespi avait tout.
      final positions = await ref.watch(gpsRepositoryProvider)
          .getHistoryFromSupabase(
            vehiculeId: vehiculeId,
            from: from,
            to: now,
            limit: 20000,
          );

      if (positions.length < 2) return DailyKmStats.empty();

      double km = 0, maxSpeed = 0;
      // Mêmes corrections que periodStatsProvider : on cumule en secondes
      // (pas de division entière par segment) et on ne pondère la vitesse
      // moyenne que sur le temps de conduite réel.
      const seuilRouleKmh = 2.0;
      double drivingSpeedWeightedSum = 0;
      double drivingSeconds = 0;
      double stoppedSecondsTotal = 0;

      for (int i = 1; i < positions.length; i++) {
        final prev = positions[i - 1];
        final curr = positions[i];

        // Ignorer les fixes invalides (pas de satellite fiable / position aberrante)
        if (curr.positionValid == false || curr.gnssValid == false) continue;

        final segKm = _haversineKm(prev.latitude, prev.longitude, curr.latitude, curr.longitude);
        final gapSec = curr.fixTime.difference(prev.fixTime).inSeconds;
        if (gapSec <= 0) continue; // doublon / horodatage non croissant

        // Écart trop grand (véhicule éteint / hors ligne entre les deux
        // fixes) : on ignore le segment pour ne pas ajouter un déplacement
        // fantôme entre deux positions non liées (même filtre que
        // periodStatsProvider, absent ici auparavant).
        if (gapSec > _ecartMaxContinuPeriodStats.inSeconds) continue;

        // Filtre bruit GPS à l'arrêt : un véhicule immobile "dérive" de
        // quelques mètres entre deux fixes rapprochés → sans ce filtre, ce
        // bruit s'accumule sur des centaines de points et fausse totalement
        // le kilométrage.
        if (segKm < 0.015 && gapSec < 60) continue;

        km += segKm;
        if (curr.speed != null) {
          if (curr.speed! > maxSpeed) maxSpeed = curr.speed!;
          final dtSeconds = gapSec.toDouble();
          if (curr.speed! > seuilRouleKmh) {
            drivingSpeedWeightedSum += curr.speed! * dtSeconds;
            drivingSeconds += dtSeconds;
          } else {
            stoppedSecondsTotal += dtSeconds;
          }
        }
      }

      return DailyKmStats(
        kmToday:       km,
        avgSpeed:      drivingSeconds > 0 ? drivingSpeedWeightedSum / drivingSeconds : 0,
        maxSpeed:      maxSpeed,
        movingMinutes: (drivingSeconds / 60).round(),
        stoppedMinutes: (stoppedSecondsTotal / 60).round(),
        positions:     positions,
      );
    } catch (_) {
      return DailyKmStats.empty();
    }
  },
);

// ═══════════════════════════════════════════════════════════
// 7bis. ★ NOUVEAU — Statistiques sur une période libre (panneau analytique)
// ═══════════════════════════════════════════════════════════

enum AnalyticsPreset { today, days7, days30, custom }

/// Période sélectionnée pour le panneau analytique. Contrairement à
/// [HeatmapPeriod] (plus bas), celle-ci vit dans le ProviderScope créé par
/// `showGpsAnalyticsPanel`, donc pas de risque de collision entre véhicules.
class AnalyticsPeriod {
  final DateTime from;
  final DateTime to;
  final AnalyticsPreset preset;

  const AnalyticsPeriod({required this.from, required this.to, required this.preset});

  factory AnalyticsPeriod.today() {
    final now = DateTime.now();
    return AnalyticsPeriod(
      from: DateTime(now.year, now.month, now.day),
      to: now,
      preset: AnalyticsPreset.today,
    );
  }

  factory AnalyticsPeriod.days(int n, AnalyticsPreset preset) {
    final now = DateTime.now();
    return AnalyticsPeriod(from: now.subtract(Duration(days: n)), to: now, preset: preset);
  }

  @override
  bool operator ==(Object other) =>
      other is AnalyticsPeriod && other.from == from && other.to == to;
  @override
  int get hashCode => Object.hash(from, to);
}

final analyticsPeriodProvider =
    StateProvider.autoDispose<AnalyticsPeriod>((ref) => AnalyticsPeriod.today());

/// Statistiques génériques sur une période (from → to), même structure que
/// [DailyKmStats] mais pas limité à "aujourd'hui".
class PeriodKmStats {
  final double kmTotal;
  final double avgSpeed;
  final double maxSpeed;
  final int    movingMinutes;
  final int    stoppedMinutes;
  final List<GpsPosition> positions;

  const PeriodKmStats({
    required this.kmTotal,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.movingMinutes,
    required this.stoppedMinutes,
    required this.positions,
  });

  static PeriodKmStats empty() => const PeriodKmStats(
    kmTotal: 0, avgSpeed: 0, maxSpeed: 0,
    movingMinutes: 0, stoppedMinutes: 0, positions: [],
  );
}

class PeriodStatsParams {
  final String   vehiculeId;
  final DateTime from;
  final DateTime to;
  const PeriodStatsParams({required this.vehiculeId, required this.from, required this.to});

  @override
  bool operator ==(Object other) =>
      other is PeriodStatsParams && other.vehiculeId == vehiculeId &&
      other.from == from && other.to == to;
  @override
  int get hashCode => Object.hash(vehiculeId, from, to);
}

/// Écart de temps max entre deux points pour qu'on les relie dans le calcul
/// cinématique (km / vitesse). Au-delà : véhicule éteint / hors ligne entre
/// les deux fix → on ne trace pas de trajet fantôme entre eux.
/// Même valeur que [DrivingScoreCalculator.ecartMaxContinu] pour rester
/// cohérent avec le score de conduite.
const _ecartMaxContinuPeriodStats = Duration(minutes: 5);

final periodStatsProvider =
    FutureProvider.autoDispose.family<PeriodKmStats, PeriodStatsParams>(
  (ref, p) async {
    // Période longue → on élargit la limite pour ne pas tronquer le trajet
    // (une limite trop basse ferait mentir le "km total" affiché).
    // ⚠️ Le device peut envoyer 2000-4000+ positions par jour (ping continu,
    // à l'arrêt comme en mouvement) — l'ancien budget de 400/jour ne
    // couvrait donc qu'une fraction du premier jour de la période avant de
    // couper le reste, sous-évaluant fortement le km sur des périodes comme
    // "7 jours" (ex : 100 km réels affichés à 2 km).
    final days = p.to.difference(p.from).inDays.clamp(1, 400);
    final limit = (days * 5000).clamp(5000, 200000);

    final raw = await ref.watch(gpsRepositoryProvider).getHistoryFromSupabase(
          vehiculeId: p.vehiculeId,
          from: p.from.toUtc(),
          to: p.to.toUtc(),
          limit: limit,
        );

    // On écarte les fix GPS non fiables (mêmes critères que Flespi expose) :
    // un point avec gnss_valid == false ou position_valid == false peut être
    // décalé de plusieurs dizaines de mètres et fausser le km/vitesse.
    final positions = raw
        .where((pos) => pos.gnssValid != false && pos.positionValid != false)
        .toList()
      ..sort((a, b) => a.fixTime.compareTo(b.fixTime));

    if (positions.length < 2) return PeriodKmStats.empty();

    double km = 0, maxSpeed = 0;
    // ⚠️ Deux bugs corrigés ici :
    //  1) `avgSpeed` était calculé sur TOUT le temps valide (roulé + arrêté),
    //     alors que le device pingue en continu même à l'arrêt. Sur une
    //     journée où le véhicule roule 1h et reste garé 23h, l'ancienne
    //     moyenne pondérée par le temps total tirait la vitesse moyenne vers
    //     ~0 au lieu de refléter la vitesse moyenne "en conduite". On ne
    //     pondère désormais QUE sur le temps où le véhicule roule réellement
    //     (speed > seuil).
    //  2) `movingMin`/`stoppedMin` étaient incrémentés à CHAQUE itération via
    //     `dt.inSeconds ~/ 60` (division entière). Avec un ping toutes les
    //     20-45s (dt < 60s), ce calcul valait quasi TOUJOURS 0 minute par
    //     segment → le total réel (fait de centaines de segments <60s)
    //     restait proche de zéro. On cumule maintenant en SECONDES et on ne
    //     convertit en minutes qu'une seule fois, à la fin.
    const _seuilRouleKmh = 2.0;
    double drivingSpeedWeightedSum = 0; // Σ(speed * dt) uniquement pendant la conduite
    double drivingSeconds = 0;
    double stoppedSecondsTotal = 0;

    for (int i = 1; i < positions.length; i++) {
      final prev = positions[i - 1];
      final curr = positions[i];
      final dt = curr.fixTime.difference(prev.fixTime);

      // Trou trop grand (véhicule éteint / hors ligne) : on ignore le
      // segment pour ne pas ajouter un déplacement fantôme entre deux
      // trajets non liés, ni une fausse accélération/vitesse.
      if (dt <= Duration.zero || dt > _ecartMaxContinuPeriodStats) continue;

      km += _haversineKm(prev.latitude, prev.longitude, curr.latitude, curr.longitude);

      if (curr.speed != null) {
        if (curr.speed! > maxSpeed) maxSpeed = curr.speed!;
        final dtSeconds = dt.inMilliseconds / 1000.0;
        if (curr.speed! > _seuilRouleKmh) {
          drivingSpeedWeightedSum += curr.speed! * dtSeconds;
          drivingSeconds += dtSeconds;
        } else {
          stoppedSecondsTotal += dtSeconds;
        }
      }
    }

    final movingMin  = (drivingSeconds / 60).round();
    final stoppedMin = (stoppedSecondsTotal / 60).round();

    return PeriodKmStats(
      kmTotal:        km,
      avgSpeed:       drivingSeconds > 0 ? drivingSpeedWeightedSum / drivingSeconds : 0,
      maxSpeed:       maxSpeed,
      movingMinutes:  movingMin,
      stoppedMinutes: stoppedMin,
      positions:      positions,
    );
  },
);

// ═══════════════════════════════════════════════════════════
// 8. Position live par véhicule (existant — conservé)
// ═══════════════════════════════════════════════════════════

class GpsLiveState {
  final GpsPosition? position;
  final bool         isLoading;
  final GpsFailure?  failure;

  const GpsLiveState({this.position, this.isLoading = false, this.failure});

  bool get hasError  => failure != null;
  bool get isOffline => failure is GpsOfflineFailure;

  GpsLiveState copyWith({
    GpsPosition? position, bool? isLoading, GpsFailure? failure, bool clearFailure = false,
  }) => GpsLiveState(
    position:  position  ?? this.position,
    isLoading: isLoading ?? this.isLoading,
    failure:   clearFailure ? null : (failure ?? this.failure),
  );
}

class GpsLiveNotifier extends StateNotifier<GpsLiveState> {
  final GpsRepository _repo;
  final String vehiculeId;
  final int    flespiDeviceId;

  GpsLiveNotifier({required GpsRepository repo, required this.vehiculeId, required this.flespiDeviceId})
      : _repo = repo, super(const GpsLiveState());

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final r = await _repo.fetchAndStoreLivePosition(
        flespiDeviceId: flespiDeviceId, vehiculeId: vehiculeId);
    state = GpsLiveState(position: r.position, isLoading: false, failure: r.failure);
  }

  Future<void> refreshReadOnly() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final r = await _repo.getLivePosition(flespiDeviceId, vehiculeId);
    state = GpsLiveState(position: r.position, isLoading: false, failure: r.failure);
  }
}

final gpsLiveProvider = StateNotifierProvider.family<
    GpsLiveNotifier, GpsLiveState, ({String vehiculeId, int flespiDeviceId})>(
  (ref, p) => GpsLiveNotifier(
    repo:           ref.watch(gpsRepositoryProvider),
    vehiculeId:     p.vehiculeId,
    flespiDeviceId: p.flespiDeviceId,
  ),
);

// ═══════════════════════════════════════════════════════════
// 9. Historique (existant — conservé)
// ═══════════════════════════════════════════════════════════

class GpsHistoryParams {
  final String   vehiculeId;
  final DateTime from;
  final DateTime to;
  const GpsHistoryParams({required this.vehiculeId, required this.from, required this.to});

  @override
  bool operator ==(Object other) =>
      other is GpsHistoryParams && other.vehiculeId == vehiculeId &&
      other.from == from && other.to == to;
  @override
  int get hashCode => Object.hash(vehiculeId, from, to);
}

final gpsHistoryProvider = FutureProvider.autoDispose.family<List<GpsPosition>, GpsHistoryParams>(
  (ref, p) => ref.watch(gpsRepositoryProvider)
      .getHistoryFromSupabase(vehiculeId: p.vehiculeId, from: p.from, to: p.to),
);

// ═══════════════════════════════════════════════════════════
// 10. ★ NOUVEAU — Lecture de trajet (Playback)
// ═══════════════════════════════════════════════════════════

class GpsPlaybackState {
  final List<GpsPosition> positions;
  final int         currentIndex;  // index "plancher" (point GPS courant ou précédent)
  final double      indexFraction; // 0..1 : progression vers positions[currentIndex+1]
  final bool        isPlaying;
  final double      speed; // 1.0 / 2.0 / 4.0 ... / 1024.0
  final bool        isLoading;

  /// True pendant l'appel au service de calage-route (comblement des trous
  /// GPS) — se produit juste après isLoading, avant que le trajet soit
  /// affichable. Permet d'afficher un message distinct dans l'UI.
  final bool        isFillingGaps;

  /// Reconstitution du trajet sur les trous GPS via routing — activé par
  /// défaut. Désactivable si l'utilisateur préfère voir les lignes droites
  /// brutes (ou en cas de doute sur la fiabilité du calage).
  final bool        roadSnapEnabled;

  const GpsPlaybackState({
    this.positions       = const [],
    this.currentIndex    = 0,
    this.indexFraction   = 0,
    this.isPlaying       = false,
    this.speed           = 1.0,
    this.isLoading       = false,
    this.isFillingGaps   = false,
    this.roadSnapEnabled = true,
  });

  bool get isEmpty    => positions.isEmpty;
  bool get isFinished => !isEmpty && currentIndex >= positions.length - 1;
  double get progress => (isEmpty || positions.length < 2)
      ? 0
      : ((currentIndex + indexFraction) / (positions.length - 1)).clamp(0, 1);

  /// Nombre de points reconstitués (comblement de trou) dans le trajet
  /// actuellement chargé — utile pour un petit badge informatif dans l'UI.
  int get interpolatedCount => positions.where((p) => p.isInterpolated).length;

  /// Position interpolée en continu entre currentIndex et currentIndex+1 —
  /// donne un mouvement fluide (façon Uber/Waze) même quand les points GPS
  /// bruts sont espacés de plusieurs secondes/minutes.
  GpsPosition? get current {
    if (isEmpty) return null;
    final i = currentIndex.clamp(0, positions.length - 1);
    if (indexFraction <= 0 || i >= positions.length - 1) return positions[i];
    return _interpolate(positions[i], positions[i + 1], indexFraction);
  }

  List<GpsPosition> get trail {
    if (isEmpty) return [];
    final base = positions.sublist(0, (currentIndex + 1).clamp(1, positions.length));
    final c = current;
    if (c != null && indexFraction > 0 && currentIndex < positions.length - 1) {
      return [...base, c];
    }
    return base;
  }

  static GpsPosition _interpolate(GpsPosition a, GpsPosition b, double t) {
    double lerp(double x, double y) => x + (y - x) * t;
    double? lerpN(double? x, double? y) => (x == null || y == null) ? null : x + (y - x) * t;

    final ms = a.fixTime.millisecondsSinceEpoch +
        ((b.fixTime.millisecondsSinceEpoch - a.fixTime.millisecondsSinceEpoch) * t).round();

    return GpsPosition(
      vehiculeId:    a.vehiculeId,
      latitude:      lerp(a.latitude, b.latitude),
      longitude:     lerp(a.longitude, b.longitude),
      speed:         lerpN(a.speed, b.speed) ?? b.speed,
      altitude:      lerpN(a.altitude, b.altitude),
      heading:       _lerpHeading(a.heading, b.heading, t),
      fixTime:       DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      serverTime:    b.serverTime,
      ignitionOn:    b.ignitionOn,
      batteryLevel:  b.batteryLevel,
      fuelLevel:     b.fuelLevel,
      doorOpen:      b.doorOpen,
      gnssValid:     b.gnssValid,
      positionValid: b.positionValid,
      isOnline:      b.isOnline,
    );
  }

  /// Interpolation circulaire du cap (évite un demi-tour parasite 359°→1°).
  static double? _lerpHeading(double? a, double? b, double t) {
    if (a == null || b == null) return b ?? a;
    var diff = (b - a) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (a + diff * t) % 360;
  }

  GpsPlaybackState copyWith({
    List<GpsPosition>? positions,
    int?    currentIndex,
    double? indexFraction,
    bool?   isPlaying,
    double? speed,
    bool?   isLoading,
    bool?   isFillingGaps,
    bool?   roadSnapEnabled,
  }) => GpsPlaybackState(
    positions:       positions       ?? this.positions,
    currentIndex:    currentIndex    ?? this.currentIndex,
    indexFraction:   indexFraction   ?? this.indexFraction,
    isPlaying:       isPlaying       ?? this.isPlaying,
    speed:           speed           ?? this.speed,
    isLoading:       isLoading       ?? this.isLoading,
    isFillingGaps:   isFillingGaps   ?? this.isFillingGaps,
    roadSnapEnabled: roadSnapEnabled ?? this.roadSnapEnabled,
  );
}

class GpsPlaybackNotifier extends StateNotifier<GpsPlaybackState> {
  final GpsRepository        _repo;
  final RouteMatchingService _routing;
  Timer? _timer;

  // Derniers paramètres de chargement — pour pouvoir relancer avec/sans
  // calage-route quand l'utilisateur bascule le toggle.
  String?   _lastVehiculeId;
  DateTime? _lastFrom;
  DateTime? _lastTo;
  int?      _lastLimit;

  // ~25 fps : assez fluide visuellement, sans surcharger le CPU sur mobile.
  static const _tickMs = 40;

  GpsPlaybackNotifier(this._repo, this._routing) : super(const GpsPlaybackState());

  Future<void> load({
    required String   vehiculeId,
    required DateTime from,
    required DateTime to,
    int?               limit,
  }) async {
    _lastVehiculeId = vehiculeId;
    _lastFrom = from;
    _lastTo   = to;
    _lastLimit = limit;

    _stop();
    state = state.copyWith(isLoading: true, positions: [], currentIndex: 0, indexFraction: 0);
    try {
      // Intervalle plus large qu'une journée → on élargit la limite pour ne
      // pas tronquer le trajet rejoué (plafonné pour rester fluide sur la carte).
      final days = to.difference(from).inDays.clamp(1, 400);
      final effectiveLimit = limit ?? (days * 400).clamp(2000, 15000);
      var positions = await _repo.getHistoryFromSupabase(
          vehiculeId: vehiculeId, from: from, to: to, limit: effectiveLimit);

      if (state.roadSnapEnabled && positions.length > 1) {
        state = state.copyWith(isLoading: false, isFillingGaps: true);
        // ⚠️ snapTraceToRoads recale CHAQUE point réel sur la route (dérive
        // GPS normale) puis comble les vrais trous de signal — remplace
        // l'ancien fillRoadGaps seul, qui ne traitait que les gros trous et
        // laissait passer le bruit fin une fois l'historique dense chargé.
        positions = await snapTraceToRoads(positions, routing: _routing);
      }

      state = state.copyWith(
        positions:     positions,
        currentIndex:  0,
        indexFraction: 0,
        isPlaying:     false,
        isLoading:     false,
        isFillingGaps: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, isFillingGaps: false);
    }
  }

  /// Bascule le comblement de trous par calage-route et recharge le trajet
  /// courant avec le nouveau réglage.
  Future<void> toggleRoadSnap() async {
    state = state.copyWith(roadSnapEnabled: !state.roadSnapEnabled);
    if (_lastVehiculeId != null && _lastFrom != null && _lastTo != null) {
      await load(vehiculeId: _lastVehiculeId!, from: _lastFrom!, to: _lastTo!, limit: _lastLimit);
    }
  }

  void play() {
    if (state.isEmpty) return;
    if (state.isFinished) {
      state = state.copyWith(currentIndex: 0, indexFraction: 0);
    }
    state = state.copyWith(isPlaying: true);
    _startTimer();
  }

  void pause() {
    _stop();
    state = state.copyWith(isPlaying: false);
  }

  void seek(int index) {
    state = state.copyWith(
      currentIndex:  index.clamp(0, state.positions.length - 1),
      indexFraction: 0,
    );
  }

  /// Avance ou recule de [delta] points GPS (delta négatif = recul) — utilisé
  /// par le geste multi-tap gauche/droite façon lecteur vidéo.
  void seekBy(int delta) {
    if (state.isEmpty) return;
    final next = (state.currentIndex + delta).clamp(0, state.positions.length - 1);
    state = state.copyWith(currentIndex: next, indexFraction: 0);
  }

  void setSpeed(double speed) {
    state = state.copyWith(speed: speed);
  }

  void reset() {
    _stop();
    state = state.copyWith(currentIndex: 0, indexFraction: 0, isPlaying: false);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) => _advance());
  }

  /// Avance le curseur "temps virtuel" en tenant compte du véritable écart
  /// de temps entre les deux points GPS encadrants — c'est ce qui rend la
  /// vitesse de lecture cohérente avec la réalité (et pas un simple
  /// défilement à index fixe toutes les 200ms).
  void _advance() {
    final positions = state.positions;
    if (positions.length < 2 || state.currentIndex >= positions.length - 1) {
      _finish();
      return;
    }

    var index = state.currentIndex;
    var frac  = state.indexFraction;

    // Durée du segment courant, bornée pour éviter un blocage visuel sur un
    // long arrêt (véhicule éteint plusieurs heures) ou une division par un
    // écart quasi nul.
    final segMs = positions[index + 1].fixTime
        .difference(positions[index].fixTime)
        .inMilliseconds
        .clamp(200, 120000);

    final deltaMs = _tickMs * state.speed;
    frac += deltaMs / segMs;

    while (frac >= 1 && index < positions.length - 1) {
      frac -= 1;
      index++;
      if (index >= positions.length - 1) {
        frac = 0;
        break;
      }
    }

    if (index >= positions.length - 1) {
      _finish();
      return;
    }
    state = state.copyWith(currentIndex: index, indexFraction: frac);
  }

  void _finish() {
    _stop();
    state = state.copyWith(
      currentIndex:  state.positions.isEmpty ? 0 : state.positions.length - 1,
      indexFraction: 0,
      isPlaying:     false,
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() { _stop(); super.dispose(); }
}

final routeMatchingServiceProvider =
    Provider<RouteMatchingService>((ref) => const RouteMatchingService());

final playbackProvider =
    StateNotifierProvider.autoDispose<GpsPlaybackNotifier, GpsPlaybackState>(
  (ref) => GpsPlaybackNotifier(
    ref.watch(gpsRepositoryProvider),
    ref.watch(routeMatchingServiceProvider),
  ),
);

// ═══════════════════════════════════════════════════════════
// 11. ★ Géofences — persistées dans Supabase (table gps_geofences)
// ═══════════════════════════════════════════════════════════

final geofenceSourceProvider = Provider<GpsGeofenceSource>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  return GpsGeofenceSource(
    supabase:   Supabase.instance.client,
    showroomId: showroomId ?? '',
  );
});

class GeofencesNotifier extends StateNotifier<AsyncValue<List<GpsGeofence>>> {
  final GpsGeofenceSource _source;

  GeofencesNotifier(this._source) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final list = await _source.getGeofences();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  Future<void> addGeofence(GpsGeofence geofence) async {
    final created = await _source.creerGeofence(geofence);
    state = state.whenData((list) => [created, ...list]);
  }

  Future<void> updateGeofence(GpsGeofence geofence) async {
    await _source.mettreAJourGeofence(geofence);
    state = state.whenData(
      (list) => [for (final g in list) if (g.id == geofence.id) geofence else g],
    );
  }

  Future<void> toggleActif(String id, bool actif) async {
    await _source.toggleActif(id, actif);
    state = state.whenData(
      (list) => [for (final g in list) if (g.id == id) g.copyWith(actif: actif) else g],
    );
  }

  Future<void> deleteGeofence(String id) async {
    await _source.supprimerGeofence(id);
    state = state.whenData((list) => list.where((g) => g.id != id).toList());
  }
}

final geofencesProvider =
    StateNotifierProvider<GeofencesNotifier, AsyncValue<List<GpsGeofence>>>(
  (ref) => GeofencesNotifier(ref.watch(geofenceSourceProvider)),
);

// ═══════════════════════════════════════════════════════════
// 11bis. ★ Moniteur de franchissement de zones
//     Compare chaque nouvelle position live aux géofences actives et
//     crée une alerte (type 'zone') sur chaque entrée/sortie détectée.
//     Activé une fois via `ref.read(geofenceMonitorProvider)` (ex. dans
//     GpsDashboardScreen.initState, comme autoRefreshProvider).
// ═══════════════════════════════════════════════════════════

class GeofenceMonitorNotifier extends StateNotifier<void> {
  final Ref _ref;
  // vehiculeId -> ids des zones dans lesquelles il se trouvait au dernier tick.
  // Absence de clé = pas encore observé (on évite de spammer des alertes
  // "entrée" au démarrage pour des véhicules déjà dans une zone).
  final Map<String, Set<String>> _insideCache = {};

  GeofenceMonitorNotifier(this._ref) : super(null) {
    _ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      liveFleetProvider,
      (previous, next) => next.whenData(_checkFleet),
    );
  }

  Future<void> _checkFleet(List<Map<String, dynamic>> fleet) async {
    final geofences = _ref.read(geofencesProvider).valueOrNull
        ?.where((g) => g.actif)
        .toList() ?? [];
    if (geofences.isEmpty) return;

    final alerteSource = _ref.read(gpsAlerteSourceProvider);
    bool anyChange = false;

    for (final item in fleet) {
      final pos = item['position'] as GpsPosition?;
      if (pos == null) continue;
      final v          = item['vehicule'] as Map<String, dynamic>;
      final vehiculeId = v['id'] as String;
      final vehiculeNom =
          '${v['marque']} ${v['modele']} (${v['immatriculation'] ?? ''})';

      final isFirstObservation = !_insideCache.containsKey(vehiculeId);
      final wasInside = _insideCache[vehiculeId] ?? <String>{};
      final nowInside = <String>{};

      for (final zone in geofences) {
        final inside = zone.contains(pos.latitude, pos.longitude);
        if (inside) nowInside.add(zone.id);

        if (isFirstObservation) continue; // baseline silencieuse

        final wasIn = wasInside.contains(zone.id);
        final l10n = lookupAppLocalizations(_ref.read(localeProvider));
        if (inside && !wasIn && zone.alerteEntree) {
          anyChange = true;
          await alerteSource.creerAlerte(
            vehiculeId:  vehiculeId,
            vehiculeNom: vehiculeNom,
            type:        'zone',
            message:     l10n.entreeDansLaZone(zone.nom),
          );
        } else if (!inside && wasIn && zone.alerteSortie) {
          anyChange = true;
          await alerteSource.creerAlerte(
            vehiculeId:  vehiculeId,
            vehiculeNom: vehiculeNom,
            type:        'zone',
            message:     l10n.sortieDeLaZone(zone.nom),
          );
        }
      }

      _insideCache[vehiculeId] = nowInside;
    }

    if (anyChange) {
      _ref.invalidate(unifiedAlertsProvider);
      _ref.invalidate(toutesAlertesProvider);
      _ref.invalidate(nombreAlertesNonLuesProvider);
    }
  }
}

final geofenceMonitorProvider =
    StateNotifierProvider<GeofenceMonitorNotifier, void>(
  (ref) => GeofenceMonitorNotifier(ref),
);

// ═══════════════════════════════════════════════════════════
// 12. ★ NOUVEAU — Alertes d'entretien (pour alertes unifiées)
// ═══════════════════════════════════════════════════════════

class UnifiedAlert {
  final String   id;
  final String   type;        // 'gps' | 'entretien'
  final String   subType;     // 'vitesse' / 'zone' / 'vidange' / ...
  final String   vehiculeNom;
  final String   vehiculeId;
  final String   message;
  final bool     isRead;
  final DateTime date;

  const UnifiedAlert({
    required this.id,
    required this.type,
    required this.subType,
    required this.vehiculeNom,
    required this.vehiculeId,
    required this.message,
    required this.isRead,
    required this.date,
  });
}

final unifiedAlertsProvider = FutureProvider.autoDispose<List<UnifiedAlert>>((ref) async {
  final showroomId = ref.watch(currentShowroomIdProvider);
  if (showroomId == null) return [];

  // Récupération des alertes GPS
  final gpsAlertes = await ref.watch(gpsAlerteSourceProvider).getToutesAlertes();

  // Récupération des alertes entretien
  final entretienRows = await Supabase.instance.client
      .from('alertes_entretien')
      .select('id, type_alerte, description, statut, vehicule_id, created_at, vehicules(marque, modele, immatriculation)')
      .eq('showroom_id', showroomId)
      .neq('statut', 'fait')
      .order('created_at', ascending: false)
      .limit(50);

  final unified = <UnifiedAlert>[];

  for (final a in gpsAlertes) {
    unified.add(UnifiedAlert(
      id: a.id,
      type: 'gps',
      subType: a.type,
      vehiculeNom: a.vehiculeNom,
      vehiculeId: a.vehiculeId,
      message: a.message,
      isRead: a.lue,
      date: a.dateAlerte,
    ));
  }

  for (final row in entretienRows as List<dynamic>) {
    final v = row['vehicules'] as Map<String, dynamic>?;
    final nom = v != null
        ? '${v['marque']} ${v['modele']} (${v['immatriculation'] ?? ''})'
        : 'Véhicule inconnu';
    unified.add(UnifiedAlert(
      id: row['id'] as String,
      type: 'entretien',
      subType: row['type_alerte'] as String? ?? 'autre',
      vehiculeNom: nom,
      vehiculeId: row['vehicule_id'] as String? ?? '',
      message: row['description'] as String? ?? '',
      isRead: row['statut'] == 'ignoree',
      date: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
    ));
  }

  unified.sort((a, b) => b.date.compareTo(a.date));
  return unified;
});
final unreadUnifiedCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(unifiedAlertsProvider).whenOrNull(
        data: (list) => list.where((a) => !a.isRead).length,
      ) ?? 0;
});

// ═══════════════════════════════════════════════════════════
// 13. Alertes GPS (existant — conservé)
// ═══════════════════════════════════════════════════════════

final gpsAlerteSourceProvider = Provider<GpsAlerteSource>((ref) {
  final showroomId = ref.watch(currentShowroomIdProvider);
  return GpsAlerteSource(
    supabase:   Supabase.instance.client,
    showroomId: showroomId ?? '',
  );
});

final toutesAlertesProvider = FutureProvider.autoDispose<List<GpsAlerte>>((ref) {
  return ref.watch(gpsAlerteSourceProvider).getToutesAlertes();
});

final alertesNonLuesProvider = FutureProvider.autoDispose<List<GpsAlerte>>((ref) {
  return ref.watch(gpsAlerteSourceProvider).getAlertesNonLues();
});

final nombreAlertesNonLuesProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(gpsAlerteSourceProvider).getNombreNonLues();
});

// ═══════════════════════════════════════════════════════════
// 14. ★ NOUVEAU — Auto-refresh countdown (dashboard)
// ═══════════════════════════════════════════════════════════

final refreshCountdownProvider = StateProvider<int>((ref) => 30);

class AutoRefreshNotifier extends StateNotifier<void> {
  final Ref _ref;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  static const _interval = 30;

  AutoRefreshNotifier(this._ref) : super(null) { _start(); }

  void _start() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = _ref.read(refreshCountdownProvider);
      if (current <= 1) {
        _ref.read(refreshCountdownProvider.notifier).state = _interval;
        _ref.invalidate(liveFleetProvider);
      } else {
        _ref.read(refreshCountdownProvider.notifier).state = current - 1;
      }
    });
  }

  void forceRefresh() {
    _ref.read(refreshCountdownProvider.notifier).state = _interval;
    _ref.invalidate(liveFleetProvider);
  }

  @override
  void dispose() { _refreshTimer?.cancel(); _countdownTimer?.cancel(); super.dispose(); }
}

final autoRefreshProvider = StateNotifierProvider<AutoRefreshNotifier, void>(
  (ref) => AutoRefreshNotifier(ref),
);

// ═══════════════════════════════════════════════════════════
// 15. ★ Heat map — positions de toute la flotte sur une période
// ═══════════════════════════════════════════════════════════

enum HeatmapPreset { today, days7, days30, custom }

class HeatmapPeriod {
  final DateTime from;
  final DateTime to;
  final HeatmapPreset preset;

  const HeatmapPeriod({required this.from, required this.to, required this.preset});

  factory HeatmapPeriod.today() {
    final now = DateTime.now();
    return HeatmapPeriod(
      from: DateTime(now.year, now.month, now.day),
      to:   now,
      preset: HeatmapPreset.today,
    );
  }

  factory HeatmapPeriod.days(int n, HeatmapPreset preset) {
    final now = DateTime.now();
    return HeatmapPeriod(from: now.subtract(Duration(days: n)), to: now, preset: preset);
  }

  @override
  bool operator ==(Object other) =>
      other is HeatmapPeriod && other.from == from && other.to == to;
  @override
  int get hashCode => Object.hash(from, to);
}

final heatmapPeriodProvider =
    StateProvider.autoDispose<HeatmapPeriod>((ref) => HeatmapPeriod.days(7, HeatmapPreset.days7));

final fleetHeatmapProvider =
    FutureProvider.autoDispose.family<List<GpsPosition>, HeatmapPeriod>(
  (ref, period) => ref.watch(gpsRepositoryProvider).getFleetHistoryForPeriod(
        from: period.from,
        to:   period.to,
      ),
);