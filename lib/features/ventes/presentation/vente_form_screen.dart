import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Core
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/pdf/contrat_orchestrator.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/car_damage_map.dart';
import '../../../shared/services/notification_service.dart';

// Features
import '../../auth/presentation/auth_provider.dart'; // ✅ pour currentShowroomIdProvider
import '../../clients/domain/client_model.dart';
import '../../clients/presentation/clients_provider.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/domain/etat_carrosserie_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import '../../admin/domain/showroom_settings_model.dart';
import '../../admin/presentation/showroom_settings_provider.dart';
import '../domain/vente_model.dart';
import 'ventes_provider.dart'; // ✅ pour ventesRepositoryProvider
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class VenteFormScreen extends ConsumerStatefulWidget {
  final String? vehiculeId;
  const VenteFormScreen({super.key, this.vehiculeId});
  @override
  ConsumerState<VenteFormScreen> createState() => _State();
}

class _State extends ConsumerState<VenteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  Vehicule? _vehicule;
  Client?   _client;
  bool _loading    = false;
  bool _genererPdf = true;
  String _modePaiement = 'especes';

  final _prixCtrl    = TextEditingController();
  final _acompteCtrl = TextEditingController(text: '0');
  final _comCtrl     = TextEditingController();
  final _notesCtrl   = TextEditingController();

  CommissionType _comType = CommissionType.pct;
  bool _settingsLoaded = false;
  EtatCarrosserie _etatCarrosserie = const EtatCarrosserie();

  double get _prix    => double.tryParse(_prixCtrl.text) ?? 0;
  double get _acompte => double.tryParse(_acompteCtrl.text) ?? 0;
  double get _comVal  => double.tryParse(_comCtrl.text) ?? 0;
  // ✅ _comMnt et _solde sont utilisés dans l'UI (récap financier) — on les garde
  double get _comMnt  => _comType == CommissionType.pct ? _prix * _comVal / 100 : _comVal;
  double get _solde   => (_prix - _acompte).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      // Pré-sélectionner le véhicule si passé en paramètre
      if (widget.vehiculeId != null) {
        final all = ref.read(vehiculesProvider).valueOrNull ?? [];
        final veh = all.cast<Vehicule?>().firstWhere(
          (v) => v?.id == widget.vehiculeId,
          orElse: () => null,
        );
        if (veh != null) setState(() => _vehicule = veh);
      }
    });
  }

  void _loadSettings() {
    if (_settingsLoaded) return;
    ref.read(showroomSettingsTypedProvider).whenData((s) {
      if (!mounted) return;
      setState(() {
        _comType = s.commissionVente.type;
        _comCtrl.text = s.commissionVente.valeur.toStringAsFixed(
            s.commissionVente.valeur == s.commissionVente.valeur.truncate() ? 0 : 2);
        _settingsLoaded = true;
      });
    });
  }

  // ✅ _getSettings retourne tous les champs attendus par l'orchestrateur PDF
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
  void dispose() {
    _prixCtrl.dispose();
    _acompteCtrl.dispose();
    _comCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicules = ref.watch(vehiculesProvider).valueOrNull
        ?.where((v) => v.statut == VehiculeStatut.disponible).toList() ?? [];
    final clients = ref.watch(clientsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.nouveauBonDeVente, showHomeButton: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Véhicule ──────────────────────────────────────────────────
            Text(context.l10n.vehicule, style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            DropdownButtonFormField<Vehicule>(
              value: _vehicule != null && vehicules.contains(_vehicule)
                  ? _vehicule : null,
              decoration: InputDecoration(labelText: context.l10n.selectionnerLeVehicule),
              hint: Text(context.l10n.choisirUnVehicule),
              items: vehicules.map((v) => DropdownMenuItem<Vehicule>(
                value: v,
                child: Text(
                  '${v.displayName}'
                  '${v.prixVente != null ? ' — ${v.prixVente!.toInt()} DA' : ''}',
                ),
              )).toList(),
              onChanged: (v) => setState(() => _vehicule = v),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            // ── Client ────────────────────────────────────────────────────
            Text(context.l10n.sectionClient, style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            DropdownButtonFormField<Client>(
              value: _client,
              decoration: InputDecoration(labelText: context.l10n.selectionnerLeClient),
              items: clients.map((c) => DropdownMenuItem<Client>(
                value: c,
                child: Row(children: [
                  Text(c.fullName),
                  if (c.statut == ClientStatut.blacklist) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.block, color: AppColors.retard, size: 14),
                  ],
                ]),
              )).toList(),
              onChanged: (c) => setState(() => _client = c),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            // ── Prix & paiement ───────────────────────────────────────────
            Text(context.l10n.prixPaiement, style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _prixCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.l10n.prixDeVente, suffixText: 'DA'),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  if ((double.tryParse(v) ?? 0) <= 0) return 'Invalide';
                  return null;
                },
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _acompteCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.l10n.acompte, suffixText: 'DA'),
                onChanged: (_) => setState(() {}),
              )),
            ]),
            const SizedBox(height: 10),

            // Mode de paiement
            DropdownButtonFormField<String>(
              value: _modePaiement,
              decoration: InputDecoration(labelText: context.l10n.modeDePaiement),
              items: [
                DropdownMenuItem(value: 'especes',  child: Text(context.l10n.modeEspeces)),
                DropdownMenuItem(value: 'virement', child: Text(context.l10n.modeVirement)),
                DropdownMenuItem(value: 'cheque',   child: Text(context.l10n.modeCheque)),
                DropdownMenuItem(value: 'mixte',    child: Text(context.l10n.modeMixte)),
              ],
              onChanged: (v) => setState(() => _modePaiement = v ?? 'especes'),
            ),
            const SizedBox(height: 16),

            // ── Commission gérant ─────────────────────────────────────────
            Text(context.l10n.commissionGerant, style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            TextFormField(
              controller: _comCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _comType == CommissionType.pct
                    ? 'Commission (%)'
                    : 'Commission (DA fixe)',
                suffixText: _comType == CommissionType.pct ? '%' : 'DA',
                helperText: _prix > 0
                    ? 'Montant : ${_comMnt.toStringAsFixed(0)} DA'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // ── État carrosserie ──────────────────────────────────────────
            VehicleInspectorCard(
              title: context.l10n.etatCarrosserie,
              etat: _etatCarrosserie,
              onChanged: (updated) => setState(() => _etatCarrosserie = updated),
            ),
            const SizedBox(height: 16),

            // ── Notes ─────────────────────────────────────────────────────
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(labelText: context.l10n.notesOptionnel),
            ),
            const SizedBox(height: 16),

            // ── Récap financier ───────────────────────────────────────────
            if (_prix > 0) _buildRecap(),
            const SizedBox(height: 16),

            // ── Checkbox PDF ──────────────────────────────────────────────
            CheckboxListTile(
              value: _genererPdf,
              onChanged: (v) => setState(() => _genererPdf = v ?? true),
              title: Text(context.l10n.genererEtPartagerLeContratPdf),
              secondary: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 8),

            // ── Bouton soumettre ──────────────────────────────────────────
            _buildSubmitButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRecap() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
    ),
    child: Column(children: [
      _recapRow('Prix de vente', '${_prix.toInt()} DA'),
      _recapRow('Acompte versé', '${_acompte.toInt()} DA'),
      _recapRow('Reste à payer', '${_solde.toInt()} DA'),
      const Divider(height: 12),
      _recapRow(
        _comType == CommissionType.pct
            ? 'Commission gérant (${_comVal.toInt()}%)'
            : 'Commission gérant (fixe)',
        '${_comMnt.toInt()} DA',
        color: AppColors.gerant,
      ),
    ]),
  );

  Widget _recapRow(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: color ?? AppColors.textPrimary,
        )),
      ],
    ),
  );

  Widget _buildSubmitButton() => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton.icon(
      onPressed: _loading ? null : _submit,
      icon: _loading
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.sell),
      label: Text(_loading ? 'Enregistrement...' : 'Valider la vente'),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vehicule == null || _client == null) return;
    setState(() => _loading = true);

    try {
      // ✅ Passe par VentesRepository (injecte showroom_id, retire les champs fantômes)
      final repo       = ref.read(ventesRepositoryProvider);
      final showroomId = ref.read(currentShowroomIdProvider);

      final vente = await repo.create({
        'vehicule_id':           _vehicule!.id,
        'client_id':             _client!.id,
        'prix_vente':            _prix,
        'mode_paiement':         _modePaiement,
        'commission_gerant_pct': _comVal,
        'statut_paiement':       _acompte >= _prix ? 'complet' : 'partiel',
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        // ✅ etat_carrosserie : encoder en JSON string (colonne jsonb côté Supabase)
        'etat_carrosserie': _etatCarrosserie.hasAnyDamage
            ? _etatCarrosserie.toJsonString()
            : null,
      });

      if (vente == null) throw Exception('Erreur lors de la création de la vente');  // l10n_key: erreurLorsDeLaCreationDe;

      // ✅ Enregistrer l'acompte comme premier paiement si > 0
      if (_acompte > 0) {
        await repo.addPaiement(VentePaiement(
          id:           '',
          venteId:      vente.id,
          montant:      _acompte,
          datePaiement: DateTime.now(),
          mode:         _modePaiement,
          notes:        'Acompte à la signature',
        ));
      }

      // ✅ Mettre à jour le statut du véhicule avec verrou showroom_id
      await ref.read(supabaseClientProvider)
          .from('vehicules')
          .update({'statut': 'vendu'})
          .eq('showroom_id', showroomId ?? '')
          .eq('id', _vehicule!.id);

      ref.invalidate(vehiculesProvider);
      ref.invalidate(ventesListProvider);
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
      // ── Génération PDF via ContratOrchestrator ──────────────────────
      // La vente est déjà enregistrée à ce stade : une erreur de génération
      // PDF ne doit donc pas être confondue avec un échec de la vente.
      String? pdfError;
      if (_genererPdf && mounted) {
        try {
          final orchestrator = ContratOrchestrator(
            () => _fetchSettings(ref),
            supabase:   ref.read(supabaseClientProvider),
            showroomId: ref.read(currentShowroomIdProvider) ?? '',
          );
          await orchestrator.generateAndShareVente(
            vente:    vente,
            client:   _client!,
            vehicule: _vehicule!,
          );
        } catch (e) {
          pdfError = e.toString();
        }
      }

      if (mounted) {
        context.pop();
        if (pdfError != null) {
          NotificationService().error(
            'Vente enregistrée, mais la génération du contrat PDF a échoué : $pdfError',
          );
        } else {
          NotificationService().success(context.l10n.venteEnregistreeAvecSucces);
        }
      }
    } catch (e) {
      if (mounted) NotificationService().error('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}