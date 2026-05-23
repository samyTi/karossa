// lib/features/ventes/presentation/vente_detail_screen.dart
//
// Écran de détail d'une vente :
//  - Informations de la vente (véhicule, client, montants, commission)
//  - Liste des paiements reçus avec total encaissé / solde restant
//  - Ajout d'un nouveau paiement
//  - Bouton régénérer contrat PDF
//  - Bouton marquer comme soldée

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/contrat_generator_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/delete_confirm.dart';
import '../../clients/domain/client_model.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../data/ventes_repository.dart';
import '../domain/vente_model.dart';
import 'ventes_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final venteDetailProvider =
    FutureProvider.autoDispose.family<Vente?, String>((ref, id) {
  return ref
      .watch(ventesRepositoryProvider)
      .getById(id);
});

final ventesRepositoryProvider = Provider<VentesRepository>((ref) {
  return VentesRepository(ref.watch(supabaseClientProvider));
});

// ── Screen ────────────────────────────────────────────────────────────────────

class VenteDetailScreen extends ConsumerWidget {
  final String venteId;
  const VenteDetailScreen({super.key, required this.venteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venteAsync = ref.watch(venteDetailProvider(venteId));

    return venteAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Erreur : $e'))),
      data: (vente) => vente == null
          ? const Scaffold(body: Center(child: Text('Vente introuvable')))
          : _VenteDetailBody(vente: vente),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _VenteDetailBody extends ConsumerWidget {
  final Vente vente;
  const _VenteDetailBody({required this.vente});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSolde = vente.isSolde;

    return Scaffold(
      appBar: CustomAppBar(
        title: vente.vehiculeNom ?? 'Détail vente',
        showHomeButton: true,
        actions: [
          if (!isSolde)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Marquer comme soldée',
              onPressed: () => _marquerSolde(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Régénérer contrat PDF',
            onPressed: () => _regenererPdf(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Statut paiement ────────────────────────────────────────
          _StatutBanner(isSolde: isSolde),
          const SizedBox(height: 16),

          // ── Véhicule + Client ──────────────────────────────────────
          _InfoCard(vente: vente),
          const SizedBox(height: 14),

          // ── Récapitulatif financier ────────────────────────────────
          _FinanceCard(vente: vente),
          const SizedBox(height: 14),

          // ── Paiements reçus ────────────────────────────────────────
          _PaiementSection(vente: vente),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: isSolde
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddPaiement(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter paiement'),
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _marquerSolde(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Marquer comme soldée ?'),
        content: const Text(
            'Le statut de paiement passera à "Soldé". Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary),
              child: const Text('Confirmer')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref
          .read(ventesRepositoryProvider)
          .update(vente.id, {'statut_paiement': 'complet'});
      ref.invalidate(venteDetailProvider(vente.id));
      ref.invalidate(ventesProvider);
      if (context.mounted) {
        NotificationService().success('Vente marquée comme soldée');
      }
    } catch (e) {
      if (context.mounted) NotificationService().error('Erreur : $e');
    }
  }

  Future<void> _regenererPdf(BuildContext context, WidgetRef ref) async {
    try {
      // Charger les infos client et véhicule pour le PDF
      final supabase = ref.read(supabaseClientProvider);
      final clientData = await supabase
          .from('clients')
          .select()
          .eq('id', vente.clientId)
          .single();
      final vehiculeData = await supabase
          .from('vehicules')
          .select()
          .eq('id', vente.vehiculeId)
          .single();

      final client = Client.fromJson(clientData);
      final vehicule = Vehicule.fromJson(vehiculeData);

      final pdfFile = await ContratGeneratorService.genererVente(
        vente: vente,
        client: client,
        vehicule: vehicule,
      );

      if (pdfFile != null && context.mounted) {
        await ContratGeneratorService.partager(context, pdfFile);
      }
    } catch (e) {
      if (context.mounted) NotificationService().error('Erreur PDF : $e');
    }
  }

  void _showAddPaiement(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPaiementSheet(
        vente: vente,
        onSaved: () {
          ref.invalidate(venteDetailProvider(vente.id));
          ref.invalidate(ventesProvider);
        },
      ),
    );
  }
}

// ── Statut Banner ─────────────────────────────────────────────────────────────

class _StatutBanner extends StatelessWidget {
  final bool isSolde;
  const _StatutBanner({required this.isSolde});

  @override
  Widget build(BuildContext context) {
    final color = isSolde ? AppColors.secondary : AppColors.accent;
    final label = isSolde ? '✅ Vente soldée' : '⏳ Paiement partiel';
    final sub = isSolde
        ? 'Tous les paiements ont été reçus'
        : 'Un solde reste à encaisser';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(children: [
        Icon(
            isSolde ? Icons.check_circle : Icons.pending_actions,
            color: color,
            size: 28),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(sub, style: AppTextStyles.label),
        ]),
      ]),
    );
  }
}

// ── Info Card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Vente vente;
  const _InfoCard({required this.vente});

  @override
  Widget build(BuildContext context) {
    final date = vente.createdAt;
    final fmt =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle('Informations', Icons.info_outline, AppColors.primary),
        const SizedBox(height: 12),
        _Row('Véhicule', vente.vehiculeNom ?? '—'),
        _Row('Client', vente.clientNom ?? '—'),
        _Row('Date', fmt),
        _Row('Mode paiement', _modeLabel(vente.modePaiement)),
        if (vente.notes != null && vente.notes!.isNotEmpty)
          _Row('Notes', vente.notes!),
      ]),
    );
  }

  String _modeLabel(String mode) => switch (mode) {
        'especes' => 'Espèces',
        'virement' => 'Virement',
        'cheque' => 'Chèque',
        'mixte' => 'Mixte',
        _ => mode,
      };
}

// ── Finance Card ──────────────────────────────────────────────────────────────

class _FinanceCard extends StatelessWidget {
  final Vente vente;
  const _FinanceCard({required this.vente});

  @override
  Widget build(BuildContext context) {
    final solde = vente.soldeRestant;

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle(
            'Récapitulatif financier', Icons.account_balance_wallet_outlined,
            AppColors.secondary),
        const SizedBox(height: 12),
        if (vente.prixCatalogue != null)
          _Row('Prix catalogue',
              '${vente.prixCatalogue!.toInt()} DA',
              color: AppColors.textSecondary),
        _Row('Prix de vente', '${vente.prixVente.toInt()} DA',
            bold: true),
        const Divider(height: 20),
        _Row(
            'Commission gérant (${vente.commissionGerantPct.toStringAsFixed(1)}%)',
            '${vente.commissionGerantMnt.toInt()} DA',
            color: AppColors.gerant),
        _Row('Part propriétaire',
            '${(vente.prixVente - vente.commissionGerantMnt).toInt()} DA',
            color: AppColors.proprietaireShowroom),
        const Divider(height: 20),
        _Row('Total encaissé', '${vente.totalPaye.toInt()} DA',
            color: AppColors.secondary),
        _Row('Solde restant', '${solde.toInt()} DA',
            bold: true,
            color: solde > 0 ? AppColors.retard : AppColors.secondary),
      ]),
    );
  }
}

// ── Paiement Section ──────────────────────────────────────────────────────────

class _PaiementSection extends ConsumerWidget {
  final Vente vente;
  const _PaiementSection({required this.vente});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle(
            'Paiements reçus (${vente.paiements.length})',
            Icons.payments_outlined,
            AppColors.gerant),
        const SizedBox(height: 12),
        if (vente.paiements.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucun paiement enregistré',
                style: AppTextStyles.bodySecondary),
          )
        else
          ...vente.paiements.map(
              (p) => _PaiementTile(paiement: p, venteId: vente.id, ref: ref)),
      ]),
    );
  }
}

class _PaiementTile extends StatelessWidget {
  final VentePaiement paiement;
  final String venteId;
  final WidgetRef ref;
  const _PaiementTile(
      {required this.paiement,
      required this.venteId,
      required this.ref});

  @override
  Widget build(BuildContext context) {
    final d = paiement.datePaiement;
    final fmt =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final modeLabel = switch (paiement.mode ?? '') {
      'especes' => 'Espèces',
      'virement' => 'Virement',
      'cheque' => 'Chèque',
      'mixte' => 'Mixte',
      _ => '—',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.20)),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle, color: AppColors.secondary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${paiement.montant.toInt()} DA',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary)),
            Text('$modeLabel · $fmt', style: AppTextStyles.label),
            if (paiement.notes != null && paiement.notes!.isNotEmpty)
              Text(paiement.notes!, style: AppTextStyles.label),
          ]),
        ),
        DeleteConfirmButton(
          onConfirmed: () async {
            await ref
                .read(ventesRepositoryProvider)
                .deletePaiement(paiement.id);
            ref.invalidate(venteDetailProvider(venteId));
            ref.invalidate(ventesProvider);
          },
        ),
      ]),
    );
  }
}

// ── Add Paiement Sheet ────────────────────────────────────────────────────────

class _AddPaiementSheet extends ConsumerStatefulWidget {
  final Vente vente;
  final VoidCallback onSaved;
  const _AddPaiementSheet({required this.vente, required this.onSaved});

  @override
  ConsumerState<_AddPaiementSheet> createState() => _AddPaiementSheetState();
}

class _AddPaiementSheetState extends ConsumerState<_AddPaiementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _mode = 'especes';
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec le solde restant
    final solde = widget.vente.soldeRestant;
    if (solde > 0) _montantCtrl.text = solde.toInt().toString();
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Ajouter un paiement', style: AppTextStyles.heading2),
          const SizedBox(height: 4),
          Text(
              'Solde restant : ${widget.vente.soldeRestant.toInt()} DA',
              style: AppTextStyles.bodySecondary),
          const SizedBox(height: 20),

          // Montant
          TextFormField(
            controller: _montantCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Montant', suffixText: 'DA'),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Requis';
              final d = double.tryParse(v);
              if (d == null || d <= 0) return 'Montant invalide';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Mode + Date
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _mode,
                decoration: const InputDecoration(labelText: 'Mode'),
                items: const [
                  DropdownMenuItem(value: 'especes', child: Text('Espèces')),
                  DropdownMenuItem(
                      value: 'virement', child: Text('Virement')),
                  DropdownMenuItem(value: 'cheque', child: Text('Chèque')),
                  DropdownMenuItem(value: 'mixte', child: Text('Mixte')),
                ],
                onChanged: (v) => setState(() => _mode = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.inputFill,
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${_date.day.toString().padLeft(2, '0')}/'
                      '${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                      style: AppTextStyles.body,
                    ),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Notes
          TextFormField(
            controller: _notesCtrl,
            decoration:
                const InputDecoration(labelText: 'Notes (optionnel)'),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label:
                  Text(_loading ? 'Enregistrement...' : 'Enregistrer'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final montant = double.parse(_montantCtrl.text);
      final paiement = VentePaiement(
        id: '',
        venteId: widget.vente.id,
        montant: montant,
        datePaiement: _date,
        mode: _mode,
        notes:
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      await ref.read(ventesRepositoryProvider).addPaiement(paiement);

      // Mettre à jour statut_paiement si solde soldé
      final nouveauTotal = widget.vente.totalPaye + montant;
      if (nouveauTotal >= widget.vente.prixVente) {
        await ref.read(ventesRepositoryProvider).update(
            widget.vente.id, {'statut_paiement': 'complet'});
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        NotificationService().success('Paiement enregistré');
      }
    } catch (e) {
      if (mounted) NotificationService().error('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionTitle(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: AppTextStyles.heading3.copyWith(color: color)),
        const SizedBox(width: 8),
        Expanded(
            child: Divider(
                color: color.withValues(alpha: 0.25))),
      ]);
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _Row(this.label, this.value,
      {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: bold
                    ? AppTextStyles.heading3
                    : AppTextStyles.bodySecondary),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: bold ? 15 : 13,
                      fontWeight: FontWeight.w700,
                      color: color ?? AppColors.textPrimary)),
            ),
          ],
        ),
      );
}

/// Bouton de suppression avec confirmation inline
class DeleteConfirmButton extends StatefulWidget {
  final Future<void> Function() onConfirmed;
  const DeleteConfirmButton({super.key, required this.onConfirmed});

  @override
  State<DeleteConfirmButton> createState() => _DeleteConfirmButtonState();
}

class _DeleteConfirmButtonState extends State<DeleteConfirmButton> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    if (!_confirming) {
      return IconButton(
        icon: const Icon(Icons.delete_outline,
            color: AppColors.retard, size: 18),
        onPressed: () => setState(() => _confirming = true),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      TextButton(
          onPressed: () => setState(() => _confirming = false),
          child: const Text('Annuler', style: TextStyle(fontSize: 12))),
      TextButton(
          onPressed: () async {
            setState(() => _confirming = false);
            await widget.onConfirmed();
          },
          child: const Text('Supprimer',
              style: TextStyle(
                  color: AppColors.retard, fontSize: 12))),
    ]);
  }
}