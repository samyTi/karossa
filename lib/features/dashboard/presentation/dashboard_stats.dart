import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/extensions/l10n_extension.dart';

class DashboardStats extends StatelessWidget {
  final int nbDispo, nbLoues, nbRepairs, nbClients, totalVehicules;
  final String occupationRate;

  const DashboardStats({
    super.key, 
    required this.nbDispo, 
    required this.nbLoues, 
    required this.nbRepairs, 
    required this.nbClients, 
    required this.occupationRate, 
    required this.totalVehicules
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(context.l10n.vueDEnsemble, style: AppTextStyles.heading2),
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
        _buildChartSection(context),
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
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildChartSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(context.l10n.repartitionDuParc, style: AppTextStyles.heading2),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
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
                    PieChartSectionData(color: AppColors.disponible, value: nbDispo.toDouble(), title: nbDispo > 0 ? '$nbDispo' : '', titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), radius: 50),
                    PieChartSectionData(color: AppColors.loue, value: nbLoues.toDouble(), title: nbLoues > 0 ? '$nbLoues' : '', titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), radius: 50),
                    PieChartSectionData(color: AppColors.reparation, value: nbRepairs.toDouble(), title: nbRepairs > 0 ? '$nbRepairs' : '', titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), radius: 50),
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
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTextStyles.body)),
        Text('$count', style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}