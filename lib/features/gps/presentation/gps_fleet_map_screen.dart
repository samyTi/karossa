// lib/features/gps/presentation/gps_fleet_map_screen.dart
//
// Carte GPS de la flotte :
//   • Marqueurs de position actuelle de tous les véhicules
//   • Bouton « Trajet » → sélecteur d'intervalle de dates → polyline
//   • Fiche info au tap sur un marqueur
//   • Auto-refresh toutes les 30 s

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../domain/gps_position.dart';
import 'gps_provider.dart';

class GpsFleetMapScreen extends ConsumerStatefulWidget {
  const GpsFleetMapScreen({super.key});

  @override
  ConsumerState<GpsFleetMapScreen> createState() => _GpsFleetMapScreenState();
}

class _GpsFleetMapScreenState extends ConsumerState<GpsFleetMapScreen> {
  final _mapController = MapController();

  // Véhicule sélectionné
  Map<String, dynamic>? _selectedItem;

  // Période pour l'historique du parcours
  DateTime _historyFrom = DateTime.now().subtract(const Duration(hours: 8));
  DateTime _historyTo   = DateTime.now();

  // Afficher ou non le tracé
  bool _showTrajet = false;

  // Points du trajet chargés manuellement (après sync Flespi → Supabase)
  List<GpsPosition> _trajetPositions = [];

  // État du chargement du trajet
  bool _isLoadingTrajet = false;
  String? _trajetError;

  // ── Auto-refresh ───────────────────────────────────────────
  static const _refreshInterval = Duration(seconds: 30);
  Timer?   _refreshTimer;
  DateTime _lastRefresh = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted) return;
      ref.refresh(liveFleetProvider);
      setState(() => _lastRefresh = DateTime.now());
    });
  }

  void _manualRefresh() {
    ref.refresh(liveFleetProvider);
    setState(() => _lastRefresh = DateTime.now());
  }

  // ── Chargement du trajet (sync Flespi → Supabase → lecture) ──
  Future<void> _loadTrajet({
    required String vehiculeId,
    required int flespiDeviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    setState(() {
      _isLoadingTrajet = true;
      _trajetError = null;
      _trajetPositions = [];
    });

    final repo = ref.read(gpsRepositoryProvider);

    try {
      // Étape 1 : Synchroniser Flespi → Supabase
      final synced = await repo.syncHistoryToSupabase(
        flespiDeviceId: flespiDeviceId,
        vehiculeId: vehiculeId,
        from: from,
        to: to,
      );

      // Étape 2 : Lire depuis Supabase (même si sync = 0, des données peuvent déjà exister)
      List<GpsPosition> positions = await repo.getHistoryFromSupabase(
        vehiculeId: vehiculeId,
        from: from,
        to: to,
        limit: 1000,
      );

      // Étape 3 : Si toujours vide, essayer directement Flespi
      if (positions.isEmpty) {
        positions = await repo.getHistoryFromFlespi(
          flespiDeviceId: flespiDeviceId,
          vehiculeId: vehiculeId,
          from: from,
          to: to,
        );
      }

      if (!mounted) return;

      if (positions.isEmpty) {
        setState(() {
          _isLoadingTrajet = false;
          _trajetError = 'Aucune position GPS trouvée sur cet intervalle.';
          _showTrajet = false;
        });
        return;
      }

      // Centrer la carte sur le trajet
      if (positions.isNotEmpty) {
        final midIndex = positions.length ~/ 2;
        final mid = positions[midIndex];
        _mapController.move(LatLng(mid.latitude, mid.longitude), 13);
      }

      setState(() {
        _trajetPositions = positions;
        _isLoadingTrajet = false;
        _showTrajet = true;
      });

      debugPrint('[GPS Trajet] synced=$synced, loaded=${positions.length} points');

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingTrajet = false;
        _trajetError = 'Erreur : $e';
        _showTrajet = false;
      });
    }
  }

  // ── Bouton Trajet ──────────────────────────────────────────
  Future<void> _openTrajetPicker(Map<String, dynamic> item) async {
    final vehiculeMap = item['vehicule'] as Map<String, dynamic>;
    final vehiculeId  = vehiculeMap['id'] as String;
    final deviceId    = vehiculeMap['flespi_device_id'] as int?;

    if (deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device ID Flespi manquant pour ce véhicule.')),
      );
      return;
    }

    final result = await showModalBottomSheet<_TrajetInterval>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _TrajetPickerSheet(
        initialFrom: _historyFrom,
        initialTo:   _historyTo,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _historyFrom = result.from;
      _historyTo   = result.to;
    });

    await _loadTrajet(
      vehiculeId:      vehiculeId,
      flespiDeviceId:  deviceId,
      from:            result.from,
      to:              result.to,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fleetAsync = ref.watch(liveFleetProvider);

    final selectedVehiculeId =
        (_selectedItem?['vehicule'] as Map<String, dynamic>?)?['id'] as String?;

    final historyPoints = _trajetPositions
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Carte GPS — Flotte',
        showHomeButton: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(
                _formatLastRefresh(_lastRefresh),
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
          ),
          IconButton(
            icon:    const Icon(Icons.refresh),
            tooltip: 'Rafraîchir maintenant',
            onPressed: _manualRefresh,
          ),
        ],
      ),
      body: fleetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.refresh(liveFleetProvider),
        ),
        data: (fleet) {
          if (fleet.isEmpty) return const _EmptyFleetView();

          final firstPos  = fleet.first;
          final centerLat = firstPos['lat'] as double? ?? 36.7;
          final centerLon = firstPos['lon'] as double? ?? 3.05;

          return Stack(
            children: [
              // ── Carte ────────────────────────────────────
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(centerLat, centerLon),
                  initialZoom:   12,
                  onTap: (_, __) => setState(() {
                    _selectedItem    = null;
                    _showTrajet      = false;
                    _trajetPositions = [];
                    _trajetError     = null;
                  }),
                ),
                children: [
                  TileLayer(
                    urlTemplate:         'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.garage_auto',
                  ),

                  // Tracé du parcours
                  if (_showTrajet && historyPoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points:      historyPoints,
                          color:       AppColors.primary.withValues(alpha: 0.85),
                          strokeWidth: 4.5,
                        ),
                      ],
                    ),

                  // Points départ / arrivée
                  if (_showTrajet && historyPoints.length >= 2)
                    MarkerLayer(
                      markers: [
                        _buildEndpointMarker(
                          historyPoints.first,
                          color: Colors.green,
                          icon:  Icons.play_arrow,
                          label: 'Départ',
                        ),
                        _buildEndpointMarker(
                          historyPoints.last,
                          color: AppColors.primary,
                          icon:  Icons.flag,
                          label: 'Arrivée',
                        ),
                      ],
                    ),

                  // Marqueurs position actuelle
                  MarkerLayer(
                    markers: fleet.map((item) {
                      final lat        = item['lat']      as double;
                      final lon        = item['lon']      as double;
                      final speed      = item['speed']    as double? ?? 0;
                      final isOnline   = item['isOnline'] as bool?   ?? false;
                      final isSelected = _selectedItem == item;

                      return Marker(
                        point:  LatLng(lat, lon),
                        width:  isSelected ? 56 : 48,
                        height: isSelected ? 56 : 48,
                        child:  GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedItem    = null;
                                _showTrajet      = false;
                                _trajetPositions = [];
                                _trajetError     = null;
                              } else {
                                _selectedItem    = item;
                                _showTrajet      = false;
                                _trajetPositions = [];
                                _trajetError     = null;
                              }
                            });
                            if (!isSelected) {
                              _mapController.move(LatLng(lat, lon), 14);
                            }
                          },
                          child: _VehiculeMarker(
                            isMoving:   speed > 0,
                            isOnline:   isOnline,
                            isSelected: isSelected,
                            heading:    item['heading'] as double?,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // ── Badge compteur ────────────────────────────
              Positioned(
                top: 12, left: 12,
                child: _FleetCountBadge(
                  total:  fleet.length,
                  online: fleet.where((i) => i['isOnline'] == true).length,
                  moving: fleet.where((i) => (i['speed'] as double? ?? 0) > 0).length,
                ),
              ),

              // ── Indicateur chargement historique ─────────
              if (_isLoadingTrajet)
                const Positioned(
                  top: 60, left: 0, right: 0,
                  child: Center(child: _LoadingPill(label: 'Chargement du trajet…')),
                ),

              // ── Erreur trajet ─────────────────────────────
              if (_trajetError != null)
                Positioned(
                  top: 60, left: 16, right: 16,
                  child: _TrajetErrorBanner(
                    message: _trajetError!,
                    onClose: () => setState(() => _trajetError = null),
                  ),
                ),

              // ── Bandeau résumé du trajet (si affiché) ────
              if (_showTrajet && selectedVehiculeId != null && historyPoints.length >= 2)
                Positioned(
                  top: 12, right: 12,
                  child: _TrajetSummaryBadge(
                    from:        _historyFrom,
                    to:          _historyTo,
                    pointsCount: historyPoints.length,
                    onEdit: () {
                      if (_selectedItem != null) {
                        _openTrajetPicker(_selectedItem!);
                      }
                    },
                    onClose: () => setState(() {
                      _showTrajet      = false;
                      _trajetPositions = [];
                    }),
                  ),
                ),

              // ── Fiche véhicule sélectionné ────────────────
              if (_selectedItem != null)
                Positioned(
                  bottom: 20, left: 12, right: 12,
                  child: _VehiculeInfoCard(
                    item:          _selectedItem!,
                    historyCount:  historyPoints.length,
                    showTrajet:    _showTrajet,
                    isLoadingTrajet: _isLoadingTrajet,
                    onTrajetTap:   () => _openTrajetPicker(_selectedItem!),
                    onClearTrajet: () => setState(() {
                      _showTrajet      = false;
                      _trajetPositions = [];
                    }),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Marker _buildEndpointMarker(
    LatLng point, {
    required Color    color,
    required IconData icon,
    required String   label,
  }) {
    return Marker(
      point:  point,
      width:  40,
      height: 40,
      child: Tooltip(
        message: label,
        child: Container(
          decoration: BoxDecoration(
            color:  color,
            shape:  BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  String _formatLastRefresh(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 5)  return 'À l\'instant';
    if (diff.inSeconds < 60) return 'il y a ${diff.inSeconds}s';
    return 'il y a ${diff.inMinutes} min';
  }
}

// ══════════════════════════════════════════════════════════════════
// Bannière d'erreur trajet
// ══════════════════════════════════════════════════════════════════

class _TrajetErrorBanner extends StatelessWidget {
  final String       message;
  final VoidCallback onClose;

  const _TrajetErrorBanner({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Colors.red.shade200),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, size: 16, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// BOTTOM SHEET — Sélecteur de dates du trajet
// ══════════════════════════════════════════════════════════════════

class _TrajetInterval {
  final DateTime from;
  final DateTime to;
  const _TrajetInterval({required this.from, required this.to});
}

class _TrajetPickerSheet extends StatefulWidget {
  final DateTime initialFrom;
  final DateTime initialTo;

  const _TrajetPickerSheet({
    required this.initialFrom,
    required this.initialTo,
  });

  @override
  State<_TrajetPickerSheet> createState() => _TrajetPickerSheetState();
}

class _TrajetPickerSheetState extends State<_TrajetPickerSheet> {
  late DateTime _from;
  late DateTime _to;

  int _tabIndex = 0;

  static final _fmt     = DateFormat('dd/MM/yyyy');
  static final _fmtTime = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to   = widget.initialTo;
  }

  bool get _isValid => _from.isBefore(_to);

  void _applyPreset(Duration duration) {
    setState(() {
      _to   = DateTime.now();
      _from = _to.subtract(duration);
    });
  }

  void _applyToday() {
    final now = DateTime.now();
    setState(() {
      _from = DateTime(now.year, now.month, now.day);
      _to   = now;
    });
  }

  void _applyYesterday() {
    final now       = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    setState(() {
      _from = yesterday;
      _to   = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _from : _to;
    final picked  = await showDatePicker(
      context:     context,
      initialDate: initial,
      firstDate:   DateTime.now().subtract(const Duration(days: 365)),
      lastDate:    DateTime.now(),
      locale:      const Locale('fr', 'FR'),
      builder:     (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary:   AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _from = DateTime(picked.year, picked.month, picked.day, _from.hour, _from.minute);
      } else {
        _to = DateTime(picked.year, picked.month, picked.day, _to.hour, _to.minute);
      }
    });
  }

  Future<void> _pickTime({required bool isFrom}) async {
    final initial = TimeOfDay.fromDateTime(isFrom ? _from : _to);
    final picked  = await showTimePicker(
      context:     context,
      initialTime: initial,
      builder:     (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary:   AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color:        theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top:    8,
        left:   20,
        right:  20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poignée
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Titre
          Row(
            children: [
              Container(
                padding:    const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:        AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.route, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trajet parcouru',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Choisissez un intervalle de dates',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Onglets
          Row(
            children: [
              _TabButton(
                label:    'Raccourcis',
                icon:     Icons.bolt,
                selected: _tabIndex == 0,
                onTap:    () => setState(() => _tabIndex = 0),
              ),
              const SizedBox(width: 8),
              _TabButton(
                label:    'Personnalisé',
                icon:     Icons.tune,
                selected: _tabIndex == 1,
                onTap:    () => setState(() => _tabIndex = 1),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_tabIndex == 0) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PresetChip(label: '1 heure',    onTap: () => _applyPreset(const Duration(hours: 1))),
                _PresetChip(label: '3 heures',   onTap: () => _applyPreset(const Duration(hours: 3))),
                _PresetChip(label: '8 heures',   onTap: () => _applyPreset(const Duration(hours: 8))),
                _PresetChip(label: "Aujourd'hui", onTap: _applyToday),
                _PresetChip(label: 'Hier',       onTap: _applyYesterday),
                _PresetChip(label: '24 heures',  onTap: () => _applyPreset(const Duration(hours: 24))),
                _PresetChip(label: '3 jours',    onTap: () => _applyPreset(const Duration(days: 3))),
                _PresetChip(label: '7 jours',    onTap: () => _applyPreset(const Duration(days: 7))),
              ],
            ),
            const SizedBox(height: 16),
            _IntervalPreview(from: _from, to: _to),
          ] else ...[
            _DateTimeRow(
              label:      'De',
              icon:       Icons.play_circle_outline,
              iconColor:  Colors.green,
              date:       _from,
              fmtDate:    _fmt,
              fmtTime:    _fmtTime,
              onPickDate: () => _pickDate(isFrom: true),
              onPickTime: () => _pickTime(isFrom: true),
            ),
            const SizedBox(height: 12),
            _DateTimeRow(
              label:      'À',
              icon:       Icons.flag_outlined,
              iconColor:  AppColors.primary,
              date:       _to,
              fmtDate:    _fmt,
              fmtTime:    _fmtTime,
              onPickDate: () => _pickDate(isFrom: false),
              onPickTime: () => _pickTime(isFrom: false),
            ),
            const SizedBox(height: 12),
            _IntervalPreview(from: _from, to: _to),
          ],

          const SizedBox(height: 20),

          if (!_isValid)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'La date de début doit être avant la date de fin.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isValid
                      ? () => Navigator.pop(
                          context,
                          _TrajetInterval(from: _from, to: _to),
                        )
                      : null,
                  icon:  const Icon(Icons.route, size: 18),
                  label: const Text('Afficher le trajet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:         const EdgeInsets.symmetric(vertical: 14),
                    shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle:       const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Widgets internes du picker
// ══════════════════════════════════════════════════════════════════

class _TabButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final bool         selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:        selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      selected ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:        AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize:   13,
            fontWeight: FontWeight.w600,
            color:      AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        iconColor;
  final DateTime     date;
  final DateFormat   fmtDate;
  final DateFormat   fmtTime;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  const _DateTimeRow({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.date,
    required this.fmtDate,
    required this.fmtTime,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onPickDate,
            child: _PickerTile(icon: Icons.calendar_today, value: fmtDate.format(date)),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onPickTime,
          child: _PickerTile(icon: Icons.access_time, value: fmtTime.format(date)),
        ),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String   value;

  const _PickerTile({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color:        AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      AppColors.primary,
              )),
        ],
      ),
    );
  }
}

class _IntervalPreview extends StatelessWidget {
  final DateTime from;
  final DateTime to;

  const _IntervalPreview({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final diff      = to.difference(from);
    final hours     = diff.inHours;
    final minutes   = diff.inMinutes % 60;
    final durLabel  = hours > 0
        ? '${hours}h${minutes > 0 ? ' ${minutes}min' : ''}'
        : '${minutes}min';

    final fmt = DateFormat('dd/MM/yyyy  HH:mm');

    return Container(
      padding:    const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        from.isBefore(to)
            ? AppColors.primary.withValues(alpha: 0.05)
            : Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(
          color: from.isBefore(to)
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time_filled,
            size:  18,
            color: from.isBefore(to) ? AppColors.primary : Colors.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Du ${fmt.format(from)}', style: const TextStyle(fontSize: 12)),
                Text('Au ${fmt.format(to)}',   style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          if (from.isBefore(to))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                durLabel,
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Badge résumé du trajet affiché sur la carte
// ══════════════════════════════════════════════════════════════════

class _TrajetSummaryBadge extends StatelessWidget {
  final DateTime     from;
  final DateTime     to;
  final int          pointsCount;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  const _TrajetSummaryBadge({
    required this.from,
    required this.to,
    required this.pointsCount,
    required this.onEdit,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final fmt      = DateFormat('dd/MM  HH:mm');
    final diff     = to.difference(from);
    final durLabel = diff.inHours > 0
        ? '${diff.inHours}h${diff.inMinutes % 60 > 0 ? ' ${diff.inMinutes % 60}min' : ''}'
        : '${diff.inMinutes}min';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color:        Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.route, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Trajet  •  $durLabel',
                  style: const TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.bold,
                    color:      AppColors.primary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${fmt.format(from)} → ${fmt.format(to)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '$pointsCount points GPS',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: Text(
                  'Modifier',
                  style: TextStyle(
                    fontSize:        11,
                    fontWeight:      FontWeight.w600,
                    color:           AppColors.primary,
                    decoration:      TextDecoration.underline,
                    decorationColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Carte info véhicule (avec bouton Trajet intégré)
// ══════════════════════════════════════════════════════════════════

class _VehiculeInfoCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int                  historyCount;
  final bool                 showTrajet;
  final bool                 isLoadingTrajet;
  final VoidCallback?        onTrajetTap;
  final VoidCallback         onClearTrajet;

  const _VehiculeInfoCard({
    required this.item,
    required this.historyCount,
    required this.showTrajet,
    required this.isLoadingTrajet,
    required this.onTrajetTap,
    required this.onClearTrajet,
  });

  @override
  Widget build(BuildContext context) {
    final v        = item['vehicule'] as Map<String, dynamic>;
    final speed    = item['speed']    as double? ?? 0;
    final isOnline = item['isOnline'] as bool?   ?? false;
    final last     = item['lastSeen'] as DateTime?;
    final position = item['position'] as GpsPosition?;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête véhicule
            Row(
              children: [
                Container(
                  padding:    const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_car, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${v['marque']} ${v['modele']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        v['immatriculation'] ?? '',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        (isOnline ? AppColors.secondary : AppColors.textSecondary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    speed > 0
                        ? '${speed.toStringAsFixed(0)} km/h'
                        : (isOnline ? 'Arrêté' : 'Hors ligne'),
                    style: TextStyle(
                      color:      isOnline ? AppColors.secondary : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize:   12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (position != null)
              Text(
                '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            const SizedBox(height: 8),

            // Ligne info + bouton Trajet
            Row(
              children: [
                if (last != null)
                  Text(
                    'Vu ${_relativeTime(last)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                const Spacer(),

                // Bouton Trajet
                if (isLoadingTrajet)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (!showTrajet)
                  GestureDetector(
                    onTap: onTrajetTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:        AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color:      AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset:     const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Trajet',
                            style: TextStyle(
                              color:      Colors.white,
                              fontSize:   13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.route, color: AppColors.primary, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        '$historyCount points',
                        style: const TextStyle(
                          color:      AppColors.primary,
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onClearTrajet,
                        child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours   < 24) return 'il y a ${diff.inHours}h';
    return DateFormat('dd/MM HH:mm').format(dt.toLocal());
  }
}

// ══════════════════════════════════════════════════════════════════
// Widgets réutilisables
// ══════════════════════════════════════════════════════════════════

class _VehiculeMarker extends StatelessWidget {
  final bool    isMoving;
  final bool    isOnline;
  final bool    isSelected;
  final double? heading;

  const _VehiculeMarker({
    required this.isMoving,
    required this.isOnline,
    required this.isSelected,
    this.heading,
  });

  @override
  Widget build(BuildContext context) {
    Color markerColor;
    if (!isOnline)     markerColor = AppColors.textSecondary;
    else if (isMoving) markerColor = AppColors.secondary;
    else               markerColor = AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color:  markerColor,
        shape:  BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
          width: isSelected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: isSelected ? 0.35 : 0.2),
            blurRadius: isSelected ? 8 : 4,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isMoving ? Icons.navigation : Icons.directions_car,
        color: Colors.white,
        size:  isSelected ? 26 : 22,
      ),
    );
  }
}

class _FleetCountBadge extends StatelessWidget {
  final int total;
  final int online;
  final int moving;

  const _FleetCountBadge({
    required this.total,
    required this.online,
    required this.moving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BadgeDot(color: AppColors.secondary),
          const SizedBox(width: 6),
          Text(
            '$online/$total en ligne  •  $moving en mouvement',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _BadgeDot extends StatelessWidget {
  final Color color;
  const _BadgeDot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _LoadingPill extends StatelessWidget {
  final String label;
  const _LoadingPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:        Theme.of(context).cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.signal_wifi_off, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'Impossible de charger la flotte\n$message',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon:      const Icon(Icons.refresh),
            label:     const Text('Réessayer'),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _EmptyFleetView extends StatelessWidget {
  const _EmptyFleetView();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.gps_off, size: 64, color: AppColors.textHint),
          SizedBox(height: 16),
          Text(
            'Aucun véhicule GPS en ligne.\n'
            'Renseignez le Flespi Device ID\n'
            'dans la fiche véhicule.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}