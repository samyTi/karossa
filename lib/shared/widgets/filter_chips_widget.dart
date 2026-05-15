// lib/shared/widgets/filter_chips_widget.dart
// Chips de filtres horizontaux (statut, type, période)

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class FilterChipsRow extends StatelessWidget {
  final List<FilterChipData> chips;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const FilterChipsRow({
    super.key,
    required this.chips,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Chip 'Tous'
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: const Text('Tous'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
            backgroundColor: AppColors.inputFill,
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              color: selected == null ? AppColors.primary : AppColors.textSecondary,
              fontWeight: selected == null ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
            side: BorderSide(
              color: selected == null ? AppColors.primary : AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ),
        ...chips.map((c) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            avatar: c.icon != null
              ? Icon(c.icon, size: 14,
                  color: c.value == selected ? c.color ?? AppColors.primary : AppColors.textSecondary)
              : null,
            label: Text(c.label),
            selected: selected == c.value,
            onSelected: (_) => onSelected(c.value == selected ? null : c.value),
            backgroundColor: AppColors.inputFill,
            selectedColor: (c.color ?? AppColors.primary).withValues(alpha: 0.15),
            checkmarkColor: c.color ?? AppColors.primary,
            labelStyle: TextStyle(
              color: c.value == selected
                ? (c.color ?? AppColors.primary) : AppColors.textSecondary,
              fontWeight: c.value == selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
            side: BorderSide(
              color: c.value == selected
                ? (c.color ?? AppColors.primary) : AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        )),
      ],
    ),
  );
}

class FilterChipData {
  final String label;
  final String value;
  final Color? color;
  final IconData? icon;
  const FilterChipData({
    required this.label,
    required this.value,
    this.color,
    this.icon,
  });
}
