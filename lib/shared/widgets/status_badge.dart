import 'package:flutter/material.dart';
import '../../features/vehicules/domain/vehicule_model.dart';

class StatusBadge extends StatelessWidget {
  final VehiculeStatut statut;
  const StatusBadge({super.key, required this.statut});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: statut.color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: statut.color.withValues(alpha: 0.3)),
    ),
    child: Text(statut.label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
        color: statut.color)),
  );
}
