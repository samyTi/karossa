import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../clients/domain/client_model.dart';
import '../../clients/presentation/clients_provider.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import 'echanges_provider.dart';
import '../../../core/services/contrat_generator_service.dart';
import '../../../shared/services/notification_service.dart';

class EchangeFormScreen extends ConsumerStatefulWidget {
  const EchangeFormScreen({super.key});
  @override
  ConsumerState<EchangeFormScreen> createState() => _EchangeFormScreenState();
}

class _EchangeFormScreenState extends ConsumerState<EchangeFormScreen> {
  final _formKey = GlobalKey<FormState>();
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

  double get _valeur     => double.tryParse(_valeurCtrl.text) ?? 0;
  double get _complement => double.tryParse(_complementCtrl.text) ?? 0;
  double get _com        => double.tryParse(_comCtrl.text) ?? 5;
  double get _prixVente  => _vehiculeCede?.prixVente ?? 0;
  double get _comMnt     => (_prixVente + _complement) * _com / 100;

  @override
  Widget build(BuildContext context) {
    final vehicules = ref.watch(vehiculesProvider).valueOrNull
        ?.where((v) => v.statut == VehiculeStatut.disponible).toList() ?? [];
    final clients = ref.watch(clientsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Dossier echange / reprise',
        showBackButton: true,
        showHomeButton: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Vehicule cede (du magasin)', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            DropdownButtonFormField<Vehicule>(
              initialValue: _vehiculeCede,
              decoration: const InputDecoration(labelText: 'Selectionner le vehicule'),
              items: vehicules.map((v) => DropdownMenuItem(
                value: v, child: Text(v.displayName))).toList(),
              onChanged: (v) => setState(() => _vehiculeCede = v),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            Text('Client', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            DropdownButtonFormField<Client>(
              initialValue: _client,
              decoration: const InputDecoration(labelText: 'Selectionner le client'),
              items: clients.map((c) => DropdownMenuItem(
                value: c, child: Text(c.fullName))).toList(),
              onChanged: (c) => setState(() => _client = c),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            Text('Vehicule repris (du client)', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _marqueCtrl,
                decoration: const InputDecoration(labelText: 'Marque'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _modeleCtrl,
                decoration: const InputDecoration(labelText: 'Modele'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _anneeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Annee'),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _kmCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kilometrage', suffixText: 'km'),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _immatCtrl,
                decoration: const InputDecoration(labelText: 'Immatriculation'),
              )),
            ]),
            const SizedBox(height: 16),
            Text('Valeurs financieres', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _valeurCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Valeur reprise', suffixText: 'DA'),
                onChanged: (_) => setState(() {}),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _complementCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Complement client', suffixText: 'DA'),
                onChanged: (_) => setState(() {}),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _comCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Commission Bilel', suffixText: '%'),
                onChanged: (_) => setState(() {}),
              )),
            ]),
            const SizedBox(height: 12),
            if (_vehiculeCede != null) _RecapEchange(
              vehiculeCede:  _vehiculeCede!.displayName,
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
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 20),

            _buildCheckboxPdf(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.swap_horiz),
                label: Text(_loading ? 'Enregistrement...' : "Valider l'echange"),
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
        'vehicule_cede_id':        _vehiculeCede!.id,
        'client_id':               _client!.id,
        'vehicule_reprise_marque': _marqueCtrl.text.trim(),
        'vehicule_reprise_modele': _modeleCtrl.text.trim(),
        'vehicule_reprise_annee':  int.tryParse(_anneeCtrl.text),
        'vehicule_reprise_km':     int.tryParse(_kmCtrl.text),
        'vehicule_reprise_immat':  _immatCtrl.text.trim().isEmpty
                                    ? null : _immatCtrl.text.trim(),
        'valeur_reprise':          _valeur,
        'complement_client':       _complement,
        'commission_gerant_pct':   _com,
        'commission_gerant_mnt':   _comMnt,
        'date_echange':            DateTime.now().toIso8601String().substring(0, 10),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'created_by': ref.read(supabaseClientProvider).auth.currentUser?.id,
      });
      ref.invalidate(echangesProvider);
      ref.invalidate(vehiculesProvider);

      // ── Génération du contrat PDF ──────────────────────────────────
      if (_genererPdf && mounted) {
        final pdfFile = await ContratGeneratorService.genererEchange(
          echange:      echange,
          client:       _client!,
          vehiculeCede: _vehiculeCede!,
        );
        if (pdfFile != null && mounted) {
          await ContratGeneratorService.partager(context, pdfFile);
        }
      }

      if (mounted) {
        context.pop();
        NotificationService().success('Échange enregistré avec succès');
      }
    } catch (e) {
      if (mounted) NotificationService().error('Erreur: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildCheckboxPdf() => CheckboxListTile(
    value: _genererPdf,
    onChanged: (v) => setState(() => _genererPdf = v ?? true),
    title: const Text('Générer et partager le contrat PDF'),
    secondary: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
    contentPadding: EdgeInsets.zero,
    dense: true,
  );
}

class _RecapEchange extends StatelessWidget {
  final String vehiculeCede, vehiculeRepris;
  final double valeurReprise, complement, commissionPct, commissionMnt;
  const _RecapEchange({
    required this.vehiculeCede, required this.vehiculeRepris,
    required this.valeurReprise, required this.complement,
    required this.commissionPct, required this.commissionMnt,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
    ),
    child: Column(children: [
      _row('Vehicule cede', vehiculeCede),
      _row('Vehicule repris', vehiculeRepris),
      const Divider(height: 14),
      _row('Valeur de reprise', '${valeurReprise.toInt()} DA'),
      _row('Complement client', '${complement.toInt()} DA'),
      _row('Commission Gérant (${commissionPct.toInt()}%)',
        '${commissionMnt.toInt()} DA', color: AppColors.gerant),
    ]),
  );

  Widget _row(String k, String v, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: const TextStyle(
        fontSize: 13, color: AppColors.textSecondary)),
      Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary)),
    ]),
  );
}