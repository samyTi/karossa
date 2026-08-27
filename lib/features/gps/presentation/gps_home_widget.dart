// lib/features/gps/presentation/gps_home_widget.dart
//
// ★ FEATURE #10 — Widget "Flotte en un coup d'œil"
//
// Mini carte interactive affichant les véhicules en temps réel.
// Conçu pour s'intégrer sur le dashboard principal sans quitter l'écran.
//
// Usage :
//   GpsFleetHomeWidget()                 // taille par défaut (220 px de haut)
//   GpsFleetHomeWidget(height: 280)      // personnalisable
//   GpsFleetHomeWidget(maxVehicles: 3)   // limite les marqueurs affichés
//
// Dépendances :
//   flutter_map, latlong2, flutter_riverpod
//   providers : fleetSummaryProvider, fleetStatsProvider,
//               refreshCountdownProvider, autoRefreshProvider

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import 'gps_provider.dart';
import 'gps_provider_additions.dart';
import '../../../core/extensions/l10n_extension.dart';

// ══════════════════════════════════════════════════════════════
// Widget public
// ══════════════════════════════════════════════════════════════

class GpsFleetHomeWidget extends ConsumerStatefulWidget {
  final double height;
  final int    maxVehicles;

  const GpsFleetHomeWidget({
    super.key,
    this.height      = 220,
    this.maxVehicles = 10,
  });

  @override
  ConsumerState<GpsFleetHomeWidget> createState() =>
      _GpsFleetHomeWidgetState();
}

class _GpsFleetHomeWidgetState extends ConsumerState<GpsFleetHomeWidget>
    with SingleTickerProviderStateMixin {
  final MapController _map = MapController();
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // Démarre l'auto-refresh partagé avec le dashboard GPS
    ref.read(autoRefreshProvider);

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fleet     = ref.watch(fleetSummaryProvider);
    final stats     = ref.watch(fleetStatsProvider);
    final countdown = ref.watch(refreshCountdownProvider);
    final isLoading = ref.watch(liveFleetProvider).isLoading;

    // Filtre les véhicules avec position connue
    final visible = fleet
        .where((v) => v.latitude != null && v.longitude != null)
        .take(widget.maxVehicles)
        .toList();

    return Card(
      margin:       EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape:        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation:    2,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            // ── CARTE ──────────────────────────────────────────
            _MiniMap(
              vehicles: visible,
              mapController: _map,
              pulse: _pulse,
            ),

            // ── GRADIENT OVERLAY (lisibilité des badges) ────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end:   Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── TITRE + STATS ──────────────────────────────────
            Positioned(
              top: 10, left: 12, right: 56,
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Flotte en direct',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _StatChip(
                    color: AppColors.secondary,
                    icon:  Icons.directions_car,
                    label: '${stats.moving}',
                    tooltip: context.l10n.enMouvement,
                  ),
                  const SizedBox(width: 4),
                  _StatChip(
                    color: AppColors.primary,
                    icon:  Icons.pause_circle,
                    label: '${stats.stopped}',
                    tooltip: 'À l\'arrêt',
                  ),
                  if (stats.offline > 0) ...[
                    const SizedBox(width: 4),
                    _StatChip(
                      color: AppColors.textSecondary,
                      icon:  Icons.wifi_off,
                      label: '${stats.offline}',
                      tooltip: context.l10n.horsLigne,
                    ),
                  ],
                ],
              ),
            ),

            // ── REFRESH INDICATOR (coin haut droit) ────────────
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: () => ref.read(autoRefreshProvider.notifier).forceRefresh(),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color:  Colors.black.withValues(alpha: 0.55),
                    shape:  BoxShape.circle,
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                value:       1 - (countdown / 30),
                                strokeWidth: 2,
                                color:       Colors.white30,
                              ),
                            ),
                            Text(
                              '$countdown',
                              style: const TextStyle(
                                color:     Colors.white,
                                fontSize:  9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            // ── LISTE MINI VÉHICULES (bas de la carte) ─────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _MiniVehicleList(
                vehicles: fleet.take(4).toList(),
                onTap: (id) {
                  // Focus sur la carte
                  final v = fleet.firstWhere((f) => f.vehiculeId == id,
                      orElse: () => fleet.first);
                  if (v.latitude != null) {
                    _map.move(LatLng(v.latitude!, v.longitude!), 14);
                  }
                },
              ),
            ),

            // ── BOUTON "Voir tout" ─────────────────────────────
            Positioned(
              bottom: 52, right: 8,
              child: GestureDetector(
                onTap: () => context.push('/gps/dashboard'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color:        AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:      AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset:     const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_full, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Mission Control',
                        style: TextStyle(
                          color:      Colors.white,
                          fontSize:   11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── ÉTAT VIDE ───────────────────────────────────────
            if (visible.isEmpty && !isLoading)
              const _EmptyFleetOverlay(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Carte flutter_map (mini)
// ══════════════════════════════════════════════════════════════

class _MiniMap extends StatelessWidget {
  final List<FleetSummaryItem> vehicles;
  final MapController          mapController;
  final AnimationController    pulse;

  const _MiniMap({
    required this.vehicles,
    required this.mapController,
    required this.pulse,
  });

  LatLng _center() {
    final pts = vehicles.where((v) => v.latitude != null);
    if (pts.isEmpty) return const LatLng(36.7372, 3.0865); // Alger défaut
    final avgLat = pts.map((v) => v.latitude!).reduce((a, b) => a + b) / pts.length;
    final avgLon = pts.map((v) => v.longitude!).reduce((a, b) => a + b) / pts.length;
    return LatLng(avgLat, avgLon);
  }

  double _zoom() {
    if (vehicles.length <= 1) return 13;
    // Spread géographique → zoom adaptatif
    final lats = vehicles.where((v) => v.latitude != null).map((v) => v.latitude!);
    final lons = vehicles.where((v) => v.longitude != null).map((v) => v.longitude!);
    final latSpread = lats.reduce(math.max) - lats.reduce(math.min);
    final lonSpread = lons.reduce(math.max) - lons.reduce(math.min);
    final spread = math.max(latSpread, lonSpread);
    if (spread < 0.01) return 13;
    if (spread < 0.05) return 11;
    if (spread < 0.2)  return 9;
    return 7;
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _center(),
        initialZoom:   _zoom(),
        interactionOptions: const InteractionOptions(
          // Désactive zoom/pan pour le widget home (navigation accidentelle)
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains:  const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.garageauto.app',
          retinaMode: RetinaMode.isHighDensity(context),
        ),
        AnimatedBuilder(
          animation: pulse,
          builder: (_, __) => MarkerLayer(
            markers: vehicles.map((v) {
              if (v.latitude == null) return null;
              return Marker(
                point:  LatLng(v.latitude!, v.longitude!),
                width:  36,
                height: 36,
                child:  _MiniMarker(
                  isMoving: v.isMoving,
                  isOnline: v.isOnline,
                  heading:  v.heading,
                  pulse:    pulse.value,
                ),
              );
            }).whereType<Marker>().toList(),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Marqueur miniature (voiture + couleur + rotation)
// ══════════════════════════════════════════════════════════════

class _MiniMarker extends StatelessWidget {
  final bool   isMoving;
  final bool   isOnline;
  final double? heading;
  final double  pulse;

  const _MiniMarker({
    required this.isMoving,
    required this.isOnline,
    required this.pulse,
    this.heading,
  });

  Color get _color {
    if (!isOnline) return AppColors.textSecondary;
    if (isMoving)  return AppColors.secondary;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final angle = heading != null ? heading! * math.pi / 180 : 0.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Halo pulsant (uniquement si en mouvement)
        if (isMoving)
          Container(
            width:  36 + 8 * pulse,
            height: 36 + 8 * pulse,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color.withValues(alpha: 0.15 * (1 - pulse * 0.5)),
            ),
          ),
        // Icône voiture rotative
        Transform.rotate(
          angle: isMoving ? angle : 0,
          child: Container(
            width:  28, height: 28,
            decoration: BoxDecoration(
              color:  _color,
              shape:  BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:      _color.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              isMoving ? Icons.navigation_rounded : Icons.directions_car,
              color: Colors.white,
              size:  14,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Liste mini véhicules en bas (fond glassmorphism)
// ══════════════════════════════════════════════════════════════

class _MiniVehicleList extends StatelessWidget {
  final List<FleetSummaryItem>      vehicles;
  final void Function(String id)    onTap;

  const _MiniVehicleList({required this.vehicles, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end:   Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.80),
            Colors.black.withValues(alpha: 0.60),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: vehicles.map((v) {
          final color = !v.isOnline
              ? AppColors.textSecondary
              : v.isMoving
                  ? AppColors.secondary
                  : AppColors.primary;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(v.vehiculeId),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color:        color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      v.isMoving ? Icons.directions_car : Icons.local_parking,
                      color: color,
                      size:  14,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      v.immat.isNotEmpty
                          ? v.immat.split(' ').last // immat courte
                          : v.nom.split(' ').first,
                      style: TextStyle(
                        color:      color,
                        fontSize:   9,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines:  1,
                      overflow:  TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (v.isMoving && v.speed != null)
                      Text(
                        '${v.speed!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color:    Colors.white54,
                          fontSize: 8,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Badge statistique compact
// ══════════════════════════════════════════════════════════════

class _StatChip extends StatelessWidget {
  final Color    color;
  final IconData icon;
  final String   label;
  final String   tooltip;

  const _StatChip({
    required this.color,
    required this.icon,
    required this.label,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color:        Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 10),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color:      color,
                fontSize:   10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// État vide
// ══════════════════════════════════════════════════════════════

class _EmptyFleetOverlay extends StatelessWidget {
  const _EmptyFleetOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color:        Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_off, color: Colors.white38, size: 32),
            SizedBox(height: 8),
            Text(
              'Aucun véhicule GPS actif',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}