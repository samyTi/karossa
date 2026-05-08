import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
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

class ModernDashboard extends ConsumerWidget {
  const ModernDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final vehiculesAsync = ref.watch(vehiculesProvider);
    final clients = ref.watch(clientsProvider).valueOrNull ?? [];
    final retards = ref.watch(locationsRetardProvider).valueOrNull ?? [];
    final actives = ref.watch(locationsActivesProvider).valueOrNull ?? [];

    final canManage = profile?.isGerant ?? false;
    final canCreateLocation = profile?.canCreateLocation ?? false;
    final canCreateVehicule = profile?.canCreateVehicule ?? false;
    final canCreateClient = profile?.canCreateClient ?? false;

    final vehicules = vehiculesAsync.valueOrNull ?? [];
    final nbDispo = vehicules.where((v) => v.statut == VehiculeStatut.disponible).length;
    final nbLoues = vehicules.where((v) => v.statut == VehiculeStatut.loue).length;
    final nbRepairs = vehicules.where((v) => v.statut == VehiculeStatut.reparation).length;
    final nbClients = clients.length;
    final totalVehicules = vehicules.length;
    final occupationRate = totalVehicules > 0 ? ((nbLoues / totalVehicules) * 100).toStringAsFixed(0) : '0';

    final prenom = profile?.prenom ?? '';
    final role = profile?.role;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: vehiculesAsync.when(
        loading: () => const ModernDashboardShimmer(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (_) => CustomScrollView(
          slivers: [
            // ── App Bar moderne avec dégradé ──────────────────
            _buildModernAppBar(context, prenom, role, retards),

            // ── Barre de recherche rapide ─────────────────────
            _buildQuickSearchBar(context),

            // ── Section: Activité récente ─────────────────────
            _buildRecentActivitySection(context),

            // ── Section: Alertes (si retards) ──────────────────
            if (retards.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildAlertesSection(retards, context),
              ),

            // ── Section: Statistiques avec cartes modernes ─────
            SliverToBoxAdapter(
              child: _buildStatsSection(
                nbDispo, nbLoues, nbRepairs, nbClients, occupationRate, totalVehicules,
              ),
            ),

            // ── Section: Actions rapides ───────────────────────
            if (canManage)
              SliverToBoxAdapter(
                child: _buildQuickActions(context, canCreateLocation, canCreateVehicule, canCreateClient),
              ),

            // ── Section: Graphique de répartition ──────────────
            if (totalVehicules > 0)
              SliverToBoxAdapter(
                child: _buildChartSection(nbDispo, nbLoues, nbRepairs),
              ),

            // ── Section: Locations en cours ────────────────────
            SliverToBoxAdapter(
              child: _buildLocationsSection(actives, context),
            ),

            // ── Padding final ──────────────────────────────────
            const SliverToBoxAdapter(
              child: const SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context, String prenom, UserRole? role, List<Location> retards) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8),
                AppColors.secondary.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                        ),
                        child: const Icon(Icons.dashboard, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bonjour, $prenom',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (role != null)
                              Text(
                                _getRoleLabel(role),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Bouton de rafraîchissement
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () {
                            // Rafraîchissement via le bouton dans l'app bar originale
                          },
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Indicateur de retards
                  if (retards.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${retards.length} retard(s) à gérer',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrateur';
      case UserRole.gerant:
        return 'Gérant';
      case UserRole.proprietaire_showroom:
        return 'Propriétaire Showroom';
      case UserRole.proprietaire_vehicule:
        return 'Propriétaire Véhicule';
    }
  }

  Widget _buildAlertesSection(List<Location> retards, BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.retard.withValues(alpha: 0.1),
            AppColors.retard.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.retard.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.retard.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.retard, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                '${retards.length} retard(s) de location',
                style: AppTextStyles.heading3.copyWith(color: AppColors.retard),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/locations'),
                child: const Text('Voir tout', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...retards.take(3).map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.vehiculeNom ?? '---',
                    style: AppTextStyles.body,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.retard.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${l.joursRetard}j',
                    style: const TextStyle(
                      color: AppColors.retard,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildStatsSection(int nbDispo, int nbLoues, int nbRepairs, int nbClients, String occupationRate, int totalVehicules) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text('Vue d\'ensemble', style: AppTextStyles.heading2),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildStatCard('Disponibles', '$nbDispo', AppColors.disponible, Icons.check_circle_outline, null),
              _buildStatCard('Loués', '$nbLoues', AppColors.loue, Icons.car_rental, null),
              _buildStatCard('Réparation', '$nbRepairs', AppColors.reparation, Icons.build_outlined, null),
              _buildStatCard('Clients', '$nbClients', AppColors.primary, Icons.people_outline, null),
              _buildStatCard('Occupation', '$occupationRate%', AppColors.secondary, Icons.pie_chart_outline, null),
              _buildStatCard('Total', '$totalVehicules', AppColors.accent, Icons.directions_car_outlined, null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon, double? trend) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: color.withValues(alpha: 0.7)),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: trend >= 0 ? AppColors.disponible.withValues(alpha: 0.15) : AppColors.retard.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    trend >= 0 ? Icons.trending_up : Icons.trending_down,
                    size: 10,
                    color: trend >= 0 ? AppColors.disponible : AppColors.retard,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool canCreateLocation, bool canCreateVehicule, bool canCreateClient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text('Actions rapides', style: AppTextStyles.heading2),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (canCreateLocation)
                Expanded(child: _buildQuickActionCard('Location', Icons.car_rental, AppColors.secondary, () => context.go('/locations/new'))),
              if (canCreateVehicule)
                Expanded(child: _buildQuickActionCard('Véhicule', Icons.directions_car, AppColors.primary, () => context.go('/vehicules/new'))),
              if (canCreateClient)
                Expanded(child: _buildQuickActionCard('Client', Icons.person_add, AppColors.accent, () => context.go('/clients/new'))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(int nbDispo, int nbLoues, int nbRepairs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text('Répartition du parc', style: AppTextStyles.heading2),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      color: AppColors.disponible,
                      value: nbDispo.toDouble(),
                      title: nbDispo > 0 ? '$nbDispo' : '',
                      titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      radius: 50,
                    ),
                    PieChartSectionData(
                      color: AppColors.loue,
                      value: nbLoues.toDouble(),
                      title: nbLoues > 0 ? '$nbLoues' : '',
                      titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      radius: 50,
                    ),
                    PieChartSectionData(
                      color: AppColors.reparation,
                      value: nbRepairs.toDouble(),
                      title: nbRepairs > 0 ? '$nbRepairs' : '',
                      titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      radius: 50,
                    ),
                  ],
                )),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('Disponibles', nbDispo, AppColors.disponible),
                    const SizedBox(height: 8),
                    _buildLegendItem('Loués', nbLoues, AppColors.loue),
                    const SizedBox(height: 8),
                    _buildLegendItem('Réparation', nbRepairs, AppColors.reparation),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, int count, Color color) {
    final total = count > 0 ? count : 0;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: AppTextStyles.body),
        ),
        Text('$total', style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildQuickSearchBar(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            // TODO: Ouvrir la recherche globale
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recherche globale à implémenter')),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: AppColors.textHint),
                const SizedBox(width: 10),
                Text(
                  'Rechercher un véhicule, un client...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.keyboard, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '⌘K',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context) {
    // Activités récentes simulées (à connecter aux données réelles)
    final activities = [
      RecentActivity(
        icon: Icons.car_rental,
        title: 'Nouvelle location',
        subtitle: 'Toyota Corolla - Client: Ahmed',
        time: 'Il y a 2h',
        color: AppColors.loue,
      ),
      RecentActivity(
        icon: Icons.sell,
        title: 'Vente conclue',
        subtitle: 'BMW Série 3 - 2,500,000 DA',
        time: 'Il y a 4h',
        color: AppColors.secondary,
      ),
      RecentActivity(
        icon: Icons.person_add,
        title: 'Nouveau client',
        subtitle: 'Sarah Mohamed inscrit',
        time: 'Il y a 6h',
        color: AppColors.primary,
      ),
      RecentActivity(
        icon: Icons.build,
        title: 'Réparation terminée',
        subtitle: 'Peugeot 208 - Prête',
        time: 'Hier',
        color: AppColors.reparation,
      ),
    ];

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Activité récente', style: AppTextStyles.heading2),
                TextButton.icon(
                  onPressed: () => context.go('/notifications'),
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Voir tout'),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: activities.asMap().entries.map((entry) {
                final index = entry.key;
                final activity = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: index < activities.length - 1 ? 12 : 0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: activity.color.withValues(alpha: 0.1),
                        child: Icon(activity.icon, size: 16, color: activity.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              style: AppTextStyles.heading3.copyWith(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              activity.subtitle,
                              style: AppTextStyles.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        activity.time,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsSection(List<Location> actives, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Locations en cours', style: AppTextStyles.heading2),
              TextButton.icon(
                onPressed: () => context.go('/locations'),
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: const Text('Voir tout'),
              ),
            ],
          ),
        ),
        if (actives.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: EmptyState(icon: Icons.car_rental, message: 'Aucune location active'),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: actives.take(5).length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _buildLocationCard(actives[i], context),
          ),
      ],
    );
  }

  Widget _buildLocationCard(Location location, BuildContext context) {
    final isOverdue = location.isOverdue;
    final color = isOverdue ? AppColors.retard : AppColors.loue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(Icons.car_rental, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.vehiculeNom ?? '---',
                  style: AppTextStyles.heading3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  location.clientNom ?? '---',
                  style: AppTextStyles.bodySecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.retard.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${location.joursRetard}j retard',
                    style: const TextStyle(color: AppColors.retard, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                )
              else
                Text(
                  'Retour le ${location.dateFinPrevue.day.toString().padLeft(2, '0')}/${location.dateFinPrevue.month.toString().padLeft(2, '0')}',
                  style: AppTextStyles.label,
                ),
              const SizedBox(height: 4),
              Text(
                '${(location.prixJour * location.nbJours).toInt()} DA',
                style: AppTextStyles.money.copyWith(fontSize: 14),
              ),
            ],
          ),
        ],
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
      body: const Center(child: const CircularProgressIndicator()),
    );
  }
}

// Modèle pour l'activité récente
class RecentActivity {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  RecentActivity({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });
}
