import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../main.dart';
import '../../clients/domain/client_model.dart';
import '../../clients/presentation/clients_provider.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';

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
  bool _loading = false;
  String _modePaiement = 'especes';
  final _prixCtrl    = TextEditingController();
  final _acompteCtrl = TextEditingController(text: '0');
  final _comCtrl     = TextEditingController(text: '5');
  final _notesCtrl   = TextEditingController();

  double get _prix    => double.tryParse(_prixCtrl.text) ?? 0;
  double get _acompte => double.tryParse(_acompteCtrl.text) ?? 0;
  double get _com     => double.tryParse(_comCtrl.text) ?? 5;
  double get _comMnt  => _prix * _com / 100;
  double get _solde   => _prix - _acompte;

  @override
  Widget build(BuildContext context) {
    final vehicules = ref.watch(vehiculesProvider).valueOrNull
      ?.where((v) => v.statut == VehiculeStatut.disponible).toList() ?? [];
    final clients = ref.watch(clientsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Nouveau bon de vente',
        showBackButton: true,
        showHomeButton: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Vehicule', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            DropdownButtonFormField<Vehicule>(
              initialValue: _vehicule,
              decoration: const InputDecoration(
                labelText: 'Selectionner le vehicule'),
              items: vehicules.map((v) => DropdownMenuItem(
                value: v,
                child: Text('${v.displayName}'
                  '${v.prixVente != null
                    ? " - ${v.prixVente!.toInt()} DA" : ""}'),
              )).toList(),
              onChanged: (v) {
                setState(() {
                  _vehicule = v;
                  if (v?.prixVente != null) {
                    _prixCtrl.text = v!.prixVente!.toInt().toString();
                  }
                });
              },
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            Text('Client', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            DropdownButtonFormField<Client>(
              initialValue: _client,
              decoration: const InputDecoration(
                labelText: 'Selectionner le client'),
              items: clients.map((c) => DropdownMenuItem(
                value: c, child: Text(c.fullName))).toList(),
              onChanged: (c) => setState(() => _client = c),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            Text('Details financiers', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            TextFormField(
              controller: _prixCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Prix de vente', suffixText: 'DA'),
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                (v == null || v.isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _acompteCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Acompte', suffixText: 'DA'),
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
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _modePaiement,
              decoration: const InputDecoration(
                labelText: 'Mode de paiement'),
              items: const [
                DropdownMenuItem(value: 'especes',
                  child: Text('Especes')),
                DropdownMenuItem(value: 'virement',
                  child: Text('Virement')),
                DropdownMenuItem(value: 'cheque',
                  child: Text('Cheque')),
                DropdownMenuItem(value: 'mixte',
                  child: Text('Mixte')),
              ],
              onChanged: (v) =>
                setState(() => _modePaiement = v!),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optionnel)'),
            ),
            const SizedBox(height: 20),

            // Recap
            if (_prix > 0) Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2))),
              child: Column(children: [
                _r('Prix de vente', '${_prix.toInt()} DA',
                  bold: true),
                _r('Commission Gérant (${_com.toInt()}%)',
                  '${_comMnt.toInt()} DA',
                  color: AppColors.gerant),
                _r('Part Propriétaire',
                  '${(_prix - _comMnt).toInt()} DA',
                  color: AppColors.proprietaireShowroom),
                const Divider(height: 14),
                _r('Acompte recu', '${_acompte.toInt()} DA'),
                _r('Solde restant', '${_solde.toInt()} DA',
                  bold: true,
                  color: _solde > 0
                    ? AppColors.accent : AppColors.secondary),
              ]),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sell),
                label: Text(_loading
                  ? 'Enregistrement...' : 'Valider la vente'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _r(String k, String v,
    {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: bold
          ? AppTextStyles.heading3
          : AppTextStyles.bodySecondary),
        Text(v, style: TextStyle(
          fontSize: bold ? 15 : 13,
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.textPrimary)),
      ],
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await supabase.from('ventes').insert({
        'vehicule_id':          _vehicule!.id,
        'client_id':            _client!.id,
        'prix_catalogue':       _vehicule!.prixVente,
        'prix_vente':           _prix,
        'acompte':              _acompte,
        'solde_restant':        _solde,
        'mode_paiement':        _modePaiement,
        'commission_gerant_pct': _com,
        'commission_gerant_mnt': _comMnt,
        'statut_paiement':      _acompte >= _prix
                                  ? 'complet' : 'partiel',
        'notes':                _notesCtrl.text.trim().isEmpty
                                  ? null : _notesCtrl.text.trim(),
        'created_by':           supabase.auth.currentUser?.id,
      });
      // Véhicule -> vendu (géré par trigger Supabase)
      ref.invalidate(vehiculesProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vente enregistree avec succes'),
            backgroundColor: AppColors.secondary));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'),
          backgroundColor: AppColors.retard));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
