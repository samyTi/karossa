import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class RevenusChart extends StatefulWidget {
  final List<double> revenus;
  final List<double> depenses;
  const RevenusChart({super.key, required this.revenus, required this.depenses});

  @override
  State<RevenusChart> createState() => _RevenusChartState();
}

class _RevenusChartState extends State<RevenusChart> {
  int? _touchedGroupIndex;

  @override
  Widget build(BuildContext context) {
    final mois = ['J','F','M','A','M','J','J','A','S','O','N','D'];
    final maxY = (widget.revenus + widget.depenses).fold(0.0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Revenus vs Dépenses', style: AppTextStyles.heading3),
          const SizedBox(height: 4),
          const Row(children: [
            _Legend(AppColors.secondary, 'Revenus'),
            SizedBox(width: 16),
            _Legend(AppColors.reparation, 'Dépenses'),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(BarChartData(
              maxY: maxY * 1.2,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.border, strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  ),
                topTitles: const AxisTitles(
                  ),
                rightTitles: const AxisTitles(
                  ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Text(
                      mois[v.toInt().clamp(0, 11)],
                      style: AppTextStyles.label),
                  )),
              ),
              barGroups: List.generate(12, (i) => BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: widget.revenus.length > i ? widget.revenus[i] : 0,
                    color: AppColors.secondary,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  BarChartRodData(
                    toY: widget.depenses.length > i ? widget.depenses[i] : 0,
                    color: AppColors.reparation,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              )),
            )),
          ),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4),
    Text(label, style: AppTextStyles.label),
  ]);
}

class RepartitionPieChart extends StatefulWidget {
  final Map<String, double> parts;
  const RepartitionPieChart({super.key, required this.parts});

  @override
  State<RepartitionPieChart> createState() => _RepartitionPieChartState();
}

class _RepartitionPieChartState extends State<RepartitionPieChart> {
  final int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.disponible,
      AppColors.loue,
      AppColors.reparation,
      AppColors.reserve,
    ];
    final entries = widget.parts.entries.toList();
    final total = widget.parts.values.fold(0.0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Répartition du parc', style: AppTextStyles.heading3),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 35,
                  sections: List.generate(entries.length, (i) {
                    final isTouched = i == _touchedIndex;
                    final radius = isTouched ? 42.0 : 36.0;
                    final title = total > 0
                        ? '${(entries[i].value / total * 100).toStringAsFixed(0)}%'
                        : '0%';
                    return PieChartSectionData(
                      color: colors[i % colors.length],
                      value: entries[i].value,
                      title: isTouched ? title : '',
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      radius: radius,
                    );
                  }),
                )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(entries.length, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entries[i].key,
                          style: AppTextStyles.body,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        total > 0
                            ? '${(entries[i].value / total * 100).toStringAsFixed(0)}%'
                            : '0%',
                        style: AppTextStyles.bodySecondary.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                  )),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Widget de statistiques avec indicateur de tendance
class StatTrendCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final double? trend;

  const StatTrendCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.trend,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 18, color: color.withValues(alpha: 0.7)),
            if (trend != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: trend! >= 0
                      ? AppColors.disponible.withValues(alpha: 0.15)
                      : AppColors.retard.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trend! >= 0 ? Icons.trending_up : Icons.trending_down,
                      size: 10,
                      color: trend! >= 0
                          ? AppColors.disponible
                          : AppColors.retard,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${trend!.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: trend! >= 0
                            ? AppColors.disponible
                            : AppColors.retard,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.label,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}