// lib/shared/widgets/location_financial_recap.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class LocationFinancialRecap extends StatelessWidget {
  final int nbJours;
  final double prixJour;
  final double total;
  final double gerantMnt;
  final double proprioMnt;
  final List dynamicProprietes;
  final bool modeHistorique;
  final double totalPaiements;
  final double resteAPayer;
  final double retenueCaution;
  final String settingsLabel;

  const LocationFinancialRecap({
    super.key,
    required this.nbJours,
    required this.prixJour,
    required this.total,
    required this.gerantMnt,
    required this.proprioMnt,
    required this.dynamicProprietes,
    required this.settingsLabel,
    this.modeHistorique = false,
    this.totalPaiements = 0,
    this.resteAPayer = 0,
    this.retenueCaution = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Somme des parts déclarées des propriétaires (peut être < 100 si multi-proprio)
    final totalPartsPct = dynamicProprietes.fold<double>(
      0.0, (sum, p) => sum + (p.partPct as double));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _buildRow('Durée', '$nbJours jour(s)'),
          _buildRow('Prix / jour', '${prixJour.toInt()} DA'),
          const Divider(height: 14),
          _buildRow('TOTAL brut', '${total.toInt()} DA', bold: true),
          const SizedBox(height: 4),
          // Commission gérant (calculée sur le total)
          _buildRow(
            '  $settingsLabel',
            '${gerantMnt.toInt()} DA',
            color: AppColors.gerant,
          ),
          // Part nette restante pour les propriétaires
          if (dynamicProprietes.isNotEmpty) ...[
            _buildRow(
              '  Net propriétaires',
              '${proprioMnt.toInt()} DA',
              color: AppColors.proprietaireVehicule,
            ),
            const Divider(height: 10),
            // Répartition par propriétaire selon sa part %
            ...dynamicProprietes.map((p) {
              final partPct = p.partPct as double;
              // Part de ce propriétaire dans le montant net propriétaires
              final partMnt = totalPartsPct > 0
                  ? (proprioMnt * partPct / totalPartsPct)
                  : 0.0;
              return _buildRow(
                '  ${p.proprietaireNom} (${partPct.toStringAsFixed(0)}%)',
                '${partMnt.toInt()} DA',
                color: AppColors.proprietaireVehicule,
              );
            }),
          ],
          if (modeHistorique) ...[
            const Divider(height: 14),
            if (retenueCaution > 0)
              _buildRow(
                'Retenue caution',
                '- ${retenueCaution.toInt()} DA',
                color: AppColors.retard,
              ),
            _buildRow(
              'Paiements saisis',
              '${totalPaiements.toInt()} DA',
              color: AppColors.secondary,
            ),
            _buildRow(
              'Reste à payer',
              '${resteAPayer.toInt()} DA',
              bold: resteAPayer > 0,
              color: resteAPayer > 0 ? AppColors.retard : AppColors.secondary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(String key, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: bold ? AppTextStyles.heading3 : AppTextStyles.bodySecondary),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}