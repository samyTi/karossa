import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class AchatPdfBuilder {
  // Constructeur privé pour empêcher l'instanciation
  AchatPdfBuilder._();

  static pw.Document build({
    required Map<String, dynamic> achatData,
    required Map<String, dynamic> settings,
  }) {
    final doc = pw.Document();
    final format = NumberFormat('#,###', 'fr_FR');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(settings),
              pw.SizedBox(height: 20),
              pw.Text('BON D\'ACHAT / REPRISE', 
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              _buildDetails(achatData, format),
              pw.Spacer(),
              _buildFooter(),
            ],
          );
        },
      ),
    );
    return doc;
  }

  static pw.Widget _buildHeader(Map<String, dynamic> settings) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(settings['nom'] ?? 'GARAGE AUTO', 
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now())),
      ],
    );
  }

  static pw.Widget _buildDetails(Map<String, dynamic> data, NumberFormat fmt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Véhicule : ${data['marque']} ${data['modele']} (${data['annee']})'),
        pw.Text('Kilométrage : ${data['kilometrage']} km'),
        pw.SizedBox(height: 10),
        pw.Text('Montant accordé : ${fmt.format(data['prix_achat'] ?? 0)} DA',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Text('Document généré par Karossa', 
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
    );
  }
}