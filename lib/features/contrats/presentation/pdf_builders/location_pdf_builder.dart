import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class LocationPdfBuilder {
  LocationPdfBuilder._();

  static pw.Document build({
    required Map<String, dynamic> locationData, // Données de la location (bdd)
    required Map<String, dynamic> settings,     // Infos agence
  }) {
    final doc = pw.Document();
    final fmt = NumberFormat('#,###', 'fr_FR');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(settings),
              pw.SizedBox(height: 20),
              pw.Text('CONTRAT DE LOCATION', 
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              
              _buildSectionTitle('INFORMATIONS LOCATION'),
              pw.Text('Date de début : ${locationData['date_debut']}'),
              pw.Text('Date de fin : ${locationData['date_fin_prevue']}'),
              pw.Text('Prix par jour : ${fmt.format(locationData['prix_jour'])} DA'),
              
              pw.SizedBox(height: 15),
              _buildSectionTitle('DÉTAILS FINANCIERS'),
              _buildFinancialSummary(locationData, fmt),
              
              pw.Spacer(),
              _buildFooter(),
            ],
          );
        },
      ),
    );
    return doc;
  }

  static pw.Widget _buildHeader(Map<String, dynamic> settings) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(settings['nom'] ?? 'GARAGE AUTO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text('Contrat N° ${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}'),
    ],
  );

  static pw.Widget _buildSectionTitle(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 10, bottom: 5),
    child: pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey)),
  );

  static pw.Widget _buildFinancialSummary(Map<String, dynamic> data, NumberFormat fmt) => pw.Table.fromTextArray(
    border: pw.TableBorder.all(width: 0.5),
    headers: ['Libellé', 'Montant'],
    data: [
      ['Montant Brut', '${fmt.format(data['montant_brut'])} DA'],
      ['Caution', '${fmt.format(data['caution'])} DA'],
    ],
  );

  static pw.Widget _buildFooter() => pw.Center(
    child: pw.Text('Document certifié - Karossa', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
  );
}