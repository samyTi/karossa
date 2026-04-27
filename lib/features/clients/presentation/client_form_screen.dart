import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../main.dart';
import 'clients_provider.dart';

class ClientFormScreen extends ConsumerStatefulWidget {
  final String? clientId;
  const ClientFormScreen({super.key, this.clientId});
  @override
  ConsumerState<ClientFormScreen> createState() => _State();
}

class _State extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading  = false;

  final _nomCtrl    = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _telCtrl    = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _adresseCtrl= TextEditingController();
  final _permisCtrl = TextEditingController();
  final _cniCtrl    = TextEditingController();
  final _notesCtrl  = TextEditingController();
  String _statut = 'normal';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clientId == null
          ? 'Nouveau client' : 'Modifier client')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Identite', style: AppTextStyles.heading3),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _prenomCtrl,
                decoration: const InputDecoration(labelText: 'Prenom'),
                validator: (v) =>
                  (v == null || v.isEmpty) ? 'Requis' : null,
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _nomCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) =>
                  (v == null || v.isEmpty) ? 'Requis' : null,
              )),
            ]),
            const SizedBox(height: 10),
            TextFormField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telephone'),
              validator: (v) =>
                (v == null || v.isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optionnel)'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _adresseCtrl,
              decoration: const InputDecoration(
                labelText: 'Adresse (optionnel)'),
            ),
            const SizedBox(height: 20),

            Text('Documents', style: AppTextStyles.heading3),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _permisCtrl,
                decoration: const InputDecoration(
                  labelText: 'N° Permis'),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _cniCtrl,
                decoration: const InputDecoration(
                  labelText: 'N° CNI'),
              )),
            ]),
            const SizedBox(height: 20),

            Text('Statut client', style: AppTextStyles.heading3),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _statut,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: const [
                DropdownMenuItem(value: 'normal',
                  child: Text('Normal')),
                DropdownMenuItem(value: 'fiable',
                  child: Text('Client fiable')),
                DropdownMenuItem(value: 'risque',
                  child: Text('A risque')),
                DropdownMenuItem(value: 'blacklist',
                  child: Text('Liste noire')),
              ],
              onChanged: (v) => setState(() => _statut = v!),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes internes (optionnel)'),
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
                  : const Icon(Icons.person_add),
                label: Text(_loading
                  ? 'Enregistrement...' : 'Enregistrer le client'),
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
      await ref.read(clientsRepositoryProvider).create({
        'nom':         _nomCtrl.text.trim(),
        'prenom':      _prenomCtrl.text.trim(),
        'telephone':   _telCtrl.text.trim(),
        'email':       _emailCtrl.text.trim().isEmpty
                         ? null : _emailCtrl.text.trim(),
        'adresse':     _adresseCtrl.text.trim().isEmpty
                         ? null : _adresseCtrl.text.trim(),
        'num_permis':  _permisCtrl.text.trim().isEmpty
                         ? null : _permisCtrl.text.trim(),
        'num_cni':     _cniCtrl.text.trim().isEmpty
                         ? null : _cniCtrl.text.trim(),
        'statut':      _statut,
        'note_interne':_notesCtrl.text.trim().isEmpty
                         ? null : _notesCtrl.text.trim(),
        'created_by':  supabase.auth.currentUser?.id,
      });
      ref.invalidate(clientsProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client enregistre')));
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
