import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/reparation_model.dart';
import 'reparations_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';
import '../../../shared/widgets/delete_confirm.dart';

class ReparationsScreen extends ConsumerWidget {
  const ReparationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reps = ref.watch(reparationsProvider);
    return Scaffold(
      appBar: CustomAppBar(
        title: context.l10n.journalDesReparations,
        showBackButton: false,
        showHomeButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/reparations/new'),
        icon: const Icon(Icons.build_outlined),
        label: Text(context.l10n.nouvelleReparation),
        backgroundColor: AppColors.reparation,
        foregroundColor: Colors.white,
      ),
      body: reps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text(context.l10n.erreurAvecDetail(e.toString()))),
        data:    (list) {
          final total = list.fold(0.0, (s, r) => s + r.cout);
          return Column(children: [
            _TotalBanner(total: total),
            Expanded(child: list.isEmpty
              ? EmptyState(icon: Icons.build_outlined,
                  message: context.l10n.aucuneReparationEnregistree)
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
      Text(context.l10n.totalDepensesReparations, style: AppTextStyles.bodySecondary),
      Text('${total.toInt()} DA',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
          color: AppColors.reparation)),
    ]),
  );
}

class _RepCard extends ConsumerWidget {
  final Reparation rep;
  const _RepCard({required this.rep});

  Future<void> _supprimer(BuildContext context, WidgetRef ref) {
    return confirmAndDelete(
      context,
      title: context.l10n.supprimerDefinitivement,
      message: '${rep.vehiculeNom ?? "ce véhicule"} — ${rep.description}\n${context.l10n.actionIrreversible}',
      onDelete: () => ref.read(reparationsRepositoryProvider).delete(rep.id),
      onSuccess: () => ref.invalidate(reparationsProvider),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Stack(children: [
      ListTile(
        onTap: () => context.push('/reparations/${rep.id}/edit', extra: rep),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 40, 8),
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
          Row(children: [
            Icon(rep.paiementMultiple ? Icons.groups_outlined : Icons.account_balance_wallet_outlined,
              size: 12, color: AppColors.reparation),
            const SizedBox(width: 4),
            Flexible(child: Text('${context.l10n.payePar} : ${rep.payeurResume}',
              style: AppTextStyles.label, overflow: TextOverflow.ellipsis)),
          ]),
          if (rep.responsableResume != null)
            Row(children: [
              const Icon(Icons.swap_horiz, size: 12, color: AppColors.retard),
              const SizedBox(width: 4),
              Flexible(child: Text(context.l10n.alaChargeDe(rep.responsableResume ?? ''),
                style: AppTextStyles.label.copyWith(color: AppColors.retard),
                overflow: TextOverflow.ellipsis)),
            ]),
        ]),
        isThreeLine: true,
        trailing: Column(mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${rep.cout.toInt()} DA',
            style: const TextStyle(fontWeight: FontWeight.w700,
              color: AppColors.reparation, fontSize: 14)),
          Text('${rep.dateRep.day.toString().padLeft(2,'0')}/'
               '${rep.dateRep.month.toString().padLeft(2,'0')}/'
               '${rep.dateRep.year}',
            style: AppTextStyles.label),
        ]),
      ),
      // Placé hors du ListTile (dont trailing a une hauteur plafonnée) pour
      // éviter tout risque d'overflow, quel que soit le nombre de lignes du
      // sous-titre.
      Positioned(
        top: 0,
        right: 0,
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          iconSize: 18,
          splashRadius: 18,
          icon: const Icon(Icons.more_vert),
          onSelected: (v) {
            if (v == 'edit') context.push('/reparations/${rep.id}/edit', extra: rep);
            if (v == 'delete') _supprimer(context, ref);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Row(children: [
              const Icon(Icons.edit_outlined, size: 16), const SizedBox(width: 8), Text(context.l10n.btnModifier),
            ])),
            PopupMenuItem(value: 'delete', child: Row(children: [
              const Icon(Icons.delete_outline, size: 16, color: AppColors.retard),
              const SizedBox(width: 8),
              Text(context.l10n.btnSupprimer, style: const TextStyle(color: AppColors.retard)),
            ])),
          ],
        ),
      ),
    ]),
  );
}
