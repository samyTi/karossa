//lib/features/reparations/presentation/reparation_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../vehicules/domain/vehicule_model.dart';
import '../../vehicules/presentation/vehicules_provider.dart';
import '../../admin/presentation/users_provider.dart';
import '../../auth/domain/profile_model.dart';
import '../domain/reparation_model.dart';
import 'reparations_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class ReparationFormScreen extends ConsumerStatefulWidget {
  final Reparation? existing;
  const ReparationFormScreen({super.key, this.existing});

  bool get isEdit => existing != null;

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
  // Qui a payé cette dépense, éventuellement réparti entre plusieurs
  // payeurs (showroom et/ou un ou plusieurs propriétaires), chacun avec
  // son montant. Par défaut : le showroom paie la totalité.
  final List<_PayeurRow> _payeurs = [_PayeurRow(type: 'showroom')];
  final _descCtrl        = TextEditingController();
  final _prestataireCtrl = TextEditingController();
  final _coutCtrl        = TextEditingController();
  final _kmCtrl          = TextEditingController();

  final List<String> _types =
    ['mecanique','carrosserie','electrique','pneus','autre'];
  final List<String> _typesLabels =
    ['Mecanique','Carrosserie','Electrique','Pneus','Autre'];

  bool _vehiculePrefilled = false;

  @override
  void initState() {
    super.initState();
    // Cas le plus fréquent : un seul payeur → son montant suit
    // automatiquement le coût total tant qu'il n'y a qu'une ligne.
    _coutCtrl.addListener(() {
      if (_payeurs.length == 1 && mounted) {
        setState(() => _payeurs.first.montantCtrl.text = _coutCtrl.text);
      }
    });
    final r = widget.existing;
    if (r != null) {
      _type = r.typeRep;
      _descCtrl.text = r.description;
      _prestataireCtrl.text = r.prestataire ?? '';
      _coutCtrl.text = r.cout.toStringAsFixed(0);
      _kmCtrl.text = r.kmAuMoment?.toString() ?? '';
      _deductible = r.deductible;
      if (r.paiements.isNotEmpty) {
        _payeurs
          ..clear()
          ..addAll(r.paiements.map((p) => _PayeurRow(
                type: p.payeePar.value,
                proprietaireId: p.proprietaireId,
                debiteurId: p.debiteurId,
                montantCtrl: TextEditingController(text: p.montant.toStringAsFixed(0)),
              )));
      } else {
        _payeurs
          ..clear()
          ..add(_PayeurRow(
            type: r.payeePar.value,
            proprietaireId: r.proprietairePayeurId,
            montantCtrl: TextEditingController(text: r.cout.toStringAsFixed(0)),
          ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicules = ref.watch(vehiculesProvider).valueOrNull ?? [];
    // Le véhicule ne peut être pré-sélectionné qu'une fois la liste chargée
    // (on retrouve l'objet par id pour que le Dropdown reconnaisse la valeur).
    if (widget.existing != null && !_vehiculePrefilled && vehicules.isNotEmpty) {
      final match = vehicules.where((v) => v.id == widget.existing!.vehiculeId);
      if (match.isNotEmpty) {
        _vehicule = match.first;
        _vehiculePrefilled = true;
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit 
          ? context.l10n.modifierReparation 
          : context.l10n.nouvelleReparation
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<Vehicule>(
              initialValue: _vehicule,
              decoration: InputDecoration(labelText: context.l10n.vehicule),
              items: vehicules.map((v) => DropdownMenuItem<Vehicule>(
                value: v, child: Text(v.displayName))).toList(),
              onChanged: (v) => setState(() {
                _vehicule = v;
                // Un nouveau véhicule invalide le/les propriétaire(s) choisis
                // pour le paiement : on repart sur "showroom" par défaut.
                _payeurs
                  ..clear()
                  ..add(_PayeurRow(
                      type: 'showroom',
                      montantCtrl: TextEditingController(text: _coutCtrl.text)));
              }),
              validator: (v) => v == null ? context.l10n.requis : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: context.l10n.champType),
              items: List.generate(_types.length, (i) => DropdownMenuItem<String>(
                value: _types[i], child: Text(_typesLabels[i]))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: InputDecoration(labelText: context.l10n.description),
              validator: (v) =>
                (v == null || v.isEmpty) ? context.l10n.requis : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _prestataireCtrl,
                decoration: InputDecoration(labelText: context.l10n.prestataire),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _kmCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.kmAuMoment, suffixText: 'km'),
              )),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _coutCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.coutTotal, suffixText: 'DA'),
              validator: (v) =>
                (v == null || v.isEmpty) ? context.l10n.requis : null,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _deductible,
              onChanged: (v) => setState(() => _deductible = v),
              title: Text(context.l10n.deduireDuProfitAvantRepartition),
              subtitle: Text(context.l10n.seraDeduitDesRevenusDuVehicule, style: AppTextStyles.label),
            ),
            const SizedBox(height: 4),
            Text(context.l10n.payeePar, style: AppTextStyles.label),
            const SizedBox(height: 6),
            Builder(builder: (context) {
              final profiles = ref.watch(usersProvider).valueOrNull ?? [];
              final coutSaisi = double.tryParse(_coutCtrl.text) ?? 0;
              final sommePayeurs = _payeurs.fold<double>(
                0, (s, p) => s + (double.tryParse(p.montantCtrl.text) ?? 0));
              final ecart = coutSaisi - sommePayeurs;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (int i = 0; i < _payeurs.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _payeurs[i].type == 'showroom'
                                ? 'showroom'
                                : 'proprietaire:${_payeurs[i].proprietaireId}',
                            isExpanded: true,
                            decoration: InputDecoration(labelText: context.l10n.payeur),
                            items: [
                              DropdownMenuItem(
                                  value: 'showroom', 
                                  child: Text(context.l10n.showroomCaisse)),
                              ...profiles.map((p) => DropdownMenuItem(
                                    value: 'proprietaire:${p.id}',
                                    child: Text(
                                      '${p.fullName} ${context.l10n.aRembourser}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )),
                            ],
                            onChanged: (v) => setState(() {
                              if (v == null || v == 'showroom') {
                                _payeurs[i].type = 'showroom';
                                _payeurs[i].proprietaireId = null;
                              } else {
                                _payeurs[i].type = 'proprietaire';
                                _payeurs[i].proprietaireId = v.split(':').last;
                              }
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _payeurs[i].montantCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.l10n.champMontant, 
                              suffixText: 'DA'
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) => (v == null || v.isEmpty || double.tryParse(v) == null)
                                ? context.l10n.requis : null,
                          ),
                        ),
                        if (_payeurs.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.retard),
                            onPressed: () => setState(() => _payeurs.removeAt(i)),
                          ),
                      ]),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _payeurs[i].debiteurId == null
                            ? 'prorata'
                            : 'responsable:${_payeurs[i].debiteurId}',
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.l10n.doitSupporterMontant,
                          helperText: context.l10n.helperDebiteur,
                          helperMaxLines: 2,
                        ),
                        items: [
                          DropdownMenuItem(
                              value: 'prorata',
                              child: Text(context.l10n.coProprietairesParDefaut)),
                          ...profiles.map((p) => DropdownMenuItem(
                                value: 'responsable:${p.id}',
                                child: Text(p.fullName, overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) => setState(() {
                          _payeurs[i].debiteurId =
                              (v == null || v == 'prorata') ? null : v.split(':').last;
                        }),
                      ),
                    ]),
                  ),
                Row(children: [
                  TextButton.icon(
                    onPressed: () => setState(
                        () => _payeurs.add(_PayeurRow(type: 'showroom'))),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.l10n.ajouterPayeur),
                  ),
                  const Spacer(),
                  if (coutSaisi > 0 && ecart.abs() > 0.5)
                    Text(
                      ecart > 0
                          ? '${context.l10n.reste} ${ecart.toStringAsFixed(0)} DA'
                          : '${context.l10n.depasse} ${(-ecart).toStringAsFixed(0)} DA',
                      style: const TextStyle(color: AppColors.retard, fontSize: 12),
                    ),
                ]),
              ]);
            }),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _changerStatut,
              onChanged: (v) => setState(() => _changerStatut = v),
              title: Text(context.l10n.passerLeVehiculeEnReparation),
              subtitle: Text(context.l10n.indisponibleALaLocationPendantLes, style: AppTextStyles.label),
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
                  ? context.l10n.enregistrementEnCours
                  : (widget.isEdit 
                      ? context.l10n.enregistrerModifications 
                      : context.l10n.enregistrerReparation)),
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

    for (final p in _payeurs) {
      if (p.type == 'proprietaire' && p.proprietaireId == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.choisirProprietairePaiement),
          backgroundColor: AppColors.retard));
        return;
      }
    }

    final cout = double.parse(_coutCtrl.text);
    final sommePayeurs = _payeurs.fold<double>(
        0, (s, p) => s + (double.tryParse(p.montantCtrl.text) ?? 0));
    if ((cout - sommePayeurs).abs() > 0.5) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.erreurSommePaiements(
          sommePayeurs.toStringAsFixed(0),
          cout.toStringAsFixed(0),
        )),
        backgroundColor: AppColors.retard));
      return;
    }
    

    setState(() => _loading = true);
    try {
      final repo = ref.read(reparationsRepositoryProvider);
      final currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      // Payeur "principal" conservé pour compatibilité (1ère ligne) : les
      // écrans/rapports qui liraient encore l'ancien champ voient une valeur
      // cohérente ; la vraie répartition vit dans reparation_paiements.
      final principal = _payeurs.first;
      final baseData = {
        'vehicule_id':    _vehicule!.id,
        'type_rep':       _type,
        'description':    _descCtrl.text.trim(),
        'prestataire':    _prestataireCtrl.text.trim().isEmpty
                           ? null : _prestataireCtrl.text.trim(),
        'cout':           cout,
        'km_au_moment':   int.tryParse(_kmCtrl.text),
        'deductible':     _deductible,
        'payee_par':      principal.type,
        // Toujours envoyé (même null) pour bien effacer l'ancien payeur si on
        // repasse de "propriétaire" à "showroom" lors d'une modification.
        'proprietaire_payeur_id': principal.type == 'proprietaire' ? principal.proprietaireId : null,
        'statut_vehicule': _changerStatut,
      };
      final paiementsPayload = [
        for (final p in _payeurs)
          {
            'payeur_type': p.type,
            'proprietaire_id': p.type == 'proprietaire' ? p.proprietaireId : null,
            'montant': double.parse(p.montantCtrl.text),
            'debiteur_id': p.debiteurId,
          },
      ];

      if (widget.isEdit) {
        await repo.update(widget.existing!.id, baseData,
            paiements: paiementsPayload, createdBy: currentUserId);
      } else {
        await repo.create({
          ...baseData,
          'date_rep':   DateTime.now().toIso8601String().substring(0, 10),
          'created_by': currentUserId,
        }, paiements: paiementsPayload, createdBy: currentUserId);
      }
      ref.invalidate(reparationsProvider);
      ref.invalidate(vehiculesProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isEdit
            ? context.l10n.reparationModifiee
            : context.l10n.reparationEnregistree)));
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

/// Ligne éditable du formulaire : un payeur + le montant qu'il a payé,
/// et éventuellement un responsable désigné (si différent de la
/// répartition par défaut entre copropriétaires).
class _PayeurRow {
  String type; // 'showroom' | 'proprietaire'
  String? proprietaireId;
  String? debiteurId; // null = répartition par défaut (prorata copropriétaires)
  final TextEditingController montantCtrl;

  _PayeurRow({
    required this.type,
    this.proprietaireId,
    this.debiteurId,
    TextEditingController? montantCtrl,
  }) : montantCtrl = montantCtrl ?? TextEditingController();
}