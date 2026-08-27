// lib/features/finance/presentation/gerant_commission_screen.dart
//
// Vue financière consolidée d'un gérant : commissions perçues sur les
// locations/ventes/échanges (table commission_gerant), versements déjà
// effectués, solde restant à verser.
//
// Volontairement séparé de ProprietaireFinanceScreen même si le repository
// est partagé : un gérant copropriétaire d'un véhicule a deux flux d'argent
// de nature différente (commission de gestion vs part de copropriété) qu'on
// ne veut pas mélanger dans le même écran "solde".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/delete_confirm.dart';
import '../../../shared/widgets/modern_text_field.dart';
import '../../../shared/widgets/modern_button.dart';
import '../domain/proprietaire_solde_model.dart';
import '../domain/versement_model.dart';
import '../domain/transfert_model.dart';
import 'proprietaire_finance_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class GerantCommissionScreen extends ConsumerWidget {
  final String gerantId;
  final String gerantNom;

  const GerantCommissionScreen({
    super.key,
    required this.gerantId,
    required this.gerantNom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soldeAsync = ref.watch(gerantCommissionProvider(gerantId));

    return Scaffold(
      appBar: CustomAppBar(
        title: gerantNom,
        showHomeButton: true,
      ),
      body: soldeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.erreurAvecDetail(e.toString()))),
        data: (solde) => _Body(solde: solde),
      ),
      floatingActionButton: soldeAsync.hasValue
          ? FloatingActionButton.extended(
              heroTag: 'fab-gerant-commission-$gerantId',
              onPressed: () => _ouvrirFormulaireVersement(context, ref),
              icon: const Icon(Icons.payments_outlined),
              label: Text(context.l10n.nouveauVersement),
              backgroundColor: AppColors.secondary,
            )
          : null,
    );
  }

  void _ouvrirFormulaireVersement(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VersementForm(gerantId: gerantId, gerantNom: gerantNom),
    );
  }
}

// ── Corps de la page ─────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  final ProprietaireSolde solde;
  const _Body({required this.solde});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _SoldeCard(solde: solde),
        const SizedBox(height: 20),

        _SectionTitle('Commissions perçues (${solde.gains.length})'),
        const SizedBox(height: 8),
        if (solde.gains.isEmpty)
          const _EmptyHint('Aucune commission enregistrée pour le moment')
        else
          ...solde.gains.map((g) => _GainTile(g)),
        const SizedBox(height: 20),

        if (solde.aDesTransferts) ...[
          _SectionTitle('Transferts entre utilisateurs'),
          const SizedBox(height: 8),
          if (solde.totalOnLuiDoit > 0)
            _TransfertResumeTile(
              label: 'On lui doit',
              montant: solde.totalOnLuiDoit,
              color: AppColors.secondary,
            ),
          if (solde.totalIlDoit > 0)
            _TransfertResumeTile(
              label: 'Il doit',
              montant: solde.totalIlDoit,
              color: AppColors.error,
            ),
          const SizedBox(height: 8),
          ..._transfertsTries(solde).map((e) => _TransfertTile(
                transfert: e.$1,
                envoye: e.$2,
                gerantId: solde.proprietaireId,
              )),
          const SizedBox(height: 20),
        ],

        _SectionTitle('Versements effectués (${solde.versements.length})'),
        const SizedBox(height: 8),
        if (solde.versements.isEmpty)
          const _EmptyHint('Aucun versement enregistré pour le moment')
        else
          ...solde.versements.map(
            (v) => _VersementTile(versement: v, gerantId: solde.proprietaireId),
          ),
      ],
    );
  }
}

/// Fusionne les transferts envoyés et reçus en une seule liste triée par
/// date, chaque élément gardant trace de son sens (`true` = envoyé par ce
/// profil, `false` = reçu par ce profil).
List<(TransfertUtilisateur, bool)> _transfertsTries(ProprietaireSolde solde) {
  final combines = [
    for (final t in solde.transfertsEnvoyes) (t, true),
    for (final t in solde.transfertsRecus) (t, false),
  ];
  combines.sort((a, b) => b.$1.dateTransfert.compareTo(a.$1.dateTransfert));
  return combines;
}

class _TransfertResumeTile extends StatelessWidget {
  final String label;
  final double montant;
  final Color color;
  const _TransfertResumeTile({
    required this.label,
    required this.montant,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: AppTextStyles.body)),
            Text(montant.toDA(),
                style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
}

class _TransfertTile extends ConsumerWidget {
  final TransfertUtilisateur transfert;
  final bool envoye; // true = ce profil a payé, false = ce profil a reçu
  final String gerantId;
  const _TransfertTile({
    required this.transfert,
    required this.envoye,
    required this.gerantId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autrePersonne = envoye ? transfert.beneficiaireNom : transfert.payeurNom;
    final sousTitre = StringBuffer()
      ..write(envoye ? 'Donné à ' : 'Reçu de ')
      ..write(autrePersonne?.isNotEmpty == true ? autrePersonne : 'Utilisateur')
      ..write(' · ${transfert.motif} · ${transfert.dateTransfert.toDisplayDate()}');
    if (transfert.remboursable) {
      sousTitre.write(transfert.rembourse ? ' · Remboursé' : ' · À rembourser');
    } else {
      sousTitre.write(' · Don définitif');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(
          envoye ? Icons.call_made : Icons.call_received,
          color: envoye ? AppColors.error : AppColors.secondary,
        ),
        title: Text(transfert.montant.toDA(),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sousTitre.toString(), style: AppTextStyles.label),
        trailing: transfert.enAttenteRemboursement
            ? PopupMenuButton<String>(
                onSelected: (v) async {
                  try {
                    if (v == 'rembourse') {
                      await ref
                          .read(proprietaireFinanceRepositoryProvider)
                          .marquerTransfertRembourse(transfert.id);
                    } else if (v == 'supprimer') {
                      final ok = await showDeleteConfirm(
                        context,
                        title: context.l10n.supprimerCeTransfert,
                        message:
                            context.l10n.transfertSeraSupprimeDefinitivement(transfert.montant.toDA()),
                      );
                      if (!ok) return;
                      await ref
                          .read(proprietaireFinanceRepositoryProvider)
                          .supprimerTransfert(transfert.id);
                    }
                    ref.invalidate(proprietaireSoldeProvider(gerantId));
                    ref.invalidate(gerantCommissionProvider(gerantId));
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.erreurAvecDetail(e.toString())), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'rembourse', child: Text(context.l10n.marquerRembourse)),
                  PopupMenuItem(value: 'supprimer', child: Text(context.l10n.btnSupprimer)),
                ],
              )
            : IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                onPressed: () async {
                  final ok = await showDeleteConfirm(
                    context,
                    title: context.l10n.supprimerCeTransfert,
                    message:
                        context.l10n.transfertSeraSupprimeDefinitivement(transfert.montant.toDA()),
                  );
                  if (!ok) return;
                  try {
                    await ref
                        .read(proprietaireFinanceRepositoryProvider)
                        .supprimerTransfert(transfert.id);
                    ref.invalidate(proprietaireSoldeProvider(gerantId));
                    ref.invalidate(gerantCommissionProvider(gerantId));
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.erreurAvecDetail(e.toString())), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
              ),
      ),
    );
  }
}

class _SoldeCard extends StatelessWidget {
  final ProprietaireSolde solde;
  const _SoldeCard({required this.solde});

  @override
  Widget build(BuildContext context) {
    final soldeColor = solde.aDejaTropPercu ? AppColors.error : AppColors.secondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: context.l10n.totalCommissions,
                  value: solde.totalGains.toDA(),
                  color: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: context.l10n.dejaVerse,
                  value: solde.totalVerse.toDA(),
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solde.aDejaTropPercu ? 'Trop perçu' : 'Solde restant à verser',
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      solde.solde.abs().toDA(),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: soldeColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (solde.soldeAjusteDiffere) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              solde.soldeAjuste < 0 ? 'Trop perçu (ajusté)' : 'Solde ajusté',
                              style: AppTextStyles.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: context.l10n.soldeRestantTooltip,
                            child: Icon(Icons.info_outline,
                                size: 14, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        solde.soldeAjuste.abs().toDA(),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: solde.soldeAjuste < 0 ? AppColors.error : AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.label),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: AppTextStyles.heading3);
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: AppTextStyles.bodySecondary),
      );
}

class _GainTile extends StatelessWidget {
  final LigneGain gain;
  const _GainTile(this.gain);

  IconData get _icon {
    switch (gain.typeOperation) {
      case 'location':
        return Icons.car_rental;
      case 'vente':
        return Icons.sell_outlined;
      case 'echange':
        return Icons.swap_horiz;
      default:
        return Icons.receipt_long;
    }
  }

  String get _typeLabel {
    switch (gain.typeOperation) {
      case 'location':
        return 'Location';
      case 'vente':
        return 'Vente';
      case 'echange':
        return 'Échange';
      default:
        return gain.typeOperation;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          leading: Icon(_icon, color: AppColors.secondary),
          title: Text(gain.vehiculeLabel, style: AppTextStyles.body),
          subtitle: Text(
            '$_typeLabel · commission ${gain.pourcentage.toStringAsFixed(1)}% · '
            '${gain.date.toDisplayDate()}',
            style: AppTextStyles.label,
          ),
          trailing: Text(
            gain.montant.toDA(),
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.secondary, fontSize: 14),
          ),
        ),
      );
}

class _VersementTile extends ConsumerWidget {
  final Versement versement;
  final String gerantId;
  const _VersementTile({required this.versement, required this.gerantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.check_circle, color: AppColors.info),
          title: Text(versement.montant.toDA(),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            '${versement.dateVersement.toDisplayDate()}'
            '${versement.mode != null ? ' · ${versement.mode!.label}' : ''}'
            '${versement.notes != null && versement.notes!.isNotEmpty ? ' · ${versement.notes}' : ''}',
            style: AppTextStyles.label,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
            onPressed: () async {
              final ok = await showDeleteConfirm(
                context,
                title: context.l10n.supprimerCeVersement,
                message:
                    'Ce versement de ${versement.montant.toDA()} et sa sortie de caisse associée seront supprimés.',
              );
              if (!ok) return;
              try {
                await ref
                    .read(proprietaireFinanceRepositoryProvider)
                    .supprimerVersement(versement.id);
                ref.invalidate(gerantCommissionProvider(gerantId));
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.erreurAvecDetail(e.toString())), backgroundColor: AppColors.error),
                  );
                }
              }
            },
          ),
        ),
      );
}

// ── Formulaire de saisie d'un versement ──────────────────────────────────────

class _VersementForm extends ConsumerStatefulWidget {
  final String gerantId;
  final String gerantNom;
  const _VersementForm({required this.gerantId, required this.gerantNom});

  @override
  ConsumerState<_VersementForm> createState() => _VersementFormState();
}

class _VersementFormState extends ConsumerState<_VersementForm> {
  final _montantCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  ModeVersement _mode = ModeVersement.especes;
  bool _loading = false;
  String? _erreur;

  @override
  void dispose() {
    _montantCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final montant = double.tryParse(_montantCtrl.text.replaceAll(',', '.'));
    if (montant == null || montant <= 0) {
      setState(() => _erreur = 'Montant invalide');
      return;
    }
    setState(() {
      _loading = true;
      _erreur = null;
    });
    try {
      await ref.read(creerVersementProvider)(
        proprietaireId: widget.gerantId,
        montant: montant,
        dateVersement: _date,
        mode: _mode,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        typePart: TypePart.commissionGerant,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _erreur = "Erreur lors de l'enregistrement : $e";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.nouveauVersement, style: AppTextStyles.heading2),
            Text(widget.gerantNom, style: AppTextStyles.bodySecondary),
            const SizedBox(height: 16),

            ModernTextField(
              label: context.l10n.montantDa,
              keyboardType: TextInputType.number,
              controller: _montantCtrl,
              prefixIcon: Icons.payments_outlined,
            ),
            const SizedBox(height: 12),

            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.l10n.dateDuVersement,
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(_date.toDisplayDate()),
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<ModeVersement>(
              initialValue: _mode,
              decoration: InputDecoration(
                labelText: context.l10n.modeDePaiement,
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: ModeVersement.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                  .toList(),
              onChanged: (v) => setState(() => _mode = v ?? ModeVersement.especes),
            ),
            const SizedBox(height: 12),

            ModernTextField(
              label: context.l10n.notesOptionnel,
              controller: _notesCtrl,
              maxLines: 2,
              prefixIcon: Icons.notes_outlined,
            ),

            if (_erreur != null) ...[
              const SizedBox(height: 8),
              Text(_erreur!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],

            const SizedBox(height: 20),
            ModernButton(
              text: 'Enregistrer le versement',
              icon: Icons.check,
              isLoading: _loading,
              isFullWidth: true,
              type: ModernButtonType.success,
              onPressed: _loading ? null : _valider,
            ),
          ],
        ),
      ),
    );
  }
}