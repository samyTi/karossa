// lib/shared/widgets/vehicle_checklist_widget.dart
// Checklist état du véhicule au retour de location

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class VehicleChecklistWidget extends StatefulWidget {
  final ValueChanged<Map<String, bool>> onChanged;
  const VehicleChecklistWidget({super.key, required this.onChanged});

  @override
  State<VehicleChecklistWidget> createState() => _VehicleChecklistWidgetState();
}

class _VehicleChecklistWidgetState extends State<VehicleChecklistWidget> {
  final Map<String, bool> _items = {
    'Carrosserie sans rayures':       true,
    'Vitres intactes':                true,
    'Pneus en bon état':              true,
    'Carburant niveau correct':       true,
    'Intérieur propre':               true,
    'Documents présents':             true,
    'Roue de secours présente':       true,
    'Triangle de sécurité présent':   true,
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('État du véhicule', style: AppTextStyles.heading3),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: _items.entries.map((e) {
            final isLast = e.key == _items.keys.last;
            return Column(
              children: [
                CheckboxListTile(
                  dense: true,
                  title: Text(e.key,
                    style: const TextStyle(fontSize: 13)),
                  value: e.value,
                  activeColor: AppColors.secondary,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) {
                    setState(() {
                      _items[e.key] = v ?? true;
                      widget.onChanged(Map.from(_items));
                    });
                  },
                ),
                if (!isLast) const Divider(height: 1),
              ],
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 8),
      // Résumé
      if (_items.values.any((v) => !v))
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.retard.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.retard.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded,
              color: AppColors.retard, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '\${_items.values.where((v) => !v).length} point(s) à signaler — '
              'pensez à retenir sur la caution',
              style: const TextStyle(
                color: AppColors.retard, fontSize: 12),
            )),
          ]),
        ),
    ],
  );
}
