// lib/features/locations/presentation/location_edit_screen.dart
//
// Écran d'édition complète d'une location existante.
// Accessible via : context.push('/locations/${id}/edit')
//
// Champs modifiables :
//   • Véhicule, Client
//   • Dates (début, fin prévue, fin réelle)
//   • Contrat ouvert (toggle)
//   • Km départ / retour
//   • Prix / jour, Caution, Retenue caution
//   • Statut
//   • Notes départ / retour
//   • État carrosserie départ / retour
//   • Paiements : ajout, modification inline, suppression
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage_auto/core/utils/app_logger.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/car_damage_map.dart'; // Utilisé par VehicleInspectorCard s'il est dedans
import '../../clients/domain/client_model.dart';
import '../../clients/presentation/clients_provider.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/domain/etat_carrosserie_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import '../domain/location_model.dart';
import 'locations_provider.dart';
import 'location_interruption_widget.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ÉCRAN PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class LocationEditScreen extends ConsumerStatefulWidget {
  final String locationId;
  const LocationEditScreen({super.key, required this.locationId});

  @override
  ConsumerState<LocationEditScreen> createState() => _LocationEditScreenState();
}

class _LocationEditScreenState extends ConsumerState<LocationEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _dataLoaded = false;

  // ── Champs location ────────────────────────────────────────────────────────
  Vehicule? _vehicule;
  Client?   _client;

  DateTime  _debut         = DateTime.now();
  DateTime  _fin           = DateTime.now().add(const Duration(days: 1));
  DateTime? _dateFinReelle;
  bool      _contratOuvert = false;

  final _kmDepartCtrl    = TextEditingController();
  final _kmRetourCtrl    = TextEditingController();
  final _prixJourCtrl    = TextEditingController();
  final _cautionCtrl     = TextEditingController();
  final _retenueCtrl     = TextEditingController(text: '0');
  final _notesDepartCtrl = TextEditingController();
  final _notesRetourCtrl = TextEditingController();

  String _statut = 'en_cours';

  EtatCarrosserie _etatDepart  = const EtatCarrosserie();
  EtatCarrosserie _etatRetour  = const EtatCarrosserie();
  bool            _hasEtatRetour = false;

  // ── Paiements (état local) ─────────────────────────────────────────────────
  final List<_PaiementEdit> _paiements          = [];
  final List<String>        _deletedPaiementIds  = [];

  // ── Calculs ────────────────────────────────────────────────────────────────
  int get _nbJours {
    if (_contratOuvert) return 1;
    return _fin.difference(_debut).inDays.clamp(1, 9999);
  }

  double get _prixJour    => double.tryParse(_prixJourCtrl.text) ?? 0;
  double get _totalBrut   => _prixJour * _nbJours;
  double get _retenue     => double.tryParse(_retenueCtrl.text) ?? 0;
  double get _totalPaie   =>
      _paiements.fold(0.0, (s, p) => s + (double.tryParse(p.montantCtrl.text) ?? 0));
  double get _resteAPayer =>
      (_totalBrut - _retenue - _totalPaie).clamp(0, double.infinity);

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chargerDonnees());
  }

  @override
  void dispose() {
    _kmDepartCtrl.dispose();
    _kmRetourCtrl.dispose();
    _prixJourCtrl.dispose();
    _cautionCtrl.dispose();
    _retenueCtrl.dispose();
    _notesDepartCtrl.dispose();
    _notesRetourCtrl.dispose();
    for (final p in _paiements) {
      p.dispose();
    }
    super.dispose();
  }

  // ── Chargement initial ─────────────────────────────────────────────────────
  Future<void> _chargerDonnees() async {
    try {
      final location =
          await ref.read(locationsRepositoryProvider).getById(widget.locationId);
      if (location == null || !mounted) return;

      final allVehicules = ref.read(vehiculesProvider).valueOrNull ?? [];
      final allClients   = ref.read(clientsProvider).valueOrNull ?? [];

      final vehicule = allVehicules.cast<Vehicule?>().firstWhere(
            (v) => v?.id == location.vehiculeId,
            orElse: () => null,
          );
      final client = allClients.cast<Client?>().firstWhere(
            (c) => c?.id == location.clientId,
            orElse: () => null,
          );

      // Reconstituer état carrosserie départ
      EtatCarrosserie etatDepart = const EtatCarrosserie();
      if (location.etatCarrosserieDepart != null) {
        try {
          etatDepart =
              EtatCarrosserie.fromJsonString(location.etatCarrosserieDepart!);
        } catch (_) {}
      }

      // Reconstituer état carrosserie retour
      EtatCarrosserie etatRetour  = const EtatCarrosserie();
      bool            hasEtatRetour = false;
      if (location.etatCarrosserieRetour != null) {
        try {
          etatRetour =
              EtatCarrosserie.fromJsonString(location.etatCarrosserieRetour!);
          hasEtatRetour = true;
        } catch (_) {}
      }

      // Paiements existants → éditables
      final paiementsEdit =
          location.paiements.map((p) => _PaiementEdit.fromExisting(p)).toList();

      setState(() {
        _vehicule      = vehicule;
        _client        = client;
        _debut         = location.dateDebut;
        _fin           = location.dateFinPrevue ??
            location.dateDebut.add(const Duration(days: 1));
        _dateFinReelle = location.dateFinReelle;
        _contratOuvert = location.isContratOuvert;
        _statut        = location.statut.name;
        _etatDepart    = etatDepart;
        _etatRetour    = etatRetour;
        _hasEtatRetour = hasEtatRetour;

        _kmDepartCtrl.text    = location.kmDepart.toString();
        _kmRetourCtrl.text    = location.kmRetour?.toString() ?? '';
        _prixJourCtrl.text    = location.prixJour.toStringAsFixed(0);
        _cautionCtrl.text     = location.caution.toStringAsFixed(0);
        _retenueCtrl.text     = location.retenueCaution.toStringAsFixed(0);
        _notesDepartCtrl.text = location.notesDepart ?? '';
        _notesRetourCtrl.text = location.notesRetour ?? '';

        _paiements.clear();
        _paiements.addAll(paiementsEdit);
        _dataLoaded = true;
      });
    } catch (e) {
      if (mounted) NotificationService().error('Erreur chargement : $e');
    }
  }

  // ── Sauvegarde ─────────────────────────────────────────────────────────────
  Future<void> _sauvegarder() async {
    AppLogger.e('LocationEditScreen - Sauvegarde en cours...');
    if (!_formKey.currentState!.validate()) return;

    if (_dateFinReelle != null && _dateFinReelle!.isBefore(_debut)) {
      NotificationService().error(
          context.l10n.dateRetourAvantDebut);
      return;
    }

    setState(() => _loading = true);

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    try {
      final repo = ref.read(locationsRepositoryProvider);

      // 1. Mise à jour champs location
      final data = <String, dynamic>{
        'vehicule_id':   _vehicule!.id,
        'client_id':     _client!.id,
        'date_debut':    fmt(_debut),
        if (!_contratOuvert) 'date_fin_prevue': fmt(_fin)
        else 'date_fin_prevue': null,
        'date_fin_reelle': _dateFinReelle != null ? fmt(_dateFinReelle!) : null,
        'km_depart':     int.tryParse(_kmDepartCtrl.text) ?? 0,
        if (_kmRetourCtrl.text.isNotEmpty)
          'km_retour':   int.tryParse(_kmRetourCtrl.text),
        'prix_jour':     _prixJour,
        'caution':       double.tryParse(_cautionCtrl.text) ?? 0,
        'retenue_caution': _retenue,
        'statut':        _statut,
        'notes_depart':  _notesDepartCtrl.text.trim().isEmpty
            ? null
            : _notesDepartCtrl.text.trim(),
        'notes_retour':  _notesRetourCtrl.text.trim().isEmpty
            ? null
            : _notesRetourCtrl.text.trim(),
        'etat_carrosserie_depart': _etatDepart.toJsonString(),
        'etat_carrosserie_retour': _hasEtatRetour 
            ? _etatRetour.toJsonString() 
            : null,
        'nb_jours':    _contratOuvert ? null : _nbJours,
        'montant_brut': _contratOuvert ? null : _totalBrut,
      };
      AppLogger.d('LocationEditScreen - Données à sauvegarder: $data');
      await repo.update(widget.locationId, data);

      // 2. Synchronisation paiements — upsert
      for (final p in _paiements) {
        final montant = double.tryParse(p.montantCtrl.text) ?? 0;
        if (montant <= 0) {
          if (p.id != null) await repo.deletePaiement(p.id!);
          continue;
        }

        if (p.id == null) {
          await repo.addPaiement(LocationPaiement(
            id:           '',
            locationId:   widget.locationId,
            montant:      montant,
            datePaiement: p.date,
            mode:         p.mode,
            notes: p.notesCtrl.text.trim().isEmpty
                ? null
                : p.notesCtrl.text.trim(),
          ));
        } else {
          AppLogger.d('Mise à jour paiement existant - ID: ${p.id}, Montant: $montant');
          await repo.updatePaiement(
            p.id!,
            montant:      montant,
            datePaiement: p.date,
            mode:         p.mode ?? 'especes',
            notes: p.notesCtrl.text.trim().isEmpty
                ? null
                : p.notesCtrl.text.trim(),
          );
        }
      }

      // 3. Paiements supprimés explicitement
      for (final id in _deletedPaiementIds) {
        await repo.deletePaiement(id);
      }

      // 4. Invalider tous les providers concernés
      ref.invalidate(locationsActivesProvider);
      ref.invalidate(locationsRetardProvider);      
      ref.invalidate(locationsHistoriqueProvider);
      ref.invalidate(locationsAllProvider);
      ref.invalidate(locationsStatsProvider);
      ref.invalidate(locationDetailProvider(widget.locationId));
      ref.invalidate(locationPaiementsProvider(widget.locationId));

      if (mounted) {
        NotificationService().success(context.l10n.locationMiseAJour);
        context.pop();
      }
    } catch (e) {
      if (mounted) NotificationService().error('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Gestion des paiements ──────────────────────────────────────────────────
  void _supprimerPaiement(int index) {
    final p = _paiements[index];
    if (p.id != null) _deletedPaiementIds.add(p.id!);
    setState(() => _paiements.removeAt(index));
  }

  void _ajouterPaiement() {
    setState(() => _paiements.add(_PaiementEdit.nouveau()));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_dataLoaded) {
      return Scaffold(
        appBar: CustomAppBar(title: context.l10n.modifierLaLocation, showHomeButton: false),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final allVehicules = ref.watch(vehiculesProvider).valueOrNull ?? [];
    final allClients   = ref.watch(clientsProvider).valueOrNull ?? [];
    
    // Récupération de la location pour le bouton d'interruption
    final locationData = ref.watch(locationDetailProvider(widget.locationId)).valueOrNull;

    return Scaffold(
      appBar: CustomAppBar(
        title: context.l10n.modifierLaLocation,
        showHomeButton: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Véhicule ────────────────────────────────────────────────────
            _SectionHeader(label: context.l10n.vehicule, icon: Icons.directions_car_outlined),
            const SizedBox(height: 8),
            DropdownButtonFormField<Vehicule>(
              value: _vehicule,
              decoration: InputDecoration(labelText: context.l10n.vehicule),
              items: allVehicules
                  .map((v) => DropdownMenuItem<Vehicule>(
                        value: v,
                        child: Text(
                          '${v.displayName}'
                          '${v.prixLocationJour != null ? ' — ${v.prixLocationJour!.toInt()} DA/j' : ''}',
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _vehicule = v;
                if (v?.prixLocationJour != null) {
                  _prixJourCtrl.text = v!.prixLocationJour!.toStringAsFixed(0);
                }
              }),
              validator: (v) => v == null ? 'Requis' : null,
            ),

            const SizedBox(height: 20),

            // ── Client ──────────────────────────────────────────────────────
            _SectionHeader(label: 'Client', icon: Icons.person_outline),
            const SizedBox(height: 8),
            DropdownButtonFormField<Client>(
              value: _client,
              decoration: InputDecoration(labelText: context.l10n.sectionClient),
              items: allClients
                  .map((c) => DropdownMenuItem<Client>(
                        value: c,
                        child: Row(children: [
                          Text(c.fullName),
                          if (c.statut == ClientStatut.blacklist) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.block, color: AppColors.retard, size: 14),
                          ],
                          if (c.statut == ClientStatut.risque) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.warning_amber,
                                color: AppColors.accent, size: 14),
                          ],
                        ]),
                      ))
                  .toList(),
              onChanged: (c) => setState(() => _client = c),
              validator: (v) => v == null ? 'Requis' : null,
            ),

            const SizedBox(height: 20),

            // ── Statut ──────────────────────────────────────────────────────
            _SectionHeader(label: context.l10n.champStatut, icon: Icons.flag_outlined),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _statut,
              decoration:
                  InputDecoration(labelText: context.l10n.statutDeLaLocation),
              items: [
                DropdownMenuItem(value: 'en_cours', child: Text(context.l10n.locationEnCours)),
                DropdownMenuItem(value: 'retard',   child: Text(context.l10n.locationRetard)),
                DropdownMenuItem(value: 'termine',  child: Text(context.l10n.terminee)),
                DropdownMenuItem(value: 'annule',   child: Text(context.l10n.annulee)),
              ],
              onChanged: (v) => setState(() => _statut = v ?? _statut),
            ),

            const SizedBox(height: 20),

            // ── Période ─────────────────────────────────────────────────────
            _SectionHeader(label: context.l10n.periode, icon: Icons.date_range_outlined),
            const SizedBox(height: 8),

            SwitchListTile(
              value: _contratOuvert,
              onChanged: (v) => setState(() => _contratOuvert = v),
              title: Text(context.l10n.contratOuvertSansDateDeFin),
              subtitle: Text(context.l10n.laDureeSeraCalculeeAuRetour, style: TextStyle(fontSize: 11),
              ),
              secondary: Icon(
                Icons.all_inclusive,
                color: _contratOuvert
                    ? AppColors.secondary
                    : AppColors.textSecondary,
              ),
              activeColor: AppColors.secondary,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 8),

            Row(children: [
              Expanded(
                child: _DateTile(
                  label: context.l10n.dateDepart,
                  date: _debut,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _debut,
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) {
                      setState(() {
                        _debut = d;
                        if (!_contratOuvert && _fin.isBefore(_debut)) {
                          _fin = _debut.add(const Duration(days: 1));
                        }
                      });
                    }
                  },
                ),
              ),
              if (!_contratOuvert) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _DateTile(
                    label: context.l10n.retourPrevu,
                    date: _fin,
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _fin,
                        firstDate: _debut.add(const Duration(days: 1)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() => _fin = d);
                    },
                  ),
                ),
              ],
            ]),

            const SizedBox(height: 10),

            _DateTile(
              label: context.l10n.dateRetourReelleOptionnel,
              date: _dateFinReelle,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dateFinReelle ?? DateTime.now(),
                  firstDate: _debut,
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (d != null) setState(() => _dateFinReelle = d);
              },
              nullable: true,
              onClear: () => setState(() => _dateFinReelle = null),
            ),

            const SizedBox(height: 20),

            // ── Kilométrage ─────────────────────────────────────────────────
            _SectionHeader(label: context.l10n.kilometrage, icon: Icons.speed_outlined),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _kmDepartCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: context.l10n.kmDepart, suffixText: 'km'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _kmRetourCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: context.l10n.kmRetour, suffixText: 'km'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final km = int.tryParse(v);
                    if (km == null) return 'Invalide';
                    final dep = int.tryParse(_kmDepartCtrl.text) ?? 0;
                    if (km < dep) return context.l10n.kmDepartInferieur;
                    return null;
                  },
                ),
              ),
            ]),

            const SizedBox(height: 20),

            // ── Financier ───────────────────────────────────────────────────
            _SectionHeader(label: 'Financier', icon: Icons.payments_outlined),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _prixJourCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: context.l10n.prixJour, suffixText: 'DA'),
                  onChanged: (_) => setState(() {}),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cautionCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: context.l10n.champCaution, suffixText: 'DA'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _retenueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: context.l10n.retenueCaution, suffixText: 'DA'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),

            if (!_contratOuvert) ...[
              const SizedBox(height: 14),
              _FinancierRecap(
                nbJours:     _nbJours,
                prixJour:    _prixJour,
                totalBrut:   _totalBrut,
                totalPaie:   _totalPaie,
                retenue:     _retenue,
                resteAPayer: _resteAPayer,
              ),
            ],

            const SizedBox(height: 20),

            // ── Paiements ───────────────────────────────────────────────────
            _SectionHeader(
                label: 'Paiements', icon: Icons.receipt_long_outlined),
            const SizedBox(height: 8),

            if (_paiements.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(context.l10n.aucunPaiementEnregistre, style: AppTextStyles.bodySecondary),
              ),

            ..._paiements.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return _PaiementEditRow(
                key: ValueKey(p.key),
                paiement: p,
                onDelete: () => _supprimerPaiement(i),
                onChanged: () => setState(() {}),
              );
            }),

            OutlinedButton.icon(
              onPressed: _ajouterPaiement,
              icon: const Icon(Icons.add, size: 16),
              label: Text(context.l10n.ajouterUnPaiement),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.secondary),
              ),
            ),

            const SizedBox(height: 20),

            // ── Notes ───────────────────────────────────────────────────────
            _SectionHeader(label: context.l10n.champNotes, icon: Icons.note_outlined),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesDepartCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: context.l10n.notesEtatDuVehiculeAuDepart),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesRetourCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: context.l10n.notesEtatDuVehiculeAuRetour),
            ),

            const SizedBox(height: 20),

            // ── État carrosserie départ ─────────────────────────────────────
            _SectionHeader(
                label: context.l10n.etatCarrosserieDepart,
                icon: Icons.car_repair_outlined),
            const SizedBox(height: 8),
            VehicleInspectorCard(
              title: context.l10n.carrosserieDepart,
              etat: _etatDepart,
              onChanged: (updated) => setState(() => _etatDepart = updated),
            ),

            const SizedBox(height: 20),

            // ── État carrosserie retour ─────────────────────────────────────
            Row(children: [
              Expanded(
                child: _SectionHeader(
                    label: context.l10n.etatCarrosserieRetour,
                    icon: Icons.keyboard_return_outlined),
              ),
              Switch(
                value: _hasEtatRetour,
                onChanged: (v) => setState(() => _hasEtatRetour = v),
                activeColor: AppColors.warning,
              ),
              Text(_hasEtatRetour ? 'Activé' : 'Désactivé',
                  style: const TextStyle(fontSize: 12)),
            ]),
            if (_hasEtatRetour) ...[
              const SizedBox(height: 8),
              VehicleInspectorCard(
                title: context.l10n.carrosserieRetour,
                etat: _etatRetour,
                onChanged: (updated) => setState(() => _etatRetour = updated),
                accentColor: AppColors.warning,
              ),
            ],

            const SizedBox(height: 24),

            // ── AJOUT : Gestion des Interruptions de contrat ────────────────
            if (locationData != null) ...[
              _SectionHeader(
                label: context.l10n.interruptionsDeContrat,
                icon: Icons.pause_circle_outline,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showInterruptionManager(context, locationData),
                  icon: Icon(
                    locationData.hasInterruptionActive 
                        ? Icons.pause_circle_filled 
                        : Icons.pause_circle_outline,
                    color: AppColors.warning,
                  ),
                  label: Text(
                    locationData.hasInterruptionActive
                        ? '⏸ Interruption en cours'
                        : 'Gérer les interruptions',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ── Bouton sauvegarder ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _sauvegarder,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(
                    _loading ? 'Enregistrement…' : 'Enregistrer les modifications'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODÈLE INTERNE — paiement éditable
// ─────────────────────────────────────────────────────────────────────────────

class _PaiementEdit {
  final String? id;           
  final String  key;          
  final TextEditingController montantCtrl;
  final TextEditingController notesCtrl;
  DateTime date;
  String?  mode;

  _PaiementEdit({
    this.id,
    required String key,
    required this.date,
    required this.mode,
    required this.montantCtrl,
    required this.notesCtrl,
  }) : key = key;

  factory _PaiementEdit.fromExisting(LocationPaiement p) => _PaiementEdit(
        id:          p.id,
        key:         p.id,
        date:        p.datePaiement,
        mode:        p.mode,
        montantCtrl: TextEditingController(text: p.montant.toStringAsFixed(0)),
        notesCtrl:   TextEditingController(text: p.notes ?? ''),
      );

  factory _PaiementEdit.nouveau() => _PaiementEdit(
        id:          null,
        key:         'new_${DateTime.now().millisecondsSinceEpoch}',
        date:        DateTime.now(),
        mode:        'especes',
        montantCtrl: TextEditingController(),
        notesCtrl:   TextEditingController(),
      );

  void dispose() {
    montantCtrl.dispose();
    notesCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — ligne de paiement éditable
// ─────────────────────────────────────────────────────────────────────────────

class _PaiementEditRow extends StatefulWidget {
  final _PaiementEdit paiement;
  final VoidCallback  onDelete;
  final VoidCallback  onChanged;

  const _PaiementEditRow({
    super.key,
    required this.paiement,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_PaiementEditRow> createState() => _PaiementEditRowState();
}

class _PaiementEditRowState extends State<_PaiementEditRow> {
  bool _expanded = false;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final p = widget.paiement;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: p.montantCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.champMontant,
                    suffixText: 'DA',
                    isDense: true,
                  ),
                  onChanged: (_) => widget.onChanged(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requis';
                    if ((double.tryParse(v) ?? 0) <= 0) return '> 0';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: p.date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (d != null) {
                      setState(() => p.date = d);
                      widget.onChanged();
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.l10n.champDate,
                      isDense: true,
                      suffixIcon: Icon(Icons.calendar_today, size: 14),
                    ),
                    child: Text(_fmt(p.date),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: p.mode ?? 'especes',
                  isDense: true,
                  decoration: InputDecoration(
                      labelText: context.l10n.champMode, isDense: true),
                  items: [
                    DropdownMenuItem(
                        value: 'especes', child: Text(context.l10n.modeEspeces)),
                    DropdownMenuItem(
                        value: 'virement', child: Text(context.l10n.modeVirement)),
                    DropdownMenuItem(
                        value: 'cheque', child: Text(context.l10n.modeCheque)),
                    DropdownMenuItem(
                        value: 'mixte', child: Text(context.l10n.modeMixte)),
                  ],
                  onChanged: (v) {
                    setState(() => p.mode = v);
                    widget.onChanged();
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                tooltip: context.l10n.champNotes,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.retard),
                onPressed: widget.onDelete,
                tooltip: context.l10n.supprimerCePaiement,
              ),
            ]),

            if (_expanded) ...[
              const SizedBox(height: 8),
              TextField(
                controller: p.notesCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.notesOptionnel,
                  isDense: true,
                ),
                maxLines: 1,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS UTILITAIRES INTERNES
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String  label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label,
            style: AppTextStyles.heading3.copyWith(color: AppColors.primary)),
      ]);
}

class _DateTile extends StatelessWidget {
  final String    label;
  final DateTime? date;
  final bool      nullable;
  final VoidCallback? onClear;
  final VoidCallback  onTap;

  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
    this.nullable = false,
    this.onClear,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    date != null ? _fmt(date!) : 'Non définie',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: date != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (nullable && date != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.clear,
                    size: 16, color: AppColors.textSecondary),
              ),
          ]),
        ),
      );
}

class _FinancierRecap extends StatelessWidget {
  final int    nbJours;
  final double prixJour;
  final double totalBrut;
  final double totalPaie;
  final double retenue;
  final double resteAPayer;

  const _FinancierRecap({
    required this.nbJours,
    required this.prixJour,
    required this.totalBrut,
    required this.totalPaie,
    required this.retenue,
    required this.resteAPayer,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          _RecapRow(
              label: context.l10n.duree,
              value: '$nbJours jour${nbJours > 1 ? "s" : ""}'),
          _RecapRow(
              label: context.l10n.prixJour, value: '${prixJour.toInt()} DA'),
          _RecapRow(
              label: context.l10n.totalBrut,
              value: '${totalBrut.toInt()} DA',
              bold: true),
          if (retenue > 0)
            _RecapRow(
                label: context.l10n.retenueCaution,
                value: '−${retenue.toInt()} DA',
                color: AppColors.retard),
          _RecapRow(
              label: context.l10n.encaisse,
              value: '${totalPaie.toInt()} DA',
              color: AppColors.secondary),
          const Divider(height: 10),
          _RecapRow(
            label: context.l10n.resteAPercevoir,
            value: '${resteAPayer.toInt()} DA',
            color: resteAPayer > 0 ? AppColors.retard : AppColors.secondary,
            bold: true,
          ),
        ]),
      );
}

class _RecapRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   bold;
  final Color? color;
  const _RecapRow({
    required this.label,
    required this.value,
    this.bold  = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: color ?? AppColors.textPrimary)),
        ]),
      );
}