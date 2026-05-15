import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import 'achats_provider.dart';
import '../../../core/services/contrat_generator_service.dart';
import '../../../shared/services/notification_service.dart';


class AchatFormScreen extends ConsumerStatefulWidget {
  const AchatFormScreen({super.key});

  @override
  ConsumerState<AchatFormScreen> createState() => _AchatFormScreenState();
}

class _AchatFormScreenState extends ConsumerState<AchatFormScreen> {
  final _formKey        = GlobalKey<FormState>();
  bool  _loading        = false;
  bool  _creerVehicule  = true;
  bool  _genererPdf     = true;

  Vehicule? _vehiculeExistant;

  final _vendeurNomCtrl   = TextEditingController();
  final _vendeurTelCtrl   = TextEditingController();
  final _vendeurEmailCtrl = TextEditingController();
  final _prixProposeCtrl  = TextEditingController();
  final _prixAccordeCtrl  = TextEditingController();
  final _remarquesCtrl    = TextEditingController();

  // Champs véhicule
  final _marqueCtrl  = TextEditingController();
  final _modeleCtrl  = TextEditingController();
  final _anneeCtrl   = TextEditingController();
  final _kmCtrl      = TextEditingController();
  final _immatCtrl   = TextEditingController();
  DateTime _dateAchat = DateTime.now();

  @override
  void dispose() {
    for (final c in [
      _vendeurNomCtrl, _vendeurTelCtrl, _vendeurEmailCtrl,
      _prixProposeCtrl, _prixAccordeCtrl, _remarquesCtrl,
      _marqueCtrl, _modeleCtrl, _anneeCtrl, _kmCtrl, _immatCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicules = ref.watch(vehiculesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Nouvel achat / reprise',
        showHomeButton: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Véhicule ───────────────────────────────────────────────
            Text('Véhicule', style: AppTextStyles.heading2),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Nouveau véhicule'),
                  selected: _creerVehicule,
                  onSelected: (_) => setState(() {
                    _creerVehicule = true;
                    _vehiculeExistant = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Véhicule existant'),
                  selected: !_creerVehicule,
                  onSelected: (_) => setState(() => _creerVehicule = false),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            if (_creerVehicule) ...[
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _marqueCtrl,
                  decoration: const InputDecoration(labelText: 'Marque *'),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                )),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(
                  controller: _modeleCtrl,
                  decoration: const InputDecoration(labelText: 'Modèle *'),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _anneeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Année'),
                )),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(
                  controller: _kmCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Kilométrage', suffixText: 'km'),
                )),
              ]),
              const SizedBox(height: 10),
              TextFormField(
                controller: _immatCtrl,
                decoration: const InputDecoration(labelText: 'Immatriculation'),
              ),
            ] else ...[
              DropdownButtonFormField<Vehicule>(
                initialValue: _vehiculeExistant,
                decoration: const InputDecoration(labelText: 'Sélectionner le véhicule'),
                items: vehicules.map((v) => DropdownMenuItem<Vehicule>(
                  value: v,
                  child: Text(v.displayName),
                )).toList(),
                onChanged: (v) => setState(() => _vehiculeExistant = v),
                validator: (v) => v == null ? 'Requis' : null,
              ),
            ],

            const SizedBox(height: 20),
            const Divider(),

            // ── Vendeur ────────────────────────────────────────────────
            Text('Informations vendeur', style: AppTextStyles.heading2),
            const SizedBox(height: 10),

            TextFormField(
              controller: _vendeurNomCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom du vendeur *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _vendeurTelCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone *',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _vendeurEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optionnel)',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),

            // ── Prix ───────────────────────────────────────────────────
            Text('Négociation', style: AppTextStyles.heading2),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(child: TextFormField(
                controller: _prixProposeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Prix demandé', suffixText: 'DA'),
                onChanged: (_) => setState(() {}),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _prixAccordeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Prix accordé *', suffixText: 'DA'),
                onChanged: (_) => setState(() {}),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              )),
            ]),

            // Économie réalisée
            if (_prixProposeCtrl.text.isNotEmpty && _prixAccordeCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 10),
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
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Économie négociée', style: AppTextStyles.bodySecondary),
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

            const SizedBox(height: 10),

            // Date achat
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
                decoration: const InputDecoration(
                  labelText: 'Date d\'achat',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.chevron_right),
                ),
                child: Text(
                  '${_dateAchat.day.toString().padLeft(2,'0')}/'
                  '${_dateAchat.month.toString().padLeft(2,'0')}/'
                  '${_dateAchat.year}',
                ),
              ),
            ),

            const SizedBox(height: 10),
            TextFormField(
              controller: _remarquesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Remarques / observations',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 24),


            _buildCheckboxPdf(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.shopping_cart),
                label: Text(_loading ? 'Enregistrement...' : 'Enregistrer l\'achat'),
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
      String vehiculeId;
      String vehiculeMarque;
      String vehiculeModele;

      if (_creerVehicule) {
        vehiculeMarque = _marqueCtrl.text.trim();
        vehiculeModele = _modeleCtrl.text.trim();
        // Créer le véhicule dans le stock
        final vRes = await ref.read(supabaseClientProvider).from('vehicules').insert({
          'marque':         vehiculeMarque,
          'modele':         vehiculeModele,
          'annee':          int.tryParse(_anneeCtrl.text) ?? DateTime.now().year,
          'kilometrage':    int.tryParse(_kmCtrl.text) ?? 0,
          'immatriculation': _immatCtrl.text.trim().isEmpty ? null : _immatCtrl.text.trim(),
          'statut':         'disponible',
          'photos':         [],
        }).select().single();
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

      // ── Génération du contrat PDF ──────────────────────────────────
      if (_genererPdf && achat != null && mounted) {
        final achatData = <String, dynamic>{
          'id': achat.id,
          'vendeur_nom': achat.vendeurNom,
          'vendeur_tel': achat.vendeurTelephone,
          'vehicule_marque': vehiculeMarque,
          'vehicule_modele': vehiculeModele,
          'vehicule_annee': int.tryParse(_anneeCtrl.text),
          'vehicule_immat': _immatCtrl.text.trim().isEmpty ? null : _immatCtrl.text.trim(),
          'vehicule_km': int.tryParse(_kmCtrl.text),
          'prix_achat': achat.prixAccorde,
          'date_achat': achat.dateAchat.toIso8601String(),
          'notes': achat.remarques,
        };
        final pdfFile = await ContratGeneratorService.genererAchat(
          achatData: achatData,
        );
        if (pdfFile != null && mounted) {
          await ContratGeneratorService.partager(context, pdfFile);
        }
      }

      if (mounted) {
        context.pop();
        NotificationService().success('Achat enregistré avec succès');
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
