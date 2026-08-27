// lib/features/locations/presentation/location_retour_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/car_damage_map.dart';
import '../../../shared/widgets/signature_pad.dart';

import '../../auth/presentation/auth_provider.dart'; // ✅ pour currentShowroomIdProvider
import '../../vehicules/domain/etat_carrosserie_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import '../domain/location_model.dart';
import 'locations_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class LocationRetourScreen extends ConsumerStatefulWidget {
  final String locationId;
  const LocationRetourScreen({super.key, required this.locationId});

  @override
  ConsumerState<LocationRetourScreen> createState() => _State();
}

class _State extends ConsumerState<LocationRetourScreen> {
  final _formKey    = GlobalKey<FormState>();
  bool  _loading    = false;

  final _kmCtrl      = TextEditingController();
  final _retenueCtrl = TextEditingController(text: '0');
  final _notesCtrl   = TextEditingController();

  Location? _location;
  final _signatureKey = GlobalKey<SignaturePadState>();

  EtatCarrosserie  _etatRetour = const EtatCarrosserie();
  EtatCarrosserie? _etatDepart;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _kmCtrl.dispose();
    _retenueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      final loc = await ref.read(locationsRepositoryProvider).getById(widget.locationId);
      if (!mounted) return;
      setState(() {
        _location = loc;
        final raw = loc?.etatCarrosserieDepart;
        if (raw != null && raw.isNotEmpty) {
          _etatDepart = EtatCarrosserie.fromJsonString(raw);
        }
      });
    } catch (_) {
      try {
        final list = await ref.read(locationsRepositoryProvider).getActives();
        final loc  = list.cast<Location?>().firstWhere(
          (l) => l?.id == widget.locationId, orElse: () => null);
        if (loc != null && mounted) setState(() => _location = loc);
      } catch (_) {}
    }
  }

  double get _montant =>
      _location?.montantBrut ?? _location?.montantCalcule ?? 0;

  double get _retenue => double.tryParse(_retenueCtrl.text) ?? 0;
  double get _cautionARestituer =>
      ((_location?.caution ?? 0) - _retenue).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    if (_location == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.retourVehicule)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final l = _location!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.l10n.enregistrerLeRetour),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [

            // ── Récap location ──────────────────────────────────────────────
            _LocationSummaryCard(location: l),
            const SizedBox(height: 20),

            // ── État carrosserie départ (lecture seule) ─────────────────────
            if (_etatDepart != null && _etatDepart!.hasAnyDamage) ...[
              _SectionHeader(
                icon: Icons.departure_board,
                label: context.l10n.etatCarrosserieAuDepart,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              Container(
                height: 300,
                decoration: BoxDecoration( // Corrected: removed const from here
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CarDamageMap(etat: _etatDepart!, readOnly: true),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Kilométrage & retenue ────────────────────────────────────────
            _SectionHeader(
              icon: Icons.speed,
              label: context.l10n.detailsDuRetour,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _kmCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: context.l10n.kmAuRetour,
                    suffixText: 'km',
                    prefixIcon: const Icon(Icons.speed, size: 20),
                    helperText: context.l10n.departKm(l.kmDepart.toString()),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requis';
                    final km = int.tryParse(v);
                    if (km == null)      return 'Invalide';
                    if (km < l.kmDepart) return context.l10n.kmDepartInferieur;
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _retenueCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: context.l10n.retenueCaution,
                    suffixText: 'DA',
                    prefixIcon: Icon(Icons.money_off, size: 20),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.observationsAuRetour,
                hintText: context.l10n.carburantPropreteDegradationsConstatees,
                prefixIcon: Icon(Icons.edit_note, size: 20),
              ),
            ),
            const SizedBox(height: 20),

            // ── Schéma état carrosserie retour ──────────────────────────────
            _SectionHeader(
              icon: Icons.directions_car,
              label: context.l10n.etatCarrosserieAuRetour,
              color: AppColors.warning,
            ),
            const SizedBox(height: 8),
            VehicleInspectorCard(
              title: context.l10n.marquezLesDommagesConstatesAuRetour,
              etat: _etatRetour,
              onChanged: (v) => setState(() => _etatRetour = v),
            ),
            const SizedBox(height: 24),

            // ── Signature électronique du client ─────────────────────────────
            _SectionHeader(
              icon: Icons.draw_outlined,
              label: 'Signature du client',
              color: AppColors.primary,
            ),
            const SizedBox(height: 8),
            SignaturePad(key: _signatureKey),

            const SizedBox(height: 24),

            // ── Récap financier ─────────────────────────────────────────────
            _FinancialRecap(
              montant:           _montant,
              caution:           l.caution,
              retenue:           _retenue,
              cautionARestituer: _cautionARestituer,
              kmDepart:          l.kmDepart,
              kmRetour:          int.tryParse(_kmCtrl.text),
            ),
            const SizedBox(height: 24),

            // ── Bouton submit ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_loading ? 'Enregistrement…' : 'Valider le retour'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final etatRetourJson =
          (_etatRetour.hasAnyDamage || _etatRetour.observations != null)
              ? _etatRetour.toJsonString()
              : null;

      // Signature électronique (optionnelle mais fortement recommandée)
      String? signatureUrl;
      final signatureBytes = await _signatureKey.currentState?.exportPng();
      if (signatureBytes != null) {
        signatureUrl = await ref.read(locationsRepositoryProvider).uploadSignature(
              locationId: widget.locationId,
              pngBytes: signatureBytes,
              suffix: 'retour',
            );
      }

      await ref.read(locationsRepositoryProvider).cloturerLocation(
        locationId:           widget.locationId,
        kmRetour:             int.parse(_kmCtrl.text),
        retenueCaution:       _retenue,
        notesRetour:          _notesCtrl.text.trim().isEmpty
                                  ? null : _notesCtrl.text.trim(),
        etatCarrosserieRetour: etatRetourJson,
        signatureClientRetourUrl: signatureUrl,
      );

      if (_location?.vehiculeId != null) {
        final showroomId = ref.read(currentShowroomIdProvider);
        await ref.read(supabaseClientProvider)
            .from('vehicules')
            .update({'statut': 'disponible'})
            .eq('showroom_id', showroomId ?? '')
            .eq('id', _location!.vehiculeId);
      }

      ref.invalidate(locationsActivesProvider);
      ref.invalidate(locationsRetardProvider);
      ref.invalidate(locationsHistoriqueProvider);
      ref.invalidate(vehiculesProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.retourEnregistreAvecSucces),
          backgroundColor: AppColors.secondary,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.erreurAvecDetail(e.toString())),
          backgroundColor: AppColors.retard,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS LOCAUX
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: color),
    ),
    const SizedBox(width: 8),
    Text(label,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: color)),
  ]);
}

class _LocationSummaryCard extends StatelessWidget {
  final Location location;
  const _LocationSummaryCard({required this.location});

  @override
  Widget build(BuildContext context) {
    final dateFinStr = location.dateFinPrevue != null
        ? '${location.dateFinPrevue!.day}/${location.dateFinPrevue!.month}/${location.dateFinPrevue!.year}'
        : 'Contrat ouvert';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: location.isOverdue
                ? AppColors.retard.withValues(alpha: 0.3)
                : AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.directions_car, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
              child: Text(location.vehiculeNom ?? '---',
                  style: AppTextStyles.heading3)),
          if (location.isOverdue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.retard.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(context.l10n.joursRetard(location.joursRetard.toString()),
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.retard,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 4),
        Text(location.clientNom ?? '---', style: AppTextStyles.bodySecondary),
        const SizedBox(height: 8),
        Row(children: [
          _Chip(
            icon: Icons.calendar_today,
            label: '${location.dateDebut.day}/${location.dateDebut.month}/${location.dateDebut.year} → $dateFinStr',
          ),
          const SizedBox(width: 8),
          _Chip(icon: Icons.speed, label: '${location.kmDepart} km'),
        ]),
        const SizedBox(height: 6),
        _Chip(
          icon: Icons.payments_outlined,
          label:
              '${location.prixJour.toInt()} DA/j × ${location.nbJours}j'
              ' = ${location.montantCalcule.toInt()} DA',
        ),
        if (location.interruptions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _Chip(
              icon: Icons.pause_circle_outline,
              label: '${location.joursInterruption} j interruption déduits',
            ),
          ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.inputFill,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500)),
    ]),
  );
}

class _FinancialRecap extends StatelessWidget {
  final double montant;
  final double caution;
  final double retenue;
  final double cautionARestituer;
  final int    kmDepart;
  final int?   kmRetour;

  const _FinancialRecap({
    required this.montant,
    required this.caution,
    required this.retenue,
    required this.cautionARestituer,
    required this.kmDepart,
    this.kmRetour,
  });

  @override
  Widget build(BuildContext context) {
    final distance = kmRetour != null ? kmRetour! - kmDepart : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        _Row('Montant location', '${montant.toInt()} DA', bold: true),
        const SizedBox(height: 8),
        _Row('Caution versée', '${caution.toInt()} DA'),
        _Row('Retenue caution', '− ${retenue.toInt()} DA',
            color: AppColors.retard),
        const Divider(height: 16, color: AppColors.border),
        _Row(
          'Caution à restituer',
          '${cautionARestituer.toInt()} DA',
          bold: true,
          color: cautionARestituer > 0
              ? AppColors.secondary
              : AppColors.retard,
        ),
        if (distance != null) ...[
          const Divider(height: 16, color: AppColors.border),
          _Row('Distance parcourue', '$distance km'),
        ],
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String k;
  final String v;
  final bool   bold;
  final Color? color;
  const _Row(this.k, this.v, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k,
            style: TextStyle(
                fontSize: bold ? 13 : 12,
                color: AppColors.textSecondary,
                fontWeight:
                    bold ? FontWeight.w600 : FontWeight.normal)),
        Text(v,
            style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.textPrimary)),
      ],
    ),
  );
}