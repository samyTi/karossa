// lib/features/contrats/presentation/contrat_card.dart
//
// ⚠️  FICHIER INUTILISÉ — NE PAS IMPORTER.
//
// Ce widget était basé sur ContratModel (un modèle générique jamais hydraté
// depuis Supabase). Il a été remplacé par _ContratTile dans contrats_screen.dart
// qui travaille directement sur les Maps retournées par Supabase.
//
// Conservé pour éviter des erreurs de compilation si une référence persiste
// ailleurs dans le projet. Peut être supprimé lors d'un refactoring futur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/contrat_model.dart';

@Deprecated('Utiliser _ContratTile dans contrats_screen.dart')
class ContratCard extends ConsumerWidget {
  final ContratModel contrat;
  const ContratCard({super.key, required this.contrat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(contrat.clientNom),
        subtitle: Text('${contrat.vehicule} — ${contrat.prix.toStringAsFixed(0)} DA'),
      ),
    );
  }
}