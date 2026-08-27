// lib/features/locations/presentation/location_recap_screen.dart
//
// Écran de résumé financier d'une location.
// Affiche la répartition gérant / propriétaire(s) et permet de
// générer un récapitulatif PDF interne (≠ facture client).
//
// Usage :
//   context.push('/locations/${id}/recap')
// ou en modal :
//   showModalBottomSheet(... child: LocationRecapScreen(locationId: id))

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/widgets/modern_button.dart';
import '../domain/location_model.dart';
import 'locations_provider.dart';

// PDF
import '../../../core/services/pdf/recap_location_pdf_generator.dart';
import '../../../core/services/pdf/pdf_storage_service.dart';

// Showroom settings
import '../../admin/presentation/showroom_settings_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';


// ─────────────────────────────────────────────────────────────────────────────
// ENTRÉE PUBLIQUE : bottom-sheet ou full-screen
// ─────────────────────────────────────────────────────────────────────────────

/// Affiche le récapitulatif financier en bottom-sheet (usage recommandé).
Future<void> showLocationRecap(BuildContext context, String locationId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LocationRecapSheet(locationId: locationId),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM-SHEET WRAPPER
// ─────────────────────────────────────────────────────────────────────────────

class LocationRecapSheet extends ConsumerWidget {
  final String locationId;
  const LocationRecapSheet({super.key, required this.locationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(locationDetailProvider(locationId));

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Poignée
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

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.analytics_outlined,
                        color: AppColors.secondary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.resumeFinancier, style: AppTextStyles.heading2),
                        locationAsync.whenOrNull(
                              data: (loc) => loc == null
                                  ? null
                                  : Text(
                                      loc.vehiculeNom ?? 'Location',
                                      style: AppTextStyles.bodySecondary,
                                    ),
                            ) ??
                            const SizedBox.shrink(),
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

            // Contenu scrollable
            Expanded(
              child: locationAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(context.l10n.erreurAvecDetail(e.toString()))),
                data: (location) {
                  if (location == null) {
                    return Center(child: Text(context.l10n.locationIntrouvable));
                  }
                  return _LocationRecapBody(
                    location: location,
                    scrollController: controller,
                  );
                },
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

class _LocationRecapBody extends ConsumerStatefulWidget {
  final Location location;
  final ScrollController scrollController;

  const _LocationRecapBody({
    required this.location,
    required this.scrollController,
  });

  @override
  ConsumerState<_LocationRecapBody> createState() => _LocationRecapBodyState();
}

class _LocationRecapBodyState extends ConsumerState<_LocationRecapBody> {
  bool _generatingPdf = false;

  Location get loc => widget.location;

  // ── Calculs ──────────────────────────────────────────────────────────────

  double get _montantBrut => loc.montantCalcule;

  /// Répartition depuis location_repartitions (données réelles Supabase)
  /// Si aucune répartition enregistrée, on affiche un message.
  List<LocationRepartition> get _repartitions => loc.repartitions;

  double get _totalGerant => _repartitions
      .where((r) => r.typePart == 'commission_gerant')
      .fold(0.0, (s, r) => s + r.montant);

  double get _totalProprio => _repartitions
      .where((r) => r.typePart == 'part_proprietaire')
      .fold(0.0, (s, r) => s + r.montant);

  double get _totalPaiements => loc.totalPaiements;

  double get _solde => _montantBrut - loc.retenueCaution - _totalPaiements;

  // ── Génération PDF ────────────────────────────────────────────────────────

  Future<void> _genererPdf() async {
    setState(() => _generatingPdf = true);
    try {
      // Charger les settings showroom (même pattern que location_form_screen)
      final typed = await ref.read(showroomSettingsTypedProvider.future);
      final settings = <String, dynamic>{
        'nom':     typed.nom,
        'adresse': typed.adresse ?? '',
        'tel':     typed.tel ?? '',
        'email':   typed.email ?? '',
        'rc':      typed.rc ?? '',
      };

      final dto = RecapLocationDto(
        locationId: loc.id,
        dateEmission: DateTime.now(),
        // Agence
        agenceNom: settings['nom'] as String,
        agenceAdresse: settings['adresse'] as String,
        agenceTel: settings['tel'] as String,
        agenceEmail: settings['email'] as String?,
        agenceRc: settings['rc'] as String?,
        agenceCouleurHex: '#10B981', // AppColors.secondary
        // Location
        vehiculeNom: loc.vehiculeNom ?? 'Véhicule',
        clientNom: loc.clientNom ?? 'Client',
        dateDebut: loc.dateDebut,
        dateFinPrevue: loc.dateFinPrevue,
        dateFinReelle: loc.dateFinReelle,
        nbJours: loc.joursActuels,
        prixJour: loc.prixJour,
        montantBrut: _montantBrut,
        caution: loc.caution,
        retenueCaution: loc.retenueCaution,
        totalPaiements: _totalPaiements,
        // Répartitions
        repartitions: _repartitions
            .map((r) => RecapRepartitionDto(
                  nom: r.beneficiaireNom,
                  typePart: r.typePart,
                  pourcentage: r.pourcentage,
                  montant: r.montant,
                ))
            .toList(),
      );

      final doc = await RecapLocationPdfGenerator.build(dto);
      final bytes = await doc.save();

      await PdfStorageService.saveAndShare(
        bytes: bytes,
        filename:
            'recap_location_${loc.id.substring(0, 8).toUpperCase()}.pdf',
        subject: 'Récapitulatif location — ${loc.vehiculeNom}',
      );

      if (mounted) {
        NotificationService().success(context.l10n.pdfGenereAvecSucces);
      }
    } catch (e) {
      if (mounted) NotificationService().error('Erreur PDF : $e');
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        // ── Info location ──────────────────────────────────────────────────
        _SectionCard(
          icon: Icons.directions_car_outlined,
          title: context.l10n.detailsDeLaLocation,
          color: AppColors.primary,
          child: Column(
            children: [
              _InfoRow('Véhicule', loc.vehiculeNom ?? '—'),
              _InfoRow('Client', loc.clientNom ?? '—'),
              _InfoRow('Début', _fmtDate(loc.dateDebut)),
              if (loc.dateFinReelle != null)
                _InfoRow('Fin réelle', _fmtDate(loc.dateFinReelle!))
              else if (loc.dateFinPrevue != null)
                _InfoRow('Fin prévue', _fmtDate(loc.dateFinPrevue!))
              else
                const _InfoRow('Type', 'Contrat ouvert'),
              _InfoRow('Durée', '${loc.joursActuels} jour(s)'),
              if (loc.interruptions.isNotEmpty) ...[
              _InfoRow(
                'Jours interruption',
                '− ${loc.joursInterruption} j',
                valueColor: AppColors.warning,
              ),
              _InfoRow(
                'Jours facturables',
                '${loc.joursFacturables} j',
                bold: true,
              ),
            ],
              _InfoRow('Prix / jour', '${loc.prixJour.toInt()} DA'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Montants ──────────────────────────────────────────────────────
        _SectionCard(
          icon: Icons.payments_outlined,
          title: context.l10n.montants,
          color: AppColors.secondary,
          child: Column(
            children: [
              _InfoRow(
                'Montant brut',
                '${_montantBrut.toInt()} DA',
                bold: true,
                valueColor: AppColors.textPrimary,
              ),
              if (loc.caution > 0)
                _InfoRow('Caution versée', '${loc.caution.toInt()} DA'),
              if (loc.retenueCaution > 0)
                _InfoRow(
                  'Retenue caution',
                  '- ${loc.retenueCaution.toInt()} DA',
                  valueColor: AppColors.error,
                ),
              _InfoRow(
                'Total encaissé',
                '${_totalPaiements.toInt()} DA',
                valueColor: AppColors.success,
              ),
              _InfoRow(
                _solde > 0 ? 'Reste à payer' : 'Solde',
                '${_solde.toInt()} DA',
                bold: true,
                valueColor: _solde > 0 ? AppColors.error : AppColors.success,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Répartition ───────────────────────────────────────────────────
        _SectionCard(
          icon: Icons.pie_chart_outline,
          title: context.l10n.repartitionDesGains,
          color: AppColors.accent,
          child: _repartitions.isEmpty
              ? _EmptyRepartition()
              : Column(
                  children: [
                    // Gérant(s)
                    if (_totalGerant > 0) ...[
                      _RepartitionHeader(
                        label: context.l10n.commissionGerant,
                        montant: _totalGerant,
                        color: AppColors.gerant,
                      ),
                      ..._repartitions
                          .where((r) => r.typePart == 'commission_gerant')
                          .map((r) => _RepartitionRow(repartition: r)),
                    ],

                    if (_totalGerant > 0 && _totalProprio > 0)
                      const Divider(height: 16),

                    // Propriétaire(s)
                    if (_totalProprio > 0) ...[
                      _RepartitionHeader(
                        label: context.l10n.partProprietaireS,
                        montant: _totalProprio,
                        color: AppColors.proprietaireVehicule,
                      ),
                      ..._repartitions
                          .where((r) => r.typePart == 'part_proprietaire')
                          .map((r) => _RepartitionRow(repartition: r)),
                    ],

                    const Divider(height: 16),

                    // Total vérifié
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.l10n.totalReparti, style: AppTextStyles.heading3
                                .copyWith(color: AppColors.textSecondary)),
                        Text(
                          '${(_totalGerant + _totalProprio).toInt()} DA / ${_montantBrut.toInt()} DA',
                          style: AppTextStyles.heading3.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 12),

        // ── Paiements reçus ───────────────────────────────────────────────
        if (loc.paiements.isNotEmpty) ...[
          _SectionCard(
            icon: Icons.receipt_long_outlined,
            title: context.l10n.paiementsRecusCount(loc.paiements.length.toString()),
            color: AppColors.info,
            child: Column(
              children: loc.paiements
                  .map((p) => _InfoRow(
                        _fmtDate(p.datePaiement),
                        '${p.montant.toInt()} DA${p.mode != null ? ' · ${p.mode}' : ''}',
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Bouton PDF ────────────────────────────────────────────────────
        ModernButton(
          text: 'Générer récapitulatif PDF',
          icon: Icons.picture_as_pdf_outlined,
          onPressed: _generatingPdf ? null : _genererPdf,
          isLoading: _generatingPdf,
          type: ModernButtonType.primary,
        ),

        const SizedBox(height: 8),

        Text(
          '⚠️ Ce document est à usage interne uniquement.\n'
          'Il ne doit pas être remis au client.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS INTERNES
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: AppTextStyles.body
                        .copyWith(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _InfoRow(
    this.label,
    this.value, {
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySecondary),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RepartitionHeader extends StatelessWidget {
  final String label;
  final double montant;
  final Color color;

  const _RepartitionHeader({
    required this.label,
    required this.montant,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.body.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              )),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${montant.toInt()} DA',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepartitionRow extends StatelessWidget {
  final LocationRepartition repartition;

  const _RepartitionRow({required this.repartition});

  @override
  Widget build(BuildContext context) {
    final color = repartition.typePart == 'commission_gerant'
        ? AppColors.gerant
        : AppColors.proprietaireVehicule;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              repartition.beneficiaireNom.isEmpty
                  ? (repartition.typePart == 'commission_gerant'
                      ? 'Gérant'
                      : 'Propriétaire')
                  : repartition.beneficiaireNom,
              style: AppTextStyles.body,
            ),
          ),
          Text(
            '${repartition.pourcentage.toStringAsFixed(0)}%',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(width: 12),
          Text(
            '${repartition.montant.toInt()} DA',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRepartition extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.info_outline, color: AppColors.textTertiary, size: 32),
        const SizedBox(height: 8),
        Text(
          'Aucune répartition enregistrée.\n'
          'La répartition est calculée à la clôture de la location.',
          style: AppTextStyles.bodySecondary,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}