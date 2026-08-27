// lib/features/gps/presentation/gps_driving_score_card.dart
//
// Carte "Score de conduite" — à placer par exemple dans
// gps_dashboard_screen.dart ou vehicule_detail_screen.dart.
//
// Usage :
//   GpsDrivingScoreCard(
//     vehiculeId: vehicule.id,
//     from: DateTime.now().subtract(const Duration(days: 7)),
//     to:   DateTime.now(),
//   )

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/driving_score.dart';
import 'gps_driving_score_provider.dart';
import '../../../core/extensions/l10n_extension.dart';

class GpsDrivingScoreCard extends ConsumerWidget {
  final String vehiculeId;
  final DateTime from;
  final DateTime to;

  const GpsDrivingScoreCard({
    super.key,
    required this.vehiculeId,
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(drivingScoreProvider((vehiculeId: vehiculeId, from: from, to: to)));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 80,
            child: Center(child: Text(context.l10n.scoreIndisponiblePourPeriode)),
          ),
          data: (result) => _ScoreBody(result: result),
        ),
      ),
    );
  }
}

class _ScoreBody extends StatelessWidget {
  final DrivingScoreResult result;
  const _ScoreBody({required this.result});

  Color get _scoreColor {
    if (result.score >= 90) return const Color(0xFF22C55E);
    if (result.score >= 75) return const Color(0xFF84CC16);
    if (result.score >= 55) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _AnimatedScoreGauge(score: result.score, color: _scoreColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.scoreDeConduite,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    result.label,
                    style: TextStyle(color: _scoreColor, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${result.distanceKm.toStringAsFixed(0)} km parcourus',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.warning_amber_rounded,
                label: 'Freinages brusques',
                value: '${result.nbFreinagesBrusques}',
              ),
            ),
            Expanded(
              child: _StatTile(
                icon: Icons.speed_rounded,
                label: 'Excès de vitesse',
                value: '${result.nbExcesVitesse}',
              ),
            ),
            Expanded(
              child: _StatTile(
                icon: Icons.bolt_rounded,
                label: 'Accél. brusques',
                value: '${result.nbAccelerationsBrusques}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

/// Jauge circulaire animée (0 → score) façon "wow" — se remplit en douceur
/// à l'ouverture de l'écran, sans dépendance externe.
class _AnimatedScoreGauge extends StatelessWidget {
  final int score;
  final Color color;
  const _AnimatedScoreGauge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score / 100),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(72, 72),
                painter: _GaugePainter(progress: value, color: color),
              ),
              Text(
                '${(value * 100).round()}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
