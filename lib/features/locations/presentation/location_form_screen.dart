// lib/features/locations/presentation/location_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/contrat_generator_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../admin/domain/showroom_settings_model.dart';
import '../../admin/presentation/showroom_settings_provider.dart';
import '../../clients/domain/client_model.dart';
import '../../clients/presentation/clients_provider.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import 'locations_provider.dart';

// Importations de nos nouveaux widgets isolés
import '../../../shared/widgets/location_financial_recap.dart';
import '../../../shared/widgets/location_form_components.dart';
import '../../../shared/widgets/paiement_entry_row.dart';

class LocationFormScreen extends ConsumerStatefulWidget {
  final String? vehiculeId;
  const LocationFormScreen({super.key, this.vehiculeId});
  @override
  ConsumerState<LocationFormScreen> createState() => _State();
}

class _State extends ConsumerState<LocationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  Vehicule? _vehicule;
  Client?   _client;
  DateTime  _debut  = DateTime.now();
  DateTime  _fin    = DateTime.now().add(const Duration(days: 1));
  bool _loading    = false;
  bool _genererPdf = true;
  
  final _kmCtrl     = TextEditingController();
  final _cautionCtrl= TextEditingController();
  final _notesCtrl  = TextEditingController();

  bool _modeHistorique = false;
  DateTime? _dateFinReelle;
  final _kmRetourCtrl    = TextEditingController();
  final _retenueCtrl     = TextEditingController(text: '0');
  final _notesRetourCtrl = TextEditingController();
  String _statutFinal    = 'termine';

  final List<PaiementEntry> _paiements = [];

  CommissionType _comType = CommissionType.pct;
  double _comValeurConfig = 10.0;
  bool _settingsLoaded = false;

  int    get _nbJours  => _fin.difference(_debut).inDays.clamp(1, 9999);
  double get _prixJour => _vehicule?.prixLocationJour ?? 0;
  double get _total    => _prixJour * _nbJours;

  double get _gerantMnt => _comType == CommissionType.pct
      ? _total * _comValeurConfig / 100
      : _comValeurConfig * _nbJours;

  double get _proprioMnt => (_total - _gerantMnt).clamp(0, double.infinity);
  double get _totalPaiements => _paiements.fold(0.0, (s, p) => s + p.montant);
  double get _resteAPayer => (_total - (double.tryParse(_retenueCtrl.text) ?? 0) - _totalPaiements).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      if (widget.vehiculeId != null) {
        final allVehicules = ref.read(vehiculesProvider).valueOrNull ?? [];
        final veh = allVehicules.isNotEmpty
            ? allVehicules.firstWhere((v) => v.id == widget.vehiculeId, orElse: () => allVehicules.first)
            : null;
        if (veh != null) setState(() => _vehicule = veh);
      }
    });
  }

  /// Charge les settings depuis Supabase et met à jour la commission.
  /// Utilise le future directement pour attendre la valeur même si le provider
  /// n'est pas encore résolu au moment du 1er rendu.
  Future<void> _loadSettings() async {
    if (_settingsLoaded) return;
    try {
      final s = await ref.read(showroomSettingsTypedProvider.future);
      if (!mounted) return;
      setState(() {
        _comType = s.commissionLocation.type;
        _comValeurConfig = s.commissionLocation.valeur;
        _settingsLoaded = true;
      });
    } catch (_) {
      // Garde les valeurs par défaut (10%)
    }
  }

  @override
  void dispose() {
    _kmCtrl.dispose(); _cautionCtrl.dispose(); _notesCtrl.dispose();
    _kmRetourCtrl.dispose(); _retenueCtrl.dispose(); _notesRetourCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allVehicules = ref.watch(vehiculesProvider).valueOrNull ?? [];
    final vehicules = _modeHistorique
        ? allVehicules.where((v) => v.statut == VehiculeStatut.disponible || v.statut == VehiculeStatut.loue).toList()
        : allVehicules.where((v) => v.statut == VehiculeStatut.disponible).toList();
    final clients = ref.watch(clientsProvider).valueOrNull ?? [];

    final settingsLabel = _comType == CommissionType.pct ? 'Gérant (${_comValeurConfig.toInt()}%)' : 'Gérant (${_comValeurConfig.toInt()} DA/j)';

    return Scaffold(
      appBar: CustomAppBar(
        title: _modeHistorique ? 'Saisie location passée' : 'Nouveau contrat de location',
        showHomeButton: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ModeHistoriqueBanner(
              value: _modeHistorique,
              onChanged: (v) => setState(() {
                _modeHistorique = v;
                if (v) {
                  _debut = DateTime.now().subtract(const Duration(days: 7));
                  _fin   = DateTime.now().subtract(const Duration(days: 1));
                  _dateFinReelle = _fin;
                  _genererPdf = false;
                } else {
                  _debut = DateTime.now();
                  _fin   = DateTime.now().add(const Duration(days: 1));
                  _dateFinReelle = null;
                  _genererPdf = true;
                }
              }),
            ),
            const SizedBox(height: 16),

            Text('Véhicule', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            DropdownButtonFormField<Vehicule>(
              value: _vehicule != null && vehicules.contains(_vehicule!) ? _vehicule : null,
              decoration: const InputDecoration(labelText: 'Sélectionner le véhicule'),
              hint: const Text('Choisir un véhicule'),
              items: vehicules.map((v) => DropdownMenuItem<Vehicule>(value: v, child: Text('${v.displayName}${v.prixLocationJour != null ? ' - ${v.prixLocationJour!.toInt()} DA/j' : ''}'))).toList(),
              onChanged: (v) => setState(() => _vehicule = v),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            Text('Client', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            DropdownButtonFormField<Client>(
              value: _client,
              decoration: const InputDecoration(labelText: 'Sélectionner le client'),
              items: clients.map((c) => DropdownMenuItem<Client>(
                value: c,
                child: Row(children: [
                  Text(c.fullName),
                  if (c.statut == ClientStatut.blacklist) ...[const SizedBox(width: 6), const Icon(Icons.block, color: AppColors.retard, size: 14)],
                  if (c.statut == ClientStatut.risque) ...[const SizedBox(width: 6), const Icon(Icons.warning_amber, color: AppColors.accent, size: 14)],
                ]),
              )).toList(),
              onChanged: (c) {
                if (c?.statut == ClientStatut.blacklist) {
                  NotificationService().show(message: '⚠️ Ce client est en liste noire ! Soyez prudent.', type: NotificationType.warning, duration: const Duration(seconds: 5));
                }
                setState(() => _client = c);
              },
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            Text('Période', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: DateSelectionTile(
                label: 'Départ',
                date: _debut,
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _debut, firstDate: DateTime(2015), lastDate: _modeHistorique ? DateTime.now() : DateTime.now().add(const Duration(days: 365)));
                  if (d != null) {
                    setState(() {
                      _debut = d;
                      if (_fin.isBefore(_debut)) _fin = _debut.add(const Duration(days: 1));
                      if (_dateFinReelle != null && _dateFinReelle!.isBefore(_debut)) _dateFinReelle = _fin;
                    });
                  }
                },
              )),
              const SizedBox(width: 10),
              Expanded(child: DateSelectionTile(
                label: 'Retour prévu',
                date: _fin,
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _fin, firstDate: _debut.add(const Duration(days: 1)), lastDate: _modeHistorique ? DateTime.now() : DateTime.now().add(const Duration(days: 365)));
                  if (d != null) setState(() => _fin = d);
                },
              )),
            ]),
            const SizedBox(height: 16),

            Row(children: [
              Expanded(child: TextFormField(controller: _kmCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Km au départ', suffixText: 'km'), validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null)),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _cautionCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Caution', suffixText: 'DA'))),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes état du véhicule au départ (optionnel)')),

            if (_modeHistorique) ...[
              const SizedBox(height: 24),
              const FormSectionHeader(label: 'Informations de retour', icon: Icons.keyboard_return, color: AppColors.secondary),
              const SizedBox(height: 12),
              Text('Statut final', style: AppTextStyles.label),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: LocationStatutChip(label: 'Terminée', icon: Icons.check_circle_outline, selected: _statutFinal == 'termine', color: AppColors.secondary, onTap: () => setState(() => _statutFinal = 'termine'))),
                const SizedBox(width: 10),
                Expanded(child: LocationStatutChip(label: 'Annulée', icon: Icons.cancel_outlined, selected: _statutFinal == 'annule', color: AppColors.retard, onTap: () => setState(() => _statutFinal = 'annule'))),
              ]),
              const SizedBox(height: 14),
              DateSelectionTile(
                label: 'Date retour réelle',
                date: _dateFinReelle ?? _fin,
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _dateFinReelle ?? _fin, firstDate: _debut, lastDate: DateTime.now());
                  if (d != null) setState(() => _dateFinReelle = d);
                },
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _kmRetourCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Km au retour', suffixText: 'km'), onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (_statutFinal == 'annule') return null;
                    if (v == null || v.isEmpty) return 'Requis';
                    final km = int.tryParse(v);
                    if (km == null) return 'Invalide';
                    if (km < (int.tryParse(_kmCtrl.text) ?? 0)) return '< km départ';
                    return null;
                  },
                )),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _retenueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Retenue caution', suffixText: 'DA'), onChanged: (_) => setState(() {}))),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: _notesRetourCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Etat du véhicule au retour (optionnel)')),
              const SizedBox(height: 24),
              const FormSectionHeader(label: 'Paiements reçus', icon: Icons.payments_outlined, color: AppColors.gerant),
              const SizedBox(height: 10),
              ..._paiements.asMap().entries.map((e) => PaiementEntryRow(
                    entry: e.value,
                    onDelete: () => setState(() => _paiements.removeAt(e.key)),
                    onChanged: () => setState(() {}),
                  )),
              OutlinedButton.icon(
                onPressed: () => setState(() => _paiements.add(PaiementEntry())),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter un paiement'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.gerant, side: const BorderSide(color: AppColors.gerant)),
              ),
            ],

            const SizedBox(height: 20),
            if (_vehicule != null) ...[
              LocationFinancialRecap(
                nbJours: _nbJours,
                prixJour: _prixJour,
                total: _total,
                gerantMnt: _gerantMnt,
                proprioMnt: _proprioMnt,
                dynamicProprietes: _vehicule!.proprietes,
                settingsLabel: settingsLabel,
                modeHistorique: _modeHistorique,
                totalPaiements: _totalPaiements,
                resteAPayer: _resteAPayer,
                retenueCaution: double.tryParse(_retenueCtrl.text) ?? 0,
              ),
              const SizedBox(height: 20),
            ],

            if (!_modeHistorique) ...[
              _buildCheckboxPdf(),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(_modeHistorique ? Icons.history_edu : Icons.check),
                label: Text(_loading ? (_modeHistorique ? 'Enregistrement...' : 'Création...') : (_modeHistorique ? 'Enregistrer la location passée' : 'Créer le contrat')),
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
      final repo = ref.read(locationsRepositoryProvider);
      final currentUser = ref.read(supabaseClientProvider).auth.currentUser;
      final debutStr = '${_debut.year}-${_debut.month.toString().padLeft(2, '0')}-${_debut.day.toString().padLeft(2, '0')}';
      final finStr   = '${_fin.year}-${_fin.month.toString().padLeft(2, '0')}-${_fin.day.toString().padLeft(2, '0')}';

      if (_modeHistorique) {
        final dateFinReelle = _dateFinReelle ?? _fin;
        final kmRetour = _statutFinal == 'annule' ? (int.tryParse(_kmCtrl.text) ?? 0) : (int.tryParse(_kmRetourCtrl.text) ?? 0);

        final data = <String, dynamic>{
          'vehicule_id':     _vehicule!.id,
          'client_id':       _client!.id,
          'date_debut':      debutStr,
          'date_fin_prevue': finStr,
          'date_fin_reelle': '${dateFinReelle.year}-${dateFinReelle.month.toString().padLeft(2, '0')}-${dateFinReelle.day.toString().padLeft(2, '0')}',
          'km_depart':       int.tryParse(_kmCtrl.text) ?? 0,
          'km_retour':       kmRetour,
          'prix_jour':       _prixJour.toStringAsFixed(2),
          'caution':         (double.tryParse(_cautionCtrl.text) ?? 0).toStringAsFixed(2),
          'retenue_caution': (double.tryParse(_retenueCtrl.text) ?? 0).toStringAsFixed(2),
          'notes_depart':    _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          'notes_retour':    _notesRetourCtrl.text.trim().isEmpty ? null : _notesRetourCtrl.text.trim(),
          'statut':          _statutFinal,
          if (currentUser != null) 'created_by': currentUser.id,
        };

        final paiementsData = _paiements
            .where((p) => p.montant > 0)
            .map((p) => {
                  'montant':       p.montant.toStringAsFixed(2),
                  'date_paiement': '${p.date.year}-${p.date.month.toString().padLeft(2, '0')}-${p.date.day.toString().padLeft(2, '0')}',
                  'mode':          p.mode,
                  if (currentUser != null) 'created_by': currentUser.id,
                })
            .toList();

        await repo.createHistorique(locationData: data, paiements: paiementsData);
      } else {
        final data = <String, dynamic>{
          'vehicule_id':     _vehicule!.id,
          'client_id':       _client!.id,
          'date_debut':      debutStr,
          'date_fin_prevue': finStr,
          'km_depart':       int.tryParse(_kmCtrl.text) ?? 0,
          'prix_jour':       _prixJour.toStringAsFixed(2),
          'caution':         (double.tryParse(_cautionCtrl.text) ?? 0).toStringAsFixed(2),
          'retenue_caution': 0,
          'notes_depart':    _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          'statut':          'en_cours',
          if (currentUser != null) 'created_by': currentUser.id,
        };

        final location = await repo.create(data);
        await ref.read(supabaseClientProvider).from('vehicules').update({'statut': 'loue'}).eq('id', _vehicule!.id);
        
        if (_genererPdf && mounted) {
          final locationData = <String, dynamic>{
            'id': location.id, 'vehicule_id': location.vehiculeId, 'client_id': location.clientId,
            'date_debut': location.dateDebut.toIso8601String(), 'date_fin_prevue': location.dateFinPrevue.toIso8601String(),
            'km_depart': location.kmDepart, 'prix_jour': location.prixJour, 'caution': location.caution, 'notes_depart': location.notesDepart,
            'clients': { 'nom': _client?.nom, 'prenom': _client?.prenom, 'telephone': _client?.telephone, 'email': _client?.email, 'adresse': _client?.adresse, 'num_permis': _client?.numPermis, 'num_cni': _client?.numCni },
            'vehicules': { 'marque': _vehicule?.marque, 'modele': _vehicule?.modele, 'couleur': _vehicule?.couleur, 'immatriculation': _vehicule?.immatriculation, 'carburant': _vehicule?.carburant, 'boite': _vehicule?.boite, 'etat_vehicule': _vehicule?.etatVehicule },
          };
          final pdfFile = await ContratGeneratorService.genererLocation(locationData: locationData);
          if (pdfFile != null && mounted) await ContratGeneratorService.partager(context, pdfFile);
        }
      }

      ref.invalidate(locationsActivesProvider);
      ref.invalidate(vehiculesProvider);

      if (mounted) {
        context.pop();
        NotificationService().success(_modeHistorique ? 'Location passée enregistrée !' : 'Contrat créé avec succès !');
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