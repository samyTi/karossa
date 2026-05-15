import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../data/caisse_operation.dart';
import '../domain/caisse_providers.dart';

class CaisseStatsBar extends ConsumerStatefulWidget {
  const CaisseStatsBar({super.key});

  @override
  ConsumerState<CaisseStatsBar> createState() => _CaisseStatsBarState();
}

class _CaisseStatsBarState extends ConsumerState<CaisseStatsBar> {
  bool _showDetail = false;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(caisseStatsProvider);

    return Column(
      children: [
        // ── Résumé principal ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(child: _SoldeCard(
              label: 'Entrées',
              value: _fmt(stats.totalEntrees),
              color: AppColors.secondary,
              icon: Icons.arrow_downward_rounded,
            )),
            const SizedBox(width: 8),
            Expanded(child: _SoldeCard(
              label: 'Sorties',
              value: _fmt(stats.totalSorties),
              color: AppColors.retard,
              icon: Icons.arrow_upward_rounded,
            )),
            const SizedBox(width: 8),
            Expanded(child: _SoldeCard(
              label: 'Solde',
              value: _fmt(stats.solde),
              color: stats.solde >= 0 ? AppColors.primary : AppColors.retard,
              icon: Icons.account_balance_wallet_outlined,
            )),
          ]),
        ),

        // ── Toggle détail catégories ─────────────────────────────────────────
        if (stats.parCategorie.isNotEmpty) ...[
          InkWell(
            onTap: () => setState(() => _showDetail = !_showDetail),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Text('Détail par catégorie',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(
                  _showDetail
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16, color: AppColors.primary),
              ]),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _showDetail
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _CategoryBreakdown(stats: stats),
          ),
        ],
        const SizedBox(height: 4),
        const Divider(height: 1),
      ],
    );
  }

  String _fmt(double v) =>
      '${v < 0 ? '-' : ''}${v.abs().toStringAsFixed(0)} DA';
}

class _CategoryBreakdown extends StatelessWidget {
  final CaisseStats stats;
  const _CategoryBreakdown({required this.stats});

  @override
  Widget build(BuildContext context) {
    final sorted = stats.parCategorie.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = sorted.isEmpty ? 1.0 : sorted.first.value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: sorted.map((e) {
          // ✅ Fix : categorieLabels (public) au lieu de _categorieLabels (privé)
          final label =
              CaisseOperation.categorieLabels[e.key] ?? e.key;
          final ratio = e.value / max;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(
                width: 110,
                child: Text(label,
                  style: AppTextStyles.label,
                  overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(
                      AppColors.primary.withValues(alpha: 0.6)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${e.value.toStringAsFixed(0)} DA',
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w700)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _SoldeCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _SoldeCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      ),
      Text(label,
        style: AppTextStyles.label, textAlign: TextAlign.center),
    ]),
  );
}