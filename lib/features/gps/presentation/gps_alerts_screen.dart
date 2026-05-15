// lib/features/gps/presentation/gps_alerts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import 'gps_provider.dart';
import '../domain/gps_alerte.dart'; // ✅ corrigé : gps_alerte.dart au lieu de gps_models.dart

class GpsAlertsScreen extends ConsumerWidget {
  const GpsAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertesAsync = ref.watch(toutesAlertesProvider);
    // ✅ corrigé : gpsAlerteSourceProvider au lieu de gpsRepositoryProvider
    final alerteSource = ref.read(gpsAlerteSourceProvider);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Alertes GPS',
        showHomeButton: true,
      ),
      body: alertesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erreur : $e')),
        data: (alertes) {
          if (alertes.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              message: 'Aucune alerte GPS — toutes les alertes apparaîtront ici',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alertes.length,
            itemBuilder: (_, i) {
              final a = alertes[i];
              return _AlertCard(
                alerte: a,
                onMarqueLue: () async {
                  // ✅ corrigé : appel via alerteSource.marquerAlerteLue
                  await alerteSource.marquerAlerteLue(a.id);
                  ref.invalidate(toutesAlertesProvider);
                  ref.invalidate(alertesNonLuesProvider);
                  ref.invalidate(nombreAlertesNonLuesProvider);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final GpsAlerte alerte;
  final VoidCallback onMarqueLue;
  const _AlertCard({required this.alerte, required this.onMarqueLue});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (alerte.type) {
      'vitesse'     => (Icons.speed,    AppColors.retard),
      'zone'        => (Icons.fence,    AppColors.accent),
      'kilometrage' => (Icons.timeline, AppColors.primary),
      _             => (Icons.gps_fixed, AppColors.textSecondary),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: alerte.lue ? null : color.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: alerte.lue
            ? BorderSide.none
            : BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(alerte.vehiculeNom,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alerte.message),
            Text(
              _formatDate(alerte.dateAlerte),
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        trailing: alerte.lue
            ? null
            : TextButton(
                onPressed: onMarqueLue,
                child: const Text('Lu'),
              ),
        isThreeLine: true,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d  = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final h  = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year} $h:$mi';
  }
}
