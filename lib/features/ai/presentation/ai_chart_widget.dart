// lib/features/ai/presentation/ai_chart_widget.dart
//
// KarossaAI insère parfois des blocs spéciaux dans sa réponse markdown :
//   ```karossa-chart {json}```   → graphique (barres / ligne / donut)
//   ```karossa-action {json}```  → carte d'action à confirmer (écriture BDD)
//   ```karossa-damage {json}```  → constat de dommage détecté sur une photo
// Ce fichier extrait ces blocs et fournit les widgets de rendu associés,
// sans dépendance de charting externe (CustomPainter pur).

import 'dart:convert';
import 'package:garage_auto/core/extensions/l10n_extension.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../data/ai_tools_executor.dart' show AiActionResult;
import 'ai_provider.dart';

enum AiSegmentType { text, chart, action, damage }

class AiContentSegment {
  final AiSegmentType type;
  final String? text;
  final Map<String, dynamic>? payload;

  AiContentSegment.text(this.text)
      : type = AiSegmentType.text,
        payload = null;
  AiContentSegment.chart(this.payload)
      : type = AiSegmentType.chart,
        text = null;
  AiContentSegment.action(this.payload)
      : type = AiSegmentType.action,
        text = null;
  AiContentSegment.damage(this.payload)
      : type = AiSegmentType.damage,
        text = null;

  Map<String, dynamic>? get chartData => type == AiSegmentType.chart ? payload : null;
}

final RegExp _blockRegex =
    RegExp(r'```karossa-(chart|action|damage)\s*([\s\S]*?)```', multiLine: true);

/// Découpe le contenu d'un message IA en segments texte/markdown normaux
/// et segments spéciaux (chart/action/damage), en respectant l'ordre.
List<AiContentSegment> parseAiContentSegments(String content) {
  final segments = <AiContentSegment>[];
  int cursor = 0;

  for (final match in _blockRegex.allMatches(content)) {
    if (match.start > cursor) {
      final before = content.substring(cursor, match.start).trim();
      if (before.isNotEmpty) segments.add(AiContentSegment.text(before));
    }
    final kind = match.group(1)!;
    try {
      final parsed = jsonDecode(match.group(2)!.trim()) as Map<String, dynamic>;
      switch (kind) {
        case 'chart':
          segments.add(AiContentSegment.chart(parsed));
          break;
        case 'action':
          segments.add(AiContentSegment.action(parsed));
          break;
        case 'damage':
          segments.add(AiContentSegment.damage(parsed));
          break;
      }
    } catch (_) {
      // JSON mal formé émis par le modèle : on ignore silencieusement le bloc
      // plutôt que de planter l'affichage du message.
    }
    cursor = match.end;
  }

  if (cursor < content.length) {
    final after = content.substring(cursor).trim();
    if (after.isNotEmpty) segments.add(AiContentSegment.text(after));
  }

  if (segments.isEmpty) segments.add(AiContentSegment.text(content));
  return segments;
}

const List<Color> _seriesPalette = [
  AppColors.primary,
  AppColors.brandCyan,
  AppColors.secondary,
  AppColors.accent,
  AppColors.error,
  AppColors.primaryDark,
];

class _ChartEntry {
  final String label;
  final double value;
  const _ChartEntry(this.label, this.value);
}

/// Carte graphique animée : barres, ligne ou donut selon `type`.
/// Accepte "series" (nouveau format) ou "data" (ancien format) pour rester
/// compatible avec d'éventuelles réponses déjà en cache.
class AiChartCard extends StatefulWidget {
  final Map<String, dynamic> chartData;
  const AiChartCard({super.key, required this.chartData});

  @override
  State<AiChartCard> createState() => _AiChartCardState();
}

class _AiChartCardState extends State<AiChartCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final Animation<double> _progress =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.chartData;
    final title = data['title'] as String? ?? '';
    final unit = data['unit'] as String? ?? '';
    final type = (data['type'] as String? ?? 'bar').toLowerCase();
    final rawSeries = (data['series'] as List?) ?? (data['data'] as List?) ?? [];
    final entries = rawSeries
        .whereType<Map>()
        .map((e) => _ChartEntry((e['label'] ?? '').toString(), ((e['value'] as num?) ?? 0).toDouble()))
        .toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withValues(alpha: 0.04))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.brandCyan]),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                ),
              ],
            ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _progress,
            builder: (_, __) => switch (type) {
              'line' => _LineChart(entries: entries, unit: unit, progress: _progress.value),
              'donut' || 'pie' => _DonutChart(entries: entries, unit: unit, progress: _progress.value),
              _ => _BarChart(entries: entries, unit: unit, progress: _progress.value),
            },
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<_ChartEntry> entries;
  final String unit;
  final double progress;
  const _BarChart({required this.entries, required this.unit, required this.progress});

  @override
  Widget build(BuildContext context) {
    final maxVal = entries.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (int i = 0; i < entries.length; i++)
          _barRow(entries[i], maxVal, _seriesPalette[i % _seriesPalette.length]),
      ],
    );
  }

  Widget _barRow(_ChartEntry e, double maxVal, Color color) {
    final ratio = maxVal <= 0 ? 0.0 : (e.value / maxVal).clamp(0.0, 1.0) * progress;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(e.label, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.65)]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text('${e.value.toStringAsFixed(0)} $unit',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<_ChartEntry> entries;
  final String unit;
  final double progress;
  const _LineChart({required this.entries, required this.unit, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 110,
          width: double.infinity,
          child: CustomPaint(painter: _LineChartPainter(entries: entries, progress: progress)),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final e in entries)
              Text(e.label, style: TextStyle(fontSize: 9.5, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_ChartEntry> entries;
  final double progress;
  _LineChartPainter({required this.entries, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) return;
    final maxVal = entries.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);
    final minVal = entries.map((e) => e.value).fold<double>(maxVal, (a, b) => a < b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);

    final stepX = size.width / (entries.length - 1);
    final points = <Offset>[];
    for (int i = 0; i < entries.length; i++) {
      final normY = (entries[i].value - minVal) / range;
      final y = size.height - (normY * size.height * 0.85) - 6;
      points.add(Offset(stepX * i, y));
    }

    final visibleCount = (points.length * progress).clamp(1, points.length).toDouble();

    final linePaint = Paint()
      ..shader = const LinearGradient(colors: [AppColors.primary, AppColors.brandCyan])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.primary.withValues(alpha: 0.18), AppColors.primary.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < visibleCount.floor(); i++) {
      if (i == 0) {
        path.moveTo(points[i].dx, points[i].dy);
        fillPath.moveTo(points[i].dx, size.height);
        fillPath.lineTo(points[i].dx, points[i].dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
        fillPath.lineTo(points[i].dx, points[i].dy);
      }
    }
    if (visibleCount.floor() > 0) {
      fillPath.lineTo(points[visibleCount.floor() - 1].dx, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);
    }

    final dotPaint = Paint()..color = AppColors.brandCyan;
    for (int i = 0; i < visibleCount.floor(); i++) {
      canvas.drawCircle(points[i], 3, dotPaint);
      canvas.drawCircle(points[i], 3, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.entries != entries;
}

class _DonutChart extends StatelessWidget {
  final List<_ChartEntry> entries;
  final String unit;
  final double progress;
  const _DonutChart({required this.entries, required this.unit, required this.progress});

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<double>(0, (a, e) => a + e.value);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: CustomPaint(painter: _DonutPainter(entries: entries, progress: progress)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: _seriesPalette[i % _seriesPalette.length], shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(entries[i].label,
                            style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        total <= 0 ? '' : '${(entries[i].value / total * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_ChartEntry> entries;
  final double progress;
  _DonutPainter({required this.entries, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final total = entries.fold<double>(0, (a, e) => a + e.value);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;
    var startAngle = -math.pi / 2;

    for (int i = 0; i < entries.length; i++) {
      final sweep = (entries[i].value / total) * 2 * math.pi * progress;
      final paint = Paint()
        ..color = _seriesPalette[i % _seriesPalette.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += (entries[i].value / total) * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════
// Carte d'action — "IA qui agit"
// ═══════════════════════════════════════════════════════════════════════

class AiActionCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> actionData;
  const AiActionCard({super.key, required this.actionData});

  @override
  ConsumerState<AiActionCard> createState() => _AiActionCardState();
}

enum _ActionCardState { pending, loading, done, error }

class _AiActionCardState extends ConsumerState<AiActionCard> {
  _ActionCardState _state = _ActionCardState.pending;
  String? _resultMessage;

  Future<void> _confirmer() async {
    final action = widget.actionData['action'] as String?;
    final payload = (widget.actionData['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    if (action == null) return;

    setState(() => _state = _ActionCardState.loading);
    final repo = ref.read(aiRepositoryProvider);
    final AiActionResult result = await repo.actionExecutor.execute(action, payload);
    if (!mounted) return;
    setState(() {
      _state = result.success ? _ActionCardState.done : _ActionCardState.error;
      _resultMessage = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.actionData['label'] as String? ?? 'Confirmer l\'action';

    final Color accent = switch (_state) {
      _ActionCardState.done => AppColors.success,
      _ActionCardState.error => AppColors.error,
      _ => AppColors.brandCyan,
    };

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.10), accent.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            switch (_state) {
              _ActionCardState.done => Icons.check_circle_rounded,
              _ActionCardState.error => Icons.error_rounded,
              _ => Icons.bolt_rounded,
            },
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _state == _ActionCardState.pending || _state == _ActionCardState.loading
                  ? label
                  : (_resultMessage ?? label),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          if (_state == _ActionCardState.pending)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _confirmer,
              child: Text(context.l10n.btnConfirmer, style: const TextStyle(fontSize: 12)),
            )
          else if (_state == _ActionCardState.loading)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Carte de constat de dommage — "IA vision"
// ═══════════════════════════════════════════════════════════════════════

class AiDamageCard extends StatelessWidget {
  final Map<String, dynamic> damageData;
  const AiDamageCard({super.key, required this.damageData});

  Color _graviteColor(String? gravite) => switch (gravite) {
        'grave' => AppColors.error,
        'moyen' => AppColors.warning,
        _ => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    final synthese = damageData['synthese'] as String? ?? '';
    final cout = (damageData['cout_estime_da'] as List?)?.whereType<num>().toList() ?? [];
    final points = (damageData['points'] as List?)?.whereType<Map>().toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build_circle_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(context.l10n.constatIA, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            ],
          ),
          if (synthese.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(synthese, style: const TextStyle(fontSize: 12, height: 1.4)),
          ],
          if (cout.length == 2) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Estimation réparation : ${cout[0].toStringAsFixed(0)} – ${cout[1].toStringAsFixed(0)} DA',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentDark),
              ),
            ),
          ],
          if (points.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: _graviteColor(p['gravite'] as String?), shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style.copyWith(fontSize: 11.5),
                          children: [
                            TextSpan(
                              text: '${p['zone'] ?? ''} · ',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: (p['description'] ?? '').toString()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            'Estimation indicative — à confirmer par un professionnel.',
            style: TextStyle(fontSize: 9.5, color: Colors.grey[500], fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
