// lib/features/contrats/presentation/widgets/contrat_card.dart
//
// CORRECTION : PdfGenerator (stub corrompu) remplacé par ContratGeneratorService.
// StatelessWidget → ConsumerWidget pour accéder à ref (Riverpod).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../data/contrat_model.dart';
import '../../../../core/services/contrat_generator_service.dart';

class ContratCard extends ConsumerWidget {
  final ContratModel contrat;

  const ContratCard({super.key, required this.contrat});

  Future<void> _handlePdf(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text('Génération du PDF…'),
        ]),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      // Si un PDF est déjà disponible en mémoire on le partage directement
      if (contrat.pdfData != null) {
        final dir  = await getTemporaryDirectory();
        final file = File('${dir.path}/contrat_${contrat.id}.pdf');
        await file.writeAsBytes(contrat.pdfData!);

        messenger.hideCurrentSnackBar();
        if (context.mounted) {
          await ContratGeneratorService.partager(context, file);
          messenger.showSnackBar(
            const SnackBar(content: Text('Contrat partagé ✓')),
          );
        }
        return;
      }

      // Pas de pdfData : la génération complète se fait depuis les écrans
      // dédiés (location / vente / echange form screens) via generateAndShare*.
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Ouvre le détail du contrat pour générer le PDF complet.'),
          ),
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Erreur PDF : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(contrat.clientNom),
        subtitle: Text('${contrat.vehicule} — ${contrat.prix.toStringAsFixed(0)} DA'),
        trailing: IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          tooltip: 'Générer PDF',
          onPressed: () => _handlePdf(context, ref),
        ),
      ),
    );
  }
}
