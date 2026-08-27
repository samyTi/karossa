// lib/features/locations/presentation/location_form_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage_auto/core/utils/app_logger.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../admin/presentation/showroom_settings_provider.dart';
import '../../admin/domain/showroom_settings_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../clients/domain/client_model.dart';
import '../../clients/presentation/clients_provider.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/domain/etat_carrosserie_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import '../../../core/services/pdf/contrat_orchestrator.dart';
import '../../../core/services/pdf/vehicle_schema_pdf_renderer.dart';
import '../../contrats/domain/contrat_location_dto.dart' show ContratLocationTemplate;
import '../../contrats/presentation/widgets/contrat_location_template_picker.dart';
import 'locations_provider.dart';

import '../../../shared/widgets/location_financial_recap.dart';
import '../../../shared/widgets/location_form_components.dart';
import '../../../shared/widgets/paiement_entry_row.dart';
import '../../../shared/widgets/car_damage_map.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

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
  DateTime  _debut = DateTime.now();
  DateTime  _fin   = DateTime.now().add(const Duration(days: 1));

  /// true = contrat ouvert (sans date de fin prévue)
  bool _contratOuvert = false;

  bool _loading    = false;
  bool _genererPdf = true;

  final _kmCtrl      = TextEditingController();
  final _cautionCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();

  // ── 2ème conducteur (optionnel) — affiché sur le contrat de location ──────
  bool _hasConducteur2 = false;
  final _conducteur2NomCtrl            = TextEditingController();
  final _conducteur2PrenomCtrl         = TextEditingController();
  final _conducteur2TelCtrl            = TextEditingController();
  final _conducteur2PermisCtrl         = TextEditingController();
  final _conducteur2PermisDateCtrl     = TextEditingController();
  final _conducteur2DateNaissanceCtrl  = TextEditingController();

  // ── Heures de départ / retour (optionnelles) — affichées sur le contrat ──
  final _heureDepartCtrl = TextEditingController();
  final _heureRetourCtrl = TextEditingController();

  bool      _modeHistorique  = false;
  DateTime? _dateFinReelle;
  final _kmRetourCtrl    = TextEditingController();
  final _retenueCtrl     = TextEditingController(text: '0');
  final _notesRetourCtrl = TextEditingController();
  String _statutFinal = 'termine';

  final List<PaiementEntry> _paiements = [];

  CommissionType _comType         = CommissionType.pct;
  double         _comValeurConfig = 10.0;
  bool           _settingsLoaded  = false;

  EtatCarrosserie _etatCarrosserie = const EtatCarrosserie();

  int    get _nbJours       => _contratOuvert ? 1 : _fin.difference(_debut).inDays.clamp(1, 9999);
  double get _prixJour      => _vehicule?.prixLocationJour ?? 0;
  double get _total         => _prixJour * _nbJours;
  double get _gerantMnt     => _comType == CommissionType.pct
      ? _total * _comValeurConfig / 100
      : _comValeurConfig * _nbJours;
  double get _proprioMnt    => (_total - _gerantMnt).clamp(0, double.infinity);
  double get _totalPaiements => _paiements.fold(0.0, (s, p) => s + p.montant);
  double get _resteAPayer   =>
      (_total - (double.tryParse(_retenueCtrl.text) ?? 0) - _totalPaiements)
          .clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      if (widget.vehiculeId != null) {
        final all = ref.read(vehiculesProvider).valueOrNull ?? [];
        final veh = all.isNotEmpty
            ? all.firstWhere((v) => v.id == widget.vehiculeId,
                orElse: () => all.first)
            : null;
        if (veh != null) setState(() => _vehicule = veh);
      }
    });
  }

  Future<void> _loadSettings() async {
    if (_settingsLoaded) return;
    try {
      final s = await ref.read(showroomSettingsTypedProvider.future);
      if (!mounted) return;
      setState(() {
        _comType         = s.commissionLocation.type;
        _comValeurConfig = s.commissionLocation.valeur;
        _settingsLoaded  = true;
      });
    } catch (_) {}
  }

  Future<void> _pickHeure(TextEditingController controller) async {
    final initial = controller.text.isNotEmpty
        ? _parseHeure(controller.text) ?? TimeOfDay.now()
        : TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      controller.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  TimeOfDay? _parseHeure(String v) {
    final parts = v.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

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
    _kmCtrl.dispose();
    _cautionCtrl.dispose();
    _notesCtrl.dispose();
    _kmRetourCtrl.dispose();
    _retenueCtrl.dispose();
    _notesRetourCtrl.dispose();
    _conducteur2NomCtrl.dispose();
    _conducteur2PrenomCtrl.dispose();
    _conducteur2TelCtrl.dispose();
    _conducteur2PermisCtrl.dispose();
    _conducteur2PermisDateCtrl.dispose();
    _conducteur2DateNaissanceCtrl.dispose();
    _heureDepartCtrl.dispose();
    _heureRetourCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allVehicules = ref.watch(vehiculesProvider).valueOrNull ?? [];
    final vehicules    = _modeHistorique
        ? allVehicules
            .where((v) =>
                v.statut == VehiculeStatut.disponible ||
                v.statut == VehiculeStatut.loue)
            .toList()
        : allVehicules
            .where((v) => v.statut == VehiculeStatut.disponible)
            .toList();
    final clients = ref.watch(clientsProvider).valueOrNull ?? [];

    final settingsLabel = _comType == CommissionType.pct
        ? 'Gérant (${_comValeurConfig.toInt()}%)'
        : 'Gérant (${_comValeurConfig.toInt()} DA/j)';

    return Scaffold(
      appBar: CustomAppBar(
        title: _modeHistorique
            ? 'Saisie location passée'
            : 'Nouveau contrat de location',
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
                  _debut         = DateTime.now().subtract(const Duration(days: 7));
                  _fin           = DateTime.now().subtract(const Duration(days: 1));
                  _dateFinReelle = _fin;
                  _genererPdf    = false;
                  _contratOuvert = false;
                } else {
                  _debut         = DateTime.now();
                  _fin           = DateTime.now().add(const Duration(days: 1));
                  _dateFinReelle = null;
                  _genererPdf    = true;
                }
              }),
            ),
            SizedBox(height: 16),

            // ── Véhicule ───────────────────────────────────────────────
            Text(context.l10n.vehicule, style: AppTextStyles.heading3),
            SizedBox(height: 8),
            DropdownButtonFormField<Vehicule>(
              value: _vehicule != null && vehicules.contains(_vehicule!)
                  ? _vehicule
                  : null,
              decoration: InputDecoration(
                  labelText: context.l10n.selectionnerLeVehicule),
              hint: Text(context.l10n.choisirUnVehicule),
              items: vehicules
                  .map((v) => DropdownMenuItem<Vehicule>(
                        value: v,
                        child: Text(
                          '${v.displayName}'
                          '${v.prixLocationJour != null ? ' - ${v.prixLocationJour!.toInt()} DA/j' : ''}',
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _vehicule = v),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            SizedBox(height: 16),

            // ── Client ─────────────────────────────────────────────────
            Text(context.l10n.sectionClient, style: AppTextStyles.heading3),
            SizedBox(height: 8),
            DropdownButtonFormField<Client>(
              value: _client,
              decoration: InputDecoration(
                  labelText: context.l10n.selectionnerLeClient),
              items: clients
                  .map((c) => DropdownMenuItem<Client>(
                        value: c,
                        child: Row(children: [
                          Text(c.fullName),
                          if (c.statut == ClientStatut.blacklist) ...[
                            SizedBox(width: 6),
                            Icon(Icons.block,
                                color: AppColors.retard, size: 14),
                          ],
                          if (c.statut == ClientStatut.risque) ...[
                            SizedBox(width: 6),
                            Icon(Icons.warning_amber,
                                color: AppColors.accent, size: 14),
                          ],
                        ]),
                      ))
                  .toList(),
              onChanged: (c) {
                if (c?.statut == ClientStatut.blacklist) {
                  NotificationService().show(
                    message:
                        context.l10n.clientListeNoire,
                    type: NotificationType.warning,
                    duration: const Duration(seconds: 5),
                  );
                }
                setState(() => _client = c);
              },
              validator: (v) => v == null ? 'Requis' : null,
            ),
            SizedBox(height: 16),

            // ── Période ────────────────────────────────────────────────
            Text(context.l10n.periode, style: AppTextStyles.heading3),
            SizedBox(height: 8),

            // Toggle contrat ouvert (uniquement en mode normal)
            if (!_modeHistorique) ...[
              SwitchListTile(
                value: _contratOuvert,
                onChanged: (v) => setState(() => _contratOuvert = v),
                title: Text(context.l10n.contratOuvertSansDateFin),
                subtitle: Text(context.l10n.laDureeSeraCalculeeLorsDu, style: TextStyle(fontSize: 11)),
                secondary: Icon(
                  Icons.all_inclusive,
                  color: _contratOuvert ? AppColors.secondary : AppColors.textSecondary,
                ),
                activeColor: AppColors.secondary,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              SizedBox(height: 8),
            ],

            Row(children: [
              Expanded(child: DateSelectionTile(
                label: context.l10n.depart,
                date: _debut,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _debut,
                    firstDate: DateTime(2015),
                    lastDate: _modeHistorique
                        ? DateTime.now()
                        : DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    setState(() {
                      _debut = d;
                      if (!_contratOuvert && _fin.isBefore(_debut)) {
                        _fin = _debut.add(const Duration(days: 1));
                      }
                      if (_dateFinReelle != null &&
                          _dateFinReelle!.isBefore(_debut)) {
                        _dateFinReelle = _fin;
                      }
                    });
                  }
                },
              )),
              if (!_contratOuvert || _modeHistorique) ...[
                SizedBox(width: 10),
                Expanded(child: DateSelectionTile(
                  label: _modeHistorique ? 'Retour prévu' : 'Retour prévu',
                  date: _fin,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _fin,
                      firstDate: _debut.add(const Duration(days: 1)),
                      lastDate: _modeHistorique
                          ? DateTime.now()
                          : DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _fin = d);
                  },
                )),
              ] else ...[
                SizedBox(width: 10),
                Expanded(
                  child: Container(
                    // placeholder pour contrat ouvert — heure de retour ci-dessous
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.all_inclusive, size: 16, color: AppColors.secondary),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(context.l10n.pasDeDateDeFin, style: TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ),
              ],
            ]),
            SizedBox(height: 10),

            // ── Heures de départ / retour (optionnelles) ────────────────
            Row(children: [
              Expanded(child: TextFormField(
                controller: _heureDepartCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Heure de départ',
                  suffixIcon: Icon(Icons.access_time, size: 18),
                ),
                onTap: () => _pickHeure(_heureDepartCtrl),
              )),
              if (!_contratOuvert || _modeHistorique) ...[
                SizedBox(width: 10),
                Expanded(child: TextFormField(
                  controller: _heureRetourCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Heure de retour',
                    suffixIcon: Icon(Icons.access_time, size: 18),
                  ),
                  onTap: () => _pickHeure(_heureRetourCtrl),
                )),
              ],
            ]),
            SizedBox(height: 16),

            Row(children: [
              Expanded(child: TextFormField(
                controller: _kmCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.kmAuDepart, suffixText: 'km'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requis' : null,
              )),
              SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _cautionCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.champCaution, suffixText: 'DA'),
              )),
            ]),
            SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.l10n.notesEtatVehiculeDepart),
            ),
            SizedBox(height: 16),

            // ── 2ème conducteur (optionnel) ─────────────────────────────
            SwitchListTile(
              value: _hasConducteur2,
              onChanged: (v) => setState(() => _hasConducteur2 = v),
              title: const Text('Ajouter un 2ème conducteur'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            if (_hasConducteur2) ...[
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _conducteur2PrenomCtrl,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                )),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(
                  controller: _conducteur2NomCtrl,
                  decoration: const InputDecoration(labelText: 'Nom'),
                )),
              ]),
              const SizedBox(height: 10),
              TextFormField(
                controller: _conducteur2TelCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _conducteur2PermisCtrl,
                  decoration: const InputDecoration(labelText: 'N° permis'),
                )),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(
                  controller: _conducteur2PermisDateCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Délivré le',
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
                      _conducteur2PermisDateCtrl.text =
                          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                    }
                  },
                )),
              ]),
              const SizedBox(height: 10),
              TextFormField(
                controller: _conducteur2DateNaissanceCtrl,
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
                    _conducteur2DateNaissanceCtrl.text =
                        '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                  }
                },
              ),
              SizedBox(height: 16),
            ],

            // ── Carrosserie départ ─────────────────────────────────────
            VehicleInspectorCard(
              title: context.l10n.etatCarrosserieAuDepart,
              etat: _etatCarrosserie,
              onChanged: (updated) =>
                  setState(() => _etatCarrosserie = updated),
            ),

            // ── Mode historique ────────────────────────────────────────
            if (_modeHistorique) ...[
              SizedBox(height: 24),
              FormSectionHeader(
                label: context.l10n.informationsDeRetour,
                icon: Icons.keyboard_return,
                color: AppColors.secondary,
              ),
              SizedBox(height: 12),
              Text(context.l10n.statutFinal, style: AppTextStyles.label),
              SizedBox(height: 6),
              Row(children: [
                Expanded(child: LocationStatutChip(
                  label: context.l10n.terminee,
                  icon: Icons.check_circle_outline,
                  selected: _statutFinal == 'termine',
                  color: AppColors.secondary,
                  onTap: () => setState(() => _statutFinal = 'termine'),
                )),
                SizedBox(width: 10),
                Expanded(child: LocationStatutChip(
                  label: context.l10n.annulee,
                  icon: Icons.cancel_outlined,
                  selected: _statutFinal == 'annule',
                  color: AppColors.retard,
                  onTap: () => setState(() => _statutFinal = 'annule'),
                )),
              ]),
              SizedBox(height: 14),
              DateSelectionTile(
                label: context.l10n.dateRetourReelle,
                date: _dateFinReelle ?? _fin,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _dateFinReelle ?? _fin,
                    firstDate: _debut,
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _dateFinReelle = d);
                },
              ),
              SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _kmRetourCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.kmAuRetour, suffixText: 'km'),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (_statutFinal == 'annule') return null;
                    if (v == null || v.isEmpty) return 'Requis';
                    final km = int.tryParse(v);
                    if (km == null) return 'Invalide';
                    if (km < (int.tryParse(_kmCtrl.text) ?? 0)) {
                      return context.l10n.kmDepartInferieur;
                    }
                    return null;
                  },
                )),
                SizedBox(width: 10),
                Expanded(child: TextFormField(
                  controller: _retenueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.retenueCaution, suffixText: 'DA'),
                  onChanged: (_) => setState(() {}),
                )),
              ]),
              SizedBox(height: 12),
              TextFormField(
                controller: _notesRetourCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.l10n.etatDuVehiculeAuRetourOptionnel),
              ),
              SizedBox(height: 24),
              FormSectionHeader(
                label: context.l10n.paiementsRecus,
                icon: Icons.payments_outlined,
                color: AppColors.gerant,
              ),
              SizedBox(height: 10),
              ..._paiements.asMap().entries.map((e) => PaiementEntryRow(
                    entry: e.value,
                    onDelete: () =>
                        setState(() => _paiements.removeAt(e.key)),
                    onChanged: () => setState(() {}),
                  )),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _paiements.add(PaiementEntry())),
                icon: Icon(Icons.add, size: 16),
                label: Text(context.l10n.ajouterUnPaiement),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gerant,
                  side: const BorderSide(color: AppColors.gerant),
                ),
              ),
            ],

            SizedBox(height: 20),
            if (_vehicule != null && !_contratOuvert) ...[
              LocationFinancialRecap(
                nbJours:           _nbJours,
                prixJour:          _prixJour,
                total:             _total,
                gerantMnt:         _gerantMnt,
                proprioMnt:        _proprioMnt,
                dynamicProprietes: _vehicule!.proprietes,
                settingsLabel:     settingsLabel,
                modeHistorique:    _modeHistorique,
                totalPaiements:    _totalPaiements,
                resteAPayer:       _resteAPayer,
                retenueCaution:    double.tryParse(_retenueCtrl.text) ?? 0,
              ),
              SizedBox(height: 20),
            ],
            if (_vehicule != null && _contratOuvert) ...[
              _ContratOuvertRecap(prixJour: _prixJour),
              SizedBox(height: 20),
            ],

            if (!_modeHistorique) ...[
              _buildCheckboxPdf(),
              SizedBox(height: 8),
            ],

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
                    : Icon(_modeHistorique
                        ? Icons.history_edu
                        : Icons.check),
                label: Text(_loading
                    ? (_modeHistorique
                        ? 'Enregistrement...'
                        : 'Création...')
                    : (_modeHistorique
                        ? 'Enregistrer la location passée'
                        : 'Créer le contrat')),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    AppLogger.d('LocationFormScreen - Soumission du formulaire...');
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final repo        = ref.read(locationsRepositoryProvider);
      final currentUser = ref.read(supabaseClientProvider).auth.currentUser;
      final showroomId  = ref.read(currentShowroomIdProvider);

      String _fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      if (_modeHistorique) {
        final dateFinReelle = _dateFinReelle ?? _fin;
        final kmRetour = _statutFinal == 'annule'
            ? (int.tryParse(_kmCtrl.text) ?? 0)
            : (int.tryParse(_kmRetourCtrl.text) ?? 0);

        final data = <String, dynamic>{
          'vehicule_id':               _vehicule!.id,
          'client_id':                 _client!.id,
          'date_debut':                _fmt(_debut),
          'date_fin_prevue':           _fmt(_fin),
          'date_fin_reelle':           _fmt(dateFinReelle),
          'km_depart':                 int.tryParse(_kmCtrl.text) ?? 0,
          'km_retour':                 kmRetour,
          'prix_jour':                 _prixJour.toStringAsFixed(2),
          'caution':                   (double.tryParse(_cautionCtrl.text) ?? 0).toStringAsFixed(2),
          'retenue_caution':           (double.tryParse(_retenueCtrl.text) ?? 0).toStringAsFixed(2),
          'notes_depart':              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          'notes_retour':              _notesRetourCtrl.text.trim().isEmpty ? null : _notesRetourCtrl.text.trim(),
          'statut':                    _statutFinal,
          'etat_carrosserie_depart':   _etatCarrosserie.toJsonString(),
          'heure_depart':              _heureDepartCtrl.text.trim().isEmpty ? null : _heureDepartCtrl.text.trim(),
          'heure_retour':              _heureRetourCtrl.text.trim().isEmpty ? null : _heureRetourCtrl.text.trim(),
          if (currentUser != null) 'created_by': currentUser.id,
          if (_hasConducteur2) ...{
            'conducteur2_nom':            _conducteur2NomCtrl.text.trim().isEmpty ? null : _conducteur2NomCtrl.text.trim(),
            'conducteur2_prenom':         _conducteur2PrenomCtrl.text.trim().isEmpty ? null : _conducteur2PrenomCtrl.text.trim(),
            'conducteur2_tel':            _conducteur2TelCtrl.text.trim().isEmpty ? null : _conducteur2TelCtrl.text.trim(),
            'conducteur2_num_permis':     _conducteur2PermisCtrl.text.trim().isEmpty ? null : _conducteur2PermisCtrl.text.trim(),
            'conducteur2_permis_date':    _conducteur2PermisDateCtrl.text.trim().isEmpty ? null : _conducteur2PermisDateCtrl.text.trim(),
            'conducteur2_date_naissance': _conducteur2DateNaissanceCtrl.text.trim().isEmpty ? null : _conducteur2DateNaissanceCtrl.text.trim(),
          },
        };

        final paiementsData = _paiements
            .where((p) => p.montant > 0)
            .map((p) => {
                  'montant':       p.montant.toStringAsFixed(2),
                  'date_paiement': _fmt(p.date),
                  'mode':          p.mode,
                  if (currentUser != null) 'created_by': currentUser.id,
                })
            .toList();

        await repo.createHistorique(
          locationData: data,
          paiements:    paiementsData,
        );
      } else {
        final data = <String, dynamic>{
          'vehicule_id':             _vehicule!.id,
          'client_id':               _client!.id,
          'date_debut':              _fmt(_debut),
          // contrat ouvert = pas de date_fin_prevue
          if (!_contratOuvert) 'date_fin_prevue': _fmt(_fin),
          'km_depart':               int.tryParse(_kmCtrl.text) ?? 0,
          'prix_jour':               _prixJour.toStringAsFixed(2),
          'caution':                 (double.tryParse(_cautionCtrl.text) ?? 0).toStringAsFixed(2),
          'retenue_caution':         0,
          'notes_depart':            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          'statut':                  'en_cours',
          'etat_carrosserie_depart': _etatCarrosserie.toJsonString(),
          'heure_depart':            _heureDepartCtrl.text.trim().isEmpty ? null : _heureDepartCtrl.text.trim(),
          if (!_contratOuvert)
            'heure_retour':          _heureRetourCtrl.text.trim().isEmpty ? null : _heureRetourCtrl.text.trim(),
          if (currentUser != null) 'created_by': currentUser.id,
          if (_hasConducteur2) ...{
            'conducteur2_nom':            _conducteur2NomCtrl.text.trim().isEmpty ? null : _conducteur2NomCtrl.text.trim(),
            'conducteur2_prenom':         _conducteur2PrenomCtrl.text.trim().isEmpty ? null : _conducteur2PrenomCtrl.text.trim(),
            'conducteur2_tel':            _conducteur2TelCtrl.text.trim().isEmpty ? null : _conducteur2TelCtrl.text.trim(),
            'conducteur2_num_permis':     _conducteur2PermisCtrl.text.trim().isEmpty ? null : _conducteur2PermisCtrl.text.trim(),
            'conducteur2_permis_date':    _conducteur2PermisDateCtrl.text.trim().isEmpty ? null : _conducteur2PermisDateCtrl.text.trim(),
            'conducteur2_date_naissance': _conducteur2DateNaissanceCtrl.text.trim().isEmpty ? null : _conducteur2DateNaissanceCtrl.text.trim(),
          },
        };

        final location = await repo.create(data);

        await ref.read(supabaseClientProvider)
            .from('vehicules')
            .update({'statut': 'loue'})
            .eq('showroom_id', showroomId ?? '')
            .eq('id', _vehicule!.id);

        // La location est déjà enregistrée à ce stade : une erreur de
        // génération PDF ne doit donc pas être confondue avec un échec de
        // l'enregistrement de la location.
        String? pdfError;
        ContratLocationTemplate? _selectedTemplate;
        if (_genererPdf && mounted) {
          _selectedTemplate = await showContratLocationTemplatePicker(context);
        }
        if (_genererPdf && _selectedTemplate != null && mounted) {
          final locationData = <String, dynamic>{
            'id':              location.id,
            'vehicule_id':     location.vehiculeId,
            'client_id':       location.clientId,
            'date_debut':      location.dateDebut.toIso8601String(),
            'date_fin_prevue': location.dateFinPrevue?.toIso8601String(),
            'km_depart':       location.kmDepart,
            'prix_jour':       location.prixJour,
            'caution':         location.caution,
            'notes_depart':    location.notesDepart,
            'heure_depart':    _heureDepartCtrl.text.trim().isEmpty ? null : _heureDepartCtrl.text.trim(),
            'heure_retour':    _heureRetourCtrl.text.trim().isEmpty ? null : _heureRetourCtrl.text.trim(),
            'clients': {
              'nom':            _client?.nom,
              'prenom':         _client?.prenom,
              'telephone':      _client?.telephone,
              'email':          _client?.email,
              'adresse':        _client?.adresse,
              'num_permis':     _client?.numPermis,
              'permis_date':    _client?.permisDate,
              'num_cni':        _client?.numCni,
              'date_naissance': _client?.dateNaissance,
            },
            'vehicules': {
              'marque':          _vehicule?.marque,
              'modele':          _vehicule?.modele,
              'couleur':         _vehicule?.couleur,
              'immatriculation': _vehicule?.immatriculation,
              'carburant':       _vehicule?.carburant,
              'boite':           _vehicule?.boite,
              'etat_vehicule':   _vehicule?.etatVehicule,
              'assurance':       _vehicule?.assurance,
              'code_radio':      _vehicule?.codeRadio,
            },
            // Objet typé pour la maquette PDF (non envoyé à Supabase)
            'etat_carrosserie_depart': _etatCarrosserie,
            if (_hasConducteur2) ...{
              'conducteur2_nom':         _conducteur2NomCtrl.text.trim().isEmpty ? null : _conducteur2NomCtrl.text.trim(),
              'conducteur2_prenom':      _conducteur2PrenomCtrl.text.trim().isEmpty ? null : _conducteur2PrenomCtrl.text.trim(),
              'conducteur2_tel':         _conducteur2TelCtrl.text.trim().isEmpty ? null : _conducteur2TelCtrl.text.trim(),
              'conducteur2_num_permis':  _conducteur2PermisCtrl.text.trim().isEmpty ? null : _conducteur2PermisCtrl.text.trim(),
              'conducteur2_permis_date': _conducteur2PermisDateCtrl.text.trim().isEmpty ? null : _conducteur2PermisDateCtrl.text.trim(),
              'conducteur2_date_naissance': _conducteur2DateNaissanceCtrl.text.trim().isEmpty ? null : _conducteur2DateNaissanceCtrl.text.trim(),
            },
          };

          // Pré-chargement du blueprint — évite rootBundle async pendant PDF
          Uint8List? blueprintBytes;
          try {
            blueprintBytes = await VehicleSchemaPdfRenderer.loadBlueprintBytes();
            debugPrint('✅ [Form] Blueprint pré-chargé : ${blueprintBytes.length} bytes');
          } catch (e) {
            debugPrint('⚠️ [Form] Blueprint non chargé : $e');
          }
          if (blueprintBytes != null) {
            locationData['blueprint_bytes'] = blueprintBytes;
          }
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
          try {
            final orchestrator = ContratOrchestrator(
              () => _fetchSettings(ref),
              supabase:   ref.read(supabaseClientProvider),
              showroomId: ref.read(currentShowroomIdProvider) ?? '',
            );
            await orchestrator.generateAndShareLocation(
              locationData: locationData,
              template: _selectedTemplate!,
            );
          } catch (e) {
            pdfError = e.toString();
          }
        }

        ref.invalidate(locationsActivesProvider);
        ref.invalidate(vehiculesProvider);

        if (mounted) {
          context.pop();
          if (pdfError != null) {
            NotificationService().error(
              'Location enregistrée, mais la génération du contrat PDF a échoué : $pdfError',
            );
          } else {
            NotificationService().success('Contrat créé avec succès !');
          }
        }
        return;
      }

      ref.invalidate(locationsActivesProvider);
      ref.invalidate(vehiculesProvider);

      if (mounted) {
        context.pop();
        NotificationService().success('Location passée enregistrée !');
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
        secondary: Icon(Icons.picture_as_pdf, color: AppColors.primary),
        contentPadding: EdgeInsets.zero,
        dense: true,
      );
}

/// Récap simple pour les contrats ouverts
class _ContratOuvertRecap extends StatelessWidget {
  final double prixJour;
  const _ContratOuvertRecap({required this.prixJour});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.secondary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      Icon(Icons.info_outline, size: 16, color: AppColors.secondary),
      SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.l10n.contratOuvertPrixJour(prixJour.toInt().toString()),
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.secondary, fontSize: 13)),
          SizedBox(height: 2),
          Text(context.l10n.leMontantTotalSeraCalculeAu, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ),
    ]),
  );
}