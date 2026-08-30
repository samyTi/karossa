// lib/features/contrats/presentation/contrat_location_champs_screen.dart
//
// Écran permettant au showroom de choisir quels champs apparaissent sur le
// contrat de location (les deux modèles : standard et classique). Les choix
// sont sauvegardés dans showrooms.contrat_location_champs (jsonb) et lus par
// ContratOrchestrator au moment de la génération du PDF.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/contrat_location_champs.dart';
import 'contrats_provider.dart';

class ContratLocationChampsScreen extends ConsumerStatefulWidget {
  const ContratLocationChampsScreen({super.key});

  @override
  ConsumerState<ContratLocationChampsScreen> createState() =>
      _ContratLocationChampsScreenState();
}

class _ContratLocationChampsScreenState
    extends ConsumerState<ContratLocationChampsScreen> {
  Map<String, bool>? _champs; // état local en cours d'édition
  bool _saving = false;
  bool _dirty = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contratLocationChampsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Champs du contrat de location'),
        actions: [
          IconButton(
            tooltip: 'Réinitialiser aux valeurs par défaut',
            icon: const Icon(Icons.restart_alt),
            onPressed: _champs == null
                ? null
                : () => setState(() {
                      _champs = Map<String, bool>.from(ContratLocationChamps.defaults);
                      _dirty = true;
                    }),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur de chargement : $e')),
        data: (loaded) {
          _champs ??= Map<String, bool>.from(loaded);
          return _buildBody();
        },
      ),
      bottomNavigationBar: _champs == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: (_dirty && !_saving) ? _save : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    final champs = _champs!;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            "Choisissez les informations à faire apparaître sur le contrat de "
            "location (modèles standard et classique). Ces réglages "
            "s'appliquent à tous les contrats générés par ce showroom.",
            style: TextStyle(color: Colors.black54),
          ),
        ),
        for (final section in ContratLocationChamps.sectionsOrder) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              section,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          for (final def in ContratLocationChamps.forSection(section))
            SwitchListTile(
              dense: true,
              title: Text(def.label),
              subtitle: def.templateScope != null
                  ? Text(
                      'Modèle ${def.templateScope == 'classique' ? 'classique' : 'standard'} uniquement',
                      style: const TextStyle(fontSize: 11, color: Colors.black45),
                    )
                  : null,
              value: champs[def.key] ?? def.defaultValue,
              onChanged: (v) => setState(() {
                champs[def.key] = v;
                _dirty = true;
              }),
            ),
          const Divider(height: 1),
        ],
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(contratsRepositoryProvider)
          .updateContratLocationChamps(_champs!);
      ref.invalidate(contratLocationChampsProvider);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réglages du contrat enregistrés.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'enregistrement : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
