// lib/features/gps/data/gps_repository.dart
// Repository GPS : lie Traccar aux véhicules Supabase et gère les alertes

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../main.dart';
import '../domain/gps_models.dart';
import 'traccar_service.dart';

class GpsRepository {
  static final GpsRepository _instance = GpsRepository._internal();
  factory GpsRepository() => _instance;
  GpsRepository._internal();

  final _traccar = TraccarService();

  // ── Associer un véhicule à un boîtier Traccar ─────────────
  Future<bool> assignDeviceToVehicule({
    required String vehiculeId,
    required int traccarDeviceId,
  }) async {
    try {
      await supabase.from('vehicules').update({
        'traccar_device_id': traccarDeviceId,
      }).eq('id', vehiculeId);
      return true;
    } catch (e) {
      debugPrint('GpsRepository.assignDeviceToVehicule: $e');
      return false;
    }
  }

  /// Récupère le device_id Traccar d'un véhicule
  Future<int?> getDeviceId(String vehiculeId) async {
    try {
      final data = await supabase
          .from('vehicules')
          .select('traccar_device_id')
          .eq('id', vehiculeId)
          .single();
      return data['traccar_device_id'];
    } catch (_) {
      return null;
    }
  }

  // ── Carte live ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLiveFleet() async {
    try {
      // Récupère les véhicules avec leur device Traccar
      final vehicules = await supabase
          .from('vehicules')
          .select('id, marque, modele, immatriculation, statut, traccar_device_id')
          .not('traccar_device_id', 'is', null);

      final positions = await _traccar.getAllPositions();
      final posMap = { for (final p in positions) p.deviceId: p };

      return (vehicules as List).map((v) {
        final deviceId = v['traccar_device_id'] as int?;
        final pos = deviceId != null ? posMap[deviceId] : null;
        return {
          'vehicule': v,
          'position': pos,
          'lat':      pos?.latitude,
          'lon':      pos?.longitude,
          'speed':    pos?.speed,
          'lastSeen': pos?.fixTime,
        };
      }).where((m) => m['position'] != null).toList();
    } catch (e) {
      debugPrint('GpsRepository.getLiveFleet: $e');
      return [];
    }
  }

  // ── Stream live pour la carte ─────────────────────────────
  Stream<Map<String, dynamic>> livePositionStream() {
    return _traccar.startLiveTracking();
  }

  void stopLive() => _traccar.stopLiveTracking();

  // ── Historique de trajets ─────────────────────────────────

  Future<List<TraccarTrip>> getVehiculeTrips({
    required String vehiculeId,
    required DateTime from,
    required DateTime to,
  }) async {
    final deviceId = await getDeviceId(vehiculeId);
    if (deviceId == null) return [];
    return _traccar.getTrips(deviceId: deviceId, from: from, to: to);
  }

  Future<List<TraccarPosition>> getVehiculeTrack({
    required String vehiculeId,
    required DateTime from,
    required DateTime to,
  }) async {
    final deviceId = await getDeviceId(vehiculeId);
    if (deviceId == null) return [];
    return _traccar.getPositionsHistory(deviceId: deviceId, from: from, to: to);
  }

  // ── Alertes ────────────────────────────────────────────────

  Future<List<GpsAlerte>> getAlertes({bool nonLuesOnly = false}) async {
    try {
      var query = supabase
          .from('gps_alertes')
          .select()
          .order('date_alerte', ascending: false);
      if (nonLuesOnly) {
        final data = await supabase
            .from('gps_alertes')
            .select()
            .eq('lue', false)
            .order('date_alerte', ascending: false);
        return (data as List).map((j) => GpsAlerte.fromJson(j)).toList();
      }
      final data = await query;
      return (data as List).map((j) => GpsAlerte.fromJson(j)).toList();
    } catch (e) {
      debugPrint('GpsRepository.getAlertes: $e');
      return [];
    }
  }

  Future<void> createAlerte(GpsAlerte alerte) async {
    try {
      await supabase.from('gps_alertes').insert(alerte.toJson());
    } catch (e) {
      debugPrint('GpsRepository.createAlerte: $e');
    }
  }

  Future<void> marquerAlerteLue(String alerteId) async {
    try {
      await supabase.from('gps_alertes').update({'lue': true}).eq('id', alerteId);
    } catch (e) {
      debugPrint('GpsRepository.marquerAlerteLue: $e');
    }
  }

  // ── Kilométrage ─────────────────────────────────────────────

  Future<double> getKmParcourus({
    required String vehiculeId,
    required DateTime from,
    required DateTime to,
  }) async {
    final deviceId = await getDeviceId(vehiculeId);
    if (deviceId == null) return 0;
    final summary = await _traccar.getKmSummary(
        deviceId: deviceId, from: from, to: to);
    final dist = summary['distance'];
    return dist != null ? (dist as num).toDouble() / 1000 : 0;
  }

  /// Vérifie si un véhicule a dépassé un seuil de km et crée une alerte
  Future<void> checkKmAlerte({
    required String vehiculeId,
    required String vehiculeNom,
    required int kmSeuilAlerte,
    required int kmActuelVehicule,
  }) async {
    final deviceId = await getDeviceId(vehiculeId);
    if (deviceId == null) return;
    final pos = await _traccar.getPositionForDevice(deviceId);
    if (pos == null) return;
    final kmGps = pos.totalKm;
    if (kmGps != null && kmGps > kmSeuilAlerte) {
      final alerte = GpsAlerte(
        id:          '',
        vehiculeId:  vehiculeId,
        vehiculeNom: vehiculeNom,
        type:        'kilometrage',
        message:     'Kilométrage dépasse le seuil : ${kmGps.toStringAsFixed(0)} km (seuil: $kmSeuilAlerte km)',
        dateAlerte:  DateTime.now(),
      );
      await createAlerte(alerte);
    }
  }
}
