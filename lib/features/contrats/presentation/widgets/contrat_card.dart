import 'package:flutter/material.dart';
import '../../data/models/contrat_model.dart';
import '../../../../core/services/pdf_generator.dart';
import '../../../../core/services/file_service.dart';
import '../../../../core/services/share_service.dart';

class ContratCard extends StatelessWidget {
  final ContratModel contrat;

  const ContratCard({super.key, required this.contrat});

  Future<void> handlePdf(BuildContext context) async {
    final pdf = await PdfGenerator.generateContrat(
      client: contrat.clientNom,
      vehicule: contrat.vehicule,
      prix: contrat.prix,
    );

    final file = await FileService.savePdf(pdf, 'contrat_${contrat.id}');

    await ShareService.shareFile(file.path);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contrat généré')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(contrat.clientNom),
        subtitle: Text('${contrat.vehicule} - ${contrat.prix} DA'),
        trailing: IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          onPressed: () => handlePdf(context),
        ),
      ),
    );
  }
}