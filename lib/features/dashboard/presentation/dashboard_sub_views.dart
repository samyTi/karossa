import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/domain/profile_model.dart';
import '../../locations/domain/location_model.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

/// 🌌 En-tête Sliver du Dashboard avec dégradé et gestion de crise (retards)
class DashboardAppBar extends StatelessWidget {
  final String prenom;
  final UserRole? role;
  final List<Location> retards;
  final VoidCallback onRefresh;

  const DashboardAppBar({super.key, required this.prenom, this.role, required this.retards, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 170,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.85), AppColors.secondary.withValues(alpha: 0.7)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileRow(context),
                  const Spacer(),
                  if (retards.isNotEmpty) _buildAlertRow(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(BuildContext context) => Row(
    children: [
      Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.bonjourPrenom(prenom), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            if (role != null)
              Text(role!.label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      IconButton(
        icon: const Icon(Icons.sync_rounded, color: Colors.white),
        tooltip: context.l10n.actualiserLesFiches,
        onPressed: onRefresh,
      ),
    ],
  );

  Widget _buildAlertRow(BuildContext context) => InkWell(
    onTap: () => context.go('/locations'),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.retard, size: 16),
          const SizedBox(width: 8),
          Text(
            context.l10n.actionRequiseRetards(retards.length.toString()),
            style: const TextStyle(color: AppColors.retard, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.retard, size: 14),
        ],
      ),
    ),
  );
}

/// ⚡ Flux des Activités Récentes (Structure Sliver Native)
class DashboardRecentActivity extends StatelessWidget {
  final List<RecentActivity> activities;
  const DashboardRecentActivity({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.l10n.journalDeBord, style: AppTextStyles.heading2),
                TextButton(
                  onPressed: () => context.go('/notifications'),
                  child: Text(context.l10n.voirTout, style: TextStyle(fontSize: 12)),
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
            ),
            child: Column(
              children: List.generate(activities.length, (i) {
                final act = activities[i];
                return Padding(
                  padding: EdgeInsets.only(bottom: i < activities.length - 1 ? 12 : 0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: act.color.withValues(alpha: 0.1),
                        child: Icon(act.icon, size: 14, color: act.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(act.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(act.subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Text(act.time, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🚗 Liste des Contrats de Location Actifs
class DashboardLocationsList extends StatelessWidget {
  final List<Location> actives;
  const DashboardLocationsList({super.key, required this.actives});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.locationsEnCours, style: AppTextStyles.heading2),
              TextButton(
                onPressed: () => context.go('/locations'),
                child: Text(context.l10n.toutesLesFiches, style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        if (actives.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: EmptyState(
              icon: Icons.car_rental_outlined, 
              message: context.l10n.aucunContratLocationActif
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: actives.take(5).length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _buildCard(actives[i], context),
          ),
      ],
    );
  }

  Widget _buildCard(Location loc, BuildContext context) {
    final isOverdue = loc.isOverdue;
    final color = isOverdue ? AppColors.retard : AppColors.loue;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.08),
            child: Icon(Icons.directions_car, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.vehiculeNom ?? context.l10n.vehiculeInconnu, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(loc.clientNom ?? context.l10n.clientInconnu, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.retard.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(context.l10n.nJoursRetard(loc.joursRetard.toString()), style: const TextStyle(color: AppColors.retard, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                Text('${context.l10n.fin}: ${loc.dateFinPrevue.toDashboardFormat()}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              const SizedBox(height: 4),
              Text('${(loc.prixJour * loc.nbJours).toInt()} DA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

class RecentActivity {
  final IconData icon;
  final String title, subtitle, time;
  final Color color;
  RecentActivity({required this.icon, required this.title, required this.subtitle, required this.time, required this.color});
}