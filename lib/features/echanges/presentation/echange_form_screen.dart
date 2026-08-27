// lib/features/echanges/presentation/echange_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/car_damage_map.dart';
import '../../clients/domain/client_model.dart';
import '../../clients/presentation/clients_provider.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/domain/etat_carrosserie_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../admin/presentation/showroom_settings_provider.dart';
import '../../../core/services/pdf/contrat_orchestrator.dart';         // ✅
import 'echanges_provider.dart';
import '../../../shared/services/notification_service.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class EchangeFormScreen extends ConsumerStatefulWidget {
  const EchangeFormScreen({super.key});

  @override
  ConsumerState<EchangeFormScreen> createState() => _EchangeFormScreenState();
}

class _EchangeFormScreenState extends ConsumerState<EchangeFormScreen> {
  final _formKey        = GlobalKey<FormState>();
  Vehicule? _vehiculeCede;
  Client?   _client;

  final _marqueCtrl     = TextEditingController();
  final _modeleCtrl     = TextEditingController();
  final _anneeCtrl      = TextEditingController();
  final _kmCtrl         = TextEditingController();
  final _immatCtrl      = TextEditingController();
  final _valeurCtrl     = TextEditingController();
  final _complementCtrl = TextEditingController();
  final _comCtrl        = TextEditingController(text: '5');
  final _notesCtrl      = TextEditingController();

  bool _loading    = false;
  bool _genererPdf = true;

  EtatCarrosserie _etatCede   = const EtatCarrosserie();
  EtatCarrosserie _etatRepris = const EtatCarrosserie();

  double get _valeur     => double.tryParse(_valeurCtrl.text)     ?? 0;
  double get _complement => double.tryParse(_complementCtrl.text) ?? 0;
  double get _com        => double.tryParse(_comCtrl.text)        ?? 5;
  double get _prixVente  => _vehiculeCede?.prixVente              ?? 0;
  double get _comMnt     => (_prixVente + _complement) * _com / 100;

  @override
  void dispose() {
    for (final c in [
      _marqueCtrl, _modeleCtrl, _anneeCtrl, _kmCtrl, _immatCtrl,
      _valeurCtrl, _complementCtrl, _comCtrl, _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helper settings ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getSettings() async {
    final s = await ref.read(showroomSettingsTypedProvider.future);
    return {
      'nom':      s.nom,
      'adresse':  s.adresse,
      'tel':      s.tel,
      'email':    s.email,
      'rc':       s.rc,
      'logo_url': s.logoUrl,
    };
  }

  @override
  Widget build(BuildContext context) {
    final vehicules = ref.watch(vehiculesProvider).valueOrNull
        ?.where((v) => v.statut == VehiculeStatut.disponible).toList() ?? [];
    final clients = ref.watch(clientsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: CustomAppBar(
        title: context.l10n.dossierEchangeReprise,
        showHomeButton: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Véhicule cédé ──────────────────────────────────────────
            Text(context.l10n.vehiculeCedeDuMagasin, style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            DropdownButtonFormField<Vehicule>(
              value: _vehiculeCede,                           // ✅ value, pas initialValue
              decoration: InputDecoration(
                labelText: context.l10n.selectionnerLeVehicule),
              items: vehicules.map((v) => DropdownMenuItem<Vehicule>(
                value: v, child: Text(v.displayName))).toList(),
              onChanged: (v) => setState(() => _vehiculeCede = v),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            // ── Client ─────────────────────────────────────────────────
            Text(context.l10n.sectionClient, style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            DropdownButtonFormField<Client>(
              value: _client,                                 // ✅ value, pas initialValue
              decoration: InputDecoration(
                labelText: context.l10n.selectionnerLeClient),
              items: clients.map((c) => DropdownMenuItem<Client>(
                value: c, child: Text(c.fullName))).toList(),
              onChanged: (c) => setState(() => _client = c),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            // ── Véhicule repris ────────────────────────────────────────
            Text(context.l10n.vehiculeReprisDuClient, style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _marqueCtrl,
                decoration: InputDecoration(labelText: context.l10n.marque),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requis' : null,
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _modeleCtrl,
                decoration: InputDecoration(labelText: context.l10n.modele),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requis' : null,
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _anneeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.l10n.annee),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _kmCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.kilometrage, suffixText: 'km'),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _immatCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.immatriculation),
              )),
            ]),
            const SizedBox(height: 16),

            // ── Valeurs financières ────────────────────────────────────
            Text(context.l10n.valeursFinancieres, style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _valeurCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.valeurReprise, suffixText: 'DA'),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requis' : null,
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _complementCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.complementClient, suffixText: 'DA'),
                onChanged: (_) => setState(() {}),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _comCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.champCommission, suffixText: '%'),
                onChanged: (_) => setState(() {}),
              )),
            ]),
            const SizedBox(height: 12),

            if (_vehiculeCede != null)
              _RecapEchange(
                vehiculeCede:   _vehiculeCede!.displayName,
                vehiculeRepris: '${_marqueCtrl.text} ${_modeleCtrl.text}',
                valeurReprise:  _valeur,
                complement:     _complement,
                commissionPct:  _com,
                commissionMnt:  _comMnt,
              ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(labelText: context.l10n.champNotes),
            ),
            const SizedBox(height: 16),

            // ── Carrosserie véhicule cédé ──────────────────────────────
            VehicleInspectorCard(
              title: context.l10n.carrosserieVehiculeCede,
              etat: _etatCede,
              onChanged: (v) => setState(() => _etatCede = v),
            ),
            const SizedBox(height: 12),

            // ── Carrosserie véhicule repris ────────────────────────────
            VehicleInspectorCard(
              title: context.l10n.carrosserieVehiculeRepris,
              etat: _etatRepris,
              onChanged: (v) => setState(() => _etatRepris = v),
            ),
            const SizedBox(height: 20),

            _buildCheckboxPdf(),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.swap_horiz),
                label: Text(_loading
                    ? 'Enregistrement...'
                    : "Valider l'échange"),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final echange = await ref.read(echangesRepositoryProvider).create({
        'vehicule_cede_id':          _vehiculeCede!.id,
        'client_id':                 _client!.id,
        'vehicule_reprise_marque':   _marqueCtrl.text.trim(),
        'vehicule_reprise_modele':   _modeleCtrl.text.trim(),
        'vehicule_reprise_annee':    int.tryParse(_anneeCtrl.text),
        'vehicule_reprise_km':       int.tryParse(_kmCtrl.text),
        'vehicule_reprise_immat':    _immatCtrl.text.trim().isEmpty
                                       ? null : _immatCtrl.text.trim(),
        'valeur_reprise':            _valeur,
        'complement_client':         _complement,
        'commission_gerant_pct':     _com,
        // commission_gerant_mnt non envoyé — colonne inexistante en base
        'date_echange':              DateTime.now()
                                       .toIso8601String()
                                       .substring(0, 10),
        'notes':                     _notesCtrl.text.trim().isEmpty
                                       ? null : _notesCtrl.text.trim(),
        'etat_carrosserie_cede':     _etatCede.hasAnyDamage ||
                                     (_etatCede.observations != null)
                                       ? _etatCede.toJsonString() : null,
        'etat_carrosserie_reprise':  _etatRepris.hasAnyDamage ||
                                     (_etatRepris.observations != null)
                                       ? _etatRepris.toJsonString() : null,
        'created_by': ref.read(supabaseClientProvider).auth.currentUser?.id,
      });

      ref.invalidate(echangesProvider);
      ref.invalidate(vehiculesProvider);
      // ── Helper Settings ──────────────────────────────────────────────────────────

      Future<Map<String, dynamic>> _fetchSettings(WidgetRef ref) async {
        final s = await ref.read(showroomSettingsTypedProvider.future);
        return {
          'nom':     s.nom,
          'adresse': s.adresse ?? '',
          'tel':     s.tel ?? '',
          'email':   s.email ?? '',
          'rc':      s.rc ?? '',
          'logo_url': s.logoUrl ?? '',
        };
      }

      // ── Génération PDF via ContratOrchestrator ─────────────────────
      // L'échange est déjà enregistré à ce stade : une erreur de génération
      // PDF ne doit donc pas être confondue avec un échec de l'échange.
      String? pdfError;
      if (_genererPdf && mounted) {
        try {
          final orchestrator = ContratOrchestrator(
            () => _fetchSettings(ref),
            supabase:   ref.read(supabaseClientProvider),
            showroomId: ref.read(currentShowroomIdProvider) ?? '',
          );
          await orchestrator.generateAndShareEchange(
            echangeData: {
              'id':                        echange.id,
              'client_id':                 _client!.id,
              'clients': {
                'prenom': _client!.prenom,
                'nom':    _client!.nom,
                'telephone': _client!.telephone ?? '',
              },
              'vehicules': {
                'marque': _vehiculeCede!.marque,
                'modele': _vehiculeCede!.modele,
                'annee':  _vehiculeCede!.annee,
                'immatriculation': _vehiculeCede!.immatriculation,
              },
              'vehicule_reprise_marque': _marqueCtrl.text.trim(),
              'vehicule_reprise_modele': _modeleCtrl.text.trim(),
              'vehicule_reprise_annee':  int.tryParse(_anneeCtrl.text),
              'vehicule_reprise_km':     int.tryParse(_kmCtrl.text),
              'vehicule_reprise_immat':  _immatCtrl.text.trim().isEmpty
                                           ? null : _immatCtrl.text.trim(),
              'valeur_reprise':          _valeur,
              'complement_client':       _complement,
              'commission_gerant_pct':   _com,
              'date_echange':            echange.dateEchange.toIso8601String(),
              'notes':                   echange.notes,
            },
          );
        } catch (e) {
          pdfError = e.toString();
        }
      }

      if (mounted) {
        context.pop();
        if (pdfError != null) {
          NotificationService().error(
            "Échange enregistré, mais la génération du contrat PDF a échoué : $pdfError",
          );
        } else {
          NotificationService().success(context.l10n.echangeEnregistreAvecSucces);
        }
      }
    } catch (e) {
      if (mounted) NotificationService().error('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildCheckboxPdf() => CheckboxListTile(
        value: _genererPdf,
        onChanged: (v) => setState(() => _genererPdf = v ?? true),
        title: Text(context.l10n.genererEtPartagerLeContratPdf),
        secondary: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
        contentPadding: EdgeInsets.zero,
        dense: true,
      );
}

// ── Récap échange ─────────────────────────────────────────────────────────────

class _RecapEchange extends StatelessWidget {
  final String vehiculeCede, vehiculeRepris;
  final double valeurReprise, complement, commissionPct, commissionMnt;

  const _RecapEchange({
    required this.vehiculeCede,
    required this.vehiculeRepris,
    required this.valeurReprise,
    required this.complement,
    required this.commissionPct,
    required this.commissionMnt,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          _row('Véhicule cédé',   vehiculeCede),
          _row('Véhicule repris', vehiculeRepris),
          const Divider(height: 14),
          _row('Valeur de reprise',   '${valeurReprise.toInt()} DA'),
          _row('Complément client',   '${complement.toInt()} DA'),
          _row('Commission (${commissionPct.toInt()}%)',
              '${commissionMnt.toInt()} DA',
              color: AppColors.gerant),
        ]),
      );

  Widget _row(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary)),
            Text(v, style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.textPrimary)),
          ],
        ),
      );
}