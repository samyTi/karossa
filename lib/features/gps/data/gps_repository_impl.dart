// lib/features/gps/data/gps_repository_impl.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/gps_position.dart';
import '../domain/gps_repository.dart';
import '../domain/gps_failure.dart';
import 'flespi_service.dart';
import 'gps_local_source.dart';

class GpsRepositoryImpl implements GpsRepository {
  final FlespiService  _flespi;
  final GpsLocalSource _local;
  final String showroomId;

  GpsRepositoryImpl({
    required FlespiService  flespiService,
    required GpsLocalSource localSource,
    required this.showroomId,
  })  : _flespi = flespiService,
        _local  = localSource;

  // ── Anti-rafale ─────────────────────────────────────────────────────────
  static const _minInterval = Duration(seconds: 20);
  final Map<int, DateTime>                                         _lastAttempt = {};
  final Map<int, ({GpsPosition? position, GpsFailure? failure})>  _lastResult  = {};

  // ── Position live ────────────────────────────────────────────────────────

  @override
  Future<({GpsPosition? position, GpsFailure? failure})> fetchAndStoreLivePosition({
    required int    flespiDeviceId,
    required String vehiculeId,
  }) async {
    try {
      final telemetry = await _flespi.getLastTelemetry(flespiDeviceId);
      final position  = _fromFlespiTelemetry(telemetry, vehiculeId);
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
    int    flespiDeviceId,
    String vehiculeId,
  ) async {
    // Throttle : pas plus d'une requête Flespi par device toutes les 20s
    final last = _lastAttempt[flespiDeviceId];
    if (last != null && DateTime.now().difference(last) < _minInterval) {
      debugPrint('[GPS-DEBUG] ⏱ device $flespiDeviceId : throttled '
          '(${DateTime.now().difference(last).inSeconds}s < 20s)');
      return _lastResult[flespiDeviceId] ?? (position: null, failure: null);
    }
    _lastAttempt[flespiDeviceId] = DateTime.now();

    try {
      final telemetry = await _flespi.getLastTelemetry(flespiDeviceId);
      final position  = _fromFlespiTelemetry(telemetry, vehiculeId);

      debugPrint('[GPS-DEBUG] ✓ véhicule $vehiculeId (device $flespiDeviceId) : '
          'lat=${position.latitude}, lon=${position.longitude}, '
          'speed=${position.speed} km/h, ignition=${position.ignitionOn}, '
          'battery=${position.batteryLevel}%, fuel=${position.fuelLevel}%, '
          'door=${position.doorOpen}, online=${position.isOnline}');

      final result = (position: position, failure: null as GpsFailure?);
      _lastResult[flespiDeviceId] = result;
      return result;
    } on GpsFailure catch (f) {
      debugPrint('[GPS-DEBUG] ✗ véhicule $vehiculeId (device $flespiDeviceId) : '
          '${f.runtimeType} → ${f.message}');
      final result = (position: null as GpsPosition?, failure: f);
      _lastResult[flespiDeviceId] = result;
      return result;
    } catch (e) {
      debugPrint('[GPS-DEBUG] ✗ véhicule $vehiculeId (device $flespiDeviceId) : $e');
      final result = (position: null as GpsPosition?, failure: GpsUnknownFailure('$e'));
      _lastResult[flespiDeviceId] = result;
      return result;
    }
  }

  // ── Flotte complète ──────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getLiveFleet() async {
    debugPrint('[GPS-DEBUG] getLiveFleet() → showroomId="$showroomId"');
    try {
      final vehicules = await Supabase.instance.client
          .from('vehicules')
          .select('id, marque, modele, immatriculation, statut, flespi_device_id, km_alerte_seuil, kilometrage')
          .eq('showroom_id', showroomId)
          .not('flespi_device_id', 'is', null)
          .neq('statut', 'vendu');

      final list = vehicules as List<dynamic>;
      debugPrint('[GPS-DEBUG] Supabase → ${list.length} véhicule(s) GPS.');
      for (final v in list) {
        debugPrint('[GPS-DEBUG]   • ${v['marque']} ${v['modele']} '
            '(device=${v['flespi_device_id']}, statut=${v['statut']})');
      }

      final futures = list.map((v) async {
        final deviceId = v['flespi_device_id'] as int?;
        if (deviceId == null) return null;

        final result = await getLivePosition(deviceId, v['id'] as String);
        if (result.position == null) return null;

        final locationActive = await _getActiveLocation(v['id'] as String);

        return {
          'vehicule':       v,
          'position':       result.position,
          'lat':            result.position!.latitude,
          'lon':            result.position!.longitude,
          'speed':          result.position!.speed,
          'heading':        result.position!.heading,
          'ignitionOn':     result.position!.ignitionOn,
          'batteryLevel':   result.position!.batteryLevel,
          'fuelLevel':      result.position!.fuelLevel,
          'doorOpen':       result.position!.doorOpen,
          'lastSeen':       result.position!.serverTime,
          'isOnline':       result.position!.isOnline,
          'isMoving':       result.position!.isMoving,
          'locationActive': locationActive,
        };
      });

      final results = await Future.wait(futures);
      final fleet   = results.whereType<Map<String, dynamic>>().toList();
      debugPrint('[GPS-DEBUG] getLiveFleet() terminé → '
          '${fleet.length}/${list.length} véhicule(s) avec position.');
      return fleet;
    } catch (e, st) {
      debugPrint('[GPS-DEBUG] ✗✗ getLiveFleet() exception → $e\n$st');
      return [];
    }
  }

  // ── Contexte métier : location active ────────────────────────────────────

  Future<Map<String, dynamic>?> _getActiveLocation(String vehiculeId) async {
    try {
      final rows = await Supabase.instance.client
          .from('locations')
          .select('id, date_debut, date_fin_prevue, clients(nom, prenom, telephone)')
          .eq('vehicule_id', vehiculeId)
          .eq('statut', 'en_cours')
          .order('date_debut', ascending: false)
          .limit(1);
      final list = rows as List<dynamic>;
      return list.isEmpty ? null : list.first as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Historique Supabase ───────────────────────────────────────────────────

  @override
  Future<List<GpsPosition>> getHistoryFromSupabase({
    required String   vehiculeId,
    required DateTime from,
    required DateTime to,
    int               limit = 20000,
  }) async {
    try {
      return await _local.getHistory(vehiculeId: vehiculeId, from: from, to: to, limit: limit);
    } catch (_) {
      return [];
    }
  }

  // ── Synchronisation Flespi → Supabase ────────────────────────────────────

  @override
  Future<int> syncHistoryToSupabase({
    required int      flespiDeviceId,
    required String   vehiculeId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final messages  = await _flespi.getMessages(flespiDeviceId, from: from, to: to);
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

  // ── Historique direct Flespi ──────────────────────────────────────────────

  @override
  Future<List<GpsPosition>> getHistoryFromFlespi({
    required int      flespiDeviceId,
    required String   vehiculeId,
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

  // ── Heat map ──────────────────────────────────────────────────────────────

  @override
  Future<List<GpsPosition>> getFleetHistoryForPeriod({
    required DateTime from,
    required DateTime to,
    int               limitPerVehicle = 1000,
  }) async {
    try {
      final vehicules = await Supabase.instance.client
          .from('vehicules')
          .select('id')
          .eq('showroom_id', showroomId)
          .not('flespi_device_id', 'is', null);
      final ids = (vehicules as List<dynamic>).map((v) => v['id'] as String).toList();
      if (ids.isEmpty) return [];
      return await _local.getHistoryForVehicles(
        vehiculeIds: ids, from: from, to: to,
        limit: limitPerVehicle * ids.length,
      );
    } catch (_) {
      return [];
    }
  }

  // ── Nettoyage / rétention ─────────────────────────────────────────────────

  @override
  Future<int> deletePositionsInRange({
    String?   vehiculeId,
    required DateTime from,
    required DateTime to,
  }) async {
    return await _local.deletePositionsInRange(
      showroomId: showroomId,
      vehiculeId: vehiculeId,
      from: from,
      to: to,
    );
  }

  @override
  Future<int> decimatePositions({
    String?   vehiculeId,
    required DateTime from,
    required DateTime to,
    required int intervalMinutes,
  }) async {
    return await _local.decimatePositions(
      showroomId: showroomId,
      vehiculeId: vehiculeId,
      from: from,
      to: to,
      intervalMinutes: intervalMinutes,
    );
  }

  // ── Conversion télémétrie Flespi → GpsPosition ───────────────────────────
  //
  // Utilisé pour /telemetry (live).
  // Le Map "flat" a déjà été aplati par FlespiService.getLastTelemetry().
  // Format : {"position.latitude": 36.6, "server.timestamp": 1234567890, ...}

  GpsPosition _fromFlespiTelemetry(Map<String, dynamic> flat, String vehiculeId) {
    // server.timestamp = le ts le plus récent parmi tous les champs télémétrie
    return _fromFlespiMessage(flat, vehiculeId);
  }

  // ── Conversion message Flespi → GpsPosition ──────────────────────────────
  //
  // Utilisé pour /messages (historique).
  // Format natif Flespi : {"position.latitude": V, "timestamp": T, ...}

  GpsPosition _fromFlespiMessage(Map<String, dynamic> msg, String vehiculeId) {
    final now = DateTime.now().toUtc();

    final fixTs    = msg['timestamp']        as num?;
    final serverTs = msg['server.timestamp'] as num?;

    final fixTime = fixTs != null
        ? DateTime.fromMillisecondsSinceEpoch((fixTs * 1000).toInt(), isUtc: true)
        : now;
    final serverTime = serverTs != null
        ? DateTime.fromMillisecondsSinceEpoch((serverTs * 1000).toInt(), isUtc: true)
        : fixTime; // fallback sur fixTime si server.timestamp absent

    final ignitionOn = msg['engine.ignition.status'] as bool?;
    final batteryRaw = msg['battery.level']          as num?;
    final fuelRaw    = msg['fuel.level.1']           as num?;

    // isOnline : serveur a reçu un message il y a < 30 min, OU moteur allumé
    final isOnline = now.difference(serverTime).inMinutes < 30
        || (ignitionOn ?? false);

    return GpsPosition(
      vehiculeId:    vehiculeId,
      latitude:     (msg['position.latitude']  as num).toDouble(),
      longitude:    (msg['position.longitude'] as num).toDouble(),
      speed:        (msg['position.speed']     as num?)?.toDouble(),
      altitude:     (msg['position.altitude']  as num?)?.toDouble(),
      heading:      (msg['position.direction'] as num?)?.toDouble(),
      fixTime:       fixTime,
      serverTime:    serverTime,
      ignitionOn:    ignitionOn,
      batteryLevel:  batteryRaw?.round(),
      fuelLevel:     fuelRaw?.round(),
      doorOpen:      msg['door.open.status']  as bool?,
      gnssValid:     msg['gnss.status']       as bool?,
      positionValid: msg['position.valid']    as bool?,
      isOnline:      isOnline,
    );
  }
}