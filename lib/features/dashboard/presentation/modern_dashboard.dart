// lib/features/dashboard/presentation/modern_dashboard.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core & Shared Widgets
import '../../../core/theme/app_colors.dart';
import 'dashboard_providers.dart';
import 'dashboard_widgets.dart';
import 'dashboard_sub_views.dart';
import 'kpi_cards.dart';

// Providers Métiers
import '../../auth/presentation/auth_provider.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import '../../locations/presentation/locations_provider.dart';
import '../../clients/presentation/clients_provider.dart';
import '../../gps/presentation/gps_home_widget.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class ModernDashboard extends ConsumerWidget {
  const ModernDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Branchement sur les flux de données réactifs (SaaS / Multi-Tenant)
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final vehiculesAsync = ref.watch(vehiculesProvider);
    final clients = ref.watch(clientsProvider).valueOrNull ?? [];
    final retards = ref.watch(locationsRetardProvider).valueOrNull ?? [];
    final actives = ref.watch(locationsActivesProvider).valueOrNull ?? [];
    final annualChartsAsync = ref.watch(annualChartProvider);
    
    final vehicules = vehiculesAsync.valueOrNull ?? [];

    // 2. Traitement analytique dérivé de la flotte automobile
    final nbDispo = vehicules.where((v) => v.statut == VehiculeStatut.disponible).length;
    final nbLoues = vehicules.where((v) => v.statut == VehiculeStatut.loue).length;
    final nbRepairs = vehicules.where((v) => v.statut == VehiculeStatut.reparation).length;
    final totalVehicules = vehicules.length;
    final occupationRate = totalVehicules > 0 ? ((nbLoues / totalVehicules) * 100).toStringAsFixed(0) : '0';

    // 3. Modélisation factuelle des dernières opérations du parc
    final activities = [
      RecentActivity(icon: Icons.add_moderator_outlined, title: context.l10n.checkInVehicule, subtitle: context.l10n.retourConformeDeLaGolf8, time: '1h', color: AppColors.disponible),
      RecentActivity(icon: Icons.car_rental, title: context.l10n.nouveauContrat, subtitle: context.l10n.locationSigneeBmwSerie3, time: '3h', color: AppColors.loue),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: vehiculesAsync.when(
        loading: () => const ModernDashboardShimmer(),
        error: (err, _) => Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(context.l10n.erreurCritiqueSynchronisation(err.toString()), style: const TextStyle(color: AppColors.retard)),
        )),
        data: (_) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            // Invalidation complète des caches de données pour forcer une ré-interrogation de Supabase
            ref.invalidate(vehiculesProvider);
            ref.invalidate(clientsProvider);
            ref.invalidate(locationsRetardProvider);
            ref.invalidate(locationsActivesProvider);
            ref.invalidate(revenusKpiProvider);
            ref.invalidate(annualChartProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // En-tête Dynamique & alertes critiques
              DashboardAppBar(
                prenom: profile?.prenom ?? 'Gérant',
                role: profile?.role,
                retards: retards,
                onRefresh: () {
                  ref.invalidate(vehiculesProvider);
                  ref.invalidate(revenusKpiProvider);
                  ref.invalidate(annualChartProvider);
                },
              ),

              // Section I : Bilan comptable mensuel (Locations / Ventes / Dépenses)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: KpiRevenusRow(),
                ),
              ),

              // Section II : Indicateurs de performance horizontaux (KPI Cards)
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      StatTrendCard(label: context.l10n.disponibles, value: '$nbDispo', color: AppColors.disponible, icon: Icons.check_circle_outline, trend: 4),
                      StatTrendCard(label: context.l10n.enLocation, value: '$nbLoues', color: AppColors.loue, icon: Icons.car_rental, trend: 12),
                      StatTrendCard(label: context.l10n.enAtelier, value: '$nbRepairs', color: AppColors.reparation, icon: Icons.build_outlined, trend: -2),
                      StatTrendCard(label: context.l10n.portefeuilleClients, value: '${clients.length}', color: AppColors.primary, icon: Icons.people_outline),
                      StatTrendCard(label: context.l10n.tauxOccupation, value: '$occupationRate%', color: AppColors.secondary, icon: Icons.pie_chart_outline),
                    ],
                  ),
                ),
              ),

              // Section III : Graphique d'Analyse Comparative Annuelle (Revenus vs Dépenses)
              SliverToBoxAdapter(
                child: annualChartsAsync.when(
                  loading: () => SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (chartData) => RevenusChart(revenus: chartData.revenus, depenses: chartData.depenses),
                ),
              ),

              // Section IV : Distribution Visuelle de la flotte (PieChart)
              SliverToBoxAdapter(
                child: RepartitionPieChart(nbDispo: nbDispo, nbLoues: nbLoues, nbRepairs: nbRepairs),
              ),

              // Section IV bis : Flotte en temps réel (mini-carte GPS)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: GpsFleetHomeWidget(),
                ),
              ),

              // Section V : Journal d'activité récente du showroom
              DashboardRecentActivity(activities: activities),

              // Section VI : Listing des 5 derniers contrats de location actifs
              SliverToBoxAdapter(
                child: DashboardLocationsList(actives: actives),
              ),

              // Espacement de confort de fin de scroll
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

class ModernDashboardShimmer extends StatelessWidget {
  const ModernDashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
            SizedBox(height: 16),
            Text(context.l10n.generationDesMetriquesKarossa, style: TextStyle(color: Colors.grey, fontSize: 13, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}