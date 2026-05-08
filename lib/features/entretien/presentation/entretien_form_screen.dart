import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import 'entretien_provider.dart';

class EntretienFormScreen extends ConsumerStatefulWidget {
  const EntretienFormScreen({super.key});
  @override
  ConsumerState<EntretienFormScreen> createState() => _State();
}

class _State extends ConsumerState<EntretienFormScreen> {
  final _formKey = GlobalKey<FormState>();
  Vehicule? _vehicule;
  String _type = 'vidange';
  DateTime? _dateEcheance;
  bool _loading = false;
  final _kmCtrl   = TextEditingController();
  final _descCtrl = TextEditingController();

  final List<String> _types  =
    ['vidange','controle_technique','assurance','vignette','pneus','autre'];
  final List<String> _labels =
    ['Vidange','Controle technique','Assurance','Vignette','Pneus','Autre'];

  @override
  Widget build(BuildContext context) {
    final vehicules = ref.watch(vehiculesProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text("Nouvelle alerte d'entretien")),
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
              decoration: const InputDecoration(
                labelText: "Type d'entretien"),
              items: List.generate(_types.length, (i) => DropdownMenuItem(
                value: _types[i], child: Text(_labels[i]))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_dateEcheance == null
                ? 'Date d\'echeance (optionnel)'
                : 'Echeance : '
                  '${_dateEcheance!.day.toString().padLeft(2, "0")}/'
                  '${_dateEcheance!.month.toString().padLeft(2, "0")}/'
                  '${_dateEcheance!.year}'),
              trailing: const Icon(Icons.calendar_today,
                color: AppColors.primary),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate:
                    DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now()
                    .add(const Duration(days: 365 * 3)),
                );
                if (d != null) setState(() => _dateEcheance = d);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kmCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kilometrage echeance (optionnel)',
                suffixText: 'km'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Note (optionnel)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: const Icon(Icons.add_alert_outlined),
                label: Text(_loading
                  ? 'Enregistrement...' : "Creer l'alerte"),
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
      await ref.read(entretienRepositoryProvider).create({
        'vehicule_id':   _vehicule!.id,
        'type_alerte':   _type,
        'date_echeance': _dateEcheance != null
          ? _dateEcheance!.toIso8601String().substring(0, 10) : null,
        'km_echeance':   int.tryParse(_kmCtrl.text),
        'description':   _descCtrl.text.trim().isEmpty
          ? null : _descCtrl.text.trim(),
        'statut': 'active',
      });
      ref.invalidate(alertesEntretienProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alerte creee')));
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
