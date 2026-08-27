// lib/features/locations/presentation/location_interruption_widget.dart
//
// Widget complet pour gérer les interruptions temporaires d'une location.
// Usage : intégrer dans location_edit_screen.dart ou locations_screen.dart
//
// Fonctionnalités :
//   • Affichage de la liste des interruptions (terminées + active)
//   • Démarrage d'une interruption (récupération du véhicule)
//   • Fin d'une interruption (restitution au client)
//   • Suppression d'une interruption (correction)
//   • Calcul et affichage de l'impact financier

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/services/notification_service.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../domain/location_model.dart';
import 'locations_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

// ─────────────────────────────────────────────────────────────────────────────
// POINT D'ENTRÉE : bottom-sheet depuis n'importe quel écran
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showInterruptionManager(
  BuildContext context,
  Location location,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InterruptionSheet(location: location),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM-SHEET WRAPPER
// ─────────────────────────────────────────────────────────────────────────────

class _InterruptionSheet extends ConsumerWidget {
  final Location location;
  const _InterruptionSheet({required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pause_circle_outline,
                        color: AppColors.warning, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.interruptions, style: AppTextStyles.heading2),
                        Text(
                          location.vehiculeNom ?? 'Location',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            Expanded(
              child: _InterruptionBody(
                location: location,
                scrollController: controller,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CORPS PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class _InterruptionBody extends ConsumerStatefulWidget {
  final Location location;
  final ScrollController scrollController;

  const _InterruptionBody({
    required this.location,
    required this.scrollController,
  });

  @override
  ConsumerState<_InterruptionBody> createState() => _InterruptionBodyState();
}

class _InterruptionBodyState extends ConsumerState<_InterruptionBody> {
  late Location _location;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _location = widget.location;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    try {
      final updated = await ref
          .read(locationsRepositoryProvider)
          .getById(_location.id);
      if (updated != null && mounted) setState(() => _location = updated);
    } catch (_) {}
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _demarrer() async {
    final result = await showDialog<_InterruptionFormResult>(
      context: context,
      builder: (_) => _InterruptionFormDialog(locationId: _location.id),
    );
    if (result == null || !mounted) return;

    setState(() => _loading = true);
    try {
      final repo = ref.read(locationsRepositoryProvider);

      // 1. Créer l'interruption
      await repo.demarrerInterruption(
        locationId: _location.id,
        motif:      result.motif,
        dateDebut:  result.dateDebut,
        notes:      result.notes,
        createdById: ref.read(supabaseClientProvider).auth.currentUser?.id,
      );

      // 2. Passer le véhicule en réparation
      final showroomId = ref.read(currentShowroomIdProvider);
      final statutVehicule = result.motif == MotifInterruption.reparation
          ? 'reparation'
          : 'disponible'; // pour vidange/assurance rapide, reste dispo dans les faits
      await ref.read(supabaseClientProvider)
          .from('vehicules')
          .update({'statut': statutVehicule})
          .eq('showroom_id', showroomId ?? '')
          .eq('id', _location.vehiculeId);

      ref.invalidate(locationsActivesProvider);
      ref.invalidate(vehiculesProvider);
      await _refresh();

      if (mounted) {
        NotificationService().success(
          'Interruption démarrée — véhicule récupéré le ${_fmtDate(result.dateDebut)}',
        );
      }
    } catch (e) {
      if (mounted) NotificationService().error('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _terminer(LocationInterruption interruption) async {
    final dateFin = await _pickDate(
      context,
      title: context.l10n.dateDeRestitutionAuClient,
      initialDate: DateTime.now(),
      firstDate: interruption.dateDebut,
    );
    if (dateFin == null || !mounted) return;

    setState(() => _loading = true);
    try {
      final repo = ref.read(locationsRepositoryProvider);

      // 1. Terminer l'interruption
      await repo.terminerInterruption(
        interruptionId: interruption.id,
        dateFin:        dateFin,
      );

      // 2. Remettre le véhicule en 'loue'
      final showroomId = ref.read(currentShowroomIdProvider);
      await ref.read(supabaseClientProvider)
          .from('vehicules')
          .update({'statut': 'loue'})
          .eq('showroom_id', showroomId ?? '')
          .eq('id', _location.vehiculeId);

      ref.invalidate(locationsActivesProvider);
      ref.invalidate(vehiculesProvider);
      await _refresh();

      if (mounted) {
        final jours = dateFin.difference(interruption.dateDebut).inDays;
        NotificationService().success(
          'Véhicule restitué le ${_fmtDate(dateFin)} — $jours jour(s) déduit(s)',
        );
      }
    } catch (e) {
      if (mounted) NotificationService().error('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _supprimer(LocationInterruption interruption) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.supprimerLInterruption),
        content: const Text(
          'Cette action est irréversible. '
          'Les jours seront recalculés automatiquement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.btnAnnuler),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(context.l10n.btnSupprimer),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await ref.read(locationsRepositoryProvider)
          .deleteInterruption(interruption.id);
      // Si c'était une interruption active → remettre le véhicule en loue
      if (interruption.enCours) {
        final showroomId = ref.read(currentShowroomIdProvider);
        await ref.read(supabaseClientProvider)
            .from('vehicules')
            .update({'statut': 'loue'})
            .eq('showroom_id', showroomId ?? '')
            .eq('id', _location.vehiculeId);
        ref.invalidate(vehiculesProvider);
      }
      ref.invalidate(locationsActivesProvider);
      await _refresh();
      if (mounted) NotificationService().success(context.l10n.interruptionSupprimee);
    } catch (e) {
      if (mounted) NotificationService().error('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final interruptions = _location.interruptions;
    final active        = _location.interruptionActive;
    final joursTotal    = _location.joursInterruption;
    final montantDeduit = joursTotal * _location.prixJour;
    final terminated    = interruptions.where((i) => !i.enCours).toList();

    return Stack(
      children: [
        ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          children: [

            // ── Résumé impact ────────────────────────────────────────────
            if (interruptions.isNotEmpty) ...[
              _ImpactCard(
                joursTotal:    joursTotal,
                montantDeduit: montantDeduit,
                joursFacturables: _location.joursFacturables,
                montantFacturable: _location.montantCalcule,
                prixJour: _location.prixJour,
              ),
              const SizedBox(height: 16),
            ],

            // ── Interruption active ──────────────────────────────────────
            if (active != null) ...[
              _SectionLabel(
                label: '⏸ En cours',
                color: AppColors.warning,
              ),
              const SizedBox(height: 8),
              _InterruptionActiveCard(
                interruption: active,
                onTerminer: _loading ? null : () => _terminer(active),
                onSupprimer: _loading ? null : () => _supprimer(active),
              ),
              const SizedBox(height: 16),
            ],

            // ── Historique des interruptions terminées ───────────────────
            if (terminated.isNotEmpty) ...[
              _SectionLabel(
                label: 'Historique (${terminated.length})',
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 8),
              ...terminated.map((i) => _InterruptionHistCard(
                interruption: i,
                onSupprimer: _loading ? null : () => _supprimer(i),
              )),
              const SizedBox(height: 16),
            ],

            // ── Vide ─────────────────────────────────────────────────────
            if (interruptions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: AppColors.secondary, size: 48),
                      const SizedBox(height: 12),
                      Text(context.l10n.aucuneInterruptionEnregistree, style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: 6),
                      Text(context.l10n.laLocationSeDerouleSansInterruption, style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        // ── FAB : démarrer une interruption ─────────────────────────────
        if (active == null &&
            _location.statut == LocationStatut.en_cours)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _demarrer,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.pause_circle_outline),
              label: Text(_loading
                  ? 'Traitement…'
                  : 'Récupérer le véhicule'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),

        // Spinner overlay
        if (_loading)
          const Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(color: Colors.transparent),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARTE : impact financier
// ─────────────────────────────────────────────────────────────────────────────

class _ImpactCard extends StatelessWidget {
  final int joursTotal;
  final double montantDeduit;
  final int joursFacturables;
  final double montantFacturable;
  final double prixJour;

  const _ImpactCard({
    required this.joursTotal,
    required this.montantDeduit,
    required this.joursFacturables,
    required this.montantFacturable,
    required this.prixJour,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined,
                  color: AppColors.warning, size: 16),
              const SizedBox(width: 6),
              Text(context.l10n.impactFinancier, style: AppTextStyles.body.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ImpactRow(
            label: 'Jours d\'interruption déduits',
            value: '$joursTotal j',
            color: AppColors.error,
          ),
          _ImpactRow(
            label: context.l10n.montantDeduit,
            value: '− ${montantDeduit.toInt()} DA',
            color: AppColors.error,
          ),
          const Divider(height: 14),
          _ImpactRow(
            label: context.l10n.joursFacturables,
            value: '$joursFacturables j',
            bold: true,
          ),
          _ImpactRow(
            label: context.l10n.montantFacturable,
            value: '${montantFacturable.toInt()} DA',
            bold: true,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _ImpactRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.bodySecondary
                  .copyWith(fontSize: bold ? 13 : 12)),
          Text(value,
              style: TextStyle(
                fontSize: bold ? 14 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARTE : interruption active
// ─────────────────────────────────────────────────────────────────────────────

class _InterruptionActiveCard extends StatelessWidget {
  final LocationInterruption interruption;
  final VoidCallback? onTerminer;
  final VoidCallback? onSupprimer;

  const _InterruptionActiveCard({
    required this.interruption,
    this.onTerminer,
    this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    final joursPasses = DateTime.now()
        .difference(interruption.dateDebut)
        .inDays;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                interruption.motif.icon,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      interruption.motif.label,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                    Text(
                      'Depuis le ${_fmt(interruption.dateDebut)} · $joursPasses j',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ],
                ),
              ),
              _StatusBadge(label: context.l10n.locationEnCours, color: AppColors.warning),
            ],
          ),
          if (interruption.notes != null && interruption.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                interruption.notes!,
                style: AppTextStyles.bodySecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSupprimer,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(context.l10n.btnSupprimer),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onTerminer,
                  icon: const Icon(Icons.play_circle_outline, size: 16),
                  label: Text(context.l10n.restituerAuClient),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// CARTE : interruption terminée (historique)
// ─────────────────────────────────────────────────────────────────────────────

class _InterruptionHistCard extends StatelessWidget {
  final LocationInterruption interruption;
  final VoidCallback? onSupprimer;

  const _InterruptionHistCard({
    required this.interruption,
    this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(interruption.motif.icon,
              style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  interruption.motif.label,
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_fmt(interruption.dateDebut)} → ${_fmt(interruption.dateFin!)}',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '−${interruption.nbJours} j',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.textTertiary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onSupprimer,
                tooltip: context.l10n.btnSupprimer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG : formulaire de démarrage d'interruption
// ─────────────────────────────────────────────────────────────────────────────

class _InterruptionFormResult {
  final MotifInterruption motif;
  final DateTime dateDebut;
  final String? notes;

  _InterruptionFormResult({
    required this.motif,
    required this.dateDebut,
    this.notes,
  });
}

class _InterruptionFormDialog extends StatefulWidget {
  final String locationId;
  const _InterruptionFormDialog({required this.locationId});

  @override
  State<_InterruptionFormDialog> createState() =>
      _InterruptionFormDialogState();
}

class _InterruptionFormDialogState extends State<_InterruptionFormDialog> {
  MotifInterruption _motif  = MotifInterruption.reparation;
  DateTime          _date   = DateTime.now();
  final _notesCtrl          = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30000)),
      lastDate: DateTime.now(),
      helpText: 'Date de récupération du véhicule',
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.recupererLeVehicule),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Indiquez la raison et la date à laquelle vous récupérez le véhicule.'
              ' Ces jours seront déduits de la facturation.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 16),

            // Motif
            Text(context.l10n.champMotif, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MotifInterruption.values
                  .map((m) => ChoiceChip(
                        label: Text('${m.icon} ${m.label}'),
                        selected: _motif == m,
                        onSelected: (_) => setState(() => _motif = m),
                        selectedColor:
                            AppColors.warning.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: _motif == m
                              ? AppColors.warning
                              : AppColors.textPrimary,
                          fontWeight: _motif == m
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Date
            Text(context.l10n.dateDeRecuperation, style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      '${_date.day.toString().padLeft(2,'0')}/${_date.month.toString().padLeft(2,'0')}/${_date.year}',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.l10n.notesOptionnel,
                hintText: context.l10n.exRevision60000KmChez,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.btnAnnuler),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _InterruptionFormResult(
              motif:    _motif,
              dateDebut: _date,
              notes:    _notesCtrl.text.trim().isEmpty
                            ? null
                            : _notesCtrl.text.trim(),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.white,
          ),
          child: Text(context.l10n.btnConfirmer),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS UTILITAIRES
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET INLINE : badge compact pour la location card
// Utilisation : dans _LocationCard de locations_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

/// Affiche un badge compact si une interruption est active
/// À placer dans les infos de la LocationCard
class InterruptionBadge extends StatelessWidget {
  final Location location;

  const InterruptionBadge({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    if (!location.hasInterruptionActive) return const SizedBox.shrink();

    final interruption = location.interruptionActive!;
    final jours = DateTime.now()
        .difference(interruption.dateDebut)
        .inDays;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pause_circle_outline,
              size: 12, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            '${interruption.motif.icon} ${interruption.motif.label} · ${jours}j',
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER FUNCTION
// ─────────────────────────────────────────────────────────────────────────────

Future<DateTime?> _pickDate(
  BuildContext context, {
  required String title,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDatePicker(
    context: context,
    helpText: title,
    initialDate: initialDate ?? DateTime.now(),
    firstDate: firstDate ?? DateTime(2020),
    lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
  );
}