// lib/features/gps/presentation/gps_dashboard_screen.dart
//
// ★ NOUVEAU — Écran principal GPS "Mission Control"
//   • Carte plein écran + liste dépliable par-dessus
//   • Barre stats animée (en mouvement / à l'arrêt / hors ligne / countdown)
//   • Tap véhicule → zoom carte + panneau info rapide
//   • FAB multi-actions : Alertes, Playback, Géofences, Heat Map

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/gps_position.dart';
import 'gps_analytics_panel.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';
import 'gps_provider.dart';

class GpsDashboardScreen extends ConsumerStatefulWidget {
  const GpsDashboardScreen({super.key});

  @override
  ConsumerState<GpsDashboardScreen> createState() => _GpsDashboardScreenState();
}

class _GpsDashboardScreenState extends ConsumerState<GpsDashboardScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Animations
  late AnimationController _statsPulse;
  late AnimationController _markerAnim;

  @override
  void initState() {
    super.initState();
    // Déclenche le provider d'auto-refresh + le moniteur de géofences
    ref.read(autoRefreshProvider);
    ref.read(geofenceMonitorProvider);

    _statsPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _markerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _statsPulse.dispose();
    _markerAnim.dispose();
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _focusVehicle(Map<String, dynamic> item) {
    final lat = item['lat'] as double?;
    final lon = item['lon'] as double?;
    if (lat == null || lon == null) return;

    final v = item['vehicule'] as Map<String, dynamic>;
    ref.read(selectedVehicleIdProvider.notifier).state = v['id'] as String;

    _mapController.move(LatLng(lat, lon), 15);
    _sheetController.animateTo(
      0.28,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    _showVehiclePanel(item);
  }

  void _showVehiclePanel(Map<String, dynamic> item) {
    final v        = item['vehicule'] as Map<String, dynamic>;
    final pos      = item['position'] as GpsPosition?;
    final isOnline = item['isOnline'] as bool? ?? false;
    final speed    = (item['speed'] as num?)?.toDouble() ?? 0;
    final id       = v['id'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VehicleInfoSheet(
        vehiculeId:  id,
        marque:      '${v['marque']} ${v['modele']}',
        immat:       v['immatriculation'] as String? ?? '',
        position:    pos,
        isOnline:    isOnline,
        speed:       speed,
        onPlayback:  () { Navigator.pop(context); context.push('/gps/playback', extra: {'vehiculeId': id, 'nom': '${v['marque']} ${v['modele']}'}); },
        onAnalytics: () { Navigator.pop(context); showGpsAnalyticsPanel(context, vehiculeId: id, vehiculeNom: '${v['marque']} ${v['modele']}'); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fleetAsync = ref.watch(liveFleetProvider);
    final stats      = ref.watch(fleetStatsProvider);
    final countdown  = ref.watch(refreshCountdownProvider);
    final selectedId = ref.watch(selectedVehicleIdProvider);
    final alertCount = ref.watch(unreadUnifiedCountProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── CARTE (fond plein écran) ───────────────────────────
          fleetAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error:   (e, _) => _ErrorMapOverlay(message: '$e', onRetry: () => ref.invalidate(liveFleetProvider)),
            data:    (fleet) => _FleetMap(
              fleet:        fleet,
              selectedId:   selectedId,
              mapController: _mapController,
              markerAnim:   _markerAnim,
              onMarkerTap:  _focusVehicle,
            ),
          ),

          // ── APPBAR TRANSPARENTE ─────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _GlassAppBar(
              alertCount:  alertCount,
              countdown:   countdown,
              onRefresh:   () => ref.read(autoRefreshProvider.notifier).forceRefresh(),
              onAlerts:    () => context.push('/gps/alerts-center'),
              onGeofence:  () => context.push('/gps/geofences'),
            ),
          ),

          // ── BARRE STATS ANIMÉE ──────────────────────────────────
          Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
            left: 16, right: 16,
            child: _AnimatedStatsBanner(stats: stats, pulse: _statsPulse),
          ),

          // ── LISTE DÉPLIABLE (bas de l'écran) ───────────────────
          DraggableScrollableSheet(
            controller:     _sheetController,
            initialChildSize: 0.32,
            minChildSize:   0.12,
            maxChildSize:   0.72,
            snap:           true,
            snapSizes:      const [0.12, 0.32, 0.72],
            builder: (_, scrollController) => _VehicleListSheet(
              scrollController: scrollController,
              fleetAsync:  fleetAsync,
              selectedId:  selectedId,
              onVehicleTap: _focusVehicle,
            ),
          ),
        ],
      ),

      // ── FAB ─────────────────────────────────────────────────────
      floatingActionButton: _GpsFab(
        onHeatMap:  () => context.push('/gps/heatmap'),
        onGeofence: () => context.push('/gps/geofences'),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Carte flotte
// ══════════════════════════════════════════════════════════════

class _FleetMap extends StatelessWidget {
  final List<Map<String, dynamic>> fleet;
  final String? selectedId;
  final MapController mapController;
  final AnimationController markerAnim;
  final void Function(Map<String, dynamic>) onMarkerTap;

  const _FleetMap({
    required this.fleet,
    required this.selectedId,
    required this.mapController,
    required this.markerAnim,
    required this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _fleetCenter(),
        initialZoom:   fleet.length == 1 ? 14 : 10,
      ),
      children: [
        // Tuiles sombre
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains:  const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.garageauto.app',
          retinaMode: RetinaMode.isHighDensity(context),
        ),
        // Marqueurs
        MarkerLayer(
          markers: fleet.map((item) {
            final lat = item['lat'] as double?;
            final lon = item['lon'] as double?;
            if (lat == null || lon == null) return null;
            final v        = item['vehicule'] as Map<String, dynamic>;
            final id       = v['id'] as String;
            final isOnline = item['isOnline'] as bool? ?? false;
            final speed    = (item['speed'] as num?)?.toDouble() ?? 0;
            final heading  = (item['heading'] as num?)?.toDouble();
            final isMoving = speed > 2;
            final isSelected = id == selectedId;

            return Marker(
              point:  LatLng(lat, lon),
              width:  isSelected ? 60 : 44,
              height: isSelected ? 60 : 44,
              child: GestureDetector(
                onTap: () => onMarkerTap(item),
                child: AnimatedBuilder(
                  animation: markerAnim,
                  builder: (_, child) => _SmartMarker(
                    isOnline:   isOnline,
                    isMoving:   isMoving,
                    isSelected: isSelected,
                    heading:    heading,
                    pulse:      isSelected ? markerAnim.value : 0,
                    label:      v['immatriculation'] as String? ?? '',
                  ),
                ),
              ),
            );
          }).whereType<Marker>().toList(),
        ),
      ],
    );
  }

  LatLng _fleetCenter() {
    if (fleet.isEmpty) return const LatLng(36.7372, 3.0865); // Alger
    final lats = fleet.map((i) => (i['lat'] as num?)?.toDouble() ?? 0).where((v) => v != 0);
    final lons = fleet.map((i) => (i['lon'] as num?)?.toDouble() ?? 0).where((v) => v != 0);
    if (lats.isEmpty) return const LatLng(36.7372, 3.0865);
    return LatLng(
      lats.reduce((a, b) => a + b) / lats.length,
      lons.reduce((a, b) => a + b) / lons.length,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Marqueur intelligent avec rotation + pulse
// ══════════════════════════════════════════════════════════════

class _SmartMarker extends StatelessWidget {
  final bool   isOnline;
  final bool   isMoving;
  final bool   isSelected;
  final double? heading;
  final double pulse;
  final String label;

  const _SmartMarker({
    required this.isOnline,
    required this.isMoving,
    required this.isSelected,
    required this.pulse,
    required this.label,
    this.heading,
  });

  Color get _color {
    if (!isOnline) return AppColors.textSecondary;
    if (isMoving)  return AppColors.secondary;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Halo pulsant quand sélectionné
        if (isSelected)
          Container(
            width:  60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color.withValues(alpha: 0.15 + pulse * 0.15),
            ),
          ),
        // Marqueur principal
        Transform.rotate(
          angle: heading != null && isMoving
              ? (heading! - 90) * math.pi / 180
              : 0,
          child: Container(
            width:  isSelected ? 44 : 36,
            height: isSelected ? 44 : 36,
            decoration: BoxDecoration(
              color:  _color,
              shape:  BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color:      _color.withValues(alpha: 0.5),
                  blurRadius: isSelected ? 12 : 6,
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            child: Icon(
              isMoving ? Icons.navigation_rounded : Icons.directions_car,
              color: Colors.white,
              size:  isSelected ? 22 : 18,
            ),
          ),
        ),
        // Immatriculation au-dessus du marqueur
        if (isSelected && label.isNotEmpty)
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:        Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AppBar glassmorphism
// ══════════════════════════════════════════════════════════════

class _GlassAppBar extends StatelessWidget {
  final int alertCount;
  final int countdown;
  final VoidCallback onRefresh;
  final VoidCallback onAlerts;
  final VoidCallback onGeofence;

  const _GlassAppBar({
    required this.alertCount,
    required this.countdown,
    required this.onRefresh,
    required this.onAlerts,
    required this.onGeofence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top:   MediaQuery.of(context).padding.top + 4,
        left:  12, right: 12, bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          // Back
          Material(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.gpsFlotte,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.6), blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(context.l10n.syncDansSecondes(countdown.toString()),
                      style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Bouton refresh
          _GlassIconButton(
            icon: Icons.refresh_rounded,
            onTap: onRefresh,
          ),
          const SizedBox(width: 8),
          // Bouton alertes avec badge
          Stack(
            children: [
              _GlassIconButton(icon: Icons.notifications_outlined, onTap: onAlerts),
              if (alertCount > 0)
                Positioned(
                  top: 4, right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color:        AppColors.error,
                      shape:        BoxShape.circle,
                      border:       Border.all(color: Colors.black, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$alertCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          _GlassIconButton(icon: Icons.fence_rounded, onTap: onGeofence),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// Barre stats animée
// ══════════════════════════════════════════════════════════════

class _AnimatedStatsBanner extends StatelessWidget {
  final FleetStats stats;
  final AnimationController pulse;

  const _AnimatedStatsBanner({required this.stats, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatPill(count: stats.moving,  label: 'Mouvement', color: AppColors.secondary, pulse: pulse, animate: stats.moving > 0),
          _Divider(),
          _StatPill(count: stats.stopped, label: 'Arrêtés',   color: AppColors.primary),
          _Divider(),
          _StatPill(count: stats.offline, label: 'Hors ligne', color: AppColors.textSecondary),
          _Divider(),
          _StatPill(count: stats.total,   label: 'Total',     color: AppColors.accent),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final AnimationController? pulse;
  final bool animate;

  const _StatPill({required this.count, required this.label, required this.color, this.pulse, this.animate = false});

  @override
  Widget build(BuildContext context) {
    Widget dot = Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    if (animate && pulse != null) {
      dot = AnimatedBuilder(
        animation: pulse!,
        builder: (_, __) => Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5 + pulse!.value * 0.5), blurRadius: 6)],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            const SizedBox(width: 5),
            Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 28,
    color: Colors.white.withValues(alpha: 0.1),
  );
}

// ══════════════════════════════════════════════════════════════
// Feuille liste véhicules (DraggableScrollableSheet)
// ══════════════════════════════════════════════════════════════

class _VehicleListSheet extends StatelessWidget {
  final ScrollController scrollController;
  final AsyncValue<List<Map<String, dynamic>>> fleetAsync;
  final String? selectedId;
  final void Function(Map<String, dynamic>) onVehicleTap;

  const _VehicleListSheet({
    required this.scrollController,
    required this.fleetAsync,
    required this.selectedId,
    required this.onVehicleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          fleetAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.l10n.erreurAvecDetail(e.toString()), style: const TextStyle(color: AppColors.error)),
            ),
            data: (fleet) {
              if (fleet.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.gps_off, size: 40, color: AppColors.textTertiary),
                      const SizedBox(height: 8),
                      Text(context.l10n.aucunVehiculeGps, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                );
              }
              // Header count
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Flotte · ${fleet.length} véhicule${fleet.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller:  scrollController,
                        padding:     const EdgeInsets.symmetric(horizontal: 12),
                        itemCount:   fleet.length,
                        itemBuilder: (_, i) {
                          final item     = fleet[i];
                          final v        = item['vehicule'] as Map<String, dynamic>;
                          final id       = v['id'] as String;
                          final isOnline = item['isOnline'] as bool? ?? false;
                          final speed    = (item['speed'] as num?)?.toDouble() ?? 0;
                          final last     = item['lastSeen'] as DateTime?;
                          final isSelected = id == selectedId;

                          return _VehicleRow(
                            marque:      '${v['marque']} ${v['modele']}',
                            immat:       v['immatriculation'] as String? ?? '',
                            isOnline:    isOnline,
                            isMoving:    speed > 2,
                            speed:       speed,
                            lastSeen:    last,
                            isSelected:  isSelected,
                            onTap:       () => onVehicleTap(item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  final String    marque;
  final String    immat;
  final bool      isOnline;
  final bool      isMoving;
  final double    speed;
  final DateTime? lastSeen;
  final bool      isSelected;
  final VoidCallback onTap;

  const _VehicleRow({
    required this.marque,
    required this.immat,
    required this.isOnline,
    required this.isMoving,
    required this.speed,
    required this.lastSeen,
    required this.isSelected,
    required this.onTap,
  });

  Color get _statusColor {
    if (!isOnline) return AppColors.textSecondary;
    if (isMoving)  return AppColors.secondary;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:        isSelected
            ? _statusColor.withValues(alpha: 0.08)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? _statusColor.withValues(alpha: 0.4) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Icône status
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color:  _statusColor.withValues(alpha: 0.1),
                    shape:  BoxShape.circle,
                  ),
                  child: Icon(
                    isMoving ? Icons.navigation_rounded : Icons.directions_car,
                    color: _statusColor,
                    size:  20,
                  ),
                ),
                const SizedBox(width: 12),
                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(marque, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(immat,  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                // Vitesse / status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        _statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isMoving
                            ? '${speed.toStringAsFixed(0)} km/h'
                            : (isOnline ? 'Arrêté' : 'Hors ligne'),
                        style: TextStyle(
                          color:      _statusColor,
                          fontSize:   11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (lastSeen != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _ago(lastSeen!),
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'À l\'instant';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    return DateFormat('HH:mm').format(dt.toLocal());
  }
}

// ══════════════════════════════════════════════════════════════
// Bottom sheet info rapide d'un véhicule
// ══════════════════════════════════════════════════════════════

class _VehicleInfoSheet extends ConsumerWidget {
  final String      vehiculeId;
  final String      marque;
  final String      immat;
  final GpsPosition? position;
  final bool        isOnline;
  final double      speed;
  final VoidCallback onPlayback;
  final VoidCallback onAnalytics;

  const _VehicleInfoSheet({
    required this.vehiculeId,
    required this.marque,
    required this.immat,
    required this.position,
    required this.isOnline,
    required this.speed,
    required this.onPlayback,
    required this.onAnalytics,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(vehicleActiveLocationProvider(vehiculeId));
    final Color statusColor = !isOnline
        ? AppColors.textSecondary
        : (speed > 2 ? AppColors.secondary : AppColors.primary);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.directions_car, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(marque, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(immat,  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    speed > 2 ? '${speed.toStringAsFixed(0)} km/h' : (isOnline ? 'Arrêté' : 'Hors ligne'),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            // Contexte location active
            locationAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data: (loc) => loc == null ? const SizedBox.shrink() : _ActiveRentalBanner(loc: loc),
            ),

            const SizedBox(height: 16),
            // Coordonnées
            if (position != null)
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${position!.latitude.toStringAsFixed(5)}, ${position!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  if (position!.altitude != null) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.height, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${position!.altitude!.toStringAsFixed(0)} m',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),

            const SizedBox(height: 20),
            // Actions
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon:    Icons.bar_chart_rounded,
                    label:   'Analytiques',
                    color:   AppColors.primary,
                    onTap:   onAnalytics,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon:    Icons.play_circle_fill_rounded,
                    label:   'Rejouer trajet',
                    color:   AppColors.accent,
                    onTap:   onPlayback,
                  ),
                ),
              ],
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _ActiveRentalBanner extends StatelessWidget {
  final Map<String, dynamic> loc;
  const _ActiveRentalBanner({required this.loc});

  @override
  Widget build(BuildContext context) {
    final client  = loc['clients'] as Map<String, dynamic>?;
    final name    = client != null ? '${client['prenom']} ${client['nom']}' : 'Client';
    final dateFin = loc['date_fin_prevue'] as String?;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        AppColors.loue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppColors.loue.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.vpn_key_rounded, size: 16, color: AppColors.loue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'En location · $name${dateFin != null ? ' jusqu\'au ${DateFormat('dd/MM').format(DateTime.parse(dateFin))}' : ''}',
              style: const TextStyle(color: AppColors.loue, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color:        color.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// FAB multi-actions
// ══════════════════════════════════════════════════════════════

class _GpsFab extends StatefulWidget {
  final VoidCallback onHeatMap;
  final VoidCallback onGeofence;
  const _GpsFab({required this.onHeatMap, required this.onGeofence});

  @override
  State<_GpsFab> createState() => _GpsFabState();
}

class _GpsFabState extends State<_GpsFab> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open) ...[
          _FabItem(icon: Icons.thermostat_rounded, label: 'Heat Map', color: AppColors.retard, onTap: () { _toggle(); widget.onHeatMap(); }),
          const SizedBox(height: 8),
          _FabItem(icon: Icons.fence_rounded,      label: 'Zones',    color: AppColors.accent,   onTap: () { _toggle(); widget.onGeofence(); }),
          const SizedBox(height: 8),
        ],
        FloatingActionButton(
          onPressed:       _toggle,
          backgroundColor: AppColors.primary,
          child: AnimatedRotation(
            turns:    _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 250),
            child:    const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _FabItem extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _FabItem({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(width: 8),
      FloatingActionButton.small(
        heroTag:         label,
        onPressed:       onTap,
        backgroundColor: color,
        child:           Icon(icon, color: Colors.white, size: 20),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
// Erreur overlay
// ══════════════════════════════════════════════════════════════

class _ErrorMapOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorMapOverlay({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black87,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.signal_wifi_off, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white60), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon:  const Icon(Icons.refresh),
            label: Text(context.l10n.reessayer),
          ),
        ],
      ),
    ),
  );
}