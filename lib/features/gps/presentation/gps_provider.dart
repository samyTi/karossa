// lib/features/gps/presentation/gps_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../data/gps_repository.dart';
import '../data/traccar_service.dart';
import '../domain/gps_models.dart';

final gpsRepositoryProvider = Provider<GpsRepository>((ref) => GpsRepository(ref.watch(supabaseClientProvider)));
final traccarServiceProvider = Provider<TraccarService>((ref) => TraccarService(ref.watch(supabaseClientProvider)));

/// Liste de tous les véhicules avec leur position GPS live
final liveFleetProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(gpsRepositoryProvider).getLiveFleet();
});

/// Stream WebSocket des positions live
final livePositionStreamProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final repo = ref.watch(gpsRepositoryProvider);
  ref.onDispose(() => repo.stopLive());
  return repo.livePositionStream();
});

/// Alertes GPS non lues
final alertesNonLuesProvider = FutureProvider.autoDispose<List<GpsAlerte>>((ref) {
  return ref.watch(gpsRepositoryProvider).getAlertes(nonLuesOnly: true);
});

/// Toutes les alertes GPS
final toutesAlertesProvider = FutureProvider.autoDispose<List<GpsAlerte>>((ref) {
  return ref.watch(gpsRepositoryProvider).getAlertes();
});

/// Tous les boîtiers Traccar
final traccarDevicesProvider = FutureProvider.autoDispose<List<TraccarDevice>>((ref) {
  return ref.watch(traccarServiceProvider).getDevices();
});

/// Geofences disponibles
final geofencesProvider = FutureProvider.autoDispose<List<TraccarGeofence>>((ref) {
  return ref.watch(traccarServiceProvider).getGeofences();
});
