// lib/features/contrats/presentation/contrat_tile.dart
//
// ⚠️  FICHIER INUTILISÉ — NE PAS IMPORTER.
//
// Ce widget est un doublon de _ContratTile (privé) dans contrats_screen.dart.
// Il n'est importé par aucun autre fichier et peut être supprimé lors d'un
// refactoring futur. Le type `dynamic` pour `type` empêche une compilation
// sûre si réutilisé tel quel.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';

@Deprecated('Doublon de _ContratTile dans contrats_screen.dart')
class ContratTile extends StatelessWidget {
  // ignore: annotate_overrides
  final dynamic type;
  final Map<String, dynamic> data;
  final VoidCallback onGeneratePdf;

  const ContratTile({
    super.key,
    required this.type,
    required this.data,
    required this.onGeneratePdf,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasPdf = (data['contrat_pdf_url'] as String?)?.isNotEmpty == true;
    final dateStr = data['created_at'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(data['created_at']))
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: ListTile(
        title: Text(data['clients']?['nom'] ?? 'Client inconnu'),
        subtitle: Text('${data['vehicules']?['immatriculation'] ?? context.l10n.vehicule} • $dateStr'),
        trailing: IconButton(
          icon: Icon(Icons.picture_as_pdf,
              color: hasPdf ? AppColors.success : AppColors.textHint),
          onPressed: onGeneratePdf,
        ),
      ),
    );
  }
}