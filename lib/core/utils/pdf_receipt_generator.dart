// lib/core/utils/pdf_receipt_generator.dart
// Génère un reçu PDF pour les opérations de caisse

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfReceiptGenerator {
  static final _dateFormat  = DateFormat('dd/MM/yyyy HH:mm', 'fr');
  static final _moneyFormat = NumberFormat('#,###', 'fr');

  static pw.Document buildRecuCaisse({
    required String operationId,
    required String type,         // 'entree' | 'sortie'
    required String categorie,
    required double montant,
    required String description,
    required DateTime dateOp,
    String? vehiculeNom,
    Map<String, dynamic>? showroom,
  }) {
    final doc   = pw.Document();
    final color = type == 'entree'
      ? const PdfColor(0.11, 0.62, 0.46)   // vert
      : const PdfColor(0.89, 0.29, 0.29);  // rouge
    final sh = showroom ?? {'nom': 'Garage Auto'};

    doc.addPage(pw.Page(
      pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity,
          marginAll: 8 * PdfPageFormat.mm),
      build: (ctx) => pw.Column(
        children: [
          // En-tête
          pw.Text(sh['nom'] ?? 'Garage Auto',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center),
          if ((sh['adresse'] ?? '').isNotEmpty)
            pw.Text(sh['adresse'],
              style: const pw.TextStyle(fontSize: 9),
              textAlign: pw.TextAlign.center),
          if ((sh['tel'] ?? '').isNotEmpty)
            pw.Text('Tél : ${sh['tel']}',
              style: const pw.TextStyle(fontSize: 9),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.SizedBox(height: 4),

          // Titre reçu
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              type == 'entree' ? 'REÇU D\'ENTRÉE' : 'BON DE SORTIE',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 13),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 10),

          // Infos
          _row('N° Reçu', operationId.substring(0, 8).toUpperCase()),
          _row('Date', _dateFormat.format(dateOp)),
          _row('Catégorie', _formatCategorie(categorie)),
          if (vehiculeNom != null) _row('Véhicule', vehiculeNom),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.SizedBox(height: 8),

          // Description
          pw.Text('Description :',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(description,
            style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          pw.Divider(thickness: 1.5),
          pw.SizedBox(height: 8),

          // Montant
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('MONTANT',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              pw.Text('${_moneyFormat.format(montant)} DA',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16, color: color)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Text('Merci de conserver ce reçu.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center),
        ],
      ),
    ));
    return doc;
  }

  static pw.Widget _row(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(k,
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700,
            fontWeight: pw.FontWeight.bold)),
        pw.Text(v, style: const pw.TextStyle(fontSize: 10)),
      ],
    ),
  );

  static String _formatCategorie(String cat) {
    final map = {
      'loyer_location': 'Loyer / Location',
      'vente_vehicule': 'Vente véhicule',
      'echange': 'Échange',
      'reparation': 'Réparation',
      'entretien': 'Entretien',
      'carburant': 'Carburant',
      'assurance': 'Assurance',
      'controle_technique': 'Contrôle technique',
      'lavage': 'Lavage',
      'autre': 'Autre',
    };
    return map[cat] ?? cat;
  }
}
