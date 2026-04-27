import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/alerte_model.dart';
import 'entretien_provider.dart';

class EntretienScreen extends ConsumerWidget {
  const EntretienScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertes = ref.watch(alertesEntretienProvider);
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Entretien periodique',
        showBackButton: false,
        showHomeButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/entretien/new'),
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Nouvelle alerte'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      body: alertes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erreur: $e')),
        data:    (list) => list.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              message: "Aucune alerte d'entretien active")
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: list.length,
              itemBuilder: (_, i) => _AlerteCard(alerte: list[i], ref: ref),
            ),
      ),
    );
  }
}

class _AlerteCard extends StatelessWidget {
  final AlerteEntretien alerte;
  final WidgetRef ref;
  const _AlerteCard({required this.alerte, required this.ref});

  Color get _color {
    if (alerte.isExpired) return AppColors.retard;
    if (alerte.isUrgent)  return AppColors.accent;
    return AppColors.secondary;
  }

  IconData get _icon {
    if (alerte.typeAlerte == 'vidange')            return Icons.opacity;
    if (alerte.typeAlerte == 'controle_technique') return Icons.fact_check_outlined;
    if (alerte.typeAlerte == 'assurance')          return Icons.security_outlined;
    if (alerte.typeAlerte == 'vignette')           return Icons.confirmation_number_outlined;
    if (alerte.typeAlerte == 'pneus')              return Icons.tire_repair;
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: _color.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(_icon, color: _color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alerte.vehiculeNom ?? '---', style: AppTextStyles.heading3),
            Text(alerte.typeLabel,
              style: TextStyle(fontSize: 13, color: _color,
                fontWeight: FontWeight.w600)),
            if (alerte.dateEcheance != null)
              Text(
                'Echeance : '
                '${alerte.dateEcheance!.day.toString().padLeft(2, "0")}/'
                '${alerte.dateEcheance!.month.toString().padLeft(2, "0")}/'
                '${alerte.dateEcheance!.year}',
                style: AppTextStyles.label),
            if (alerte.kmEcheance != null)
              Text('A ${alerte.kmEcheance} km', style: AppTextStyles.label),
            if (alerte.isExpired)
              Text('EXPIRE',
                style: TextStyle(color: AppColors.retard,
                  fontSize: 11, fontWeight: FontWeight.w700)),
            if (alerte.isUrgent && !alerte.isExpired)
              Text('URGENT - moins de 7 jours',
                style: TextStyle(color: AppColors.accent,
                  fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        )),
        TextButton(
          onPressed: () async {
            await ref.read(entretienRepositoryProvider).marquerFait(alerte.id);
            ref.invalidate(alertesEntretienProvider);
          },
          child: const Text('Fait'),
        ),
      ]),
    ),
  );
}
