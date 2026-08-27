//lib/core/services/pdf/recap_location_pdf_generator.dart
// Génère le récapitulatif financier INTERNE d'une location :
//   - Détails de la location
//   - Montants (brut, caution, paiements, solde)
//   - Répartition gérant / propriétaire(s) avec montants individuels
//   - Tableau des paiements reçus
//
// ⚠️ Document INTERNE — ne pas remettre au client.
//    Pour la facture client, utiliser FactureLocationPdfGenerator.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:garage_auto/core/extensions/l10n_extension.dart';
import 'pdf_theme.dart' hide debugPrint;

// ─────────────────────────────────────────────────────────────────────────────
// DTOs
// ─────────────────────────────────────────────────────────────────────────────

class RecapRepartitionDto {
  final String nom;
  final String typePart; // 'commission_gerant' | 'part_proprietaire'
  final double pourcentage;
  final double montant;

  const RecapRepartitionDto({
    required this.nom,
    required this.typePart,
    required this.pourcentage,
    required this.montant,
  });
}

class RecapLocationDto {
  final String locationId;
  final DateTime dateEmission;

  // Agence
  final String agenceNom;
  final String agenceAdresse;
  final String agenceTel;
  final String? agenceEmail;
  final String? agenceRc;
  final String agenceCouleurHex;

  // Location
  final String vehiculeNom;
  final String clientNom;
  final DateTime dateDebut;
  final DateTime? dateFinPrevue;
  final DateTime? dateFinReelle;
  final int nbJours;
  final double prixJour;
  final double montantBrut;
  final double caution;
  final double retenueCaution;
  final double totalPaiements;

  // Répartitions
  final List<RecapRepartitionDto> repartitions;

  const RecapLocationDto({
    required this.locationId,
    required this.dateEmission,
    required this.agenceNom,
    required this.agenceAdresse,
    required this.agenceTel,
    this.agenceEmail,
    this.agenceRc,
    this.agenceCouleurHex = '#10B981',
    required this.vehiculeNom,
    required this.clientNom,
    required this.dateDebut,
    this.dateFinPrevue,
    this.dateFinReelle,
    required this.nbJours,
    required this.prixJour,
    required this.montantBrut,
    this.caution = 0,
    this.retenueCaution = 0,
    required this.totalPaiements,
    this.repartitions = const [],
  });

  double get totalGerant => repartitions
      .where((r) => r.typePart == 'commission_gerant')
      .fold(0.0, (s, r) => s + r.montant);

  double get totalProprio => repartitions
      .where((r) => r.typePart == 'part_proprietaire')
      .fold(0.0, (s, r) => s + r.montant);

  double get solde => montantBrut - retenueCaution - totalPaiements;
}

// ─────────────────────────────────────────────────────────────────────────────
// GÉNÉRATEUR
// ─────────────────────────────────────────────────────────────────────────────

class RecapLocationPdfGenerator {
  RecapLocationPdfGenerator._();

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _id8(String id) =>
      (id.length >= 8 ? id.substring(0, 8) : id).toUpperCase();

  static PdfColor _hex(String hex) {
    try {
      final h = hex.replaceAll('#', '').trim();
      return PdfColor.fromInt(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const PdfColor.fromInt(0xFF10B981);
    }
  }

  static const PdfColor _gerantColor    = PdfColor.fromInt(0xFF8B5CF6);
  static const PdfColor _proprioColor   = PdfColor.fromInt(0xFF10B981);
  static const PdfColor _errorColor     = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor _successColor   = PdfColor.fromInt(0xFF10B981);
  static const PdfColor _warningColor   = PdfColor.fromInt(0xFFF59E0B);

  // ── Point d'entrée ────────────────────────────────────────────────────────

  static Future<pw.Document> build(RecapLocationDto dto) async {
    // Ce générateur ne chargeait aucune police (ni latine ni arabe) : un nom
    // de client saisi en arabe s'affichait donc en glyphes manquants.
    await PdfTheme.loadAllFonts();
    final doc    = pw.Document();
    final accent = _hex(dto.agenceCouleurHex);
    final light  = PdfColor(accent.red, accent.green, accent.blue, 0.08);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _header(dto, accent),
        footer: (ctx) => _footer(dto, ctx),
        build: (ctx) => [
          pw.SizedBox(height: 14),
          _watermarkBanner(ctx),
          pw.SizedBox(height: 14),
          _detailsBlock(dto, accent, light, ctx),
          pw.SizedBox(height: 14),
          _montantsBlock(dto, accent, ctx),
          pw.SizedBox(height: 14),
          _repartitionBlock(dto, accent, ctx),
          pw.SizedBox(height: 14),
          _soldeBlock(dto, accent, ctx),
        ],
      ),
    );

    return doc;
  }

  // ── En-tête ───────────────────────────────────────────────────────────────

  static pw.Widget _header(RecapLocationDto dto, PdfColor accent) {
    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: pw.BoxDecoration(
          color: accent,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(dto.agenceNom,
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold)),
                if (dto.agenceAdresse.isNotEmpty)
                  pw.Text(dto.agenceAdresse,
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 8)),
                pw.Text(
                  [
                    if (dto.agenceTel.isNotEmpty) 'Tél : ${dto.agenceTel}',
                    if ((dto.agenceEmail ?? '').isNotEmpty) dto.agenceEmail!,
                    if ((dto.agenceRc ?? '').isNotEmpty) 'RC : ${dto.agenceRc}',
                  ].join('  |  '),
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 8),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                    'RÉCAPITULATIF INTERNE', // À traduire via context plus tard
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    'Location — N° ${_id8(dto.locationId)}',
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                pw.Text(
                    'Émis le ${_d(dto.dateEmission)}',
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 8),
    ]);
  }

  // ── Pied de page ──────────────────────────────────────────────────────────

  static pw.Widget _footer(RecapLocationDto dto, pw.Context ctx) {
    return pw.Column(children: [
      pw.Divider(color: PdfColors.grey300, thickness: 0.5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('${dto.agenceNom} — Document confidentiel à usage interne',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    ]);
  }

  // ── Bannière "CONFIDENTIEL" ───────────────────────────────────────────────

  static pw.Widget _watermarkBanner(pw.Context ctx) {
    // On récupère le BuildContext via le contexte PDF pour les traductions
    // Note: en PDF on utilise les traductions directes
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _warningColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Text('⚠',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 8),
          pw.Text(
            'DOCUMENT INTERNE — CONFIDENTIEL — Ne pas remettre au client',
            style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── Bloc détails location ─────────────────────────────────────────────────

  static pw.Widget _detailsBlock(
      RecapLocationDto dto, PdfColor accent, PdfColor light, pw.Context ctx) {
    final periode = dto.dateFinReelle != null
        ? '${_d(dto.dateDebut)} → ${_d(dto.dateFinReelle!)}'
        : dto.dateFinPrevue != null
            ? '${_d(dto.dateDebut)} → ${_d(dto.dateFinPrevue!)} (prévu)'
            : '${_d(dto.dateDebut)} → contrat ouvert';

    return _block(
      'Détails de la location',
      accent,
      light,
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kv('Véhicule', dto.vehiculeNom),
                _kv('Client', dto.clientNom),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kv('Période', periode),
                _kv('Durée', '${dto.nbJours} jour(s)'),
                _kv('Prix / jour', '${dto.prixJour.toInt()} DA'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bloc montants ─────────────────────────────────────────────────────────

  static pw.Widget _montantsBlock(RecapLocationDto dto, PdfColor accent, pw.Context ctx) {
    return _block(
      'Montants',
      accent,
      PdfColor(accent.red, accent.green, accent.blue, 0.08),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(2),
        },
        children: [
          _tableRow('Montant brut (${dto.nbJours}j × ${dto.prixJour.toInt()} DA)',
              '${dto.montantBrut.toInt()} DA',
              headerBg: accent, isHeader: true),
          if (dto.caution > 0)
            _tableRow('Caution versée',
                '${dto.caution.toInt()} DA'),
          if (dto.retenueCaution > 0)
            _tableRow('Retenue caution',
                '- ${dto.retenueCaution.toInt()} DA',
                valueColor: _errorColor),
          _tableRow('Total encaissé',
              '${dto.totalPaiements.toInt()} DA',
              valueColor: _successColor),
          _tableRow(
            dto.solde > 0 ? 'Reste à payer' : 'Solde réglé',
            '${dto.solde.toInt()} DA',
            valueColor: dto.solde > 0 ? _errorColor : _successColor,
            bold: true,
          ),
        ],
      ),
    );
  }

  // ── Bloc répartition ──────────────────────────────────────────────────────

  static pw.Widget _repartitionBlock(RecapLocationDto dto, PdfColor accent, pw.Context ctx) {
    if (dto.repartitions.isEmpty) {
      return _block(
        'Répartition des gains',
        accent,
        PdfColor(accent.red, accent.green, accent.blue, 0.08),
        pw.Text(
          'Aucune répartition enregistrée pour cette location.',
          style: const pw.TextStyle(
              fontSize: 9, color: PdfColors.grey600),
        ),
      );
    }

    final gerants  = dto.repartitions.where((r) => r.typePart == 'commission_gerant').toList();
    final proprios = dto.repartitions.where((r) => r.typePart == 'part_proprietaire').toList();

    return _block(
      'Répartition des gains',
      accent,
      PdfColor(accent.red, accent.green, accent.blue, 0.08),
      pw.Column(children: [
        // ── Gérant(s) ──────────────────────────────────────────────────
        if (gerants.isNotEmpty) ...[
          _repartitionSectionHeader(
              'Commission gérant', dto.totalGerant, _gerantColor),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              _repartitionHeaderRow(),
              ...gerants.map((r) => _repartitionDataRow(r, _gerantColor)),
            ],
          ),
        ],

        if (gerants.isNotEmpty && proprios.isNotEmpty)
          pw.SizedBox(height: 10),

        // ── Propriétaire(s) ────────────────────────────────────────────
        if (proprios.isNotEmpty) ...[
          _repartitionSectionHeader(
              'Part propriétaire(s)', dto.totalProprio, _proprioColor),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              _repartitionHeaderRow(),
              ...proprios.map((r) => _repartitionDataRow(r, _proprioColor)),
            ],
          ),
        ],

        pw.SizedBox(height: 10),

        // ── Total réparti ──────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL RÉPARTI',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800)),
              pw.Text(
                '${(dto.totalGerant + dto.totalProprio).toInt()} DA  /  ${dto.montantBrut.toInt()} DA',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: accent),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Bloc solde final ──────────────────────────────────────────────────────

  static pw.Widget _soldeBlock(RecapLocationDto dto, PdfColor accent, pw.Context ctx) {
    final soldeColor = dto.solde > 0 ? _errorColor : _successColor;
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 240,
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: soldeColor, width: 1.5),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Montant brut',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text('${dto.montantBrut.toInt()} DA',
                  style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Encaissé',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text('${dto.totalPaiements.toInt()} DA',
                  style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                dto.solde > 0 ? 'Reste à payer' : 'Solde',
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '${dto.solde.toInt()} DA',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: soldeColor),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS INTERNES
  // ─────────────────────────────────────────────────────────────────────────

  static pw.Widget _block(
    String title,
    PdfColor accent,
    PdfColor light,
    pw.Widget content,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: pw.BoxDecoration(
              color: light,
              borderRadius:
                  const pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
            ),
            child: pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: accent)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: content,
          ),
        ],
      ),
    );
  }

  static pw.Widget _kv(String key, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 78,
            child: pw.Text(key,
                style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700)),
          ),
          pw.Flexible(
            child: PdfTheme.smartText(value, fontSize: 8.5),
          ),
        ]),
      );

  static pw.TableRow _tableRow(
    String label,
    String value, {
    PdfColor? valueColor,
    bool bold = false,
    bool isHeader = false,
    PdfColor? headerBg,
  }) {
    return pw.TableRow(
      decoration: isHeader
          ? pw.BoxDecoration(color: headerBg ?? PdfColors.grey200)
          : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: (bold || isHeader)
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: isHeader ? PdfColors.white : PdfColors.black,
              )),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: (bold || isHeader)
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: isHeader
                    ? PdfColors.white
                    : (valueColor ?? PdfColors.black),
              )),
        ),
      ],
    );
  }

  static pw.Widget _repartitionSectionHeader(
      String label, double montant, PdfColor color) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: color)),
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: pw.BoxDecoration(
            color: PdfColor(color.red, color.green, color.blue, 0.12),
            borderRadius: pw.BorderRadius.circular(20),
          ),
          child: pw.Text('${montant.toInt()} DA',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
        ),
      ],
    );
  }

  static pw.TableRow _repartitionHeaderRow() {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _thCell('Bénéficiaire'),
        _thCell('Part %'),
        _thCell('Montant'),
      ],
    );
  }

  static pw.TableRow _repartitionDataRow(
      RecapRepartitionDto r, PdfColor color) {
    final nom = r.nom.isEmpty
        ? (r.typePart == 'commission_gerant' ? 'Gérant' : 'Propriétaire')
        : r.nom;

    return pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(nom, style: const pw.TextStyle(fontSize: 9)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text('${r.pourcentage.toStringAsFixed(0)}%',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 9)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text('${r.montant.toInt()} DA',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: color)),
      ),
    ]);
  }

  static pw.Widget _thCell(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(t,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
      );
}