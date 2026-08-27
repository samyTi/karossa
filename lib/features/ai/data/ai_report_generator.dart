// lib/features/ai/data/ai_report_generator.dart
//
// Met en page AiReportData en PDF. Utilise `pdf` (déjà présent dans le
// projet pour les contrats location/vente/échange) + `printing` pour
// partager/imprimer directement, sans dépendance supplémentaire à gérer
// manuellement (pas d'écriture disque nécessaire).
//
// pubspec.yaml (si pas déjà présent) :
//   pdf: ^3.10.0
//   printing: ^5.12.0

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/ai_report_data.dart';

class AiReportGenerator {
  static Future<void> generateAndShare(
    AiReportData data, {
    required String showroomNom,
  }) async {
    final doc = pw.Document();
    final resume = data.resume;
    final caisse = (resume['caisse_ce_mois_da'] as Map?) ?? {};
    final parStatut = (resume['parc_par_statut'] as Map?) ?? {};

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(showroomNom,
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(data.titre,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text(data.periode, style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
          pw.Divider(height: 24),

          pw.Text('Synthèse', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(_stripMarkdown(data.narratif), style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)),
          pw.SizedBox(height: 20),

          pw.Text('Chiffres clés', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _kpiTable({
            'Locations en cours': '${resume['locations_en_cours'] ?? 0}',
            'CA ventes (ce mois)': '${_fmt(resume['chiffre_affaires_ventes_ce_mois_da'])} DA',
            'CA locations (ce mois)': '${_fmt(resume['chiffre_affaires_locations_ce_mois_da'])} DA',
            'Caisse — entrées': '${_fmt(caisse['entrees'])} DA',
            'Caisse — sorties': '${_fmt(caisse['sorties'])} DA',
            'Caisse — solde': '${_fmt(caisse['solde'])} DA',
            "Alertes d'entretien actives": '${resume['alertes_entretien_actives'] ?? 0}',
          }),
          pw.SizedBox(height: 20),

          if (parStatut.isNotEmpty) ...[
            pw.Text('Parc par statut', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _kpiTable(parStatut.map((k, v) => MapEntry(k.toString(), v.toString()))),
            pw.SizedBox(height: 20),
          ],

          if (data.anomalies.isNotEmpty) ...[
            pw.Text('Anomalies détectées', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1),
              },
              children: [
                _rowHeader(['Catégorie', 'Ce mois vs moyenne 3 mois', 'Écart']),
                for (final a in data.anomalies)
                  _row([
                    '${a['categorie']} (${a['type']})',
                    '${_fmt(a['montant_mois_courant_da'])} DA vs ${_fmt(a['moyenne_3_mois_precedents_da'])} DA',
                    '${a['variation_pct']}%',
                  ]),
              ],
            ),
          ],

          pw.SizedBox(height: 24),
          pw.Text('Généré automatiquement par KarossaAI — ${DateTime.now().toString().substring(0, 16)}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'rapport-karossaai-${data.periode.replaceAll(' ', '-').toLowerCase()}.pdf',
    );
  }

  static pw.Widget _kpiTable(Map<String, String> kv) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1)},
      children: kv.entries
          .map((e) => pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 10)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(e.value,
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
              ]))
          .toList(),
    );
  }

  static pw.TableRow _rowHeader(List<String> cells) => pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: cells
            .map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(c, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ))
            .toList(),
      );

  static pw.TableRow _row(List<String> cells) => pw.TableRow(
        children: cells
            .map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(c, style: const pw.TextStyle(fontSize: 9)),
                ))
            .toList(),
      );

  static String _fmt(dynamic v) {
    if (v == null) return '0';
    final n = (v is num) ? v : num.tryParse(v.toString()) ?? 0;
    return n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
  }

  static String _stripMarkdown(String text) =>
      text.replaceAll(RegExp(r'[*#`_]'), '');
}