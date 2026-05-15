import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/services/notification_service.dart';
import '../../clients/domain/client_model.dart';
import '../../clients/presentation/clients_provider.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import 'locations_provider.dart';
import '../../../core/services/contrat_generator_service.dart';
import '../../../core/utils/app_logger.dart';

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

  int    get _nbJours  => _fin.difference(_debut).inDays.clamp(1, 9999);
  double get _prixJour => _vehicule?.prixLocationJour ?? 0;
  double get _total    => _prixJour * _nbJours;
  double get _gerant   => _total * 0.1;
  double get _proprio  => _total * 0.9;

  // ignore: unused_element
  String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2,'0')}/'
    '${d.month.toString().padLeft(2,'0')}/${d.year}';

  @override
  void initState() {
    super.initState();
    // Pré-sélectionner le véhicule si passé en paramètre
    if (widget.vehiculeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final allVehicules = ref.read(vehiculesProvider).valueOrNull ?? [];
        final veh = allVehicules.isNotEmpty
            ? allVehicules.firstWhere(
                (v) => v.id == widget.vehiculeId,
                orElse: () => allVehicules.first)
            : null;
        if (veh != null) setState(() => _vehicule = veh);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicules = ref.watch(vehiculesProvider).valueOrNull
      ?.where((v) => v.statut == VehiculeStatut.disponible).toList() ?? [];
    final clients = ref.watch(clientsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Nouveau contrat de location',
        showHomeButton: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Véhicule
            Text('Vehicule', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            DropdownButtonFormField<Vehicule>(
              initialValue: _vehicule != null && vehicules.contains(_vehicule!) 
                ? _vehicule 
                : null,
              decoration: const InputDecoration(
                labelText: 'Selectionner le vehicule'),
              hint: const Text('Choisir un véhicule'),
              items: vehicules.map((v) {
                final prix = v.prixLocationJour != null
                    ? ' - ${v.prixLocationJour!.toInt()} DA/j'
                    : '';
                return DropdownMenuItem<Vehicule>(
                  value: v,
                  child: Text('${v.displayName}$prix'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _vehicule = v),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            // Client
            Text('Client', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            DropdownButtonFormField<Client>(
              initialValue: _client,
              decoration: const InputDecoration(
                labelText: 'Selectionner le client'),
              items: clients.map((c) => DropdownMenuItem<Client>(
                value: c,
                child: Row(children: [
                  Text(c.fullName),
                  if (c.statut == ClientStatut.blacklist) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.block,
                      color: AppColors.retard, size: 14),
                  ],
                  if (c.statut == ClientStatut.risque) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.warning_amber,
                      color: AppColors.accent, size: 14),
                  ],
                ]),
              )).toList(),
              onChanged: (c) {
                if (c?.statut == ClientStatut.blacklist) {
                  NotificationService().show(
                    message: '⚠️ Ce client est en liste noire ! Soyez prudent.',
                    type: NotificationType.warning,
                    duration: const Duration(seconds: 5),
                  );
                }
                setState(() => _client = c);
              },
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            // Dates
            Text('Periode', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _DateTile(
                label: 'Depart',
                date: _debut,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _debut,
                    firstDate: DateTime.now()
                      .subtract(const Duration(days: 1)),
                    lastDate: DateTime.now()
                      .add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    setState(() {
                    _debut = d;
                    if (_fin.isBefore(_debut)) {
                      _fin = _debut.add(const Duration(days: 1));
                    }
                  });
                  }
                },
              )),
              const SizedBox(width: 10),
              Expanded(child: _DateTile(
                label: 'Retour prevu',
                date: _fin,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _fin,
                    firstDate: _debut
                      .add(const Duration(days: 1)),
                    lastDate: DateTime.now()
                      .add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _fin = d);
                },
              )),
            ]),
            const SizedBox(height: 16),

            // Km + Caution
            Row(children: [
              Expanded(child: TextFormField(
                controller: _kmCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Km au depart',
                  suffixText: 'km'),
                validator: (v) =>
                  (v == null || v.isEmpty) ? 'Requis' : null,
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _cautionCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Caution',
                  suffixText: 'DA'),
              )),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes etat du vehicule (optionnel)'),
            ),
            const SizedBox(height: 20),

            // Récapitulatif
            if (_vehicule != null) _Recap(
              nbJours:  _nbJours,
              prixJour: _prixJour,
              total:    _total,
              gerant:   _gerant,
              proprio:  _proprio,
              proprietes: _vehicule!.proprietes,
            ),
            const SizedBox(height: 20),


            // Checkbox génération PDF
            _buildCheckboxPdf(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
                label: Text(_loading
                  ? 'Creation...' : 'Creer le contrat'),
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
      // Format dates as YYYY-MM-DD for PostgreSQL date fields
      final debutStr = '${_debut.year}-${_debut.month.toString().padLeft(2, '0')}-${_debut.day.toString().padLeft(2, '0')}';
      final finStr = '${_fin.year}-${_fin.month.toString().padLeft(2, '0')}-${_fin.day.toString().padLeft(2, '0')}';
      
      // Get current user ID for created_by field
      final currentUser = ref.read(supabaseClientProvider).auth.currentUser;
      
      // Remove nb_jours from insert - it's calculated by DB default expression
      // (date_fin_prevue - date_debut)
      final data = {
        'vehicule_id':     _vehicule!.id,
        'client_id':       _client!.id,
        'date_debut':      debutStr,
        'date_fin_prevue': finStr,
        'km_depart':       int.tryParse(_kmCtrl.text) ?? 0,
        'prix_jour':       _prixJour.toStringAsFixed(2),
        'caution':         (double.tryParse(_cautionCtrl.text) ?? 0).toStringAsFixed(2),
        'retenue_caution': 0,
        'notes_depart':    _notesCtrl.text.trim().isEmpty
                             ? null : _notesCtrl.text.trim(),
        'statut':          'en_cours',
        if (currentUser != null) 'created_by': currentUser.id,
      };
      
      AppLogger.d('DEBUG FORM: Creating location with data: $data');
      AppLogger.d('DEBUG FORM: vehicule_id=${_vehicule!.id}, client_id=${_client!.id}');
      
      final location = await repo.create(data);
      // Mettre le véhicule en statut 'loué'
      await ref.read(supabaseClientProvider).from('vehicules')
        .update({'statut': 'loue'})
        .eq('id', _vehicule!.id);
      ref.invalidate(locationsActivesProvider);
      ref.invalidate(vehiculesProvider);

      // ── Génération du contrat PDF ──────────────────────────────────
      if (_genererPdf && mounted) {
        // Convert Location object to Map for the PDF generator
        final locationData = <String, dynamic>{
          'id': location.id,
          'vehicule_id': location.vehiculeId,
          'client_id': location.clientId,
          'date_debut': location.dateDebut.toIso8601String(),
          'date_fin_prevue': location.dateFinPrevue.toIso8601String(),
          'km_depart': location.kmDepart,
          'prix_jour': location.prixJour,
          'caution': location.caution,
          'notes_depart': location.notesDepart,
          // Include nested client and vehicule data
          'clients': {
            'nom': _client?.nom,
            'prenom': _client?.prenom,
            'telephone': _client?.telephone,
            'email': _client?.email,
            'adresse': _client?.adresse,
            'num_permis': _client?.numPermis,
            'num_cni': _client?.numCni,
          },
          'vehicules': {
            'marque': _vehicule?.marque,
            'modele': _vehicule?.modele,
            'couleur': _vehicule?.couleur,
            'immatriculation': _vehicule?.immatriculation,
            'carburant': _vehicule?.carburant,
            'boite': _vehicule?.boite,
            'etat_vehicule': _vehicule?.etatVehicule,
          },
        };
        final pdfFile = await ContratGeneratorService.genererLocation(
          locationData: locationData,
        );
        if (pdfFile != null && mounted) {
          await ContratGeneratorService.partager(context, pdfFile);
        }
      }

      if (mounted) {
        context.pop();
        NotificationService().success('Contrat créé avec succès !');
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

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateTile({
    required this.label, required this.date, required this.onTap});
  String get _fmt =>
    '${date.day.toString().padLeft(2,'0')}/'
    '${date.month.toString().padLeft(2,'0')}/${date.year}';
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
        color: AppColors.inputFill,
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today,
          size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(label, style: AppTextStyles.label),
          Text(_fmt, style: AppTextStyles.body),
        ]),
      ]),
    ),
  );
}

class _Recap extends StatelessWidget {
  final int nbJours;
  final double prixJour, total, gerant, proprio;
  final List proprietes;
  const _Recap({
    required this.nbJours, required this.prixJour,
    required this.total, required this.gerant,
    required this.proprio, required this.proprietes,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.secondary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: AppColors.secondary.withValues(alpha: 0.2)),
    ),
    child: Column(children: [
      _r('Duree', '$nbJours jour(s)'),
      _r('Prix / jour', '${prixJour.toInt()} DA'),
      const Divider(height: 14),
      _r('TOTAL', '${total.toInt()} DA', bold: true),
      const SizedBox(height: 8),
              _r('  Gérant (10%)', '${gerant.toInt()} DA',
                color: AppColors.gerant),
              ...proprietes.map((p) => _r(
                '  ${p.proprietaireNom} (${(90 * p.partPct / 100).toStringAsFixed(0)}%)',
                '${(proprio * p.partPct / 100).toInt()} DA',
                color: AppColors.proprietaireVehicule)),
    ]),
  );
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
          fontSize: bold ? 16 : 13,
          fontWeight: bold
            ? FontWeight.w800 : FontWeight.w600,
          color: color ?? AppColors.textPrimary)),
      ],
    ),
  );
}