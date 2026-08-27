// lib/features/contrats/presentation/widgets/contrat_location_template_picker.dart
//
// Boîte de dialogue simple permettant de choisir, au moment de la
// génération du PDF, quel habillage de contrat de location utiliser.

import 'package:flutter/material.dart';
import '../../domain/contrat_location_dto.dart';

/// Affiche une boîte de dialogue de choix de template et retourne le
/// template sélectionné, ou `null` si l'utilisateur a annulé.
Future<ContratLocationTemplate?> showContratLocationTemplatePicker(
  BuildContext context,
) {
  return showDialog<ContratLocationTemplate>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Choisir un modèle de contrat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TemplateTile(
            title: 'Modèle standard',
            subtitle: 'Mise en page actuelle (tableau départ/retour, checklist).',
            icon: Icons.description_outlined,
            onTap: () => Navigator.of(ctx).pop(ContratLocationTemplate.standard),
          ),
          const SizedBox(height: 8),
          _TemplateTile(
            title: 'Modèle classique',
            subtitle: 'Locataire/Loueur en 2 colonnes, jauge carburant, compte rendu de fin de location.',
            icon: Icons.article_outlined,
            onTap: () => Navigator.of(ctx).pop(ContratLocationTemplate.classique),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Annuler'),
        ),
      ],
    ),
  );
}

class _TemplateTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _TemplateTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
