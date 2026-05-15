// lib/features/gps/presentation/gps_provider.dart
//
// Providers Riverpod du module GPS.
// Le token Flespi est chargé depuis showroom_settings (Supabase) — jamais hardcodé.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/flespi_service.dart';
import '../data/gps_alerte_source.dart';
import '../data/gps_local_source.dart';
import '../data/gps_repository_impl.dart';
import '../domain/gps_alerte.dart';
import '../domain/gps_position.dart';
import '../domain/gps_repository.dart';
import '../domain/gps_failure.dart';

// ─────────────────────────────────────────────────────────
// 1. Config Flespi — chargée depuis showroom_settings
// ─────────────────────────────────────────────────────────

class FlespiConfig {
  final String token;
  const FlespiConfig({required this.token});
  bool get isConfigured => token.isNotEmpty;
}

/// Charge la config Flespi depuis la table showroom_settings.
/// Retourne une config vide si non configurée.
final flespiConfigProvider = FutureProvider<FlespiConfig>((ref) async {
  try {
    final row = await Supabase.instance.client
        .from('showroom_settings')
        .select('flespi_token')
        .maybeSingle();

    final token = (row?['flespi_token'] as String?) ?? '';
    return FlespiConfig(token: token);
  } catch (_) {
    return const FlespiConfig(token: '');
  }
});

// ─────────────────────────────────────────────────────────
// 2. Service & Repository
// ─────────────────────────────────────────────────────────

final flespiServiceProvider = Provider<FlespiService>((ref) {
  final configAsync = ref.watch(flespiConfigProvider);
  final token = configAsync.valueOrNull?.token ?? '';
  final service = FlespiService(token: token);
  ref.onDispose(service.dispose);
  return service;
});

final gpsLocalSourceProvider = Provider<GpsLocalSource>((ref) {
  return GpsLocalSource(supabase: Supabase.instance.client);
});

final gpsRepositoryProvider = Provider<GpsRepository>((ref) {
  return GpsRepositoryImpl(
    flespiService: ref.watch(flespiServiceProvider),
    localSource:   ref.watch(gpsLocalSourceProvider),
  );
});

// ─────────────────────────────────────────────────────────
// 3. Flotte live
// ─────────────────────────────────────────────────────────

/// Liste de tous les véhicules avec leur position GPS actuelle.
final liveFleetProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(gpsRepositoryProvider).getLiveFleet();
});

// ─────────────────────────────────────────────────────────
// 4. Position live par véhicule — StateNotifier
// ─────────────────────────────────────────────────────────

class GpsLiveState {
  final GpsPosition? position;
  final bool isLoading;
  final GpsFailure? failure;

  const GpsLiveState({
    this.position,
    this.isLoading = false,
    this.failure,
  });

  bool get hasError  => failure != null;
  bool get isOffline => failure is GpsOfflineFailure;

  GpsLiveState copyWith({
    GpsPosition? position,
    bool? isLoading,
    GpsFailure? failure,
    bool clearFailure = false,
  }) {
    return GpsLiveState(
      position:  position  ?? this.position,
      isLoading: isLoading ?? this.isLoading,
      failure:   clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class GpsLiveNotifier extends StateNotifier<GpsLiveState> {
  final GpsRepository _repo;
  final String vehiculeId;
  final int flespiDeviceId;

  GpsLiveNotifier({
    required GpsRepository repo,
    required this.vehiculeId,
    required this.flespiDeviceId,
  })  : _repo = repo,
        super(const GpsLiveState());

  /// Rafraîchit ET stocke dans Supabase
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _repo.fetchAndStoreLivePosition(
      flespiDeviceId: flespiDeviceId,
      vehiculeId:     vehiculeId,
    );
    state = GpsLiveState(
      position:  result.position,
      isLoading: false,
      failure:   result.failure,
    );
  }

  /// Lecture seule sans stocker
  Future<void> refreshReadOnly() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _repo.getLivePosition(flespiDeviceId, vehiculeId);
    state = GpsLiveState(
      position:  result.position,
      isLoading: false,
      failure:   result.failure,
    );
  }
}

final gpsLiveProvider = StateNotifierProvider.family<
    GpsLiveNotifier,
    GpsLiveState,
    ({String vehiculeId, int flespiDeviceId})>(
  (ref, params) => GpsLiveNotifier(
    repo:           ref.watch(gpsRepositoryProvider),
    vehiculeId:     params.vehiculeId,
    flespiDeviceId: params.flespiDeviceId,
  ),
);

// ─────────────────────────────────────────────────────────
// 5. Historique d'un véhicule (pour le tracé de parcours)
// ─────────────────────────────────────────────────────────

class GpsHistoryParams {
  final String vehiculeId;
  final DateTime from;
  final DateTime to;

  const GpsHistoryParams({
    required this.vehiculeId,
    required this.from,
    required this.to,
  });

  @override
  bool operator ==(Object other) =>
      other is GpsHistoryParams &&
      other.vehiculeId == vehiculeId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(vehiculeId, from, to);
}

final gpsHistoryProvider =
    FutureProvider.autoDispose.family<List<GpsPosition>, GpsHistoryParams>(
  (ref, params) => ref.watch(gpsRepositoryProvider).getHistoryFromSupabase(
        vehiculeId: params.vehiculeId,
        from:       params.from,
        to:         params.to,
      ),
);

// ─────────────────────────────────────────────────────────
// 6. Alertes GPS
// ─────────────────────────────────────────────────────────

final gpsAlerteSourceProvider = Provider<GpsAlerteSource>((ref) {
  return GpsAlerteSource(supabase: Supabase.instance.client);
});

/// Toutes les alertes (lues + non lues), triées par date décroissante.
final toutesAlertesProvider = FutureProvider.autoDispose<List<GpsAlerte>>((ref) {
  return ref.watch(gpsAlerteSourceProvider).getToutesAlertes();
});

/// Alertes non lues uniquement — pour le contenu filtré.
final alertesNonLuesProvider = FutureProvider.autoDispose<List<GpsAlerte>>((ref) {
  return ref.watch(gpsAlerteSourceProvider).getAlertesNonLues();
});

/// Nombre d'alertes non lues — pour le badge dans la navigation.
final nombreAlertesNonLuesProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(gpsAlerteSourceProvider).getNombreNonLues();
});
