// lib/features/gps/data/flespi_service.dart
//
// Client HTTP bas niveau pour l'API Flespi.
// Ne connaît pas les entités du domaine — retourne des Map<String,dynamic> bruts.
// La conversion vers GpsPosition est faite dans GpsRepositoryImpl.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/gps_failure.dart';

class FlespiService {
  static const String _baseUrl = 'https://flespi.io';

  final String _token;
  final http.Client _http;

  FlespiService({required String token, http.Client? httpClient})
      : _token = token,
        _http  = httpClient ?? http.Client();

  Map<String, String> get _headers => {
    'Authorization': 'FlespiToken $_token',
    'Content-Type':  'application/json',
  };

  // ── Dernier message d'un device ──────────────────────────

  /// Retourne le dernier message GPS brut du device.
  /// Lance une [GpsFailure] en cas d'erreur.
  Future<Map<String, dynamic>> getLastMessage(int deviceId) async {
    final uri = Uri.parse('$_baseUrl/gw/devices/$deviceId/messages?count=1');
    try {
      final resp = await _http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      return _parseMessages(resp, deviceId).first;
    } on GpsFailure {
      rethrow;
    } catch (e) {
      throw GpsNetworkFailure('Erreur réseau : $e');
    }
  }

  // ── Historique sur période ────────────────────────────────

  /// Retourne la liste des messages GPS sur une période.
  Future<List<Map<String, dynamic>>> getMessages(
    int deviceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final fromTs = from.millisecondsSinceEpoch ~/ 1000;
    final toTs   = to.millisecondsSinceEpoch   ~/ 1000;
    final uri = Uri.parse(
      '$_baseUrl/gw/devices/$deviceId/messages?from=$fromTs&to=$toTs',
    );
    try {
      final resp = await _http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      return _parseMessages(resp, deviceId);
    } on GpsFailure {
      rethrow;
    } catch (e) {
      throw GpsNetworkFailure('Erreur réseau : $e');
    }
  }

  // ── Parsing interne ───────────────────────────────────────

  List<Map<String, dynamic>> _parseMessages(http.Response resp, int deviceId) {
    switch (resp.statusCode) {
      case 401:
        throw const GpsUnauthorizedFailure();
      case 404:
        throw GpsDeviceNotFoundFailure(
          'Device $deviceId introuvable sur Flespi.',
        );
    }
    if (resp.statusCode != 200) {
      throw GpsUnknownFailure('Erreur HTTP ${resp.statusCode}: ${resp.body}');
    }

    final body   = jsonDecode(resp.body) as Map<String, dynamic>;
    final result = body['result'] as List<dynamic>?;

    if (result == null || result.isEmpty) {
      throw const GpsNoDataFailure();
    }

    final messages = result.cast<Map<String, dynamic>>();

    // Vérifie que le premier message contient des coordonnées GPS
    if (messages.first['position.latitude'] == null) {
      throw const GpsOfflineFailure();
    }

    return messages;
  }

  void dispose() => _http.close();
}
