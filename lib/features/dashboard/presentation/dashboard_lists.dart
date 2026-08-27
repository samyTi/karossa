import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../features/locations/domain/location_model.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

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
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.l10n.activiteRecente, style: AppTextStyles.heading2),
                TextButton.icon(
                  onPressed: () => context.go('/notifications'),
                  icon: Icon(Icons.arrow_forward, size: 14),
                  label: Text(context.l10n.voirTout),
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
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
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
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activity.title, style: AppTextStyles.heading3.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(activity.subtitle, style: AppTextStyles.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Text(activity.time, style: AppTextStyles.label.copyWith(color: AppColors.textTertiary, fontSize: 11)),
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
}

class DashboardLocationsList extends StatelessWidget {
  final List<Location> actives;
  const DashboardLocationsList({super.key, required this.actives});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.locationsEnCours, style: AppTextStyles.heading2),
              TextButton.icon(
                onPressed: () => context.go('/locations'),
                icon: Icon(Icons.arrow_forward, size: 14),
                label: Text(context.l10n.voirTout),
              ),
            ],
          ),
        ),
        if (actives.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: EmptyState(icon: Icons.car_rental, message: context.l10n.aucuneLocationActive),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: actives.take(5).length,
            separatorBuilder: (_, __) => SizedBox(height: 10),
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
          BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(Icons.car_rental, color: color, size: 20),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(location.vehiculeNom ?? '---', style: AppTextStyles.heading3, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(location.clientNom ?? '---', style: AppTextStyles.bodySecondary, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.retard.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(context.l10n.joursRetard(location.joursRetard.toString()), style: const TextStyle(color: AppColors.retard, fontSize: 11, fontWeight: FontWeight.w700)),
                )
              else
                Text(
                  'Retour le ${location.dateFinPrevue.toDashboardFormat()}',
                  style: AppTextStyles.label,
                ),
              SizedBox(height: 4),
              Text('${(location.prixJour * location.nbJours).toInt()} DA', style: AppTextStyles.money.copyWith(fontSize: 14)),
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