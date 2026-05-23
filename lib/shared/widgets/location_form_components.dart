// lib/features/locations/presentation/widgets/location_form_components.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class ModeHistoriqueBanner extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const ModeHistoriqueBanner({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: value ? AppColors.accent.withValues(alpha: 0.10) : AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppColors.accent.withValues(alpha: 0.40) : AppColors.border,
          width: value ? 1.5 : 1,
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.accent,
        title: Row(
          children: [
            Icon(Icons.history_edu, size: 18, color: value ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Saisie d\'une location passée',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: value ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          value ? 'Historique : dates passées, retour et paiements inclus' : 'Activez pour enregistrer une location déjà terminée',
          style: AppTextStyles.label,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true,
      ),
    );
  }
}

class FormSectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const FormSectionHeader({super.key, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.heading3.copyWith(color: color)),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: color.withValues(alpha: 0.3))),
        ],
      );
}

class LocationStatutChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const LocationStatutChip({
    super.key, required this.label, required this.icon,
    required this.selected, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : AppColors.inputFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? color : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? color : AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

class DateSelectionTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const DateSelectionTile({super.key, required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.inputFill),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.label),
                  Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}', style: AppTextStyles.body),
                ],
              ),
            ],
          ),
        ),
      );
  }