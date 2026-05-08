// lib/features/gps/presentation/gps_map_screen.dart
// Carte live de la flotte de véhicules

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import 'gps_provider.dart';

class GpsMapScreen extends ConsumerStatefulWidget {
  const GpsMapScreen({super.key});

  @override
  ConsumerState<GpsMapScreen> createState() => _GpsMapScreenState();
}

class _GpsMapScreenState extends ConsumerState<GpsMapScreen> {
  final _mapController = MapController();
  Map<String, dynamic>? _selectedVehicule;

  @override
  Widget build(BuildContext context) {
    final fleetAsync = ref.watch(liveFleetProvider);
    // Rafraîchissement via WebSocket
    ref.watch(livePositionStreamProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Carte GPS — Flotte',
        showBackButton: true,
        showHomeButton: true,
        actions: [
          Consumer(builder: (_, ref, __) {
            final alertes = ref.watch(alertesNonLuesProvider);
            final count = alertes.valueOrNull?.length ?? 0;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push('/gps/alertes'),
                ),
                if (count > 0)
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.retard,
                        shape: BoxShape.circle,
                      ),
                      child: Text('$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            );
          }),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(liveFleetProvider),
          ),
        ],
      ),
      body: fleetAsync.when(
        loading: () => const Center(child: const CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.signal_wifi_off, size: 64, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text('Impossible de contacter Traccar\n$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                onPressed: () => ref.refresh(liveFleetProvider),
              ),
            ],
          ),
        ),
        data: (fleet) {
          if (fleet.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gps_off, size: 64, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  Text('Aucun véhicule GPS en ligne',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          // Centre de la carte sur le premier véhicule
          final firstLat = fleet.first['lat'] as double? ?? 36.7;
          final firstLon = fleet.first['lon'] as double? ?? 3.05;

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(firstLat, firstLon),
                  initialZoom: 12,
                  onTap: (_, __) => setState(() => _selectedVehicule = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.garage_auto',
                  ),
                  MarkerLayer(
                    markers: fleet.map((item) {
                      final lat = item['lat'] as double;
                      final lon = item['lon'] as double;
                      final spd = item['speed'] as double? ?? 0;
                      final isSelected = _selectedVehicule == item;

                      return Marker(
                        point: LatLng(lat, lon),
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onTap: () => setState(() =>
                              _selectedVehicule = isSelected ? null : item),
                          child: Container(
                            decoration: BoxDecoration(
                              color: spd > 0
                                  ? AppColors.secondary
                                  : AppColors.textSecondary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                                width: isSelected ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: const Icon(
                              Icons.directions_car,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Compteur véhicules
              Positioned(
                top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, size: 8, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Text('${fleet.length} véhicules en ligne',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

              // Fiche véhicule sélectionné
              if (_selectedVehicule != null)
                Positioned(
                  bottom: 20, left: 12, right: 12,
                  child: _VehiculeInfoCard(item: _selectedVehicule!),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _VehiculeInfoCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _VehiculeInfoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    // Correction : Utilisation de 'v' pour correspondre aux appels ci-dessous
    final v = item['vehicule'] as Map<String, dynamic>;
    final speed = item['speed'] as double? ?? 0;
    final last = item['lastSeen'] as DateTime?;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_car,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${v['marque']} ${v['modele']}', // Changé vehiculeData par v
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        v['immatriculation'] ?? 'Sans immatriculation', // Changé vehiculeData par v
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: speed > 0
                        ? AppColors.secondary.withValues(alpha: 0.1)
                        : AppColors.textHint.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    speed > 0 ? '${speed.toStringAsFixed(0)} km/h' : 'Arrêté',
                    style: TextStyle(
                      color: speed > 0 ? AppColors.secondary : AppColors.textHint,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (last != null) ...[
              const SizedBox(height: 8),
              Text(
                'Dernière position : ${_formatTime(last)}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    // Correction de l'interpolation des strings
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }
}