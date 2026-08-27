// lib/features/gps/presentation/gps_animated_fleet_markers.dart
//
// Remplace le MarkerLayer statique de gps_fleet_map_screen.dart par :
//   • une interpolation fluide de la position à chaque refresh (les
//     véhicules "glissent" au lieu de sauter toutes les 30s) ;
//   • un regroupement (clustering) simple par grille géographique quand
//     plusieurs véhicules sont proches, pour éviter les marqueurs
//     empilés/illisibles sur une vue large.
//
// Aucune dépendance externe ajoutée (pas de flutter_map_marker_cluster ni
// flutter_map_animations) : tout est fait avec un AnimationController et
// une grille de hachage — donc pas de risque de conflit de versions.
//
// Intégration dans gps_fleet_map_screen.dart :
//
//   1. import 'gps_animated_fleet_markers.dart';
//   2. Remplacer le bloc :
//        MarkerLayer(
//          markers: fleet.map((item) { ... }).toList(),
//        )
//      par :
//        AnimatedClusteredFleetMarkers(
//          fleet: fleet,
//          selectedItem: _selectedItem,
//          mapController: _mapController,
//          onTapVehicule: (item) {
//            final lat = item['lat'] as double;
//            final lon = item['lon'] as double;
//            final isSelected = _selectedItem == item;
//            setState(() {
//              if (isSelected) {
//                _selectedItem    = null;
//                _showTrajet      = false;
//                _trajetPositions = [];
//                _trajetError     = null;
//              } else {
//                _selectedItem    = item;
//                _showTrajet      = false;
//                _trajetPositions = [];
//                _trajetError     = null;
//              }
//            });
//            if (!isSelected) _mapController.move(LatLng(lat, lon), 14);
//          },
//        )

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';

class AnimatedClusteredFleetMarkers extends StatefulWidget {
  final List<Map<String, dynamic>> fleet;
  final Map<String, dynamic>? selectedItem;
  final MapController mapController;
  final void Function(Map<String, dynamic> item) onTapVehicule;

  const AnimatedClusteredFleetMarkers({
    super.key,
    required this.fleet,
    required this.selectedItem,
    required this.mapController,
    required this.onTapVehicule,
  });

  @override
  State<AnimatedClusteredFleetMarkers> createState() => _AnimatedClusteredFleetMarkersState();
}

class _AnimatedClusteredFleetMarkersState extends State<AnimatedClusteredFleetMarkers>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  final Map<String, LatLng> _from = {};
  final Map<String, LatLng> _to = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.fleet) {
      final id = _idOf(item);
      if (id == null) continue;
      final p = LatLng(item['lat'] as double, item['lon'] as double);
      _from[id] = p;
      _to[id] = p;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedClusteredFleetMarkers oldWidget) {
    super.didUpdateWidget(oldWidget);
    var hasMovement = false;

    for (final item in widget.fleet) {
      final id = _idOf(item);
      if (id == null) continue;
      final target = LatLng(item['lat'] as double, item['lon'] as double);
      final previousTarget = _to[id];

      if (previousTarget == null) {
        // Nouveau véhicule sur la carte : apparaît directement, pas d'anim.
        _from[id] = target;
        _to[id] = target;
        continue;
      }
      if (previousTarget.latitude != target.latitude ||
          previousTarget.longitude != target.longitude) {
        _from[id] = _currentLatLng(id) ?? previousTarget;
        _to[id] = target;
        hasMovement = true;
      }
    }

    if (hasMovement) {
      _anim
        ..stop()
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  String? _idOf(Map<String, dynamic> item) {
    final vehicule = item['vehicule'];
    if (vehicule is Map && vehicule['id'] is String) return vehicule['id'] as String;
    return null;
  }

  LatLng? _currentLatLng(String id) {
    final a = _from[id];
    final b = _to[id];
    if (a == null || b == null) return null;
    final t = Curves.easeInOut.transform(_anim.value);
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  /// Taille de cellule de clustering en degrés, selon le niveau de zoom.
  /// Plus le zoom est faible (vue large), plus les cellules sont grandes.
  double _cellSizeDegrees(double zoom) {
    final z = zoom.clamp(3, 18);
    return 4.0 / math.pow(2, z - 3);
  }

  double _currentZoom() {
    try {
      return widget.mapController.camera.zoom;
    } catch (_) {
      return 13;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final zoom = _currentZoom();
        final cell = _cellSizeDegrees(zoom);

        // Regroupement par cellule de grille.
        final clusters = <String, List<Map<String, dynamic>>>{};
        for (final item in widget.fleet) {
          final id = _idOf(item);
          final pos = id != null ? (_currentLatLng(id) ?? LatLng(item['lat'] as double, item['lon'] as double))
                                  : LatLng(item['lat'] as double, item['lon'] as double);
          final key = '${(pos.latitude / cell).floor()}_${(pos.longitude / cell).floor()}';
          clusters.putIfAbsent(key, () => []).add(item);
        }

        final selectedId = widget.selectedItem == null ? null : _idOf(widget.selectedItem!);
        final markers = <Marker>[];

        for (final group in clusters.values) {
          if (group.length == 1) {
            final item = group.first;
            final id = _idOf(item);
            final pos = id != null
                ? (_currentLatLng(id) ?? LatLng(item['lat'] as double, item['lon'] as double))
                : LatLng(item['lat'] as double, item['lon'] as double);
            final isSelected = id != null && id == selectedId;

            markers.add(Marker(
              point: pos,
              width: isSelected ? 56 : 48,
              height: isSelected ? 56 : 48,
              child: GestureDetector(
                onTap: () => widget.onTapVehicule(item),
                child: _VehiculeDot(
                  isMoving: (item['speed'] as double? ?? 0) > 0,
                  isOnline: item['isOnline'] as bool? ?? false,
                  isSelected: isSelected,
                  heading: item['heading'] as double?,
                ),
              ),
            ));
          } else {
            // Cluster : centroïde du groupe.
            final avgLat = group.map((i) {
                  final id = _idOf(i);
                  return id != null
                      ? (_currentLatLng(id)?.latitude ?? i['lat'] as double)
                      : i['lat'] as double;
                }).reduce((a, b) => a + b) /
                group.length;
            final avgLon = group.map((i) {
                  final id = _idOf(i);
                  return id != null
                      ? (_currentLatLng(id)?.longitude ?? i['lon'] as double)
                      : i['lon'] as double;
                }).reduce((a, b) => a + b) /
                group.length;
            final centroid = LatLng(avgLat, avgLon);

            markers.add(Marker(
              point: centroid,
              width: 52,
              height: 52,
              child: GestureDetector(
                onTap: () => widget.mapController.move(centroid, math.min(zoom + 2.5, 18)),
                child: _ClusterBubble(count: group.length),
              ),
            ));
          }
        }

        return MarkerLayer(markers: markers);
      },
    );
  }
}

class _VehiculeDot extends StatelessWidget {
  final bool isMoving;
  final bool isOnline;
  final bool isSelected;
  final double? heading;

  const _VehiculeDot({
    required this.isMoving,
    required this.isOnline,
    required this.isSelected,
    this.heading,
  });

  @override
  Widget build(BuildContext context) {
    Color markerColor;
    if (!isOnline) {
      markerColor = AppColors.textSecondary;
    } else if (isMoving) {
      markerColor = AppColors.secondary;
    } else {
      markerColor = AppColors.primary;
    }

    return Container(
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
          width: isSelected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSelected ? 0.35 : 0.2),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isMoving ? Icons.navigation : Icons.directions_car,
        color: Colors.white,
        size: isSelected ? 26 : 22,
      ),
    );
  }
}

class _ClusterBubble extends StatelessWidget {
  final int count;
  const _ClusterBubble({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }
}
