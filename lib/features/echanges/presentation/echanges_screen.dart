import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/echange_model.dart';
import 'echanges_provider.dart';

class EchangesScreen extends ConsumerWidget {
  const EchangesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final echanges = ref.watch(echangesProvider);
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Échanges / Reprises',
        showBackButton: false,
        showHomeButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/echanges/new'),
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Nouvel échange'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      body: echanges.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erreur: $e')),
        data:    (list) => list.isEmpty
          ? const EmptyState(icon: Icons.swap_horiz, message: 'Aucun échange enregistré')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: list.length,
              itemBuilder: (_, i) => _EchangeCard(echange: list[i]),
            ),
      ),
    );
  }
}

class _EchangeCard extends StatelessWidget {
  final Echange echange;
  const _EchangeCard({required this.echange});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(echange.clientNom ?? '—', style: AppTextStyles.heading3),
          Text('${echange.dateEchange.day.toString().padLeft(2,"0")}/'
               '${echange.dateEchange.month.toString().padLeft(2,"0")}/'
               '${echange.dateEchange.year}',
            style: AppTextStyles.label),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _Tag(echange.vehiculeCedeNom ?? '—', AppColors.primary),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.swap_horiz, size: 16, color: AppColors.textSecondary)),
          _Tag(echange.vehiculeReprisNom, AppColors.accent),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _Stat('Reprise', '${echange.valeurReprise.toInt()} DA', AppColors.textSecondary),
          const SizedBox(width: 16),
          _Stat('Complément', '${echange.complementClient.toInt()} DA', AppColors.secondary),
          if (echange.commissionGerantMnt != null) ...[
            const SizedBox(width: 16),
            _Stat('Commission Gérant',
              '${echange.commissionGerantMnt!.toInt()} DA', AppColors.gerant),
          ],
        ]),
      ]),
    ),
  );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
      color: color)),
  );
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.label),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ],
  );
}
