// lib/features/achats/presentation/achat_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../core/services/pdf/contrat_orchestrator.dart';          // ✅ remplacement
import '../../admin/presentation/showroom_settings_provider.dart';      // ✅ pour settings
import 'achats_provider.dart';
import '../../../shared/services/notification_service.dart';
import '../../../core/utils/app_logger.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';


class AchatFormScreen extends ConsumerStatefulWidget {
  const AchatFormScreen({super.key});

  @override
  ConsumerState<AchatFormScreen> createState() => _AchatFormScreenState();
}

class _AchatFormScreenState extends ConsumerState<AchatFormScreen> {
  final _formKey       = GlobalKey<FormState>();
  bool  _loading       = false;
  bool  _creerVehicule = true;
  bool  _genererPdf    = true;

  Vehicule? _vehiculeExistant;

  final _vendeurNomCtrl   = TextEditingController();
  final _vendeurTelCtrl   = TextEditingController();
  final _vendeurEmailCtrl = TextEditingController();
  final _prixProposeCtrl  = TextEditingController();
  final _prixAccordeCtrl  = TextEditingController();
  final _remarquesCtrl    = TextEditingController();

  final _marqueCtrl = TextEditingController();
  final _modeleCtrl = TextEditingController();
  final _anneeCtrl  = TextEditingController();
  final _kmCtrl     = TextEditingController();
  final _immatCtrl  = TextEditingController();
  DateTime _dateAchat = DateTime.now();

  @override
  void dispose() {
    for (final c in [
      _vendeurNomCtrl, _vendeurTelCtrl, _vendeurEmailCtrl,
      _prixProposeCtrl, _prixAccordeCtrl, _remarquesCtrl,
      _marqueCtrl, _modeleCtrl, _anneeCtrl, _kmCtrl, _immatCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helper settings (même pattern que vente_form_screen) ──────────────────

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
    final vehicules = ref.watch(vehiculesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: CustomAppBar(
        title: context.l10n.nouvelAchatReprise,
        showHomeButton: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Véhicule ───────────────────────────────────────────────
            Text(context.l10n.vehicule, style: AppTextStyles.heading2),
            SizedBox(height: 10),

            Row(children: [
              Expanded(
                child: ChoiceChip(
                  label: Text(context.l10n.nouveauVehicule),
                  selected: _creerVehicule,
                  onSelected: (_) => setState(() {
                    _creerVehicule    = true;
                    _vehiculeExistant = null;
                  }),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: Text(context.l10n.vehiculeExistant),
                  selected: !_creerVehicule,
                  onSelected: (_) => setState(() => _creerVehicule = false),
                ),
              ),
            ]),
            SizedBox(height: 12),

            if (_creerVehicule) ...[
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _marqueCtrl,
                  decoration: InputDecoration(labelText: context.l10n.marque),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                )),
                SizedBox(width: 10),
                Expanded(child: TextFormField(
                  controller: _modeleCtrl,
                  decoration: InputDecoration(labelText: context.l10n.modeleChamp),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                )),
              ]),
              SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _anneeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.l10n.annee),
                )),
                SizedBox(width: 10),
                Expanded(child: TextFormField(
                  controller: _kmCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.kilometrage, suffixText: 'km'),
                )),
              ]),
              SizedBox(height: 10),
              TextFormField(
                controller: _immatCtrl,
                decoration: InputDecoration(labelText: context.l10n.immatriculation),
              ),
            ] else ...[
              DropdownButtonFormField<Vehicule>(
                value: _vehiculeExistant,
                decoration: InputDecoration(
                  labelText: context.l10n.selectionnerLeVehicule),
                items: vehicules.map((v) => DropdownMenuItem<Vehicule>(
                  value: v,
                  child: Text(v.displayName),
                )).toList(),
                onChanged: (v) => setState(() => _vehiculeExistant = v),
                validator: (v) => v == null ? 'Requis' : null,
              ),
            ],

            SizedBox(height: 20),
            const Divider(),

            // ── Vendeur ────────────────────────────────────────────────
            Text(context.l10n.informationsVendeur, style: AppTextStyles.heading2),
            SizedBox(height: 10),

            TextFormField(
              controller: _vendeurNomCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.nomDuVendeur,
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: _vendeurTelCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: context.l10n.telephoneObligatoire,
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: _vendeurEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.l10n.emailOptionnel,
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),

            SizedBox(height: 20),
            const Divider(),

            // ── Prix ───────────────────────────────────────────────────
            Text(context.l10n.negociation, style: AppTextStyles.heading2),
            SizedBox(height: 10),

            Row(children: [
              Expanded(child: TextFormField(
                controller: _prixProposeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.prixDemande, suffixText: 'DA'),
                onChanged: (_) => setState(() {}),
              )),
              SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _prixAccordeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.prixAccorde, suffixText: 'DA'),
                onChanged: (_) => setState(() {}),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              )),
            ]),

            if (_prixProposeCtrl.text.isNotEmpty &&
                _prixAccordeCtrl.text.isNotEmpty) ...[
              SizedBox(height: 10),
              Builder(builder: (_) {
                final propose = double.tryParse(_prixProposeCtrl.text) ?? 0;
                final accorde = double.tryParse(_prixAccordeCtrl.text) ?? 0;
                final eco = propose - accorde;
                if (eco <= 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.l10n.economieNegociee, style: AppTextStyles.bodySecondary),
                      Text('${eco.toInt()} DA',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                            fontSize: 14,
                          )),
                    ],
                  ),
                );
              }),
            ],

            SizedBox(height: 10),

            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateAchat,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dateAchat = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.l10n.dateDAchat,
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.chevron_right),
                ),
                child: Text(
                  '${_dateAchat.day.toString().padLeft(2, '0')}/'
                  '${_dateAchat.month.toString().padLeft(2, '0')}/'
                  '${_dateAchat.year}',
                ),
              ),
            ),

            SizedBox(height: 10),
            TextFormField(
              controller: _remarquesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.remarquesObservations,
                alignLabelWithHint: true,
              ),
            ),

            SizedBox(height: 24),
            _buildCheckboxPdf(),
            SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.shopping_cart),
                label: Text(_loading
                    ? 'Enregistrement...'
                    : 'Enregistrer l\'achat'),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      String vehiculeId;
      String vehiculeMarque;
      String vehiculeModele;

      final showroomId = ref.read(currentShowroomIdProvider);

      if (_creerVehicule) {
        vehiculeMarque = _marqueCtrl.text.trim();
        vehiculeModele = _modeleCtrl.text.trim();

        final vRes = await ref.read(supabaseClientProvider)
            .from('vehicules')
            .insert({
              'marque':          vehiculeMarque,
              'modele':          vehiculeModele,
              'annee':           int.tryParse(_anneeCtrl.text) ?? DateTime.now().year,
              'kilometrage':     int.tryParse(_kmCtrl.text) ?? 0,
              'immatriculation': _immatCtrl.text.trim().isEmpty
                                   ? null : _immatCtrl.text.trim(),
              'statut':          'disponible',
              'photos':          [],
              'showroom_id':     showroomId,               // ✅ multi-tenant
            })
            .select()
            .single();
        vehiculeId = vRes['id'];
      } else {
        vehiculeId     = _vehiculeExistant!.id;
        vehiculeMarque = _vehiculeExistant!.marque;
        vehiculeModele = _vehiculeExistant!.modele;
      }

      final achat = await ref.read(achatsRepositoryProvider).createAchat(
        vehiculeId:       vehiculeId,
        vendeurNom:       _vendeurNomCtrl.text.trim(),
        vendeurTelephone: _vendeurTelCtrl.text.trim(),
        vendeurEmail:     _vendeurEmailCtrl.text.trim().isEmpty
                            ? null : _vendeurEmailCtrl.text.trim(),
        prixPropose:      double.tryParse(_prixProposeCtrl.text) ?? 0,
        prixAccorde:      double.tryParse(_prixAccordeCtrl.text) ?? 0,
        dateAchat:        _dateAchat,
        remarques:        _remarquesCtrl.text.trim().isEmpty
                            ? null : _remarquesCtrl.text.trim(),
        achetePar:        ref.read(supabaseClientProvider).auth.currentUser?.id ?? '',
      );

      ref.invalidate(achatsProvider);
      ref.invalidate(vehiculesProvider);

      // ── Génération PDF via ContratOrchestrator ─────────────────────
      String? pdfError;
      if (_genererPdf && achat != null && mounted) {
        final achatData = <String, dynamic>{
          'id':              achat.id,
          'vendeur_nom':     achat.vendeurNom,
          'vendeur_tel':     achat.vendeurTelephone,
          'vehicule_marque': vehiculeMarque,
          'vehicule_modele': vehiculeModele,
          'vehicule_annee':  int.tryParse(_anneeCtrl.text),
          'vehicule_immat':  _immatCtrl.text.trim().isEmpty
                               ? null : _immatCtrl.text.trim(),
          'vehicule_km':     int.tryParse(_kmCtrl.text),
          'prix_achat':      achat.prixAccorde,
          'date_achat':      achat.dateAchat.toIso8601String(),
          'notes':           achat.remarques,
        };
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
        // L'achat est déjà enregistré à ce stade : une erreur de génération
        // PDF ne doit donc pas être confondue avec un échec de l'achat.
        try {
          final orchestrator = ContratOrchestrator(
            () => _fetchSettings(ref),
            supabase:   ref.read(supabaseClientProvider),
            showroomId: ref.read(currentShowroomIdProvider) ?? '',
          );
          AppLogger.d('Génération PDF achat avec data: $achatData');
          await orchestrator.generateAndShareAchat(achatData: achatData);
        } catch (e) {
          pdfError = e.toString();
        }
      }

      if (mounted) {
        context.pop();
        if (pdfError != null) {
          NotificationService().error(
            "Achat enregistré, mais la génération du contrat PDF a échoué : $pdfError",
          );
        } else {
          NotificationService().success(context.l10n.achatEnregistreAvecSucces);
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
        secondary:
            Icon(Icons.picture_as_pdf, color: AppColors.primary),
        contentPadding: EdgeInsets.zero,
        dense: true,
      );
}