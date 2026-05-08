import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/profile_model.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import '../../locations/domain/location_model.dart';
import '../../locations/presentation/locations_provider.dart';
import '../../clients/presentation/clients_provider.dart';
import 'stats_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile   = ref.watch(currentProfileProvider).valueOrNull;
    final vehicules = ref.watch(vehiculesProvider).valueOrNull ?? [];
    final clients   = ref.watch(clientsProvider).valueOrNull ?? [];
    final retards   = ref.watch(locationsRetardProvider).valueOrNull ?? [];
    final actives   = ref.watch(locationsActivesProvider).valueOrNull ?? [];

    // Check if user has management permissions (gerant or admin)
    final canManage = profile?.isGerant ?? false;
    final canCreateLocation = profile?.canCreateLocation ?? false;
    final canCreateVehicule = profile?.canCreateVehicule ?? false;
    final canCreateClient = profile?.canCreateClient ?? false;

    final nbDispo    = vehicules
      .where((v) => v.statut == VehiculeStatut.disponible).length;
    final nbLoues    = vehicules
      .where((v) => v.statut == VehiculeStatut.loue).length;
    final nbRepairs  = vehicules
      .where((v) => v.statut == VehiculeStatut.reparation).length;
    final nbClients  = clients.length;

    // Calcul du taux d'occupation
    final totalVehicules = vehicules.length;
    final occupationRate = totalVehicules > 0 
        ? ((nbLoues / totalVehicules) * 100).toStringAsFixed(0) 
        : '0';

    final prenom = profile?.prenom ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour $prenom'),
        actions: [
          if (retards.isNotEmpty)
            Badge(
              label: Text('${retards.length}'),
              child: IconButton(
                icon: const Icon(Icons.warning_amber_outlined),
                onPressed: () => context.go('/locations'),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(vehiculesProvider);
              ref.invalidate(locationsActivesProvider);
              ref.invalidate(locationsRetardProvider);
              ref.invalidate(clientsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vehiculesProvider);
          ref.invalidate(locationsActivesProvider);
          ref.invalidate(locationsRetardProvider);
          ref.invalidate(clientsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Section: Alertes
            if (retards.isNotEmpty)
              _AlerteRetards(retards: retards),

            // Section: Statistiques principales
            Text('Vue d\'ensemble', style: AppTextStyles.heading2),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: StatTrendCard(
                label: 'Disponibles', value: '$nbDispo', color: AppColors.disponible, icon: Icons.check_circle_outline)),
              const SizedBox(width: 8),
              Expanded(child: StatTrendCard(
                label: 'Loués', value: '$nbLoues', color: AppColors.loue, icon: Icons.car_rental)),
              const SizedBox(width: 8),
              Expanded(child: StatTrendCard(
                label: 'Réparation', value: '$nbRepairs', color: AppColors.reparation, icon: Icons.build_outlined)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: StatTrendCard(
                label: 'Clients', value: '$nbClients', color: AppColors.primary, icon: Icons.people_outline)),
              const SizedBox(width: 8),
              Expanded(child: StatTrendCard(
                label: 'Taux d\'occupation', value: '$occupationRate%', color: AppColors.secondary, icon: Icons.pie_chart_outline)),
              const SizedBox(width: 8),
              Expanded(child: StatTrendCard(
                label: 'Total', value: '$totalVehicules', color: AppColors.accent, icon: Icons.directions_car_outlined)),
            ]),

            // Section: Actions rapides (only for users with management permissions)
            if (canManage) ...[
              const SizedBox(height: 20),
              Text('Actions rapides', style: AppTextStyles.heading2),
              const SizedBox(height: 10),
              Row(children: [
                if (canCreateLocation)
                  Expanded(child: _QuickAction(
                    'Nouvelle location', Icons.add_circle_outline, AppColors.secondary,
                    () => context.go('/locations/new'))),
                if (canCreateVehicule)
                  Expanded(child: _QuickAction(
                    'Ajouter véhicule', Icons.car_rental, AppColors.primary,
                    () => context.go('/vehicules/new'))),
                if (canCreateClient)
                  Expanded(child: _QuickAction(
                    'Nouveau client', Icons.person_add, AppColors.accent,
                    () => context.go('/clients/new'))),
              ]),
            ],

            // Section: Répartition du parc
            if (totalVehicules > 0) ...[
              const SizedBox(height: 20),
              RepartitionPieChart(parts: {
                'Disponibles': nbDispo.toDouble(),
                'Loués': nbLoues.toDouble(),
                'Réparation': nbRepairs.toDouble(),
              }),
            ],

            // Section: Locations en cours
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Locations en cours',
                  style: AppTextStyles.heading2),
                TextButton(
                  onPressed: () => context.go('/locations'),
                  child: const Text('Voir tout')),
              ],
            ),
            const SizedBox(height: 8),
            if (actives.isEmpty)
              const EmptyState(
                icon: Icons.car_rental,
                message: 'Aucune location active')
            else
              ...actives.take(5).map((l) =>
                _LocationTile(location: l)),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _AlerteRetards extends StatelessWidget {
  final List<Location> retards;
  const _AlerteRetards({required this.retards});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.retard.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: AppColors.retard.withValues(alpha: 0.3))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded,
            color: AppColors.retard, size: 18),
          const SizedBox(width: 6),
          Text('${retards.length} retard(s)',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.retard, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        ...retards.take(3).map((l) {
          final vehNom  = l.vehiculeNom ?? '---';
          final jours   = l.joursRetard;
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(vehNom,
                  style: AppTextStyles.body
                    .copyWith(fontSize: 13)),
                Text('$jours j de retard',
                  style: const TextStyle(
                    color: AppColors.retard,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

class _LocationTile extends StatelessWidget {
  final Location location;
  const _LocationTile({required this.location});

  @override
  Widget build(BuildContext context) {
    final vehNom    = location.vehiculeNom ?? '---';
    final clientNom = location.clientNom   ?? '---';
    final jour      = location.dateFinPrevue.day
      .toString().padLeft(2, '0');
    final mois      = location.dateFinPrevue.month
      .toString().padLeft(2, '0');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: location.isOverdue
            ? AppColors.retard.withValues(alpha: 0.1)
            : AppColors.loue.withValues(alpha: 0.1),
          child: Icon(Icons.car_rental,
            color: location.isOverdue
              ? AppColors.retard : AppColors.loue,
            size: 18)),
        title: Text(vehNom, style: AppTextStyles.heading3),
        subtitle: Text(clientNom,
          style: AppTextStyles.bodySecondary),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (location.isOverdue)
              Text('${location.joursRetard}j retard',
                style: const TextStyle(
                  color: AppColors.retard,
                  fontSize: 11,
                  fontWeight: FontWeight.w600))
            else
              Text('Retour le', style: AppTextStyles.label),
            Text('$jour/$mois',
              style: AppTextStyles.bodySecondary),
          ]),
        onTap: () => context.push(
          '/locations/${location.id}/retour'),
      ),
    );
  }
}