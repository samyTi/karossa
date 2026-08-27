//lib/features/clients/presentation/client_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'clients_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class ClientFormScreen extends ConsumerStatefulWidget {
  final String? clientId;
  const ClientFormScreen({super.key, this.clientId});
  @override
  ConsumerState<ClientFormScreen> createState() => _State();
}

class _State extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading  = false;
  // true tant que la fiche client existante n'a pas été chargée dans les
  // champs. En mode "nouveau client" (clientId == null), il n'y a rien à
  // charger, donc on démarre directement à false.
  bool _fetching = false;

  final _nomCtrl    = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _telCtrl    = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _adresseCtrl= TextEditingController();
  final _permisCtrl = TextEditingController();
  final _permisDateCtrl = TextEditingController();
  final _dateNaissanceCtrl = TextEditingController();
  final _cniCtrl    = TextEditingController();
  final _notesCtrl  = TextEditingController();
  String _statut = 'normal';

  @override
  void dispose() {
    // Aucun des contrôleurs n'était disposé jusqu'ici (fuite mémoire à
    // chaque ouverture/fermeture de cet écran) — corrigé au passage.
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    _adresseCtrl.dispose();
    _permisCtrl.dispose();
    _permisDateCtrl.dispose();
    _dateNaissanceCtrl.dispose();
    _cniCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final id = widget.clientId;
    if (id != null) {
      // Bug corrigé : l'écran "Modifier client" réutilisait ce formulaire
      // sans jamais charger la fiche existante → tous les champs
      // s'affichaient vides à l'ouverture.
      _fetching = true;
      _loadExistingClient(id);
    }
  }

  Future<void> _loadExistingClient(String id) async {
    try {
      final client = await ref.read(clientsRepositoryProvider).getById(id);
      if (client == null || !mounted) return;
      _nomCtrl.text = client.nom;
      _prenomCtrl.text = client.prenom;
      _telCtrl.text = client.telephone;
      _emailCtrl.text = client.email ?? '';
      _adresseCtrl.text = client.adresse ?? '';
      _permisCtrl.text = client.numPermis ?? '';
      _permisDateCtrl.text = client.permisDate ?? '';
      _dateNaissanceCtrl.text = client.dateNaissance ?? '';
      _cniCtrl.text = client.numCni ?? '';
      _notesCtrl.text = client.noteInterne ?? '';
      setState(() => _statut = client.statut.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.erreurAvecDetail(e.toString())),
            backgroundColor: AppColors.retard));
      }
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clientId == null
          ? 'Nouveau client' : 'Modifier client')),
      body: _fetching
        ? const Center(child: CircularProgressIndicator())
        : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(context.l10n.identite, style: AppTextStyles.heading3),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _prenomCtrl,
                decoration: InputDecoration(labelText: context.l10n.champPrenom),
                validator: (v) =>
                  (v == null || v.isEmpty) ? 'Requis' : null,
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _nomCtrl,
                decoration: InputDecoration(labelText: context.l10n.champNom),
                validator: (v) =>
                  (v == null || v.isEmpty) ? 'Requis' : null,
              )),
            ]),
            const SizedBox(height: 10),
            TextFormField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: context.l10n.champTelephone),
              validator: (v) =>
                (v == null || v.isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.l10n.emailOptionnel),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _adresseCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.adresseOptionnel),
            ),
            const SizedBox(height: 10),
            // Date de naissance — affichée sur le contrat de location
            TextFormField(
              controller: _dateNaissanceCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Date de naissance',
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(now.year - 25),
                  firstDate: DateTime(1930),
                  lastDate: now,
                );
                if (picked != null) {
                  _dateNaissanceCtrl.text =
                      '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                }
              },
            ),
            const SizedBox(height: 20),

            Text(context.l10n.documents, style: AppTextStyles.heading3),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _permisCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.nPermis),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _cniCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.nCni),
              )),
            ]),
            const SizedBox(height: 10),
            // Date de délivrance du permis — affichée sur le contrat de location
            TextFormField(
              controller: _permisDateCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Date de délivrance du permis',
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: DateTime(1950),
                  lastDate: now,
                );
                if (picked != null) {
                  _permisDateCtrl.text =
                      '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                }
              },
            ),
            const SizedBox(height: 20),

            Text(context.l10n.statutClient, style: AppTextStyles.heading3),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _statut,
              decoration: InputDecoration(labelText: context.l10n.champStatut),
              items: [
                DropdownMenuItem(value: 'normal',
                  child: Text(context.l10n.clientNormal)),
                DropdownMenuItem(value: 'fiable',
                  child: Text(context.l10n.clientFiable)),
                DropdownMenuItem(value: 'risque',
                  child: Text(context.l10n.aRisque)),
                DropdownMenuItem(value: 'blacklist',
                  child: Text(context.l10n.listeNoire)),
              ],
              onChanged: (v) => setState(() => _statut = v!),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.notesInternesOptionnel),
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
      final data = {
        'nom':         _nomCtrl.text.trim(),
        'prenom':      _prenomCtrl.text.trim(),
        'telephone':   _telCtrl.text.trim(),
        'email':       _emailCtrl.text.trim().isEmpty
                         ? null : _emailCtrl.text.trim(),
        'adresse':     _adresseCtrl.text.trim().isEmpty
                         ? null : _adresseCtrl.text.trim(),
        'num_permis':  _permisCtrl.text.trim().isEmpty
                         ? null : _permisCtrl.text.trim(),
        'permis_date': _permisDateCtrl.text.trim().isEmpty
                         ? null : _permisDateCtrl.text.trim(),
        'date_naissance': _dateNaissanceCtrl.text.trim().isEmpty
                         ? null : _dateNaissanceCtrl.text.trim(),
        'num_cni':     _cniCtrl.text.trim().isEmpty
                         ? null : _cniCtrl.text.trim(),
        'statut':      _statut,
        'note_interne':_notesCtrl.text.trim().isEmpty
                         ? null : _notesCtrl.text.trim(),
      };

      final id = widget.clientId;
      if (id == null) {
        // Création
        await ref.read(clientsRepositoryProvider).create({
          ...data,
          'created_by': ref.read(supabaseClientProvider).auth.currentUser?.id,
        });
      } else {
        // Modification — c'était l'appel manquant : avant ce correctif,
        // même en mode édition on appelait toujours create(), ce qui aurait
        // dupliqué le client au lieu de le mettre à jour.
        await ref.read(clientsRepositoryProvider).update(id, data);
        ref.invalidate(clientDetailProvider(id));
      }
      ref.invalidate(clientsProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.clientEnregistre)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.erreurAvecDetail(e.toString())),
          backgroundColor: AppColors.retard));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}