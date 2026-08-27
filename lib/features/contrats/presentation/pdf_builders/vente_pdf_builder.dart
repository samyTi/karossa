import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../domain/contrat_vente_dto.dart';

class VentePdfBuilder {
  static pw.Document build(ContratVenteDto dto) {
    final doc = pw.Document();
    final fmt = NumberFormat('#,###', 'fr');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header avec les infos Agence
              _buildHeader(dto),
              pw.SizedBox(height: 20),
              
              pw.Text('CONTRAT DE VENTE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              
              // Informations Client et Véhicule
              _buildInfoSection("VENDEUR", dto.agenceNom, dto.agenceAdresse),
              _buildInfoSection("ACHETEUR", "${dto.acheteurNom} ${dto.acheteurPrenom}", dto.acheteurAdresse ?? ""),
              
              pw.SizedBox(height: 10),
              pw.Text("VÉHICULE : ${dto.vehiculeMarque} ${dto.vehiculeModele}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text("Immatriculation : ${dto.vehiculeImmatriculation}"),
              
              pw.SizedBox(height: 20),
              
              // Résumé financier
              _buildFinancialTable(dto, fmt),
            ],
          );
        },
      ),
    );
    return doc;
  }

  static pw.Widget _buildHeader(ContratVenteDto dto) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(dto.agenceNom, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(dto.dateEtablissement)}"),
    ],
  );

  static pw.Widget _buildInfoSection(String title, String name, String addr) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      pw.Text(name),
      pw.Text(addr, style: const pw.TextStyle(fontSize: 9)),
    ])
  );

  static pw.Widget _buildFinancialTable(ContratVenteDto dto, NumberFormat fmt) => pw.Table.fromTextArray(
    headers: ["Désignation", "Montant (DA)"],
    data: [
      ["Prix de vente", fmt.format(dto.prixVente)],
      ["Acompte versé", fmt.format(dto.acompteVerse)],
      ["Solde restant", fmt.format(dto.soldeRestant)],
    ],
  );
}