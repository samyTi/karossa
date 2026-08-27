// lib/features/gps/presentation/gps_analytics_panel_patch.dart
//
// PATCH pour gps_analytics_panel.dart
//
// Ajouter ces 3 widgets dans le panel existant :
//   1. _MonthlyKmCard   — km ce mois + comparatif mois dernier + projection
//   2. _SpeedChart      — graphique de vitesse sur la journée (fl_chart)
//   3. _KmAlerteBanner  — alerte visuelle si km_actuel ≥ km_alerte_seuil
//
// Dépendances nouvelles :
//   fl_chart: ^0.68.0  (ou version compatible)
//   providers : monthlyKmProvider, speedTimelineProvider,
//               vehicleGpsContextProvider (dans gps_provider_additions.dart)
//
// ──────────────────────────────────────────────────────────────
// Instructions d'intégration :
//
//   Dans showGpsAnalyticsPanel() / _GpsAnalyticsPanelContent.build(),
//   après le widget _DailyStatsRow existant, ajouter :
//
//     _KmAlerteBanner(vehiculeId: vehiculeId),
//     const SizedBox(height: 16),
//     _SpeedChart(vehiculeId: vehiculeId),
//     const SizedBox(height: 16),
//     _MonthlyKmCard(vehiculeId: vehiculeId),
//
// ──────────────────────────────────────────────────────────────

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import 'gps_provider_additions.dart';
import '../../../core/extensions/l10n_extension.dart';

// ══════════════════════════════════════════════════════════════
// 1. Bannière alerte km seuil
// ══════════════════════════════════════════════════════════════

class KmAlerteBanner extends ConsumerWidget {
  final String vehiculeId;
  const KmAlerteBanner({super.key, required this.vehiculeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(vehicleGpsContextProvider(vehiculeId));

    return ctx.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (c) {
        if (!c.isKmAlert) return const SizedBox.shrink();

        final pct = c.kmAlerteSeuil != null && c.kmAlerteSeuil! > 0
            ? (c.kilometrageActuel! / c.kmAlerteSeuil! * 100).clamp(0, 100).toInt()
            : 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:        AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seuil kilométrique atteint',
                      style: TextStyle(
                        color:      AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize:   13,
                      ),
                    ),
                    Text(
                      '${_fmt(c.kilometrageActuel ?? 0)} km / ${_fmt(c.kmAlerteSeuil ?? 0)} km ($pct%)',
                      style: const TextStyle(color: AppColors.error, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(int n) => NumberFormat('#,###', 'fr').format(n);
}

// ══════════════════════════════════════════════════════════════
// 2. Graphique de vitesse sur la journée
// ══════════════════════════════════════════════════════════════

class SpeedChart extends ConsumerWidget {
  final String vehiculeId;
  const SpeedChart({super.key, required this.vehiculeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(speedTimelineProvider(vehiculeId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vitesse aujourd\'hui',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: timelineAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:   (_, __) => Center(
              child: Text(context.l10n.donneesNonDisponibles, style: const TextStyle(color: AppColors.textSecondary)),
            ),
            data: (points) {
              if (points.isEmpty) {
                return Center(
                  child: Text(context.l10n.aucunTrajetAujourdhui,
                      style: const TextStyle(color: AppColors.textSecondary)),
                );
              }

              final maxY = points.map((p) => p.speed).reduce((a, b) => a > b ? a : b);
              final spots = points.asMap().entries.map((e) =>
                  FlSpot(e.key.toDouble(), e.value.speed)).toList();

              return LineChart(
                LineChartData(
                  minY: 0,
                  maxY: (maxY * 1.2).ceilToDouble(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 30,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.textTertiary.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 30,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                    rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval:   (spots.length / 4).ceilToDouble(),
                        reservedSize: 22,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt().clamp(0, points.length - 1);
                          return Text(
                            DateFormat('HH:mm').format(points[idx].time),
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 9,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots:         spots,
                      isCurved:      true,
                      color:         AppColors.primary,
                      barWidth:      2,
                      dotData:       const FlDotData(show: false),
                      belowBarData:  BarAreaData(
                        show:  true,
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(0)} km/h',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      )).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 3. Carte Km mensuel
// ══════════════════════════════════════════════════════════════

class MonthlyKmCard extends ConsumerWidget {
  final String vehiculeId;
  const MonthlyKmCard({super.key, required this.vehiculeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(monthlyKmProvider(vehiculeId));

    return Container(
      padding:     const EdgeInsets.all(16),
      decoration:  BoxDecoration(
        color:        Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ce mois',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:   (_, __) => const Text('—', style: TextStyle(color: AppColors.textSecondary)),
            data: (s) => Column(
              children: [
                // Km ce mois + comparatif
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MiniStat(
                      label: 'Km ce mois',
                      value: '${s.kmThisMonth.toStringAsFixed(0)} km',
                      color: AppColors.primary,
                    ),
                    _MiniStat(
                      label: 'Mois dernier',
                      value: '${s.kmLastMonth.toStringAsFixed(0)} km',
                      color: AppColors.textSecondary,
                    ),
                    if (s.variationPct != null)
                      _MiniStat(
                        label: 'Variation',
                        value: '${s.variationPct! >= 0 ? '+' : ''}${s.variationPct!.toStringAsFixed(0)}%',
                        color: s.variationPct! >= 0 ? AppColors.secondary : AppColors.error,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Barre de progression vs mois dernier
                if (s.kmLastMonth > 0) ...[
                  Row(
                    children: [
                      Text(context.l10n.vsMoisDernier,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value:           ((s.kmThisMonth / s.kmLastMonth).clamp(0, 2) / 2).toDouble(),
                            minHeight:       6,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            valueColor:      AlwaysStoppedAnimation(
                              s.kmThisMonth >= s.kmLastMonth ? AppColors.secondary : AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                // Projection fin de mois
                Row(
                  children: [
                    const Icon(Icons.trending_up, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Projection fin de mois : ${s.projectedMonth.toStringAsFixed(0)} km'
                      '  ·  Moy. ${s.avgKmPerDay.toStringAsFixed(0)} km/j',
                      style: const TextStyle(
                        color:    AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
    ],
  );
}