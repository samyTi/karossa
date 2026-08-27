// lib/features/gps/presentation/gps_playback_screen.dart
//
// ★ NOUVEAU — Lecture animée de trajet (Playback)
//   • Rejoue le trajet d'un véhicule sur la période choisie
//   • Polyline animée (trail croissant) + marqueur rotatif
//   • Contrôles : play/pause · x1/x2/x4 · slider · sélection date

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/gps_position.dart';
import 'gps_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class GpsPlaybackScreen extends ConsumerStatefulWidget {
  /// Transmis via GoRouter extra : {'vehiculeId': id, 'nom': 'BMW 320d'}
  final String vehiculeId;
  final String vehiculeNom;

  const GpsPlaybackScreen({
    super.key,
    required this.vehiculeId,
    required this.vehiculeNom,
  });

  @override
  ConsumerState<GpsPlaybackScreen> createState() => _GpsPlaybackScreenState();
}

class _GpsPlaybackScreenState extends ConsumerState<GpsPlaybackScreen>
    with TickerProviderStateMixin {
  final MapController _map = MapController();
  late AnimationController _markerPulse;

  // Intervalle datetime précis (et non plus une simple date "jour entier").
  DateTime _from = DateTime.now().subtract(const Duration(hours: 6));
  DateTime _to   = DateTime.now();

  @override
  void initState() {
    super.initState();
    _markerPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _loadRange(_from, _to);
  }

  @override
  void dispose() {
    _markerPulse.dispose();
    _map.dispose();
    _leftResetTimer?.cancel();
    _rightResetTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRange(DateTime from, DateTime to) async {
    await ref.read(playbackProvider.notifier).load(
      vehiculeId: widget.vehiculeId,
      from:       from.toUtc(),
      to:         to.toUtc(),
    );
    // Centre la carte sur le premier point
    final state = ref.read(playbackProvider);
    if (state.positions.isNotEmpty) {
      final first = state.positions.first;
      _map.move(LatLng(first.latitude, first.longitude), 13);
    }
  }

  Future<void> _pickRange() async {
    final result = await showModalBottomSheet<({DateTime from, DateTime to})>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DateTimeRangeSheet(initialFrom: _from, initialTo: _to),
    );
    if (result != null) {
      setState(() {
        _from = result.from;
        _to   = result.to;
      });
      ref.read(playbackProvider.notifier).reset();
      _loadRange(_from, _to);
    }
  }

  void _zoomBy(double delta) {
    final z = (_map.camera.zoom + delta).clamp(2.0, 19.0);
    _map.move(_map.camera.center, z);
  }

  // ── Geste multi-tap gauche/droite (avance/recul façon lecteur vidéo) ────
  // 1 tap = 5 points, 2 taps rapprochés = +10 (donc 15 cumulé), 3 = +20
  // (35 cumulé), 4 = +40 (75 cumulé), etc. — chaque tap supplémentaire dans
  // la fenêtre double l'incrément précédent.
  int _leftTapCount = 0, _rightTapCount = 0;
  int _leftCumulative = 0, _rightCumulative = 0;
  Timer? _leftResetTimer, _rightResetTimer, _feedbackTimer;
  String? _seekFeedback;
  bool _seekFeedbackIsForward = true;

  static const _tapBurstWindow = Duration(milliseconds: 650);

  int _amountForTapIndex(int tapIndex) => 5 * (1 << (tapIndex - 1)); // 5,10,20,40,80…

  void _showSeekFeedback(int cumulative, {required bool forward}) {
    setState(() {
      _seekFeedback = '${forward ? '»»' : '««'}  $cumulative pts';
      _seekFeedbackIsForward = forward;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) setState(() => _seekFeedback = null);
    });
  }

  void _onTapRightZone() {
    _leftTapCount = 0; _leftCumulative = 0; _leftResetTimer?.cancel();
    _rightTapCount++;
    final amount = _amountForTapIndex(_rightTapCount);
    _rightCumulative += amount;
    ref.read(playbackProvider.notifier).seekBy(amount);
    _showSeekFeedback(_rightCumulative, forward: true);
    _rightResetTimer?.cancel();
    _rightResetTimer = Timer(_tapBurstWindow, () {
      _rightTapCount = 0;
      _rightCumulative = 0;
    });
  }

  void _onTapLeftZone() {
    _rightTapCount = 0; _rightCumulative = 0; _rightResetTimer?.cancel();
    _leftTapCount++;
    final amount = _amountForTapIndex(_leftTapCount);
    _leftCumulative += amount;
    ref.read(playbackProvider.notifier).seekBy(-amount);
    _showSeekFeedback(_leftCumulative, forward: false);
    _leftResetTimer?.cancel();
    _leftResetTimer = Timer(_tapBurstWindow, () {
      _leftTapCount = 0;
      _leftCumulative = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackProvider);

    // Suivi automatique du marqueur en lecture
    if (state.isPlaying && state.current != null) {
      final p = state.current!;
      _map.move(LatLng(p.latitude, p.longitude), _map.camera.zoom);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── CARTE ─────────────────────────────────────────────
          _PlaybackMap(state: state, mapController: _map, pulse: _markerPulse),

          // ── ZONES DE TAP GAUCHE/DROITE (avance/recul rapide) ──
          // Bornées verticalement pour ne pas gêner l'appbar (haut) ni les
          // contrôles de lecture (bas). Translucent → le pan/pinch de la
          // carte continue de fonctionner normalement.
          Positioned(
            top: 130, left: 0, bottom: 170,
            width: MediaQuery.of(context).size.width * 0.4,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _onTapLeftZone,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: 130, right: 0, bottom: 170,
            width: MediaQuery.of(context).size.width * 0.4,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _onTapRightZone,
              child: const SizedBox.expand(),
            ),
          ),

          // ── FEEDBACK VISUEL DU MULTI-TAP ──────────────────────
          if (_seekFeedback != null)
            Positioned(
              top: 0, bottom: 0,
              left:  _seekFeedbackIsForward ? null : 0,
              right: _seekFeedbackIsForward ? 0    : null,
              width: MediaQuery.of(context).size.width * 0.4,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _seekFeedback!,
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── ZOOM (+/-) ────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 190,
            child: _ZoomControls(
              onZoomIn:  () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
            ),
          ),

          // ── APPBAR ────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _PlaybackAppBar(
              nom:        widget.vehiculeNom,
              from:       _from,
              to:         _to,
              onPickRange: _pickRange,
              roadSnapEnabled: state.roadSnapEnabled,
              onToggleRoadSnap: () => ref.read(playbackProvider.notifier).toggleRoadSnap(),
            ),
          ),

          // ── STATUT RECONSTITUTION TRAJET (petite pastille, coin haut-droit) ──
          if (state.isFillingGaps)
            Positioned(
              top: kToolbarHeight + MediaQuery.of(context).padding.top + 78,
              right: 16,
              child: const _GapFillingBanner(),
            )
          else if (!state.isLoading && state.interpolatedCount > 0)
            Positioned(
              top: kToolbarHeight + MediaQuery.of(context).padding.top + 78,
              right: 16,
              child: _InterpolatedBadge(count: state.interpolatedCount),
            ),

          // ── INFO POSITION COURANTE ─────────────────────────────
          if (state.current != null)
            Positioned(
              top:   kToolbarHeight + MediaQuery.of(context).padding.top + 12,
              left:  16, right: 16,
              child: _CurrentPositionBadge(position: state.current!),
            ),

          // ── CONTRÔLES (bas) ───────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _PlaybackControls(
              state:    state,
              onPlay:   () => ref.read(playbackProvider.notifier).play(),
              onPause:  () => ref.read(playbackProvider.notifier).pause(),
              onSeek:   (i) => ref.read(playbackProvider.notifier).seek(i),
              onSpeed:  (s) => ref.read(playbackProvider.notifier).setSpeed(s),
              onReset:  () => ref.read(playbackProvider.notifier).reset(),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Carte de lecture
// ══════════════════════════════════════════════════════════════

class _PlaybackMap extends StatelessWidget {
  final GpsPlaybackState  state;
  final MapController     mapController;
  final AnimationController pulse;

  const _PlaybackMap({
    required this.state,
    required this.mapController,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final allPositions = state.positions;
    final trail        = state.trail;
    final current      = state.current;

    if (allPositions.isEmpty) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: Center(
          child: state.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(context.l10n.aucuneDonneePourCetteDate,
                  style: const TextStyle(color: Colors.white60)),
        ),
      );
    }

    final allLatLng = allPositions
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: LatLng(allPositions.first.latitude, allPositions.first.longitude),
        initialZoom:   13,
        minZoom: 2,
        maxZoom: 19,
        // Pinch, molette (web/desktop) et double-tap doivent rester actifs
        // même pendant la lecture animée du trajet.
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.scrollWheelZoom,
        ),
      ),
      children: [
        // Tuiles sombres
        TileLayer(
          urlTemplate:         'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains:          const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.garageauto.app',
          retinaMode: RetinaMode.isHighDensity(context),
        ),
        // Trajet complet (gris clair)
        if (allLatLng.length > 1)
          PolylineLayer(polylines: [
            Polyline(
              points:      allLatLng,
              color:       Colors.white.withValues(alpha: 0.15),
              strokeWidth: 3,
            ),
          ]),
        // Trail actif, coloré par tranche de vitesse (bleu = arrêt/lent,
        // vert = normal, orange = rapide, rouge = très rapide).
        if (trail.length > 1)
          PolylineLayer(polylines: _speedColoredSegments(trail)),
        // Point de départ
        MarkerLayer(markers: [
          Marker(
            point: LatLng(allPositions.first.latitude, allPositions.first.longitude),
            width:  28, height: 28,
            child: Container(
              decoration: BoxDecoration(
                color:  AppColors.secondary,
                shape:  BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
            ),
          ),
          // Point d'arrivée
          Marker(
            point: LatLng(allPositions.last.latitude, allPositions.last.longitude),
            width:  28, height: 28,
            child: Container(
              decoration: BoxDecoration(
                color:  AppColors.retard,
                shape:  BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.flag, color: Colors.white, size: 14),
            ),
          ),
        ]),
        // Marqueur courant animé
        if (current != null)
          MarkerLayer(markers: [
            Marker(
              point:  LatLng(current.latitude, current.longitude),
              width:  52, height: 52,
              child:  AnimatedBuilder(
                animation: pulse,
                builder:   (_, __) => _PlaybackMarker(position: current, pulse: pulse.value),
              ),
            ),
          ]),
      ],
    );
  }

  /// Découpe le trail en segments de couleur selon la vitesse instantanée,
  /// en regroupant les points consécutifs de la même tranche pour limiter
  /// le nombre de Polyline (perf) tout en gardant un rendu net.
  List<Polyline> _speedColoredSegments(List<GpsPosition> points) {
    if (points.length < 2) return const [];

    Color colorFor(double speedKmh) {
      if (speedKmh < 5)   return const Color(0xFF60A5FA); // arrêt / très lent — bleu
      if (speedKmh < 50)  return const Color(0xFF34D399); // normal — vert
      if (speedKmh < 90)  return const Color(0xFFFBBF24); // rapide — orange
      return const Color(0xFFF87171);                     // très rapide — rouge
    }

    final segments = <Polyline>[];
    var bucketStart = 0;
    var bucketColor = colorFor(points[0].speed ?? 0);

    for (var i = 1; i < points.length; i++) {
      final color = colorFor(points[i].speed ?? 0);
      if (color != bucketColor || i == points.length - 1) {
        final endIndex = (i == points.length - 1) ? i : i - 1;
        if (endIndex > bucketStart) {
          segments.add(Polyline(
            points: [
              for (var j = bucketStart; j <= endIndex; j++)
                LatLng(points[j].latitude, points[j].longitude),
            ],
            color:       bucketColor,
            strokeWidth: 4,
          ));
        }
        bucketStart  = endIndex;
        bucketColor  = color;
      }
    }
    return segments;
  }
}

class _PlaybackMarker extends StatelessWidget {
  final GpsPosition position;
  final double      pulse;

  const _PlaybackMarker({required this.position, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final heading = position.heading;
    final isMoving = (position.speed ?? 0) > 2;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Halo pulsant
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.12 + pulse * 0.12),
          ),
        ),
        Transform.rotate(
          angle: heading != null && isMoving
              ? (heading - 90) * math.pi / 180
              : 0,
          child: Container(
            width:  38, height: 38,
            decoration: BoxDecoration(
              color:  AppColors.accent,
              shape:  BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color:      AppColors.accent.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              isMoving ? Icons.navigation_rounded : Icons.directions_car,
              color: Colors.white, size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AppBar de lecture
// ══════════════════════════════════════════════════════════════

class _PlaybackAppBar extends StatelessWidget {
  final String       nom;
  final DateTime     from;
  final DateTime     to;
  final VoidCallback onPickRange;
  final bool         roadSnapEnabled;
  final VoidCallback onToggleRoadSnap;

  const _PlaybackAppBar({
    required this.nom,
    required this.from,
    required this.to,
    required this.onPickRange,
    required this.roadSnapEnabled,
    required this.onToggleRoadSnap,
  });

  String _label() {
    final sameDay = from.year == to.year && from.month == to.month && from.day == to.day;
    final dFrom = DateFormat('dd MMM HH:mm', 'fr').format(from);
    final dTo   = sameDay
        ? DateFormat('HH:mm', 'fr').format(to)
        : DateFormat('dd MMM HH:mm', 'fr').format(to);
    return '$dFrom → $dTo';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top:   MediaQuery.of(context).padding.top + 6,
        left:  12, right: 12, bottom: 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                Text(context.l10n.lectureDeTrajet, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          // Sélecteur d'intervalle datetime
          GestureDetector(
            onTap: onPickRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color:        Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white70, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    _label(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Toggle calage-route (comblement intelligent des trous GPS)
          Tooltip(
            message: roadSnapEnabled
                ? 'Reconstitution de trajet activée (tap pour désactiver)'
                : 'Reconstitution de trajet désactivée (tap pour activer)',
            child: Material(
            color: roadSnapEnabled
                ? AppColors.accent.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggleRoadSnap,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.alt_route_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Statut reconstitution de trajet (calage-route)
// ══════════════════════════════════════════════════════════════

class _GapFillingBanner extends StatelessWidget {
  const _GapFillingBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 13, height: 13,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text(context.l10n.reconstitutionDuTrajet,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _InterpolatedBadge extends StatelessWidget {
  final int count;
  const _InterpolatedBadge({required this.count});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.l10n.pointsReconstituesTooltip(count.toString()),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.alt_route_rounded, color: Colors.white70, size: 13),
          const SizedBox(width: 5),
          Text(context.l10n.countReconstitues(count.toString(), count > 1 ? 's' : ''),
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// Badge position courante
// ══════════════════════════════════════════════════════════════

class _CurrentPositionBadge extends StatelessWidget {
  final GpsPosition position;
  const _CurrentPositionBadge({required this.position});

  @override
  Widget build(BuildContext context) {
    final speed = position.speed ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:        Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, color: Colors.white60, size: 14),
          const SizedBox(width: 6),
          Text(
            DateFormat('HH:mm:ss').format(position.fixTime.toLocal()),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.speed, color: Colors.white60, size: 14),
          const SizedBox(width: 4),
          Text(
            '${speed.toStringAsFixed(0)} km/h',
            style: TextStyle(
              color:      speed > 2 ? AppColors.secondary : Colors.white60,
              fontWeight: FontWeight.w700,
              fontSize:   14,
            ),
          ),
          if (position.altitude != null) ...[
            const SizedBox(width: 16),
            const Icon(Icons.height, color: Colors.white60, size: 14),
            const SizedBox(width: 4),
            Text(
              '${position.altitude!.toStringAsFixed(0)}m',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Contrôles de zoom (+/-)
// ══════════════════════════════════════════════════════════════

class _ZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  const _ZoomControls({required this.onZoomIn, required this.onZoomOut});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ZoomBtn(icon: Icons.add, onTap: onZoomIn),
        const SizedBox(height: 8),
        _ZoomBtn(icon: Icons.remove, onTap: onZoomOut),
      ],
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.6),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// Sélecteur d'intervalle datetime (bottom sheet)
// ══════════════════════════════════════════════════════════════

class _DateTimeRangeSheet extends StatefulWidget {
  final DateTime initialFrom;
  final DateTime initialTo;
  const _DateTimeRangeSheet({required this.initialFrom, required this.initialTo});

  @override
  State<_DateTimeRangeSheet> createState() => _DateTimeRangeSheetState();
}

class _DateTimeRangeSheetState extends State<_DateTimeRangeSheet> {
  late DateTime _from = widget.initialFrom;
  late DateTime _to   = widget.initialTo;

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context:   context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate:  DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime(_from.year, _from.month, _from.day),
        end:   DateTime(_to.year, _to.month, _to.day),
      ),
      locale: const Locale('fr'),
    );
    if (range == null) return;
    setState(() {
      _from = DateTime(range.start.year, range.start.month, range.start.day, _from.hour, _from.minute);
      _to   = DateTime(range.end.year, range.end.month, range.end.day, _to.hour, _to.minute);
    });
  }

  Future<void> _pickTime(bool isFrom) async {
    final base = isFrom ? _from : _to;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = DateTime(_from.year, _from.month, _from.day, picked.hour, picked.minute);
      } else {
        _to = DateTime(_to.year, _to.month, _to.day, picked.hour, picked.minute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final invalid = !_from.isBefore(_to);
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(context.l10n.intervalleDeLecture,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          _RangeRow(
            label: 'Jours',
            value: '${DateFormat('dd MMM yyyy', 'fr').format(_from)}  →  '
                '${DateFormat('dd MMM yyyy', 'fr').format(_to)}',
            icon: Icons.date_range,
            onTap: _pickDateRange,
          ),
          const SizedBox(height: 10),
          _RangeRow(
            label: 'Heure de début',
            value: DateFormat('HH:mm').format(_from),
            icon: Icons.access_time,
            onTap: () => _pickTime(true),
          ),
          const SizedBox(height: 10),
          _RangeRow(
            label: 'Heure de fin',
            value: DateFormat('HH:mm').format(_to),
            icon: Icons.access_time_filled,
            onTap: () => _pickTime(false),
          ),
          if (invalid) ...[
            const SizedBox(height: 10),
            const Text(
              "La date/heure de fin doit être après le début.",
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: invalid ? null : () => Navigator.of(context).pop((from: _from, to: _to)),
              child: Text(context.l10n.btnAppliquer),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const _RangeRow({required this.label, required this.value, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.06),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white60, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// Contrôles de lecture
// ══════════════════════════════════════════════════════════════

class _PlaybackControls extends StatelessWidget {
  final GpsPlaybackState state;
  final VoidCallback      onPlay;
  final VoidCallback      onPause;
  final VoidCallback      onReset;
  final void Function(int)    onSeek;
  final void Function(double) onSpeed;

  const _PlaybackControls({
    required this.state,
    required this.onPlay,
    required this.onPause,
    required this.onSeek,
    required this.onSpeed,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final positions = state.positions;
    final idx       = state.currentIndex;
    final total     = positions.isEmpty ? 1 : positions.length - 1;

    // Timestamps début / fin / courant
    String fmtTime(DateTime dt) => DateFormat('HH:mm:ss').format(dt.toLocal());
    final startTime = positions.isNotEmpty ? fmtTime(positions.first.fixTime) : '--:--';
    final endTime   = positions.isNotEmpty ? fmtTime(positions.last.fixTime)  : '--:--';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.bottomCenter,
          end:    Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.95), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stats du trajet
          if (positions.isNotEmpty)
            _PlaybackStats(state: state),

          const SizedBox(height: 12),

          // Slider timeline
          Row(
            children: [
              Text(startTime, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight:   3,
                    thumbShape:    const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:  const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor:   AppColors.accent,
                    overlayColor: AppColors.accent.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value:   idx.toDouble(),
                    max:     total.toDouble(),
                    onChanged: (v) => onSeek(v.round()),
                  ),
                ),
              ),
              Text(endTime, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),

          const SizedBox(height: 8),

          // Boutons de contrôle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Reset
              _CtrlBtn(
                icon: Icons.skip_previous_rounded,
                onTap: onReset,
                size: 36,
              ),
              const SizedBox(width: 12),
              // Play / Pause
              GestureDetector(
                onTap: state.isPlaying ? onPause : onPlay,
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color:  AppColors.accent,
                    shape:  BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 12),
                    ],
                  ),
                  child: Icon(
                    state.isFinished
                        ? Icons.replay_rounded
                        : (state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    color: Colors.white,
                    size:  32,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Vitesse
              _SpeedSelector(
                current:  state.speed,
                onSelect: onSpeed,
              ),
              const SizedBox(width: 12),
              // Progression
              Text(
                '${idx + 1}/${positions.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaybackStats extends StatelessWidget {
  final GpsPlaybackState state;
  const _PlaybackStats({required this.state});

  @override
  Widget build(BuildContext context) {
    final trail  = state.trail;
    final speeds = trail.where((p) => p.speed != null).map((p) => p.speed!);
    final avgSpd = speeds.isEmpty ? 0.0 : speeds.reduce((a, b) => a + b) / speeds.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatChip(icon: Icons.route,  label: '${((state.currentIndex + 1) * 100 / state.positions.length).toStringAsFixed(0)}%'),
        _StatChip(icon: Icons.speed,  label: '${avgSpd.toStringAsFixed(0)} km/h'),
        _StatChip(icon: Icons.timer,  label: _elapsed(state)),
      ],
    );
  }

  String _elapsed(GpsPlaybackState s) {
    if (s.trail.length < 2) return '0min';
    final dur = s.trail.last.fixTime.difference(s.trail.first.fixTime);
    if (dur.inMinutes < 60) return '${dur.inMinutes}min';
    return '${dur.inHours}h${dur.inMinutes % 60}min';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color:        Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white60, size: 13),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _CtrlBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  final double       size;
  const _CtrlBtn({required this.icon, required this.onTap, required this.size});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.1),
        shape:        BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.55),
    ),
  );
}

// Vitesses disponibles : x1 → x1024 (doublées à chaque cran).
const List<double> kPlaybackSpeeds = [
  1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024,
];

class _SpeedSelector extends StatelessWidget {
  final double current;
  final void Function(double) onSelect;

  const _SpeedSelector({required this.current, required this.onSelect});

  String _fmt(double s) => s >= 1000
      ? 'x${(s / 1000).toStringAsFixed(s % 1000 == 0 ? 0 : 1)}k'
      : 'x${s.toStringAsFixed(0)}';

  Future<void> _openMenu(BuildContext context) async {
    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.vitesseDeLecture,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kPlaybackSpeeds.map((s) {
                  final sel = s == current;
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.accent : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _fmt(s),
                        style: TextStyle(
                          color: sel ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) onSelect(selected);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        AppColors.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _fmt(current),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.expand_more, color: Colors.white, size: 15),
          ],
        ),
      ),
    );
  }
}