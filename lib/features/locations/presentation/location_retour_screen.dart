import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/location_model.dart';
import 'locations_provider.dart';
import '../../vehicules/presentation/vehicules_provider.dart';

class LocationRetourScreen extends ConsumerStatefulWidget {
  final String locationId;
  const LocationRetourScreen({super.key, required this.locationId});
  @override
  ConsumerState<LocationRetourScreen> createState() => _State();
}

class _State extends ConsumerState<LocationRetourScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  final _kmCtrl      = TextEditingController();
  final _retenueCtrl = TextEditingController(text: '0');
  final _notesCtrl   = TextEditingController();

  Location? _location;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final loc = await ref.read(locationsRepositoryProvider).getById(widget.locationId);
      setState(() => _location = loc);
    } catch (e) {
      // fallback: search in actives
      final list = await ref.read(locationsRepositoryProvider).getActives();
      final loc = list.cast<Location?>().firstWhere(
        (l) => l?.id == widget.locationId, orElse: () => null);
      if (loc != null) setState(() => _location = loc);
    }
  }

  double get _montant {
    if (_location == null) return 0;
    final jours = DateTime.now()
      .difference(_location!.dateDebut).inDays.clamp(1, 9999);
    return _location!.prixJour * jours;
  }

  @override
  Widget build(BuildContext context) {
    if (_location == null) {
      return Scaffold(
      appBar: AppBar(title: const Text('Retour vehicule')),
      body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Enregistrer le retour')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info location
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_location!.vehiculeNom ?? '---',
                    style: AppTextStyles.heading3),
                  Text(_location!.clientNom ?? '---',
                    style: AppTextStyles.bodySecondary),
                  Text(
                    'Depart : ${_location!.dateDebut.day}'
                    '/${_location!.dateDebut.month}'
                    '/${_location!.dateDebut.year}'
                    '  |  Km depart : ${_location!.kmDepart} km',
                    style: AppTextStyles.label),
                  if (_location!.isOverdue)
                    Text(
                      'RETARD : ${_location!.joursRetard} jour(s)',
                      style: const TextStyle(
                        color: AppColors.retard,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('Details du retour', style: AppTextStyles.heading3),
            const SizedBox(height: 10),
            TextFormField(
              controller: _kmCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kilometrage au retour',
                suffixText: 'km'),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requis';
                final km = int.tryParse(v);
                if (km == null) return 'Invalide';
                if (km < _location!.kmDepart) {
                  return 'Inférieur au km de départ';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _retenueCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Retenue sur caution (dommages)',
                suffixText: 'DA'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Etat du vehicule au retour'),
            ),
            const SizedBox(height: 20),

            // Recap financier
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.2))),
              child: Column(children: [
                _r('Montant total', '${_montant.toInt()} DA',
                  bold: true),
                _r('Caution versee',
                  '${_location!.caution.toInt()} DA'),
                _r('Retenue caution',
                  '- ${int.tryParse(_retenueCtrl.text) ?? 0} DA',
                  color: AppColors.retard),
                const Divider(height: 14),
                _r('Caution a restituer',
                  '${(_location!.caution - (double.tryParse(_retenueCtrl.text) ?? 0)).toInt()} DA',
                  bold: true, color: AppColors.secondary),
              ]),
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
                  : const Icon(Icons.check),
                label: Text(_loading
                  ? 'Enregistrement...' : 'Valider le retour'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

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
          fontSize: bold ? 15 : 13,
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.textPrimary)),
      ],
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(locationsRepositoryProvider).cloturerLocation(
        locationId:     widget.locationId,
        kmRetour:       int.parse(_kmCtrl.text),
        retenueCaution: double.tryParse(_retenueCtrl.text) ?? 0,
        notesRetour:    _notesCtrl.text.trim().isEmpty
                          ? null : _notesCtrl.text.trim(),
      );
      // Remettre le véhicule disponible
      if (_location?.vehiculeId != null) {
        await ref.read(supabaseClientProvider).from('vehicules')
          .update({'statut': 'disponible'})
          .eq('id', _location!.vehiculeId);
      }
      ref.invalidate(locationsActivesProvider);
      ref.invalidate(locationsRetardProvider);
      ref.invalidate(vehiculesProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Retour enregistre. Repartition calculee.'),
            backgroundColor: AppColors.secondary));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'),
          backgroundColor: AppColors.retard));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}