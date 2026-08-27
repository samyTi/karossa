// lib/features/gps/domain/gps_geofence.dart
//
// Modèle de zone géographique (géofence) — cercle défini par un centre + un rayon.
// Persisté dans Supabase via gps_geofence_source.dart.
// Table : voir migrations/gps_geofences_migration.sql

import 'dart:math' as math;
import 'package:flutter/material.dart';

class GpsGeofence {
  final String id;
  final String nom;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final Color  color;
  final bool   alerteEntree;
  final bool   alerteSortie;
  final bool   actif;

  const GpsGeofence({
    required this.id,
    required this.nom,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.color,
    this.alerteEntree = true,
    this.alerteSortie = true,
    this.actif        = true,
  });

  GpsGeofence copyWith({
    String? nom,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    Color?  color,
    bool?   alerteEntree,
    bool?   alerteSortie,
    bool?   actif,
  }) => GpsGeofence(
    id:            id,
    nom:           nom           ?? this.nom,
    latitude:      latitude      ?? this.latitude,
    longitude:     longitude     ?? this.longitude,
    radiusMeters:  radiusMeters  ?? this.radiusMeters,
    color:         color         ?? this.color,
    alerteEntree:  alerteEntree  ?? this.alerteEntree,
    alerteSortie:  alerteSortie  ?? this.alerteSortie,
    actif:         actif         ?? this.actif,
  );

  /// Distance en mètres entre le centre de la zone et un point donné (haversine).
  double distanceMeters(double lat, double lon) {
    const earthRadius = 6371000.0; // mètres
    final dLat = (lat - latitude) * math.pi / 180;
    final dLon = (lon - longitude) * math.pi / 180;
    final lat1 = latitude * math.pi / 180;
    final lat2 = lat * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Vérifie si une position est dans la zone.
  bool contains(double lat, double lon) => distanceMeters(lat, lon) <= radiusMeters;

  factory GpsGeofence.fromJson(Map<String, dynamic> json) => GpsGeofence(
    id:           json['id']            as String,
    nom:          json['nom']           as String,
    latitude:     (json['latitude']     as num).toDouble(),
    longitude:    (json['longitude']    as num).toDouble(),
    radiusMeters: (json['radius_m']     as num).toDouble(),
    color:        Color(int.parse(
        (json['color_hex'] as String? ?? '#2563EB').replaceFirst('#', '0xFF'))),
    alerteEntree: json['alerte_entree'] as bool? ?? true,
    alerteSortie: json['alerte_sortie'] as bool? ?? true,
    actif:        json['actif']         as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id':           id,
    'nom':          nom,
    'latitude':     latitude,
    'longitude':    longitude,
    'radius_m':     radiusMeters.toInt(),
    'color_hex':    '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
    'alerte_entree': alerteEntree,
    'alerte_sortie': alerteSortie,
    'actif':         actif,
  };
}