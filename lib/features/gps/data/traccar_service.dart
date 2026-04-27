// lib/features/gps/data/traccar_service.dart
// Client HTTP + WebSocket pour l'API Traccar
// Les credentials sont récupérés depuis la base de données Supabase

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../main.dart';
import '../domain/gps_models.dart';

class TraccarService {
  // ── Singleton ──────────────────────────────────────────────
  static final TraccarService _instance = TraccarService._internal();
  factory TraccarService() => _instance;
  TraccarService._internal();

  // ═══════════════════════════════════════════════════════════
  // Les credentials sont chargés depuis la table 'settings'
  // Si aucun credential n'est configuré, utilise l'URL par défaut
  // ═══════════════════════════════════════════════════════════
  
  static const String _defaultUrl = 'https://demo.traccar.org';
  
  String _traccarUrl = _defaultUrl;
  String? _traccarUser;
  String? _traccarPassword;
  bool _credentialsLoaded = false;
  bool _credentialsInitialized = false;

  // ── Internals ──────────────────────────────────────────────
  WebSocketChannel? _wsChannel;
  StreamController<Map<String, dynamic>>? _wsController;
  final Map<int, TraccarPosition> _lastPositions = {};
  final Map<int, TraccarDevice> _devices = {};

  /// Initialise les credentials depuis la base de données
  Future<void> _ensureCredentials() async {
    if (_credentialsInitialized) return;
    await _loadCredentials();
    _credentialsInitialized = true;
  }

  Future<void> _loadCredentials() async {
    if (_credentialsLoaded) return;

    try {
      final response = await supabase
          .from('showroom_settings')
          .select('traccar_url, traccar_user, traccar_password')
          .maybeSingle();

      if (response != null) {
        _traccarUrl = (response['traccar_url'] as String?) ?? _defaultUrl;
        _traccarUser = response['traccar_user'] as String?;
        _traccarPassword = response['traccar_password'] as String?;

        debugPrint('Traccar credentials chargés depuis la BDD: url=$_traccarUrl');
      } else {
        debugPrint('Aucun credential Traccar en BDD, utilisation des valeurs par défaut');
      }
    } catch (e) {
      debugPrint('Erreur chargement credentials Traccar: $e');
    }

    _credentialsLoaded = true;
  }

  /// Recharge les credentials (à appeler après modification dans settings)
  Future<void> reloadCredentials() async {
    _credentialsLoaded = false;
    _credentialsInitialized = false;
    await _loadCredentials();
    _credentialsInitialized = true;
  }

  String get _baseUrl => _traccarUrl;

  String get _wsBaseUrl {
    return _traccarUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
  }

  String? get _authHeaderValue {
    if (_traccarUser == null || _traccarPassword == null) return null;
    return 'Basic ${base64Encode(utf8.encode('$_traccarUser:$_traccarPassword'))}';
  }

  Map<String, String> get _headers {
    final auth = _authHeaderValue;
    return {
      if (auth != null && auth.isNotEmpty) 'Authorization': auth,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // ══ DEVICES ═══════════════════════════════════════════════

  /// Récupère tous les boîtiers GPS
  Future<List<TraccarDevice>> getDevices() async {
    await _ensureCredentials();
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/devices'),
        headers: _headers,
      );
      if (resp.statusCode != 200) throw Exception('Erreur ${resp.statusCode}');
      final List data = jsonDecode(resp.body);
      final devices = data.map((j) => TraccarDevice.fromJson(j)).toList();
      for (final d in devices) { _devices[d.id] = d; }
      return devices;
    } catch (e) {
      debugPrint('TraccarService.getDevices: $e');
      return [];
    }
  }

  /// Récupère un boîtier par immatriculation (uniqueId)
  Future<TraccarDevice?> getDeviceByImmat(String immat) async {
    final devices = await getDevices();
    try {
      return devices.firstWhere((d) => d.uniqueId == immat);
    } catch (_) {
      return null;
    }
  }

  // ══ POSITIONS ═════════════════════════════════════════════

  /// Positions actuelles de tous les boîtiers
  Future<List<TraccarPosition>> getAllPositions() async {
    await _ensureCredentials();
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/positions'),
        headers: _headers,
      );
      if (resp.statusCode != 200) throw Exception('Erreur ${resp.statusCode}');
      final List data = jsonDecode(resp.body);
      final positions = data.map((j) => TraccarPosition.fromJson(j)).toList();
      for (final p in positions) { _lastPositions[p.deviceId] = p; }
      return positions;
    } catch (e) {
      debugPrint('TraccarService.getAllPositions: $e');
      return [];
    }
  }

  /// Position actuelle d'un boîtier spécifique
  Future<TraccarPosition?> getPositionForDevice(int deviceId) async {
    await _ensureCredentials();
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/positions?deviceId=$deviceId'),
        headers: _headers,
      );
      if (resp.statusCode != 200) return null;
      final List data = jsonDecode(resp.body);
      if (data.isEmpty) return null;
      final pos = TraccarPosition.fromJson(data.first);
      _lastPositions[deviceId] = pos;
      return pos;
    } catch (e) {
      debugPrint('TraccarService.getPositionForDevice: $e');
      return null;
    }
  }

  /// Dernière position connue (cache local)
  TraccarPosition? getCachedPosition(int deviceId) => _lastPositions[deviceId];

  // ══ WEBSOCKET LIVE ════════════════════════════════════════

  /// Démarre l'écoute WebSocket (positions + événements en temps réel)
  Stream<Map<String, dynamic>> startLiveTracking() async* {
    await _ensureCredentials();

    final wsUrl = '$_wsBaseUrl/api/socket';
    debugPrint('Tentative de connexion WebSocket: $wsUrl');

    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsChannel = channel;

      yield* channel.stream.map((data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json.containsKey('positions')) {
            for (final p in (json['positions'] as List)) {
              final pos = TraccarPosition.fromJson(p);
              _lastPositions[pos.deviceId] = pos;
            }
          }
          return json;
        } catch (_) {
          return {'error': true, 'message': 'Erreur parsing WebSocket'};
        }
      }).handleError((e) {
        debugPrint('WebSocket error: $e');
      });
    } catch (e) {
      debugPrint('TraccarService.startLiveTracking: $e');
      yield {'error': true, 'message': 'Impossible de se connecter au serveur GPS'};
    }
  }

  void stopLiveTracking() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _wsController?.close();
    _wsController = null;
  }

  // ══ RAPPORTS ══════════════════════════════════════════════

  /// Historique des trajets d'un boîtier
  Future<List<TraccarTrip>> getTrips({
    required int deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    await _ensureCredentials();
    try {
      final fromStr = from.toUtc().toIso8601String();
      final toStr = to.toUtc().toIso8601String();
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/reports/trips'
            '?deviceId=$deviceId&from=$fromStr&to=$toStr'),
        headers: _headers,
      );
      if (resp.statusCode != 200) return [];
      final List data = jsonDecode(resp.body);
      return data.map((j) => TraccarTrip.fromJson(j)).toList();
    } catch (e) {
      debugPrint('TraccarService.getTrips: $e');
      return [];
    }
  }

  /// Historique complet des positions (pour dessiner la route)
  Future<List<TraccarPosition>> getPositionsHistory({
    required int deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    await _ensureCredentials();
    try {
      final fromStr = from.toUtc().toIso8601String();
      final toStr = to.toUtc().toIso8601String();
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/positions'
            '?deviceId=$deviceId&from=$fromStr&to=$toStr'),
        headers: _headers,
      );
      if (resp.statusCode != 200) return [];
      final List data = jsonDecode(resp.body);
      return data.map((j) => TraccarPosition.fromJson(j)).toList();
    } catch (e) {
      debugPrint('TraccarService.getPositionsHistory: $e');
      return [];
    }
  }

  /// Résumé kilométrique d'un boîtier sur une période
  Future<Map<String, dynamic>> getKmSummary({
    required int deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    await _ensureCredentials();
    try {
      final fromStr = from.toUtc().toIso8601String();
      final toStr = to.toUtc().toIso8601String();
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/reports/summary'
            '?deviceId=$deviceId&from=$fromStr&to=$toStr'),
        headers: _headers,
      );
      if (resp.statusCode != 200) return {};
      final List data = jsonDecode(resp.body);
      return data.isNotEmpty ? data.first : {};
    } catch (e) {
      debugPrint('TraccarService.getKmSummary: $e');
      return {};
    }
  }

  // ══ ÉVÉNEMENTS ════════════════════════════════════════════

  Future<List<TraccarEvent>> getEvents({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    List<String>? types,
  }) async {
    await _ensureCredentials();
    try {
      final fromStr = from.toUtc().toIso8601String();
      final toStr = to.toUtc().toIso8601String();
      String url = '$_baseUrl/api/reports/events'
          '?deviceId=$deviceId&from=$fromStr&to=$toStr';
      if (types != null) {
        url += '&${types.map((t) => "type=$t").join("&")}';
      }
      final resp = await http.get(Uri.parse(url), headers: _headers);
      if (resp.statusCode != 200) return [];
      final List data = jsonDecode(resp.body);
      return data.map((j) => TraccarEvent.fromJson(j)).toList();
    } catch (e) {
      debugPrint('TraccarService.getEvents: $e');
      return [];
    }
  }

  // ══ GEOFENCES ═════════════════════════════════════════════

  Future<List<TraccarGeofence>> getGeofences() async {
    await _ensureCredentials();
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/geofences'),
        headers: _headers,
      );
      if (resp.statusCode != 200) return [];
      final List data = jsonDecode(resp.body);
      return data.map((j) => TraccarGeofence.fromJson(j)).toList();
    } catch (e) {
      debugPrint('TraccarService.getGeofences: $e');
      return [];
    }
  }

  /// Crée une zone circulaire autour d'un point
  Future<TraccarGeofence?> createCircleGeofence({
    required String name,
    required double lat,
    required double lon,
    required double radiusMeters,
    String description = '',
  }) async {
    await _ensureCredentials();
    try {
      final area = 'CIRCLE ($lat $lon, $radiusMeters)';
      final body = jsonEncode({
        'name': name,
        'description': description,
        'area': area,
      });
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/geofences'),
        headers: _headers,
        body: body,
      );
      if (resp.statusCode != 200) return null;
      return TraccarGeofence.fromJson(jsonDecode(resp.body));
    } catch (e) {
      debugPrint('TraccarService.createCircleGeofence: $e');
      return null;
    }
  }

  /// Associe un boîtier à une geofence
  Future<bool> linkDeviceToGeofence(int deviceId, int geofenceId) async {
    await _ensureCredentials();
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/permissions'),
        headers: _headers,
        body: jsonEncode({
          'deviceId': deviceId,
          'geofenceId': geofenceId,
        }),
      );
      return resp.statusCode == 204;
    } catch (e) {
      debugPrint('TraccarService.linkDeviceToGeofence: $e');
      return false;
    }
  }

  void dispose() {
    stopLiveTracking();
  }
}