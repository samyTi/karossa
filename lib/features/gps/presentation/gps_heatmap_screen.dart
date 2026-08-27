// lib/features/gps/presentation/gps_heatmap_screen.dart
//
// Écran "Heat map" : montre les zones où la flotte circule le plus.
// Agrège gps_positions (toute la flotte du showroom) sur une période
// configurable en cellules géographiques, puis rend chaque cellule comme
// un halo dont la couleur (vert→jaune→rouge) et l'opacité dépendent de
// l'intensité relative. Repose uniquement sur CircleLayer (API stable de
// flutter_map), pas de projection pixel custom → robuste aux versions.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/gps_position.dart';
import 'gps_provider.dart';

/// Taille de cellule en degrés (~167 m en latitude à l'équateur, suffisant
/// pour distinguer rues/quartiers sans exploser le nombre de cercles rendus).
const double _kCellSizeDeg = 0.0015;

class _HeatCell {
  final double lat;
  final double lon;
  final int count;
  const _HeatCell({required this.lat, required this.lon, required this.count});
}

List<_HeatCell> _aggregate(List<GpsPosition> positions) {
  final buckets = <String, List<double>>{}; // key -> [sumLat, sumLon, count]
  for (final p in positions) {
    final cellLat = (p.latitude  / _kCellSizeDeg).round();
    final cellLon = (p.longitude / _kCellSizeDeg).round();
    final key = '$cellLat:$cellLon';
    final bucket = buckets.putIfAbsent(key, () => [0, 0, 0]);
    bucket[0] += p.latitude;
    bucket[1] += p.longitude;
    bucket[2] += 1;
  }
  return buckets.values
      .map((b) => _HeatCell(lat: b[0] / b[2], lon: b[1] / b[2], count: b[2].toInt()))
      .toList();
}

Color _heatColor(double intensity) {
  // 0.0 → vert (froid) · 0.5 → jaune/orange · 1.0 → rouge (chaud)
  if (intensity < 0.5) {
    return Color.lerp(const Color(0xFF10B981), const Color(0xFFF59E0B), intensity * 2)!;
  }
  return Color.lerp(const Color(0xFFF59E0B), const Color(0xFFEF4444), (intensity - 0.5) * 2)!;
}

class GpsHeatmapScreen extends ConsumerStatefulWidget {
  const GpsHeatmapScreen({super.key});

  @override
  ConsumerState<GpsHeatmapScreen> createState() => _GpsHeatmapScreenState();
}

class _GpsHeatmapScreenState extends ConsumerState<GpsHeatmapScreen> {
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate:  now,
      locale: const Locale('fr', 'FR'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (range == null) return;
    ref.read(heatmapPeriodProvider.notifier).state = HeatmapPeriod(
      from: range.start,
      to:   DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
      preset: HeatmapPreset.custom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(heatmapPeriodProvider);
    final positionsAsync = ref.watch(fleetHeatmapProvider(period));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(36.7372, 3.0865), // Alger
              initialZoom:   11,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains:  const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.garageauto.app',
                retinaMode: RetinaMode.isHighDensity(context),
              ),
              positionsAsync.when(
                loading: () => const SizedBox.shrink(),
                error:   (_, __) => const SizedBox.shrink(),
                data: (positions) {
                  final cells = _aggregate(positions);
                  if (cells.isEmpty) return const SizedBox.shrink();
                  final maxCount = cells.map((c) => c.count).reduce((a, b) => a > b ? a : b);

                  return CircleLayer(
                    circles: cells.map((cell) {
                      final intensity = (cell.count / maxCount).clamp(0.05, 1.0).toDouble();
                      final color = _heatColor(intensity);
                      return CircleMarker(
                        point: LatLng(cell.lat, cell.lon),
                        radius: 60 + intensity * 180, // mètres — halo plus large si zone chaude
                        useRadiusInMeter: true,
                        color: color.withValues(alpha: 0.10 + intensity * 0.22),
                        borderStrokeWidth: 0,
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),

          // ── Header ───────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _Header(
              onBack: () => context.pop(),
              pointCount: positionsAsync.valueOrNull?.length,
            ),
          ),

          // ── Légende ──────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 16,
            child: const _Legend(),
          ),

          // ── Loading / erreur ─────────────────────────────────
          if (positionsAsync.isLoading)
            const Positioned(
              top: 0, left: 0, right: 0, bottom: 0,
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          if (positionsAsync.hasError)
            Positioned(
              top: 100, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(context.l10n.erreurDeChargement(positionsAsync.error.toString()),
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          if (!positionsAsync.isLoading && (positionsAsync.valueOrNull?.isEmpty ?? false))
            Positioned(
              top: 0, left: 0, right: 0, bottom: 120,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.thermostat_outlined, color: Colors.white54, size: 32),
                      const SizedBox(height: 8),
                      Text(context.l10n.aucuneDonneeGpsSurPeriode,
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                ),
              ),
            ),

          // ── Sélecteur de période ─────────────────────────────
          Positioned(
            left: 16, right: 16, bottom: 24,
            child: _PeriodSelector(
              period: period,
              onPreset: (p) => ref.read(heatmapPeriodProvider.notifier).state = p,
              onCustom: _pickCustomRange,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final int? pointCount;
  const _Header({required this.onBack, required this.pointCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4, left: 12, right: 12, bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.85), Colors.black.withValues(alpha: 0.0)],
        ),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onBack,
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
              Text(context.l10n.zonesDeCirculation, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              if (pointCount != null)
                Text(context.l10n.pointsGpsAnalyses(pointCount.toString()), style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90, height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(colors: [
                const Color(0xFF10B981),
                const Color(0xFFF59E0B),
                const Color(0xFFEF4444),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.faible, style: const TextStyle(color: Colors.white60, fontSize: 9)),
              Text(context.l10n.eleve, style: const TextStyle(color: Colors.white60, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final HeatmapPeriod period;
  final ValueChanged<HeatmapPeriod> onPreset;
  final VoidCallback onCustom;

  const _PeriodSelector({required this.period, required this.onPreset, required this.onCustom});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(child: _Chip(label: "Aujourd'hui", selected: period.preset == HeatmapPreset.today,
              onTap: () => onPreset(HeatmapPeriod.today()))),
          const SizedBox(width: 6),
          Expanded(child: _Chip(label: '7 jours', selected: period.preset == HeatmapPreset.days7,
              onTap: () => onPreset(HeatmapPeriod.days(7, HeatmapPreset.days7)))),
          const SizedBox(width: 6),
          Expanded(child: _Chip(label: '30 jours', selected: period.preset == HeatmapPreset.days30,
              onTap: () => onPreset(HeatmapPeriod.days(30, HeatmapPreset.days30)))),
          const SizedBox(width: 6),
          Expanded(
            child: _Chip(
              label: period.preset == HeatmapPreset.custom
                  ? '${DateFormat('dd/MM').format(period.from)}–${DateFormat('dd/MM').format(period.to)}'
                  : 'Personnalisé',
              selected: period.preset == HeatmapPreset.custom,
              icon: Icons.calendar_month_rounded,
              onTap: onCustom,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 13, color: Colors.white), const SizedBox(width: 4)],
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}