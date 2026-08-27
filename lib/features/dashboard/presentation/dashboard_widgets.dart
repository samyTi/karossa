import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

/// 📊 Graphique Comparatif : Revenus vs Dépenses Mensuels
class RevenusChart extends StatelessWidget {
  final List<double> revenus;
  final List<double> depenses;

  const RevenusChart({super.key, required this.revenus, required this.depenses});

  @override
  Widget build(BuildContext context) {
    final mois = ['Jan','Fév','Mar','Avr','Mai','Juin','Juil','Aoû','Sep','Oct','Nov','Déc'];
    
    // Calcul sécurisé du plafond MaxY pour éviter les crashs si les comptes sont à 0
    final rawMaxY = (revenus + depenses).fold(0.0, (a, b) => a > b ? a : b);
    final maxY = rawMaxY == 0 ? 10000.0 : rawMaxY;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.comparatifAnnuelDa, style: AppTextStyles.heading3),
          const SizedBox(height: 6),
          Row(children: [
            _buildLegendCircle(AppColors.secondary, 'Revenus Terminés'),
            const SizedBox(width: 16),
            _buildLegendCircle(AppColors.reparation, 'Frais Ateliers'),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.2,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(mois[v.toInt().clamp(0, 11)], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ),
                    ),
                  ),
                ),
                barGroups: List.generate(12, (i) => BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: revenus.length > i ? revenus[i] : 0,
                      color: AppColors.secondary,
                      width: 8,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    BarChartRodData(
                      toY: depenses.length > i ? depenses[i] : 0,
                      color: AppColors.reparation,
                      width: 8,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendCircle(Color color, String text) => Row(
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ],
  );
}

/// 🍕 Graphique Circulaire : Répartition Dynamique du Parc Automobile
class RepartitionPieChart extends StatelessWidget {
  final int nbDispo, nbLoues, nbRepairs;

  const RepartitionPieChart({super.key, required this.nbDispo, required this.nbLoues, required this.nbRepairs});

  @override
  Widget build(BuildContext context) {
    final total = nbDispo + nbLoues + nbRepairs;
    final bool hasVehicules = total > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.statutDeLaFlotteAuto, style: AppTextStyles.heading3),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 35,
                    sections: hasVehicules
                        ? [
                            PieChartSectionData(color: AppColors.disponible, value: nbDispo.toDouble(), title: nbDispo > 0 ? '$nbDispo' : '', titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white), radius: 40),
                            PieChartSectionData(color: AppColors.loue, value: nbLoues.toDouble(), title: nbLoues > 0 ? '$nbLoues' : '', titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white), radius: 40),
                            PieChartSectionData(color: AppColors.reparation, value: nbRepairs.toDouble(), title: nbRepairs > 0 ? '$nbRepairs' : '', titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white), radius: 40),
                          ]
                        : [
                            PieChartSectionData(color: Colors.grey.withValues(alpha: 0.2), value: 1, title: '0', titleStyle: const TextStyle(fontSize: 13, color: Colors.grey), radius: 40),
                          ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildLegendItem('Disponibles', nbDispo, total, AppColors.disponible),
                    const SizedBox(height: 8),
                    _buildLegendItem('En Location', nbLoues, total, AppColors.loue),
                    const SizedBox(height: 8),
                    _buildLegendItem('En Atelier', nbRepairs, total, AppColors.reparation),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        Text('$count ($pct%)', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// 📈 Carte KPI Individuelle avec indicateur d'évolution / tendance
class StatTrendCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  final double? trend;

  const StatTrendCard({super.key, required this.label, required this.value, required this.color, required this.icon, this.trend});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 125,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: color.withValues(alpha: 0.7)),
              if (trend != null) _buildTrendBadge(),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildTrendBadge() {
    final isPositive = trend! >= 0;
    final badgeColor = isPositive ? AppColors.disponible : AppColors.retard;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, size: 10, color: badgeColor),
          Text('${trend!.abs().toStringAsFixed(0)}%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor)),
        ],
      ),
    );
  }
}