// lib/core/services/pdf/pdf_layout.dart
//
// Widgets pw.* partagés par tous les générateurs PDF.
// Chaque méthode est statique et prend les paramètres minimaux nécessaires.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_theme.dart';

class PdfLayout {
  PdfLayout._();

  // ── En-tête standard (FR) ──────────────────────────────────────────────────

  static pw.Widget header({
    required String agenceNom,
    required String agenceAdresse,
    required String agenceTel,
    String?         agenceEmail,
    String?         agenceRc,
    pw.ImageProvider? logoImage,
    required String titreContrat,
    required String numero,
    required DateTime date,
    DateTime?       dateEtablissement,
    required PdfColor color,
  }) {
    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Gauche : logo + infos agence
            pw.Row(children: [
              if (logoImage != null) ...[
                pw.Container(
                  width: 44, height: 44,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 8),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(agenceNom,
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold)),
                  if (agenceAdresse.isNotEmpty)
                    pw.Text(agenceAdresse,
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 8)),
                  pw.Text(
                    [
                      if (agenceTel.isNotEmpty) 'Tél : $agenceTel',
                      if ((agenceEmail ?? '').isNotEmpty) agenceEmail!,
                    ].join('  |  '),
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 8),
                  ),
                  if ((agenceRc ?? '').isNotEmpty)
                    pw.Text('RC : $agenceRc',
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 8)),
                ],
              ),
            ]),
            // Droite : titre + numéro + date
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(titreContrat,
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('N° $numero',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(PdfTheme.fmtDate(date),
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 9)),
                if (dateEtablissement != null)
                  pw.Text(
                      'Établi le ${PdfTheme.fmtDateLong(dateEtablissement)}',
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 8)),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
    ]);
  }

  // ── Pied de page standard ──────────────────────────────────────────────────

  static pw.Widget footer({
    required String agenceNom,
    required String agenceTel,
    required pw.Context ctx,
  }) {
    return pw.Column(children: [
      pw.Divider(color: PdfColors.grey300, thickness: 0.5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '$agenceNom${agenceTel.isNotEmpty ? '  |  Tél : $agenceTel' : ''}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${ctx.pageNumber}/${ctx.pagesCount}  —  '
            'Généré le ${PdfTheme.fmtDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    ]);
  }

  // ── Titre de section ───────────────────────────────────────────────────────

  static pw.Widget sectionTitle(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold)),
    );
  }

  // ── Tableau 2 colonnes ─────────────────────────────────────────────────────

  static pw.Widget twoColTable({
    required List<List<String>> left,
    required List<List<String>> right,
    required PdfColor color,
    required PdfColor light,
    double labelWidth = 82,
  }) {
    pw.Widget cell(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Row(children: [
            pw.SizedBox(
              width: labelWidth,
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700)),
            ),
            pw.Flexible(
              child: pw.Text(
                value.isEmpty ? '—' : value,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ]),
        );

    pw.Widget col(List<List<String>> rows) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: rows.map((r) => cell(r[0], r[1])).toList(),
          ),
        );

    return pw.Row(children: [
      pw.Expanded(child: col(left)),
      pw.SizedBox(width: 6),
      pw.Expanded(child: col(right)),
    ]);
  }

  // ── Ligne d'info sur une ligne ─────────────────────────────────────────────

  static pw.Widget oneLineInfo(
      String label, String value, PdfColor color, PdfColor light) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 80,
          child: pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
        ),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
      ]),
    );
  }

  // ── Bloc conditions / articles ─────────────────────────────────────────────

  static pw.Widget articlesBlock(
    List<Map<String, String>> articles, {
    List<Map<String, String>>? defaultClauses,
  }) {
    final clauses =
        articles.isNotEmpty ? articles : (defaultClauses ?? []);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
        color: const PdfColor(0.98, 0.98, 0.99),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: clauses.map((c) {
          final titre = c['titre'] ?? '';
          final corps = c['corps'] ?? '';
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (titre.isNotEmpty)
                  pw.Text(titre,
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800)),
                if (corps.isNotEmpty)
                  pw.Text(corps,
                      style: const pw.TextStyle(
                          fontSize: 8.5, color: PdfColors.grey700),
                      textAlign: pw.TextAlign.justify),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Bloc signatures (2 colonnes) ───────────────────────────────────────────

  static pw.Widget signatures({
    required String labelGauche,
    required String nomGauche,
    required String labelDroite,
    required String nomDroite,
    required PdfColor color,
    required PdfColor light,
  }) {
    pw.Widget sigBox(String label, String nom) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
              color: light,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label,
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: color)),
                pw.Text('Lu et approuvé — $nom',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
                pw.SizedBox(height: 40),
                pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                pw.Text('Date : _______________',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey500)),
              ],
            ),
          ),
        );

    return pw.Row(children: [
      sigBox(labelGauche, nomGauche),
      pw.SizedBox(width: 10),
      sigBox(labelDroite, nomDroite),
    ]);
  }

  // ── Cellules de tableau (header / data) ────────────────────────────────────

  static pw.Widget tableHeaderCell(String text, PdfColor color) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        color: color,
        child: pw.Center(
          child: pw.Text(text,
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold)),
        ),
      );

  static pw.Widget tableDataCell(
    String text, {
    bool isLabel = false,
    bool isBold = false,
    PdfColor? labelColor,
    PdfColor? labelBg,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        color: isLabel ? (labelBg ?? PdfColors.white) : PdfColors.white,
        child: pw.Center(
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: (isLabel || isBold) ? pw.FontWeight.bold : null,
                  color: isLabel
                      ? (labelColor ?? PdfColors.black)
                      : PdfColors.black)),
        ),
      );

  // ── Notes ──────────────────────────────────────────────────────────────────

  static pw.Widget notesBlock(String notes) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(notes,
            style: const pw.TextStyle(
                fontSize: 9, color: PdfColors.grey800)),
      );
}