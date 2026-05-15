// lib/features/gps/presentation/gps_position_card.dart
//
// Widget compact affichant la position GPS d'un véhicule.
// Utilisé depuis VehiculeDetailScreen via un bouton dans l'AppBar
// qui ouvre un BottomSheet avec les détails de position.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/gps_position.dart';
import 'gps_provider.dart';

// ── Bouton GPS pour la AppBar ─────────────────────────────────────────────
// Usage : actions: [ if (vehicule.flespiDeviceId != null) GpsAppBarButton(...) ]

class GpsAppBarButton extends ConsumerWidget {
  final String vehiculeId;
  final int flespiDeviceId;
  final String vehiculeNom;

  const GpsAppBarButton({
    super.key,
    required this.vehiculeId,
    required this.flespiDeviceId,
    required this.vehiculeNom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (vehiculeId: vehiculeId, flespiDeviceId: flespiDeviceId);
    final state  = ref.watch(gpsLiveProvider(params));

    return IconButton(
      tooltip: 'Position GPS',
      icon: _GpsIcon(isLoading: state.isLoading, isOnline: state.position?.isOnline),
      onPressed: () {
        // Charge la position si pas encore chargée
        if (state.position == null && !state.isLoading) {
          ref.read(gpsLiveProvider(params).notifier).refresh();
        }
        showModalBottomSheet(
          context:       context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => ProviderScope(
            parent: ProviderScope.containerOf(context),
            child: _GpsBottomSheet(
              vehiculeId:    vehiculeId,
              flespiDeviceId: flespiDeviceId,
              vehiculeNom:   vehiculeNom,
            ),
          ),
        );
      },
    );
  }
}

// ── Icône GPS avec état ───────────────────────────────────────────────────

class _GpsIcon extends StatelessWidget {
  final bool isLoading;
  final bool? isOnline;

  const _GpsIcon({required this.isLoading, this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    final color = isOnline == null
        ? Colors.white54
        : isOnline!
            ? AppColors.secondary
            : Colors.white38;
    return Icon(Icons.gps_fixed, color: color);
  }
}

// ── BottomSheet détail GPS ────────────────────────────────────────────────

class _GpsBottomSheet extends ConsumerStatefulWidget {
  final String vehiculeId;
  final int    flespiDeviceId;
  final String vehiculeNom;

  const _GpsBottomSheet({
    required this.vehiculeId,
    required this.flespiDeviceId,
    required this.vehiculeNom,
  });

  @override
  ConsumerState<_GpsBottomSheet> createState() => _GpsBottomSheetState();
}

class _GpsBottomSheetState extends ConsumerState<_GpsBottomSheet> {
  @override
  void initState() {
    super.initState();
    // Lance le chargement au premier affichage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(gpsLiveProvider((
            vehiculeId:    widget.vehiculeId,
            flespiDeviceId: widget.flespiDeviceId,
          )).notifier)
          .refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final params = (vehiculeId: widget.vehiculeId, flespiDeviceId: widget.flespiDeviceId);
    final state  = ref.watch(gpsLiveProvider(params));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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

          // Titre + bouton refresh
          Row(
            children: [
              const Icon(Icons.gps_fixed, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.vehiculeNom,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Rafraîchir',
                onPressed: state.isLoading
                    ? null
                    : () => ref.read(gpsLiveProvider(params).notifier).refresh(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Contenu selon état
          if (state.isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else if (state.hasError)
            _ErrorTile(message: state.failure!.message)
          else if (state.position != null)
            _PositionTiles(position: state.position!)
          else
            const _EmptyTile(),
        ],
      ),
    );
  }
}

// ── Tuiles de détail position ─────────────────────────────────────────────

class _PositionTiles extends StatelessWidget {
  final GpsPosition position;
  const _PositionTiles({required this.position});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Tile(
          icon:  Icons.location_on_outlined,
          label: 'Coordonnées',
          value: '${position.latitude.toStringAsFixed(5)}, '
                 '${position.longitude.toStringAsFixed(5)}',
          color: AppColors.primary,
        ),
        _Tile(
          icon:  Icons.speed,
          label: 'Vitesse',
          value: position.speed != null
              ? '${position.speed!.toStringAsFixed(0)} km/h'
              : '— km/h',
          color: position.speed != null && position.speed! > 0
              ? AppColors.secondary
              : AppColors.textSecondary,
        ),
        if (position.heading != null)
          _Tile(
            icon:  Icons.navigation_outlined,
            label: 'Cap',
            value: '${position.heading!.toStringAsFixed(0)}°',
            color: AppColors.textSecondary,
          ),
        if (position.altitude != null)
          _Tile(
            icon:  Icons.terrain_outlined,
            label: 'Altitude',
            value: '${position.altitude!.toStringAsFixed(0)} m',
            color: AppColors.textSecondary,
          ),
        _Tile(
          icon:  Icons.access_time_outlined,
          label: 'Dernière position',
          value: _formatTime(position.fixTime),
          color: position.isOnline ? AppColors.secondary : AppColors.textSecondary,
        ),
        _Tile(
          icon:  position.isOnline ? Icons.wifi : Icons.wifi_off,
          label: 'Statut',
          value: position.isOnline ? 'En ligne' : 'Hors ligne',
          color: position.isOnline ? AppColors.secondary : AppColors.textSecondary,
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final diff  = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'À l\'instant';
    if (diff.inMinutes < 60)  return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours   < 24)  return 'Il y a ${diff.inHours}h';
    return '${local.day.toString().padLeft(2,'0')}/'
           '${local.month.toString().padLeft(2,'0')} '
           '${local.hour.toString().padLeft(2,'0')}:'
           '${local.minute.toString().padLeft(2,'0')}';
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Text(value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: color,
            )),
        ],
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;
  const _ErrorTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gps_off, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
              style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Appuyez sur rafraîchir pour charger la position.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ── Carte GPS complète pour liste ─────────────────────────────────────────
// Usage : itemBuilder dans ListView (GpsScreen)
// Affiche marque/modèle, statut online, vitesse, coordonnées.
// Charge la position au premier build et expose un bouton refresh.

class GpsPositionCard extends ConsumerStatefulWidget {
  final String vehiculeId;
  final int    flespiDeviceId;
  final String vehiculeNom;

  const GpsPositionCard({
    super.key,
    required this.vehiculeId,
    required this.flespiDeviceId,
    required this.vehiculeNom,
  });

  @override
  ConsumerState<GpsPositionCard> createState() => _GpsPositionCardState();
}

class _GpsPositionCardState extends ConsumerState<GpsPositionCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(gpsLiveProvider((
            vehiculeId:     widget.vehiculeId,
            flespiDeviceId: widget.flespiDeviceId,
          )).notifier)
          .refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final params = (vehiculeId: widget.vehiculeId, flespiDeviceId: widget.flespiDeviceId);
    final state  = ref.watch(gpsLiveProvider(params));
    final pos    = state.position;

    Color statusColor;
    String statusLabel;
    if (state.isLoading) {
      statusColor = AppColors.textSecondary;
      statusLabel = 'Chargement…';
    } else if (state.hasError) {
      statusColor = AppColors.error;
      statusLabel = state.failure!.message;
    } else if (pos == null) {
      statusColor = AppColors.textSecondary;
      statusLabel = 'Aucune donnée';
    } else if (!pos.isOnline) {
      statusColor = AppColors.textSecondary;
      statusLabel = 'Hors ligne';
    } else if ((pos.speed ?? 0) > 0) {
      statusColor = AppColors.secondary;
      statusLabel = '${pos.speed!.toStringAsFixed(0)} km/h';
    } else {
      statusColor = AppColors.primary;
      statusLabel = 'Arrêté';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête : nom + badge statut + refresh ────────────────
            Row(
              children: [
                Container(
                  padding:    const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    (pos?.speed ?? 0) > 0
                        ? Icons.navigation
                        : Icons.directions_car,
                    color: statusColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.vehiculeNom,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 32, height: 32,
                  child: state.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.refresh, size: 18),
                          color: AppColors.textSecondary,
                          onPressed: () => ref
                              .read(gpsLiveProvider(params).notifier)
                              .refresh(),
                        ),
                ),
              ],
            ),

            // ── Détails position ──────────────────────────────────────
            if (pos != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  _DetailChip(
                    icon:  Icons.location_on_outlined,
                    label: '${pos.latitude.toStringAsFixed(4)}, '
                           '${pos.longitude.toStringAsFixed(4)}',
                    color: AppColors.primary,
                  ),
                  if (pos.heading != null) ...[
                    const SizedBox(width: 8),
                    _DetailChip(
                      icon:  Icons.navigation_outlined,
                      label: '${pos.heading!.toStringAsFixed(0)}°',
                      color: AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _relativeTime(pos.fixTime),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],

            // ── Message d'erreur ──────────────────────────────────────
            if (state.hasError && !state.isLoading) ...[
              const SizedBox(height: 8),
              Text(
                state.failure!.message,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'Vu à l\'instant';
    if (diff.inMinutes < 60)  return 'Vu il y a ${diff.inMinutes} min';
    if (diff.inHours   < 24)  return 'Vu il y a ${diff.inHours}h';
    final l = dt.toLocal();
    return 'Vu le ${l.day.toString().padLeft(2,'0')}/'
           '${l.month.toString().padLeft(2,'0')} '
           '${l.hour.toString().padLeft(2,'0')}:'
           '${l.minute.toString().padLeft(2,'0')}';
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _DetailChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
