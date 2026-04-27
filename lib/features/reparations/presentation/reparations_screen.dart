import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/reparation_model.dart';
import 'reparations_provider.dart';

class ReparationsScreen extends ConsumerWidget {
  const ReparationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reps = ref.watch(reparationsProvider);
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Journal des réparations',
        showBackButton: false,
        showHomeButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/reparations/new'),
        icon: const Icon(Icons.build_outlined),
        label: const Text('Nouvelle réparation'),
        backgroundColor: AppColors.reparation,
        foregroundColor: Colors.white,
      ),
      body: reps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erreur: $e')),
        data:    (list) {
          final total = list.fold(0.0, (s, r) => s + r.cout);
          return Column(children: [
            _TotalBanner(total: total),
            Expanded(child: list.isEmpty
              ? const EmptyState(icon: Icons.build_outlined,
                  message: 'Aucune réparation enregistrée')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _RepCard(rep: list[i]),
                )),
          ]);
        },
      ),
    );
  }
}

class _TotalBanner extends StatelessWidget {
  final double total;
  const _TotalBanner({required this.total});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.reparation.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.reparation.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Total dépenses réparations', style: AppTextStyles.bodySecondary),
      Text('${total.toInt()} DA',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
          color: AppColors.reparation)),
    ]),
  );
}

class _RepCard extends StatelessWidget {
  final Reparation rep;
  const _RepCard({required this.rep});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.reparation.withValues(alpha: 0.1),
        child: const Icon(Icons.build, color: AppColors.reparation, size: 18),
      ),
      title: Row(children: [
        Expanded(child: Text(rep.vehiculeNom ?? '—', style: AppTextStyles.heading3)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.reparation.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6)),
          child: Text(rep.typeLabel,
            style: const TextStyle(fontSize: 10, color: AppColors.reparation,
              fontWeight: FontWeight.w600)),
        ),
      ]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rep.description, style: AppTextStyles.bodySecondary),
        if (rep.prestataire != null)
          Text(rep.prestataire!, style: AppTextStyles.label),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${rep.cout.toInt()} DA',
          style: const TextStyle(fontWeight: FontWeight.w700,
            color: AppColors.reparation, fontSize: 14)),
        Text('${rep.dateRep.day.toString().padLeft(2,"0")}/'
             '${rep.dateRep.month.toString().padLeft(2,"0")}/'
             '${rep.dateRep.year}',
          style: AppTextStyles.label),
      ]),
    ),
  );
}
