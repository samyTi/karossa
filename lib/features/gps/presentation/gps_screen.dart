// lib/features/gps/presentation/gps_screen.dart
//
// Liste des véhicules ayant un tracker GPS Flespi configuré.
// Affiche une GpsPositionCard par véhicule.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import 'gps_position_card.dart';
import 'gps_provider.dart';

// ── Modèle minimal véhicule GPS ───────────────────────────────────────────

class VehiculeGps {
  final String id;
  final String marque;
  final String modele;
  final int flespiDeviceId;

  const VehiculeGps({
    required this.id,
    required this.marque,
    required this.modele,
    required this.flespiDeviceId,
  });
}

// ── Provider véhicules GPS ────────────────────────────────────────────────

/// Charge les véhicules ayant un flespi_device_id (ou flespi_device_id) non null.
final vehiculesGpsProvider = FutureProvider<List<VehiculeGps>>((ref) async {
  final data = await Supabase.instance.client
      .from('vehicules')
      // ✅ colonne corrigée : flespi_device_id (avec fallback flespi_device_id)
      .select('id, marque, modele, flespi_device_id, flespi_device_id')
      .or('flespi_device_id.not.is.null,flespi_device_id.not.is.null')
      .neq('statut', 'vendu');

  return (data as List<dynamic>)
      .map((row) {
        // Lit flespi_device_id en priorité, sinon flespi_device_id
        final deviceId =
            (row['flespi_device_id'] ?? row['flespi_device_id']) as int?;
        if (deviceId == null) return null;
        return VehiculeGps(
          id:            row['id']     as String,
          marque:        row['marque'] as String,
          modele:        row['modele'] as String,
          flespiDeviceId: deviceId,
        );
      })
      .whereType<VehiculeGps>()
      .toList();
});

// ── Écran ─────────────────────────────────────────────────────────────────

class GpsScreen extends ConsumerWidget {
  const GpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiculesAsync = ref.watch(vehiculesGpsProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'GPS — Flotte',
        showHomeButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Carte flotte',
            onPressed: () => context.push('/gps/map'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tout rafraîchir',
            onPressed: () => ref.invalidate(vehiculesGpsProvider),
          ),
        ],
      ),
      body: vehiculesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(vehiculesGpsProvider),
        ),
        data: (vehicules) {
          if (vehicules.isEmpty) return const _EmptyView();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vehicules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final v = vehicules[index];
              // ✅ GpsPositionCard est le widget carte complet (pas le bouton AppBar)
              return GpsPositionCard(
                vehiculeId:    v.id,
                flespiDeviceId: v.flespiDeviceId,
                vehiculeNom:   '${v.marque} ${v.modele}',
              );
            },
          );
        },
      ),
    );
  }
}

// ── Vues utilitaires ──────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Erreur de chargement : $message', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gps_off, size: 64, color: AppColors.textHint),
          SizedBox(height: 16),
          Text(
            'Aucun véhicule avec GPS configuré.\n'
            'Renseignez le Device ID Flespi dans\n'
            'la fiche véhicule.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}