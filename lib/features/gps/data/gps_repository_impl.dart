// lib/features/gps/data/gps_repository_impl.dart
//
// Implémentation concrète de GpsRepository.
// Orchestre FlespiService (API) et Supabase (cache local).
// Convertit les messages Flespi bruts en entités GpsPosition du domaine.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/gps_position.dart';
import '../domain/gps_repository.dart';
import '../domain/gps_failure.dart';
import 'flespi_service.dart';
import 'gps_local_source.dart';

class GpsRepositoryImpl implements GpsRepository {
  final FlespiService  _flespi;
  final GpsLocalSource _local;

  const GpsRepositoryImpl({
    required FlespiService  flespiService,
    required GpsLocalSource localSource,
  })  : _flespi = flespiService,
        _local  = localSource;

  // ── Position live ─────────────────────────────────────────

  @override
  Future<({GpsPosition? position, GpsFailure? failure})> fetchAndStoreLivePosition({
    required int flespiDeviceId,
    required String vehiculeId,
  }) async {
    try {
      final msg      = await _flespi.getLastMessage(flespiDeviceId);
      final position = _fromFlespiMessage(msg, vehiculeId);

      await _local.upsertPosition(position);

      return (position: position, failure: null);
    } on GpsFailure catch (f) {
      return (position: null, failure: f);
    } catch (e) {
      return (position: null, failure: GpsUnknownFailure('$e'));
    }
  }

  @override
  Future<({GpsPosition? position, GpsFailure? failure})> getLivePosition(
    int flespiDeviceId,
    String vehiculeId,
  ) async {
    try {
      final msg      = await _flespi.getLastMessage(flespiDeviceId);
      final position = _fromFlespiMessage(msg, vehiculeId);
      return (position: position, failure: null);
    } on GpsFailure catch (f) {
      return (position: null, failure: f);
    } catch (e) {
      return (position: null, failure: GpsUnknownFailure('$e'));
    }
  }

  // ── Flotte complète ──────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getLiveFleet() async {
    try {
      // 1. Récupère tous les véhicules avec flespi_device_id
      final vehicules = await Supabase.instance.client
          .from('vehicules')
          .select('id, marque, modele, immatriculation, statut, flespi_device_id')
          .not('flespi_device_id', 'is', null)
          .neq('statut', 'vendu');

      // 2. Pour chaque véhicule, récupère la position live en parallèle
      final futures = (vehicules as List<dynamic>).map((v) async {
        final deviceId = v['flespi_device_id'] as int?;
        if (deviceId == null) return null;

        final result = await getLivePosition(deviceId, v['id'] as String);
        if (result.position == null) return null;

        return {
          'vehicule':  v,
          'position':  result.position,
          'lat':       result.position!.latitude,
          'lon':       result.position!.longitude,
          'speed':     result.position!.speed,
          'heading':   result.position!.heading,
          'lastSeen':  result.position!.fixTime,
          'isOnline':  result.position!.isOnline,
        };
      });

      final results = await Future.wait(futures);
      return results.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      return [];
    }
  }

  // ── Historique Supabase ───────────────────────────────────

  @override
  Future<List<GpsPosition>> getHistoryFromSupabase({
    required String vehiculeId,
    required DateTime from,
    required DateTime to,
    int limit = 500,
  }) async {
    try {
      return await _local.getHistory(
        vehiculeId: vehiculeId,
        from:       from,
        to:         to,
        limit:      limit,
      );
    } catch (_) {
      return [];
    }
  }

  // ── Synchronisation Flespi → Supabase ────────────────────

  @override
  Future<int> syncHistoryToSupabase({
    required int flespiDeviceId,
    required String vehiculeId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final messages = await _flespi.getMessages(flespiDeviceId, from: from, to: to);
      if (messages.isEmpty) return 0;

      final positions = messages
          .where((m) => m['position.latitude'] != null)
          .map((m) => _fromFlespiMessage(m, vehiculeId))
          .toList();

      if (positions.isEmpty) return 0;

      await _local.upsertPositions(positions);
      return positions.length;
    } catch (_) {
      return 0;
    }
  }

  // ── Historique direct Flespi ──────────────────────────────

  @override
  Future<List<GpsPosition>> getHistoryFromFlespi({
    required int flespiDeviceId,
    required String vehiculeId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final messages = await _flespi.getMessages(flespiDeviceId, from: from, to: to);
      return messages
          .where((m) => m['position.latitude'] != null)
          .map((m) => _fromFlespiMessage(m, vehiculeId))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Conversion Flespi → GpsPosition ──────────────────────

  GpsPosition _fromFlespiMessage(Map<String, dynamic> msg, String vehiculeId) {
    final tsRaw    = msg['timestamp'] as num?;
    final fixTime  = tsRaw != null
        ? DateTime.fromMillisecondsSinceEpoch((tsRaw * 1000).toInt(), isUtc: true)
        : DateTime.now().toUtc();
    final now      = DateTime.now().toUtc();

    return GpsPosition(
      vehiculeId:  vehiculeId,
      latitude:    (msg['position.latitude']  as num).toDouble(),
      longitude:   (msg['position.longitude'] as num).toDouble(),
      speed:       (msg['position.speed']     as num?)?.toDouble(),
      altitude:    (msg['position.altitude']  as num?)?.toDouble(),
      heading:     (msg['position.direction'] as num?)?.toDouble(),
      fixTime:     fixTime,
      serverTime:  now,
      isOnline:    now.difference(fixTime).inMinutes < 5,
    );
  }

}
