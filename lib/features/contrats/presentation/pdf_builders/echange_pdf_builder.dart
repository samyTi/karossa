// lib/features/contrats/presentation/pdf_builders/echange_pdf_builder.dart
import 'package:pdf/pdf.dart';        // ✅ requis pour PdfColors
import 'package:pdf/widgets.dart' as pw;
import '../../domain/contrat_echange_dto.dart';

class EchangePdfBuilder {
  static pw.Document build(ContratEchangeDto dto) {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── En-tête ───────────────────────────────────────
              pw.Center(
                child: pw.Text(
                  "CONTRAT D'ÉCHANGE",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Réf : ${dto.echangeId}  —  ${_formatDate(dto.dateEtablissement)}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 20),

              // ── Parties ───────────────────────────────────────
              _section('AGENCE', [
                dto.agenceNom,
                dto.agenceAdresse,
                dto.agenceTel,
                if (dto.agenceEmail.isNotEmpty) dto.agenceEmail,
                if (dto.agenceRc.isNotEmpty) 'RC : ${dto.agenceRc}',
              ]),
              pw.SizedBox(height: 10),
              _section('CLIENT', [
                dto.clientNom,
                if (dto.clientTelephone.isNotEmpty) dto.clientTelephone,
                if (dto.clientAdresse != null) dto.clientAdresse!,
              ]),
              pw.SizedBox(height: 10),

              // ── Véhicules ─────────────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _section('VÉHICULE CÉDÉ', [
                      dto.vehiculeCedeInfos,
                      if (dto.vehiculeCedeImmat != null)
                        'Immat : ${dto.vehiculeCedeImmat}',
                      if (dto.vehiculeCedeKm != null)
                        'Km : ${dto.vehiculeCedeKm}',
                    ]),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _section('VÉHICULE REPRIS', [
                      dto.vehiculeReprisInfos,
                      if (dto.vehiculeReprisImmat != null)
                        'Immat : ${dto.vehiculeReprisImmat}',
                      if (dto.vehiculeReprisKm != null)
                        'Km : ${dto.vehiculeReprisKm}',
                    ]),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // ── Financier ─────────────────────────────────────
              _section('FINANCIER', [
                'Valeur reprise    : ${_formatMontant(dto.valeurReprise)}',
                'Complément client : ${_formatMontant(dto.complementClient)}',
                'Total             : ${_formatMontant(dto.montantTotal)}',
                if (dto.modePaiement != null)
                  'Mode de paiement  : ${dto.modePaiement}',
              ]),
              pw.SizedBox(height: 20),

              // ── Articles bilingues (côte à côte FR | AR) ──────
              if (dto.hasArticlesFr || dto.hasArticlesAr)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Colonne FR (LTR)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: dto.articlesFr
                            .map((a) => _article(a))      // ✅ Map<String,String>
                            .toList(),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    // Colonne AR (RTL)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: dto.articlesAr
                            .map((a) => _article(a))      // ✅ Map<String,String>
                            .toList(),
                      ),
                    ),
                  ],
                ),

              if (dto.notes != null && dto.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                _section('NOTES', [dto.notes!]),
              ],

              pw.SizedBox(height: 30),

              // ── Signatures ────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _signature('Le Vendeur'),
                  _signature("L'Acheteur"),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  // ── Helpers ───────────────────────────────────────────────

  /// Rend un article {'titre': ..., 'corps': ...} en bloc PDF.
  static pw.Widget _article(Map<String, String> a) {
    final titre = a['titre'] ?? '';
    final corps = a['corps'] ?? '';
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (titre.isNotEmpty)
            pw.Text(
              titre,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          if (corps.isNotEmpty)
            pw.Text(
              corps,
              style: const pw.TextStyle(fontSize: 8),
            ),
        ],
      ),
    );
  }

  /// Rend un bloc section avec titre et lignes de contenu.
  static pw.Widget _section(String titre, List<String> lignes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          titre,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Divider(thickness: 0.5),
        ...lignes.map(
          (l) => pw.Text(l, style: const pw.TextStyle(fontSize: 8)),
        ),
      ],
    );
  }

  /// Rend un bloc signature avec ligne et libellé.
  static pw.Widget _signature(String label) {
    return pw.Column(
      children: [
        pw.Container(width: 120, height: 40),
        pw.Container(width: 120, height: 0.5, color: PdfColors.black),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  static String _formatMontant(double m) =>
      '${m.toStringAsFixed(2).replaceAll('.', ',')} DA';
}