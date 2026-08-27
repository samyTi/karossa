import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/domain/profile_model.dart';
import '../../locations/domain/location_model.dart';
import '../../../core/extensions/l10n_extension.dart';

class DashboardAppBar extends StatelessWidget {
  final String prenom;
  final UserRole? role;
  final List<Location> retards;
  final VoidCallback onRefresh;

  const DashboardAppBar({
    super.key, 
    required this.prenom, 
    this.role, 
    required this.retards,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: _gradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(context),
                  const Spacer(),
                  if (retards.isNotEmpty) _buildAlertChip(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient get _gradient => LinearGradient(
    begin: Alignment.topLeft, 
    end: Alignment.bottomRight,
    colors: [
      AppColors.primary, 
      AppColors.primary.withValues(alpha: 0.8), 
      AppColors.secondary.withValues(alpha: 0.6)
    ],
  );

  Widget _buildHeaderRow(BuildContext context) => Row(
    children: [
      Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
        ),
        child: const Icon(Icons.dashboard, color: Colors.white, size: 28),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.bonjourPrenom(prenom), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            if (role != null)
              Text(role!.label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
          ],
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: onRefresh,
        ),
      ),
    ],
  );

  Widget _buildAlertChip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2), 
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
        const SizedBox(width: 6),
        Text(
          '${retards.length} retard(s) à gérer', 
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)
        ),
      ],
    ),
  );
}