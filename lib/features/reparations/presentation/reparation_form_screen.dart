import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../main.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import 'reparations_provider.dart';

class ReparationFormScreen extends ConsumerStatefulWidget {
  const ReparationFormScreen({super.key});
  @override
  ConsumerState<ReparationFormScreen> createState() => _State();
}

class _State extends ConsumerState<ReparationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  Vehicule? _vehicule;
  String _type = 'mecanique';
  bool _changerStatut = false;
  bool _deductible    = true;
  bool _loading       = false;
  final _descCtrl        = TextEditingController();
  final _prestataireCtrl = TextEditingController();
  final _coutCtrl        = TextEditingController();
  final _kmCtrl          = TextEditingController();

  final List<String> _types =
    ['mecanique','carrosserie','electrique','pneus','autre'];
  final List<String> _typesLabels =
    ['Mecanique','Carrosserie','Electrique','Pneus','Autre'];

  @override
  Widget build(BuildContext context) {
    final vehicules = ref.watch(vehiculesProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle reparation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<Vehicule>(
              initialValue: _vehicule,
              decoration: const InputDecoration(labelText: 'Vehicule'),
              items: vehicules.map((v) => DropdownMenuItem(
                value: v, child: Text(v.displayName))).toList(),
              onChanged: (v) => setState(() => _vehicule = v),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: List.generate(_types.length, (i) => DropdownMenuItem(
                value: _types[i], child: Text(_typesLabels[i]))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (v) =>
                (v == null || v.isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _prestataireCtrl,
                decoration: const InputDecoration(labelText: 'Prestataire'),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _kmCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Km au moment', suffixText: 'km'),
              )),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _coutCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cout total', suffixText: 'DA'),
              validator: (v) =>
                (v == null || v.isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _deductible,
              onChanged: (v) => setState(() => _deductible = v),
              title: const Text('Deduire du profit avant repartition'),
              subtitle: Text('Sera deduit des revenus du vehicule',
                style: AppTextStyles.label),
            ),
            SwitchListTile(
              value: _changerStatut,
              onChanged: (v) => setState(() => _changerStatut = v),
              title: const Text('Passer le vehicule en Reparation'),
              subtitle: Text(
                'Indisponible a la location pendant les travaux',
                style: AppTextStyles.label),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.reparation),
                onPressed: _loading ? null : _submit,
                icon: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
                label: Text(_loading
                  ? 'Enregistrement...' : 'Enregistrer la reparation'),
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
      await ref.read(reparationsRepositoryProvider).create({
        'vehicule_id':    _vehicule!.id,
        'type_rep':       _type,
        'description':    _descCtrl.text.trim(),
        'prestataire':    _prestataireCtrl.text.trim().isEmpty
                           ? null : _prestataireCtrl.text.trim(),
        'cout':           double.parse(_coutCtrl.text),
        'km_au_moment':   int.tryParse(_kmCtrl.text),
        'deductible':     _deductible,
        'date_rep':       DateTime.now().toIso8601String().substring(0, 10),
        'statut_vehicule': _changerStatut,
        'created_by':     supabase.auth.currentUser?.id,
      });
      ref.invalidate(reparationsProvider);
      ref.invalidate(vehiculesProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reparation enregistree')));
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