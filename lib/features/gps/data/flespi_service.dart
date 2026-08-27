// lib/features/gps/data/flespi_service.dart
//
// ────────────────────────────────────────────────────────────────────────────
// ENDPOINTS FLESPI
// ────────────────────────────────────────────────────────────────────────────
//
//  ① GET /gw/devices/{id}/telemetry
//     → Dernier état connu (position + télémétrie) pour la vue live.
//     Réponse : {"result":[{"id":X,"telemetry":{"field":{"value":V,"ts":T},...}}]}
//     ✅ C'est LE bon endpoint pour "où est mon véhicule maintenant".
//
//  ② GET /gw/devices/{id}/messages?from=T1&to=T2&count=N
//     → Historique paginé (playback, sync Supabase).
//     ✅ Toujours fournir from+to, sinon Flespi retourne tout l'historique.
//
//  ❌ /gw/devices/{id}/logs → audit logs de plateforme (config, events).
//     NE PAS utiliser pour la télémétrie GPS.
//
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/gps_failure.dart';

class FlespiService {
  static const String _baseUrl = 'https://flespi.io';

  final String _token;
  final String _showroomId;

  FlespiService({required String token, required String showroomId})
      : _token = token, _showroomId = showroomId {
    debugPrint('[GPS-DEBUG] FlespiService créé — token: '
        '${_token.isEmpty ? "❌ VIDE" : "✅ présent (${_token.length} car., "
            "commence par \"${_token.substring(0, _token.length < 6 ? _token.length : 6)}...\")"}');
  }

  // ── ① Télémétrie actuelle (DERNIER ÉTAT CONNU) ───────────────────────────
  //
  // Retourne un Map<String, dynamic> avec les champs Flespi à plat :
  // { "position.latitude": 36.6, "position.speed": 0, "engine.ignition.status": true, ... }
  // Le "ts" le plus récent parmi les champs est utilisé comme server_timestamp.

  Future<Map<String, dynamic>> getLastTelemetry(int deviceId) async {
    // Toutes plateformes → proxy via Supabase Edge Function.
    // (CORS ne concerne que le web, mais l'appel direct depuis un appareil
    // natif est aussi problématique : le token Flespi ne doit jamais être
    // exposé côté client, et certains tokens sont restreints par IP à
    // l'Edge Function. Un seul chemin de code = un seul comportement partout.)
    return _telemetryViaProxy(deviceId);
  }

  // ── ② Historique sur période (MESSAGES) ─────────────────────────────────
  //
  // ⚠️ Toujours fournir from ET to.
  //    Sans eux, Flespi retourne tout l'historique (potentiellement 100k+ msgs).

  Future<List<Map<String, dynamic>>> getMessages(
    int deviceId, {
    required DateTime from,
    required DateTime to,
    int maxMessages = 10000,
  }) async {
    // Toutes plateformes → proxy via Supabase Edge Function (voir
    // getLastTelemetry() pour le détail des raisons).
    return _messagesViaProxy(deviceId, from: from, to: to, maxMessages: maxMessages);
  }

  Future<Map<String, dynamic>> _telemetryViaProxy(int deviceId) async {
    debugPrint('[GPS-DEBUG] → Edge Function flespi-proxy telemetry device=$deviceId');
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'flespi-proxy',
        body: {'action': 'telemetry', 'deviceId': deviceId, 'showroomId': _showroomId},
      );
      final body = response.data as Map<String, dynamic>;
      if (body.containsKey('error')) {
        final msg = body['error'] as String;
        if (msg.contains('401')) throw const GpsUnauthorizedFailure();
        if (msg.contains('404')) throw GpsDeviceNotFoundFailure('Device $deviceId introuvable.');
        throw GpsUnknownFailure(msg);
      }
      final result = body['result'] as List<dynamic>?;
      if (result == null || result.isEmpty) throw const GpsNoDataFailure();
      final telemetry = (result.first as Map<String, dynamic>)['telemetry'] as Map<String, dynamic>?;
      if (telemetry == null || telemetry.isEmpty) throw const GpsNoDataFailure();
      final flat = <String, dynamic>{};
      int latestTs = 0;
      telemetry.forEach((key, raw) {
        final d = raw as Map<String, dynamic>;
        flat[key] = d['value'];
        flat['$key.__ts'] = d['ts'];
        final ts = (d['ts'] as num?)?.toInt() ?? 0;
        if (ts > latestTs) latestTs = ts;
      });
      flat['server.timestamp'] = latestTs > 0 ? latestTs : null;
      if (flat['position.latitude'] == null) throw const GpsOfflineFailure();
      debugPrint('[GPS-DEBUG] ✓ [proxy] device $deviceId télémétrie OK');
      return flat;
    } on GpsFailure { rethrow; }
    catch (e) { throw GpsNetworkFailure('Erreur proxy : $e'); }
  }

  Future<List<Map<String, dynamic>>> _messagesViaProxy(
    int deviceId, {
    required DateTime from,
    required DateTime to,
    int maxMessages = 10000,
  }) async {
    final fromTs = from.millisecondsSinceEpoch ~/ 1000;
    final toTs   = to.millisecondsSinceEpoch   ~/ 1000;
    debugPrint('[GPS-DEBUG] → Edge Function flespi-proxy messages device=$deviceId');
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'flespi-proxy',
        body: {
          'action': 'messages', 'deviceId': deviceId, 'showroomId': _showroomId,
          'from': fromTs, 'to': toTs, 'count': maxMessages,
        },
      );
      final body = response.data as Map<String, dynamic>;
      if (body.containsKey('error')) throw GpsUnknownFailure(body['error'] as String);
      final result = body['result'] as List<dynamic>?;
      if (result == null || result.isEmpty) throw const GpsNoDataFailure();
      return result.cast<Map<String, dynamic>>();
    } on GpsFailure { rethrow; }
    catch (e) { throw GpsNetworkFailure('Erreur proxy (messages) : $e'); }
  }

  // Plus de dispose() — on crée un client par requête, rien à fermer ici.
}