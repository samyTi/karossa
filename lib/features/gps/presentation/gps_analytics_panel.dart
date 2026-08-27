// lib/features/gps/presentation/gps_analytics_panel.dart
//
// ★ NOUVEAU — Panneau analytique GPS par véhicule
//   • Graphique vitesse 24h (CustomPainter — aucune dépendance)
//   • Km du jour / vitesse moy / vitesse max / temps moteur
//   • Contexte location active (client, retour prévu)
//   • Alertes entretien en attente

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../domain/gps_position.dart';
import 'gps_analytics_panel_patch.dart' show KmAlerteBanner, MonthlyKmCard;
import 'gps_provider.dart';
import 'dart:ui' as ui;

/// Ouvre le panneau analytique depuis n'importe quel écran.
Future<void> showGpsAnalyticsPanel(
  BuildContext context, {
  required String vehiculeId,
  required String vehiculeNom,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProviderScope(
      child: GpsAnalyticsPanel(vehiculeId: vehiculeId, vehiculeNom: vehiculeNom),
    ),
  );
}

String _periodLabel(AnalyticsPeriod period) {
  final sameDay = period.from.year == period.to.year &&
      period.from.month == period.to.month &&
      period.from.day == period.to.day;
  if (sameDay) {
    return "Analytiques — ${DateFormat('dd MMM yyyy', 'fr').format(period.from)}";
  }
  return "Analytiques — ${DateFormat('dd MMM', 'fr').format(period.from)} "
      "→ ${DateFormat('dd MMM yyyy', 'fr').format(period.to)}";
}

// ══════════════════════════════════════════════════════════════
// Sélecteur de période (chips)
// ══════════════════════════════════════════════════════════════

class _PeriodSelector extends StatelessWidget {
  final AnalyticsPreset current;
  final void Function(AnalyticsPreset) onSelect;
  const _PeriodSelector({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const options = {
      AnalyticsPreset.today: 'Aujourd\'hui',
      AnalyticsPreset.days7: '7 jours',
      AnalyticsPreset.days30: '30 jours',
      AnalyticsPreset.custom: 'Personnalisé',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((e) {
        final selected = e.key == current;
        return ChoiceChip(
          label: Text(e.value),
          selected: selected,
          onSelected: (_) => onSelect(e.key),
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          backgroundColor: AppColors.primary.withValues(alpha: 0.06),
          side: BorderSide(color: AppColors.primary.withValues(alpha: selected ? 0 : 0.15)),
        );
      }).toList(),
    );
  }
}

class GpsAnalyticsPanel extends ConsumerWidget {
  final String vehiculeId;
  final String vehiculeNom;

  const GpsAnalyticsPanel({
    super.key,
    required this.vehiculeId,
    required this.vehiculeNom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period        = ref.watch(analyticsPeriodProvider);
    final statsAsync     = ref.watch(periodStatsProvider(
      PeriodStatsParams(vehiculeId: vehiculeId, from: period.from, to: period.to),
    ));
    final locationAsync = ref.watch(vehicleActiveLocationProvider(vehiculeId));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize:     0.4,
      maxChildSize:     0.95,
      snap:             true,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color:        Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding:    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Titre
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehiculeNom,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                      Text(
                        _periodLabel(period),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Sélecteur de période
            _PeriodSelector(
              current: period.preset,
              onSelect: (preset) async {
                if (preset == AnalyticsPreset.custom) {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                    initialDateRange: DateTimeRange(
                      start: DateTime(period.from.year, period.from.month, period.from.day),
                      end:   DateTime(period.to.year, period.to.month, period.to.day),
                    ),
                    locale: const Locale('fr'),
                  );
                  if (range == null) return;
                  ref.read(analyticsPeriodProvider.notifier).state = AnalyticsPeriod(
                    from: range.start,
                    to: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
                    preset: AnalyticsPreset.custom,
                  );
                } else {
                  ref.read(analyticsPeriodProvider.notifier).state = switch (preset) {
                    AnalyticsPreset.today => AnalyticsPeriod.today(),
                    AnalyticsPreset.days7 => AnalyticsPeriod.days(7, AnalyticsPreset.days7),
                    AnalyticsPreset.days30 => AnalyticsPeriod.days(30, AnalyticsPreset.days30),
                    AnalyticsPreset.custom => AnalyticsPeriod.today(),
                  };
                }
              },
            ),

            const SizedBox(height: 20),

            // ★ Alerte seuil kilométrique (masquée si non atteinte)
            KmAlerteBanner(vehiculeId: vehiculeId),

            // Contexte location active
            locationAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data: (loc) => loc == null ? const SizedBox.shrink() : _ActiveRentalCard(loc: loc),
            ),

            // Stats cards
            statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child:   Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child:   Text(context.l10n.erreurAvecDetail(e.toString()), style: const TextStyle(color: AppColors.error)),
              ),
              data: (stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatsGrid(stats: stats),
                  const SizedBox(height: 24),
                  // Graphique vitesse
                  if (stats.positions.length > 1) ...[
                    Text(context.l10n.vitessePeriode(_periodLabel(period)),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 190,
                      child: _SpeedChart(
                        positions: stats.positions,
                        periodStart: period.from,
                        periodEnd: period.to,
                        avgSpeed: stats.avgSpeed,
                        maxSpeed: stats.maxSpeed,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Répartition temps
                  Text(context.l10n.repartitionDuTemps,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  _TimeBreakdown(
                    movingMin:  stats.movingMinutes,
                    stoppedMin: stats.stoppedMinutes,
                  ),
                  const SizedBox(height: 24),
                  // ★ Km ce mois + comparatif + projection
                  MonthlyKmCard(vehiculeId: vehiculeId),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Location active
// ══════════════════════════════════════════════════════════════

class _ActiveRentalCard extends StatelessWidget {
  final Map<String, dynamic> loc;
  const _ActiveRentalCard({required this.loc});

  @override
  Widget build(BuildContext context) {
    final client  = loc['clients'] as Map<String, dynamic>?;
    final name    = client != null ? '${client['prenom']} ${client['nom']}' : '—';
    final phone   = client?['telephone'] as String? ?? '';
    final dateFin = loc['date_fin_prevue'] as String?;
    final retour  = dateFin != null
        ? DateFormat('dd MMM yyyy', 'fr').format(DateTime.parse(dateFin))
        : '—';

    final isLate = dateFin != null && DateTime.parse(dateFin).isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        (isLate ? AppColors.error : AppColors.loue).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(
          color: (isLate ? AppColors.error : AppColors.loue).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLate ? Icons.warning_rounded : Icons.vpn_key_rounded,
            color: isLate ? AppColors.error : AppColors.loue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'En location${isLate ? ' — RETARD' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isLate ? AppColors.error : AppColors.loue,
                    fontSize: 13,
                  ),
                ),
                Text('$name  ·  $phone',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text(context.l10n.retourPrevuValeur(retour),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Grille de statistiques 2×2
// ══════════════════════════════════════════════════════════════

class _StatsGrid extends StatelessWidget {
  final PeriodKmStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount:   2,
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      mainAxisSpacing:  10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          icon:  Icons.route_rounded,
          label: 'Km sur la période',
          value: '${stats.kmTotal.toStringAsFixed(1)} km',
          color: AppColors.primary,
        ),
        _StatCard(
          icon:  Icons.speed_rounded,
          label: 'Vitesse moy.',
          value: '${stats.avgSpeed.toStringAsFixed(0)} km/h',
          color: AppColors.secondary,
        ),
        _StatCard(
          icon:  Icons.flash_on_rounded,
          label: 'Vitesse max.',
          value: '${stats.maxSpeed.toStringAsFixed(0)} km/h',
          color: AppColors.retard,
        ),
        _StatCard(
          icon:  Icons.timer_rounded,
          label: 'Temps roulé',
          value: _fmtMinutes(stats.movingMinutes),
          color: AppColors.accent,
        ),
      ],
    );
  }

  String _fmtMinutes(int min) {
    if (min < 60) return '${min}min';
    return '${min ~/ 60}h ${min % 60}min';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      border:       Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:  MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, color: color, size: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20)),
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// Graphique vitesse (CustomPainter)
// ══════════════════════════════════════════════════════════════

class _SpeedSample {
  final DateTime time;
  final double speed;
  const _SpeedSample(this.time, this.speed);
}

/// Réduit un historique potentiellement massif (plusieurs milliers de points
/// sur "7 jours"/"30 jours" depuis le fix de pagination) à un nombre de
/// points raisonnable pour un tracé fluide et lisible, en moyennant par
/// tranche plutôt qu'en sous-échantillonnant brutalement (ce qui écraserait
/// les pics de vitesse).
List<_SpeedSample> _downsampleForChart(List<GpsPosition> positions, {int maxPoints = 160}) {
  final valid = positions.where((p) => p.speed != null && p.speed! >= 0).toList()
    ..sort((a, b) => a.fixTime.compareTo(b.fixTime));
  if (valid.isEmpty) return [];
  if (valid.length <= maxPoints) {
    return valid.map((p) => _SpeedSample(p.fixTime, p.speed!.toDouble())).toList();
  }
  final bucketSize = (valid.length / maxPoints).ceil();
  final result = <_SpeedSample>[];
  for (int i = 0; i < valid.length; i += bucketSize) {
    final slice = valid.skip(i).take(bucketSize).toList();
    if (slice.isEmpty) continue;
    final avg = slice.map((p) => p.speed!.toDouble()).reduce((a, b) => a + b) / slice.length;
    // Timestamp du milieu de la tranche pour un meilleur alignement temporel.
    result.add(_SpeedSample(slice[slice.length ~/ 2].fixTime, avg));
  }
  return result;
}

class _SpeedChart extends StatelessWidget {
  final List<GpsPosition> positions;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double avgSpeed;
  final double maxSpeed;

  const _SpeedChart({
    required this.positions,
    required this.periodStart,
    required this.periodEnd,
    required this.avgSpeed,
    required this.maxSpeed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final samples = _downsampleForChart(positions);

    if (samples.isEmpty) {
      return Center(
        child: Text(
          'Aucune donnée de vitesse sur cette période',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Légende compacte au-dessus du graphe : unité + repères couleur.
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            children: [
              Text(context.l10n.kmh,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
              const SizedBox(width: 14),
              _ChartLegendDot(color: AppColors.primary, label: 'Vitesse'),
              const SizedBox(width: 12),
              _ChartLegendDot(color: AppColors.secondary, label: 'Moy. ${avgSpeed.toStringAsFixed(0)}'),
              const SizedBox(width: 12),
              _ChartLegendDot(color: AppColors.retard, label: 'Max ${maxSpeed.toStringAsFixed(0)}'),
            ],
          ),
        ),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _SpeedChartPainter(
              samples:     samples,
              periodStart: periodStart,
              periodEnd:   periodEnd,
              avgSpeed:    avgSpeed,
              lineColor:   AppColors.primary,
              fillColor:   AppColors.primary.withValues(alpha: 0.15),
              avgColor:    AppColors.secondary,
              maxColor:    AppColors.retard,
              axisColor:   isDark ? Colors.white24 : Colors.black12,
              labelColor:  isDark ? Colors.white60 : Colors.black45,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
    ],
  );
}

class _SpeedChartPainter extends CustomPainter {
  final List<_SpeedSample> samples;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double avgSpeed;
  final Color lineColor;
  final Color fillColor;
  final Color avgColor;
  final Color maxColor;
  final Color axisColor;
  final Color labelColor;

  const _SpeedChartPainter({
    required this.samples,
    required this.periodStart,
    required this.periodEnd,
    required this.avgSpeed,
    required this.lineColor,
    required this.fillColor,
    required this.avgColor,
    required this.maxColor,
    required this.axisColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Marges généreuses : évite que les labels d'axe soient coupés,
    // notamment le dernier repère temporel à droite.
    const pad = EdgeInsets.only(left: 34, right: 12, top: 10, bottom: 26);
    final rect = Rect.fromLTRB(pad.left, pad.top, size.width - pad.right, size.height - pad.bottom);
    if (rect.width <= 0 || rect.height <= 0) return;

    final start = periodStart;
    final end   = periodEnd.isAfter(start) ? periodEnd : start.add(const Duration(hours: 1));
    final totalMs = end.difference(start).inMilliseconds.toDouble();
    final multiDay = end.difference(start).inHours > 36;

    final pts = samples
        .map((s) => Offset(
              (s.time.toLocal().difference(start).inMilliseconds / totalMs).clamp(0.0, 1.0),
              s.speed,
            ))
        .toList();

    final maxY = pts.map((p) => p.dy).reduce(math.max).clamp(10.0, double.infinity) * 1.15;

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: labelColor, fontSize: 10);

    // Grille horizontale + labels vitesse
    for (int i = 0; i <= 4; i++) {
      final y = rect.bottom - i * rect.height / 4;
      final spd = (maxY * i / 4).round();
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), axisPaint);
      _drawText(canvas, '$spd', Offset(0, y - 6), labelStyle, maxWidth: pad.left - 4);
    }

    // Grille verticale + labels temporels — le dernier label est ancré à
    // droite (au lieu d'être centré) pour ne jamais dépasser le cadre.
    for (int i = 0; i <= 4; i++) {
      final t = start.add(Duration(milliseconds: (totalMs * i / 4).round()));
      final x = rect.left + i / 4 * rect.width;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), axisPaint);
      final label = multiDay
          ? DateFormat('dd/MM').format(t.toLocal())
          : DateFormat('HH:mm').format(t.toLocal());
      final isLast = i == 4;
      _drawText(
        canvas, label,
        Offset(isLast ? x - 30 : x - 16, rect.bottom + 6),
        labelStyle,
        maxWidth: 34,
        align: isLast ? ui.TextAlign.right : ui.TextAlign.left,
      );
    }

    // Ligne de référence "vitesse moyenne" (pointillés)
    if (avgSpeed > 0 && avgSpeed <= maxY) {
      final avgY = rect.bottom - (avgSpeed / maxY) * rect.height;
      _drawDashedLine(canvas, Offset(rect.left, avgY), Offset(rect.right, avgY),
          Paint()..color = avgColor.withValues(alpha: 0.5)..strokeWidth = 1.2);
    }

    final canvasPts = pts.map((p) => Offset(
      rect.left + p.dx * rect.width,
      rect.bottom - (p.dy / maxY) * rect.height,
    )).toList();

    // Aire sous la courbe (dégradé simple)
    if (canvasPts.length > 1) {
      final fillPath = Path()..moveTo(canvasPts.first.dx, rect.bottom);
      for (final pt in canvasPts) {
        fillPath.lineTo(pt.dx, pt.dy);
      }
      fillPath.lineTo(canvasPts.last.dx, rect.bottom);
      fillPath.close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, rect.top),
            Offset(0, rect.bottom),
            [fillColor, fillColor.withValues(alpha: 0.02)],
          ),
      );
    }

    // Courbe lissée
    if (canvasPts.length > 1) {
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()..moveTo(canvasPts.first.dx, canvasPts.first.dy);
      for (int i = 1; i < canvasPts.length; i++) {
        final prev = canvasPts[i - 1];
        final curr = canvasPts[i];
        final cp1 = Offset((prev.dx + curr.dx) / 2, prev.dy);
        final cp2 = Offset((prev.dx + curr.dx) / 2, curr.dy);
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
      }
      canvas.drawPath(path, linePaint);
    } else if (canvasPts.length == 1) {
      canvas.drawCircle(canvasPts.first, 3, Paint()..color = lineColor);
    }

    // Marqueur du pic de vitesse
    if (canvasPts.isNotEmpty) {
      final maxIdx = pts.indexWhere((p) => p.dy == pts.map((q) => q.dy).reduce(math.max));
      if (maxIdx >= 0) {
        final peak = canvasPts[maxIdx];
        canvas.drawCircle(peak, 4, Paint()..color = maxColor);
        canvas.drawCircle(peak, 4, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint, {double dash = 4, double gap = 3}) {
    final total = (b - a).distance;
    final dir = (b - a) / total;
    double covered = 0;
    while (covered < total) {
      final segEnd = math.min(covered + dash, total);
      canvas.drawLine(a + dir * covered, a + dir * segEnd, paint);
      covered += dash + gap;
    }
  }

  void _drawText(
    Canvas canvas, String text, Offset offset, TextStyle style, {
    double? maxWidth,
    ui.TextAlign align = ui.TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth ?? double.infinity);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SpeedChartPainter oldDelegate) =>
      oldDelegate.samples != samples || oldDelegate.avgSpeed != avgSpeed;
}

// ══════════════════════════════════════════════════════════════
// Répartition temps (donut simplifié)
// ══════════════════════════════════════════════════════════════

class _TimeBreakdown extends StatelessWidget {
  final int movingMin;
  final int stoppedMin;

  const _TimeBreakdown({required this.movingMin, required this.stoppedMin});

  String _fmt(int min) {
    if (min < 60) return '${min}min';
    return '${min ~/ 60}h ${min % 60}min';
  }

  @override
  Widget build(BuildContext context) {
    final total = movingMin + stoppedMin;
    if (total == 0) return const SizedBox.shrink();

    final movingPct = movingMin / total;
    final stoppedPct = stoppedMin / total;

    return Row(
      children: [
        // Barre
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Expanded(
                      flex: (movingPct * 100).round(),
                      child: Container(height: 14, color: AppColors.secondary),
                    ),
                    Expanded(
                      flex: (stoppedPct * 100).round(),
                      child: Container(height: 14, color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Legend(color: AppColors.secondary, label: 'En mouvement', value: _fmt(movingMin)),
                  const SizedBox(width: 20),
                  _Legend(color: AppColors.primary.withValues(alpha: 0.5), label: 'À l\'arrêt', value: _fmt(stoppedMin)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _Legend({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    ],
  );
}