// lib/features/gps/presentation/gps_geofences_screen.dart
//
// Écran "Geofencing visuel" :
//   • Carte plein écran, tuiles sombres cohérentes avec le dashboard
//   • Tap sur la carte → place le centre d'une nouvelle zone (mode ajout)
//   • Slider de rayon avec preview live du cercle sur la carte
//   • Liste dépliable des zones existantes : toggle actif, édition, suppression
//   • Persisté via geofencesProvider (Supabase, table gps_geofences)

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/gps_geofence.dart';
import 'gps_provider.dart';

const _kPalette = <Color>[
  Color(0xFF2563EB), // bleu
  Color(0xFF10B981), // vert
  Color(0xFFF59E0B), // orange
  Color(0xFFEF4444), // rouge
  Color(0xFFA855F7), // violet
  Color(0xFF06B6D4), // cyan
];

class GpsGeofencesScreen extends ConsumerStatefulWidget {
  const GpsGeofencesScreen({super.key});

  @override
  ConsumerState<GpsGeofencesScreen> createState() => _GpsGeofencesScreenState();
}

class _GpsGeofencesScreenState extends ConsumerState<GpsGeofencesScreen> {
  final MapController _mapController = MapController();

  bool _placing = false;
  LatLng? _draftCenter;
  double _draftRadius = 500;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _startPlacing() {
    setState(() {
      _placing = true;
      _draftCenter = null;
      _draftRadius = 500;
    });
  }

  void _cancelPlacing() {
    setState(() {
      _placing = false;
      _draftCenter = null;
    });
  }

  void _onMapTap(LatLng point) {
    if (!_placing) return;
    setState(() => _draftCenter = point);
  }

  Future<void> _confirmDraft() async {
    final center = _draftCenter;
    if (center == null) return;

    final result = await showModalBottomSheet<_GeofenceFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GeofenceFormSheet(
        initialRadius: 500,
      ),
    );
    if (result == null || !mounted) return;

    final geofence = GpsGeofence(
      id: '', // ignoré : généré par Supabase (gen_random_uuid) à l'insertion
      nom: result.nom,
      latitude: center.latitude,
      longitude: center.longitude,
      radiusMeters: result.radius,
      color: result.color,
      alerteEntree: result.alerteEntree,
      alerteSortie: result.alerteSortie,
    );

    try {
      await ref.read(geofencesProvider.notifier).addGeofence(geofence);
      if (!mounted) return;
      setState(() {
        _placing = false;
        _draftCenter = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.zoneCreeeSucces(geofence.nom))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.erreurAvecDetail(e.toString())), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _editGeofence(GpsGeofence g) async {
    final result = await showModalBottomSheet<_GeofenceFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GeofenceFormSheet(
        initialNom: g.nom,
        initialRadius: g.radiusMeters,
        initialColor: g.color,
        initialAlerteEntree: g.alerteEntree,
        initialAlerteSortie: g.alerteSortie,
        isEditing: true,
        onDelete: () async {
          Navigator.pop(context);
          await ref.read(geofencesProvider.notifier).deleteGeofence(g.id);
        },
      ),
    );
    if (result == null || !mounted) return;

    await ref.read(geofencesProvider.notifier).updateGeofence(
          g.copyWith(
            nom: result.nom,
            radiusMeters: result.radius,
            color: result.color,
            alerteEntree: result.alerteEntree,
            alerteSortie: result.alerteSortie,
          ),
        );
  }

  void _focusGeofence(GpsGeofence g) {
    _mapController.move(LatLng(g.latitude, g.longitude), 14);
  }

  @override
  Widget build(BuildContext context) {
    final geofencesAsync = ref.watch(geofencesProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(36.7372, 3.0865), // Alger
              initialZoom: 11,
              onTap: (_, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.garageauto.app',
                retinaMode: RetinaMode.isHighDensity(context),
              ),
              CircleLayer(
                circles: [
                  // Zones persistées
                  ...?geofencesAsync.valueOrNull?.map((g) => CircleMarker(
                        point: LatLng(g.latitude, g.longitude),
                        radius: g.radiusMeters,
                        useRadiusInMeter: true,
                        color: g.color.withValues(alpha: g.actif ? 0.18 : 0.06),
                        borderColor: g.color.withValues(alpha: g.actif ? 0.9 : 0.3),
                        borderStrokeWidth: 2,
                      )),
                  // Cercle brouillon en cours de création
                  if (_draftCenter != null)
                    CircleMarker(
                      point: _draftCenter!,
                      radius: _draftRadius,
                      useRadiusInMeter: true,
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderColor: AppColors.primary,
                      borderStrokeWidth: 2,
                    ),
                ].whereType<CircleMarker>().toList(),
              ),
              MarkerLayer(
                markers: [
                  ...?geofencesAsync.valueOrNull?.map((g) => Marker(
                        point: LatLng(g.latitude, g.longitude),
                        width: 28,
                        height: 28,
                        child: GestureDetector(
                          onTap: () => _editGeofence(g),
                          child: Icon(
                            Icons.fence_rounded,
                            color: g.color,
                            size: 24,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4)
                            ],
                          ),
                        ),
                      )),
                  if (_draftCenter != null)
                    Marker(
                      point: _draftCenter!,
                      width: 24,
                      height: 24,
                      child: const Icon(
                        Icons.add_location_alt_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                ].whereType<Marker>().toList(),
              ),
            ],
          ),

          // ── App bar ──────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _Header(
              placing: _placing,
              onBack: () => context.pop(),
              onAdd: _startPlacing,
              onCancel: _cancelPlacing,
            ),
          ),

          // ── Instructions / slider pendant le placement ───────
          if (_placing)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _PlacingPanel(
                hasCenter: _draftCenter != null,
                radius: _draftRadius,
                onRadiusChanged: (r) => setState(() => _draftRadius = r),
                onConfirm: _confirmDraft,
              ),
            ),

          // ── Liste des zones (masquée pendant le placement) ───
          if (!_placing)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _GeofenceListPanel(
                geofencesAsync: geofencesAsync,
                onTap: _focusGeofence,
                onEdit: _editGeofence,
                onToggle: (id, actif) =>
                    ref.read(geofencesProvider.notifier).toggleActif(id, actif),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Header
// ══════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final bool placing;
  final VoidCallback onBack;
  final VoidCallback onAdd;
  final VoidCallback onCancel;

  const _Header({
    required this.placing,
    required this.onBack,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 12,
        right: 12,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.0),
          ],
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
          Expanded(
            child: Text(
              placing ? 'Placez le centre de la zone' : 'Zones de surveillance',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          if (placing)
            TextButton(
              onPressed: onCancel,
              child: Text(context.l10n.btnAnnuler, style: const TextStyle(color: Colors.white70)),
            )
          else
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onAdd,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Zone',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
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
// Panneau de placement (slider rayon + confirmation)
// ══════════════════════════════════════════════════════════════

class _PlacingPanel extends StatelessWidget {
  final bool hasCenter;
  final double radius;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onConfirm;

  const _PlacingPanel({
    required this.hasCenter,
    required this.radius,
    required this.onRadiusChanged,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasCenter)
            const Row(
              children: [
                Icon(Icons.touch_app_rounded, color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Touchez la carte pour placer le centre de la zone',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                const Icon(Icons.radar_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Rayon : ${_formatRadius(radius)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                thumbColor: AppColors.primary,
                inactiveTrackColor: Colors.white24,
              ),
              child: Slider(
                value: radius,
                min: 50,
                max: 5000,
                divisions: 99,
                onChanged: onRadiusChanged,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(context.l10n.btnContinuer),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatRadius(double r) =>
      r >= 1000 ? '${(r / 1000).toStringAsFixed(1)} km' : '${r.round()} m';
}

// ══════════════════════════════════════════════════════════════
// Liste des zones existantes
// ══════════════════════════════════════════════════════════════

class _GeofenceListPanel extends StatelessWidget {
  final AsyncValue<List<GpsGeofence>> geofencesAsync;
  final void Function(GpsGeofence) onTap;
  final void Function(GpsGeofence) onEdit;
  final void Function(String id, bool actif) onToggle;

  const _GeofenceListPanel({
    required this.geofencesAsync,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.42,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.fence_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Zones (${geofencesAsync.valueOrNull?.length ?? 0})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: geofencesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur : $e',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.map_outlined,
                          color: AppColors.textSecondary,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aucune zone définie. Touchez "Zone" pour en tracer une.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _GeofenceCard(
                    geofence: list[i],
                    onTap: () => onTap(list[i]),
                    onEdit: () => onEdit(list[i]),
                    onToggle: (v) => onToggle(list[i].id, v),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GeofenceCard extends StatelessWidget {
  final GpsGeofence geofence;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  const _GeofenceCard({
    required this.geofence,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final g = geofence;
    return Material(
      color: AppColors.border.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: g.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.fence_rounded, color: g.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          g.radiusMeters >= 1000
                              ? '${(g.radiusMeters / 1000).toStringAsFixed(1)} km'
                              : '${g.radiusMeters.round()} m',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (g.alerteEntree) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.login_rounded,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                        ],
                        if (g.alerteSortie) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.logout_rounded,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.textSecondary,
                onPressed: onEdit,
              ),
              Switch(
                value: g.actif,
                onChanged: onToggle,
                activeColor: AppColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Formulaire création/édition
// ══════════════════════════════════════════════════════════════

class _GeofenceFormResult {
  final String nom;
  final double radius;
  final Color color;
  final bool alerteEntree;
  final bool alerteSortie;

  const _GeofenceFormResult({
    required this.nom,
    required this.radius,
    required this.color,
    required this.alerteEntree,
    required this.alerteSortie,
  });
}

class _GeofenceFormSheet extends StatefulWidget {
  final String? initialNom;
  final double initialRadius;
  final Color initialColor;
  final bool initialAlerteEntree;
  final bool initialAlerteSortie;
  final bool isEditing;
  final VoidCallback? onDelete;

  const _GeofenceFormSheet({
    this.initialNom,
    required this.initialRadius,
    this.initialColor = const Color(0xFF2563EB),
    this.initialAlerteEntree = true,
    this.initialAlerteSortie = true,
    this.isEditing = false,
    this.onDelete,
  });

  @override
  State<_GeofenceFormSheet> createState() => _GeofenceFormSheetState();
}

class _GeofenceFormSheetState extends State<_GeofenceFormSheet> {
  late final TextEditingController _nomCtrl =
      TextEditingController(text: widget.initialNom);
  late double _radius = widget.initialRadius;
  late Color _color = widget.initialColor;
  late bool _entree = widget.initialAlerteEntree;
  late bool _sortie = widget.initialAlerteSortie;

  @override
  void dispose() {
    _nomCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nomCtrl.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      _GeofenceFormResult(
        nom: _nomCtrl.text.trim(),
        radius: _radius,
        color: _color,
        alerteEntree: _entree,
        alerteSortie: _sortie,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.isEditing ? 'Modifier la zone' : 'Nouvelle zone',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nomCtrl,
            decoration: InputDecoration(
              labelText: context.l10n.champNomZone,
              hintText: context.l10n.exempleNomZone,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Rayon : ${_radius >= 1000 ? '${(_radius / 1000).toStringAsFixed(1)} km' : '${_radius.round()} m'}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _radius,
            min: 50,
            max: 5000,
            divisions: 99,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _radius = v),
          ),
          const SizedBox(height: 8),
          Text(context.l10n.champCouleur, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: _kPalette.map((c) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _color == c ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: _color == c
                        ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8)]
                        : null,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.alerterALEntree),
            value: _entree,
            activeColor: AppColors.secondary,
            onChanged: (v) => setState(() => _entree = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.alerterALaSortie),
            value: _sortie,
            activeColor: AppColors.secondary,
            onChanged: (v) => setState(() => _sortie = v),
          ),
          const SizedBox(height: 12),
          if (widget.isEditing && widget.onDelete != null)
            TextButton.icon(
              onPressed: widget.onDelete,
              icon: Icon(Icons.delete_outline, color: AppColors.error, size: 18),
              label: Text(
                'Supprimer la zone',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(widget.isEditing ? 'Enregistrer' : 'Créer la zone'),
            ),
          ),
        ],
      ),
    );
  }
}