// lib/features/gps/data/route_matching_service.dart
//
// ★ NOUVEAU — Calage sur route (map matching / routing) pour combler les
//   trous GPS (ex : tunnel, zone d'ombre sur autoroute pendant ~30s).
//
// 100% GRATUIT : utilise le serveur de démo public OSRM (project-osrm.org),
// un projet open-source, sans clé API ni carte bancaire. C'est ce qui est
// utilisé par défaut ici et qui restera gratuit.
//
// Seule limite : ce serveur démo est partagé par tout le monde, donc pas de
// garantie de disponibilité/vitesse en cas de très gros volume. Si un jour
// c'est un problème, la solution reste gratuite : héberger sa propre
// instance OSRM (logiciel open-source, aucune licence à payer) sur un petit
// serveur — le seul coût est celui du serveur lui-même, pas un coût par
// requête. Il suffirait de changer `baseUrl` ci-dessous, rien d'autre à
// modifier dans le reste du module.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RouteMatchingService {
  /// Serveur OSRM public et gratuit — profil "driving". Optionnel : tu peux
  /// pointer vers ta propre instance OSRM (aussi gratuite, open-source) si
  /// tu en héberges une un jour, sinon celle-ci suffit.
  final String baseUrl;

  const RouteMatchingService({this.baseUrl = 'https://router.project-osrm.org'});

  /// Retourne le chemin routier le plus probable entre deux points, sous
  /// forme de liste de [lat, lon], ou `null` si le service échoue / ne
  /// trouve pas de route plausible (on retombe alors sur une ligne droite).
  Future<List<List<double>>?> getRoadPath({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) async {
    final url = Uri.parse(
      '$baseUrl/route/v1/driving/'
      '$fromLon,$fromLat;$toLon,$toLat'
      '?overview=full&geometries=geojson&steps=false',
    );
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) {
        debugPrint('[GPS-DEBUG] RouteMatchingService HTTP ${res.statusCode}');
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final geometry = routes.first['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List<dynamic>?;
      if (coords == null || coords.length < 2) return null;

      // GeoJSON = [lon, lat] → on repasse en [lat, lon] pour rester cohérent
      // avec le reste du module (GpsPosition.latitude/longitude, LatLng...).
      return coords
          .map((c) => [(c[1] as num).toDouble(), (c[0] as num).toDouble()])
          .toList();
    } catch (e) {
      debugPrint('[GPS-DEBUG] RouteMatchingService erreur : $e');
      return null;
    }
  }

  /// Recale une trace de points GPS bruts sur le réseau routier (map
  /// matching, endpoint OSRM `/match`) — contrairement à [getRoadPath] qui
  /// route seulement entre 2 points, celui-ci corrige la dérive GPS de
  /// CHAQUE point de la trace (typiquement 5-20m, plus en zone urbaine
  /// dense) pour qu'il tombe sur la route la plus probable.
  ///
  /// Retourne une liste de même longueur que [points], `null` par élément
  /// non apparié avec confiance (on garde alors sa position brute d'origine)
  /// ou `null` global si l'appel échoue entièrement (repli sur les points
  /// bruts, comme avant).
  Future<List<List<double>?>?> matchTrace(
    List<({double lat, double lon, DateTime time})> points, {
    double radiusMeters = 30,
  }) async {
    if (points.length < 2) return null;

    final coords     = points.map((p) => '${p.lon},${p.lat}').join(';');
    final timestamps = points.map((p) => p.time.millisecondsSinceEpoch ~/ 1000).join(';');
    final radiuses   = List.filled(points.length, radiusMeters.toStringAsFixed(0)).join(';');

    final url = Uri.parse(
      '$baseUrl/match/v1/driving/$coords'
      '?overview=false&geometries=geojson&timestamps=$timestamps&radiuses=$radiuses',
    );
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint('[GPS-DEBUG] RouteMatchingService.matchTrace HTTP ${res.statusCode}');
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;

      final tracepoints = data['tracepoints'] as List<dynamic>?;
      if (tracepoints == null || tracepoints.length != points.length) return null;

      return tracepoints.map((tp) {
        if (tp == null) return null; // point non apparié avec confiance
        final loc = (tp as Map<String, dynamic>)['location'] as List<dynamic>?;
        if (loc == null || loc.length < 2) return null;
        return [(loc[1] as num).toDouble(), (loc[0] as num).toDouble()]; // [lat, lon]
      }).toList();
    } catch (e) {
      debugPrint('[GPS-DEBUG] RouteMatchingService.matchTrace erreur : $e');
      return null;
    }
  }
}
