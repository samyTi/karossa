import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/services/notification_service.dart';
import '../../features/ventes/domain/vente_model.dart';
import '../../features/ventes/presentation/ventes_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';
// ── UI Components ─────────────────────────────────────────────────────────────
class StatutBanner extends StatelessWidget {
  final bool isSolde;
  const StatutBanner({super.key, required this.isSolde});

  @override
  Widget build(BuildContext context) {
    final color = isSolde ? AppColors.secondary : AppColors.accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [Icon(isSolde ? Icons.check_circle : Icons.pending, color: color), const SizedBox(width: 12), Text(isSolde ? 'Vente soldée' : 'Paiement partiel', style: TextStyle(fontWeight: FontWeight.bold, color: color))]),
    );
  }
}

class InfoCard extends StatelessWidget {
  final Vente vente;
  const InfoCard({super.key, required this.vente});
  @override
  Widget build(BuildContext context) => _Card(child: Column(children: [
    const _SectionTitle('Informations', Icons.info_outline, AppColors.primary),
    _Row('Véhicule', vente.vehiculeNom ?? 'Inconnu'),
    _Row('Client', vente.clientNom ?? 'Inconnu'),
    _Row('Date', '${vente.createdAt.day}/${vente.createdAt.month}/${vente.createdAt.year}'),
  ]));
}

class FinanceCard extends StatelessWidget {
  final Vente vente;
  const FinanceCard({super.key, required this.vente});
  @override
  Widget build(BuildContext context) => _Card(child: Column(children: [
    const _SectionTitle('Finances', Icons.account_balance_wallet_outlined, AppColors.secondary),
    _Row('Prix vente', '${vente.prixVente.toInt()} DA', bold: true),
    _Row('Total payé', '${vente.totalPaye.toInt()} DA', color: AppColors.secondary),
    _Row('Solde', '${vente.soldeRestant.toInt()} DA', color: vente.soldeRestant > 0 ? AppColors.retard : AppColors.secondary),
  ]));
}

class PaiementSection extends StatelessWidget {
  final Vente vente;
  const PaiementSection({super.key, required this.vente});
  @override
  Widget build(BuildContext context) => _Card(child: Column(children: [
    _SectionTitle('Paiements (${vente.paiements.length})', Icons.payments, AppColors.gerant),
    ...vente.paiements.map((p) => _PaiementTile(paiement: p, venteId: vente.id)),
  ]));
}

class _PaiementTile extends ConsumerWidget {
  final VentePaiement paiement;
  final String venteId;
  const _PaiementTile({required this.paiement, required this.venteId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    title: Text('${paiement.montant.toInt()} DA'),
    subtitle: Text('${paiement.datePaiement.day}/${paiement.datePaiement.month}'),
    trailing: DeleteConfirmButton(onConfirmed: () async {
      await ref.read(ventesRepositoryProvider).deletePaiement(paiement.id);
      ref.invalidate(venteDetailProvider(venteId));
    }),
  );
}

// ── Logic Actions ─────────────────────────────────────────────────────────────
Future<void> marquerVenteCommeSoldee(BuildContext context, WidgetRef ref, Vente vente) async {
  await ref.read(ventesRepositoryProvider).update(vente.id, {'statut_paiement': 'complet'});
  ref.invalidate(venteDetailProvider(vente.id));
}

Future<void> genererContratPdf(BuildContext context, WidgetRef ref, Vente vente) async {
  // Logique PDF ici
}

void showAddPaiementModal(BuildContext context, WidgetRef ref, Vente vente) {
  // Logique BottomSheet ici
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: child);
}

class _SectionTitle extends StatelessWidget {
  final String label; final IconData icon; final Color color;
  const _SectionTitle(this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 8), Text(label, style: AppTextStyles.heading3.copyWith(color: color))]);
}

class _Row extends StatelessWidget {
  final String label, value; final bool bold; final Color? color;
  const _Row(this.label, this.value, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: AppTextStyles.bodySecondary), Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color))]));
}

class DeleteConfirmButton extends StatefulWidget {
  final Future<void> Function() onConfirmed;
  const DeleteConfirmButton({super.key, required this.onConfirmed});
  @override
  State<DeleteConfirmButton> createState() => _DeleteConfirmButtonState();
}

class _DeleteConfirmButtonState extends State<DeleteConfirmButton> {
  bool _confirming = false;
  @override
  Widget build(BuildContext context) => _confirming 
      ? Row(mainAxisSize: MainAxisSize.min, children: [TextButton(onPressed: () => setState(() => _confirming = false), child: Text(context.l10n.btnAnnuler)), TextButton(onPressed: () => widget.onConfirmed(), child: const Text('OK', style: TextStyle(color: Colors.red)))])
      : IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _confirming = true));
}