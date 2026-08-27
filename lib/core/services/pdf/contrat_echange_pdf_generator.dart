// lib/core/services/pdf/contrat_echange_pdf_generator.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_theme.dart';
import 'pdf_layout.dart';
import '../../../features/contrats/domain/contrat_echange_dto.dart';

export '../../../features/contrats/domain/contrat_echange_dto.dart';

/// Paire de documents PDF échange (FR + AR).
class ContratEchangePdfPair {
  final pw.Document fr;
  final pw.Document ar;
  const ContratEchangePdfPair({required this.fr, required this.ar});
}

class ContratEchangePdfGenerator {
  ContratEchangePdfGenerator._();

  static const _defaultClausesFr = [
    {
      'titre': '1. État des véhicules',
      'corps': "Les deux parties déclarent accepter les véhicules en l'état au moment de l'échange.",
    },
    {
      'titre': '2. Transfert de propriété',
      'corps': 'Le transfert de propriété est effectif dès la signature du présent contrat et le règlement du complément financier.',
    },
    {
      'titre': '3. Documents et clés',
      'corps': "Chaque partie remet à l'autre les documents de propriété dûment barrés ainsi que l'ensemble des clés.",
    },
    {
      'titre': '4. Litiges',
      'corps': 'Tout litige relatif au présent contrat sera soumis aux tribunaux compétents du lieu de signature.',
    },
  ];

  static const _defaultClausesAr = [
    {
      'titre': '١. حالة السيارتين',
      'corps': 'يُقرّ الطرفان بقبول السيارتين على ما هي عليه وقت الاستلام.',
    },
    {
      'titre': '٢. نقل الملكية',
      'corps': 'تنتقل الملكية فور التوقيع على هذا العقد وتسوية الفارق المالي.',
    },
    {
      'titre': '٣. الوثائق والمفاتيح',
      'corps': 'يُسلّم كل طرف للآخر وثائق الملكية مُشطوبةً مع جميع مفاتيح السيارة.',
    },
    {
      'titre': '٤. النزاعات',
      'corps': 'تُحال أي نزاعات تتعلق بهذا العقد إلى المحاكم المختصة في مكان التوقيع.',
    },
  ];

  // ── Points d'entrée ──────────────────────────────────────────────────────

  static Future<ContratEchangePdfPair> buildBothAsync(
      ContratEchangeDto dto) async {
    await PdfTheme.loadAllFonts();
    return ContratEchangePdfPair(fr: _buildFr(dto), ar: _buildAr(dto));
  }

  static Future<pw.Document> buildAsync(ContratEchangeDto dto) async {
    await PdfTheme.loadLatinFont();
    return _buildFr(dto);
  }

  static Future<Uint8List> buildBytes(ContratEchangeDto dto) async {
    final doc = await buildAsync(dto);
    return doc.save();
  }

  // ── Document Français ────────────────────────────────────────────────────

  static pw.Document _buildFr(ContratEchangeDto dto) {
    final doc   = pw.Document();
    final color = PdfTheme.hexColor(dto.agenceCouleurHex);
    final light = PdfTheme.lightVariant(color);
    final id8   = PdfTheme.shortId(dto.echangeId);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      header: (_) => PdfTheme.withLatinTheme(PdfLayout.header(
        agenceNom:     dto.agenceNom,
        agenceAdresse: dto.agenceAdresse,
        agenceTel:     dto.agenceTel,
        agenceEmail:   dto.agenceEmail,
        agenceRc:      dto.agenceRc,
        titreContrat:  "CONTRAT D'ÉCHANGE",
        numero:        id8,
        date:          dto.dateEtablissement,
        color:         color,
        logoImage: dto.agenceLogoBytes != null
            ? pw.MemoryImage(dto.agenceLogoBytes!)
            : null,
      )),
      footer: (ctx) => PdfTheme.withLatinTheme(
          PdfLayout.footer(agenceNom: dto.agenceNom, agenceTel: dto.agenceTel, ctx: ctx)),
      build: (_) => [PdfTheme.withLatinTheme(pw.Column(children: [
        PdfLayout.sectionTitle("PARTIES DE L'ÉCHANGE", color),
        pw.SizedBox(height: 4),
        PdfLayout.twoColTable(
          left: [
            ['Showroom', dto.agenceNom],
            ['Tél', dto.agenceTel],
            if (dto.agenceRc.isNotEmpty) ['RC', dto.agenceRc],
          ],
          right: [
            ['Client', '${dto.clientPrenom} ${dto.clientNom}'.trim()],
            ['Téléphone', dto.clientTelephone],
            if ((dto.clientCin ?? '').isNotEmpty) ['N° CIN', dto.clientCin!],
          ],
          color: color, light: light,
        ),
        pw.SizedBox(height: 10),

        PdfLayout.sectionTitle('VÉHICULE CÉDÉ PAR LE SHOWROOM', color),
        pw.SizedBox(height: 4),
        PdfLayout.twoColTable(
          left: [
            ['Marque', dto.vehiculeCedeMarque],
            ['Modèle', dto.vehiculeCedeModele],
            if (dto.vehiculeCedeAnnee != null) ['Année', dto.vehiculeCedeAnnee.toString()],
          ],
          right: [
            ['Immatriculation', dto.vehiculeCedeImmat?.isNotEmpty == true ? dto.vehiculeCedeImmat! : '—'],
            ['Kilométrage', dto.vehiculeCedeKm != null ? PdfTheme.fmtKm(dto.vehiculeCedeKm!) : '—'],
            if ((dto.vehiculeCedeCouleur ?? '').isNotEmpty) ['Couleur', dto.vehiculeCedeCouleur!],
          ],
          color: color, light: light,
        ),
        pw.SizedBox(height: 10),

        PdfLayout.sectionTitle('VÉHICULE REPRIS DU CLIENT', color),
        pw.SizedBox(height: 4),
        PdfLayout.twoColTable(
          left: [
            ['Marque', dto.vehiculeReprisMarque],
            ['Modèle', dto.vehiculeReprisModele],
            if (dto.vehiculeReprisAnnee != null) ['Année', dto.vehiculeReprisAnnee.toString()],
          ],
          right: [
            ['Immatriculation', dto.vehiculeReprisImmat?.isNotEmpty == true ? dto.vehiculeReprisImmat! : '—'],
            ['Kilométrage', dto.vehiculeReprisKm != null ? PdfTheme.fmtKm(dto.vehiculeReprisKm!) : '—'],
            if ((dto.vehiculeReprisCouleur ?? '').isNotEmpty) ['Couleur', dto.vehiculeReprisCouleur!],
          ],
          color: color, light: light,
        ),
        pw.SizedBox(height: 10),

        PdfLayout.sectionTitle('DÉTAILS FINANCIERS', color),
        pw.SizedBox(height: 4),
        _financialTableFr(dto, color, light),
        pw.SizedBox(height: 10),

        if ((dto.notes ?? '').isNotEmpty) ...[
          PdfLayout.sectionTitle('OBSERVATIONS', color),
          pw.SizedBox(height: 4),
          PdfLayout.notesBlock(dto.notes!),
          pw.SizedBox(height: 10),
        ],

        PdfLayout.sectionTitle('CONDITIONS GÉNÉRALES', color),
        pw.SizedBox(height: 4),
        PdfLayout.articlesBlock(dto.articlesFr, defaultClauses: _defaultClausesFr),
        pw.SizedBox(height: 14),

        PdfLayout.signatures(
          labelGauche: 'Signature du client',
          nomGauche:   '${dto.clientPrenom} ${dto.clientNom}'.trim(),
          labelDroite: 'Signature du showroom',
          nomDroite:   dto.agenceNom,
          color:       color,
          light:       light,
        ),
      ]))],
    ));

    return doc;
  }

  // ── Document Arabe ───────────────────────────────────────────────────────

  static pw.Document _buildAr(ContratEchangeDto dto) {
    final doc   = pw.Document();
    final color = PdfTheme.hexColor(dto.agenceCouleurHex);
    final light = PdfTheme.lightVariant(color);
    final id8   = PdfTheme.shortId(dto.echangeId);

    // Titre de section coloré (fond couleur primaire, texte blanc)
    pw.Widget arSection(String t) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Text(t,
            style: PdfTheme.arabicStyleColored(fontSize: 10, bold: true, color: PdfColors.white),
            textDirection: pw.TextDirection.rtl),
      ),
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      header: (_) => _headerAr(dto, color, id8),
      footer: (ctx) => PdfLayout.footer(agenceNom: dto.agenceNom, agenceTel: dto.agenceTel, ctx: ctx),
      build: (_) => [PdfTheme.withArabicTheme(pw.Column(children: [
        arSection('أطراف العقد'),
        pw.SizedBox(height: 4),
        _twoColAr(
          right: [
            ['المعرض', dto.agenceNom],
            ['الهاتف', dto.agenceTel],
            if (dto.agenceRc.isNotEmpty) ['س.ت', dto.agenceRc],
          ],
          left: [
            ['الزبون', '${dto.clientPrenom} ${dto.clientNom}'.trim()],
            ['الهاتف', dto.clientTelephone],
            if ((dto.clientCin ?? '').isNotEmpty) ['رقم الهوية', dto.clientCin!],
          ],
          color: color, light: light,
        ),
        pw.SizedBox(height: 10),

        arSection('السيارة المُسلَّمة من المعرض إلى الزبون'),
        pw.SizedBox(height: 4),
        _twoColAr(
          right: [
            ['الماركة', dto.vehiculeCedeMarque],
            ['الموديل', dto.vehiculeCedeModele],
            if (dto.vehiculeCedeAnnee != null) ['السنة', dto.vehiculeCedeAnnee.toString()],
          ],
          left: [
            ['رقم التسجيل', dto.vehiculeCedeImmat?.isNotEmpty == true ? dto.vehiculeCedeImmat! : '—'],
            ['الكيلومترات', dto.vehiculeCedeKm != null ? PdfTheme.fmtKm(dto.vehiculeCedeKm!) : '—'],
          ],
          color: color, light: light,
        ),
        pw.SizedBox(height: 10),

        arSection('السيارة المُستردَّة من الزبون'),
        pw.SizedBox(height: 4),
        _twoColAr(
          right: [
            ['الماركة', dto.vehiculeReprisMarque],
            ['الموديل', dto.vehiculeReprisModele],
            if (dto.vehiculeReprisAnnee != null) ['السنة', dto.vehiculeReprisAnnee.toString()],
          ],
          left: [
            ['رقم التسجيل', dto.vehiculeReprisImmat?.isNotEmpty == true ? dto.vehiculeReprisImmat! : '—'],
            ['الكيلومترات', dto.vehiculeReprisKm != null ? PdfTheme.fmtKm(dto.vehiculeReprisKm!) : '—'],
          ],
          color: color, light: light,
        ),
        pw.SizedBox(height: 10),

        arSection('التفاصيل المالية'),
        pw.SizedBox(height: 4),
        _financialTableAr(dto, color, light),
        pw.SizedBox(height: 10),

        arSection('الشروط العامة'),
        pw.SizedBox(height: 4),
        _articlesAr(dto.articlesAr, color),
        pw.SizedBox(height: 14),

        _signaturesAr(dto, color, light),
      ]))],
    ));

    return doc;
  }

  // ── Tableaux financiers ──────────────────────────────────────────────────

  static pw.Widget _financialTableFr(
      ContratEchangeDto dto, PdfColor color, PdfColor light) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(190),
        1: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(children: [
          PdfLayout.tableHeaderCell('POSTE', color),
          PdfLayout.tableHeaderCell('MONTANT', color),
        ]),
        pw.TableRow(children: [
          PdfLayout.tableDataCell('Valeur de reprise (véhicule client)',
              isLabel: true, labelColor: color, labelBg: light),
          PdfLayout.tableDataCell(PdfTheme.fmtMoney(dto.valeurReprise)),
        ]),
        pw.TableRow(children: [
          PdfLayout.tableDataCell('Complément réglé par le client',
              isLabel: true, labelColor: color, labelBg: light),
          PdfLayout.tableDataCell(PdfTheme.fmtMoney(dto.complementClient)),
        ]),
        pw.TableRow(children: [
          PdfLayout.tableDataCell('Total opération',
              isLabel: true, labelColor: color, labelBg: light),
          PdfLayout.tableDataCell(PdfTheme.fmtMoney(dto.montantTotal), isBold: true),
        ]),
      ],
    );
  }

  static pw.Widget _financialTableAr(
      ContratEchangeDto dto, PdfColor color, PdfColor light) {
    pw.Widget hCell(String t) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      color: color,
      child: pw.Center(child: pw.Text(t,
          style: PdfTheme.arabicStyleColored(fontSize: 8.5, bold: true, color: PdfColors.white),
          textDirection: pw.TextDirection.rtl)));

    pw.Widget dCell(String t, {bool isLabel = false}) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      color: isLabel ? light : PdfColors.white,
      child: pw.Center(child: pw.Text(t,
          style: isLabel
              ? PdfTheme.arabicStyleColored(fontSize: 9, bold: true, color: color)
              : PdfTheme.arabicStyle(fontSize: 9),
          textDirection: pw.TextDirection.rtl)));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {0: pw.FixedColumnWidth(160), 1: pw.FlexColumnWidth(2)},
      children: [
        pw.TableRow(children: [hCell('البند'), hCell('المبلغ')]),
        pw.TableRow(children: [
          dCell('قيمة الاسترداد (سيارة الزبون)', isLabel: true),
          dCell(PdfTheme.fmtMoney(dto.valeurReprise)),
        ]),
        pw.TableRow(children: [
          dCell('المبلغ التكميلي من الزبون', isLabel: true),
          dCell(PdfTheme.fmtMoney(dto.complementClient)),
        ]),
        pw.TableRow(children: [
          dCell('المجموع', isLabel: true),
          dCell(PdfTheme.fmtMoney(dto.montantTotal)),
        ]),
      ],
    );
  }

  // ── Header AR ────────────────────────────────────────────────────────────

  static pw.Widget _headerAr(ContratEchangeDto dto, PdfColor color, String id8) {
    final logoBytes = dto.agenceLogoBytes;
    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('عقد التبادل',
                  style: PdfTheme.arabicStyleColored(fontSize: 14, bold: true, color: PdfColors.white),
                  textDirection: pw.TextDirection.rtl),
              pw.Text('رقم $id8',
                  style: PdfTheme.arabicStyleColored(fontSize: 11, bold: true, color: PdfColors.white),
                  textDirection: pw.TextDirection.rtl),
              pw.Text(PdfTheme.fmtDate(dto.dateEtablissement),
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
            ]),
            pw.Row(children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(dto.agenceNom,
                    style: PdfTheme.arabicStyleColored(fontSize: 14, bold: true, color: PdfColors.white),
                    textDirection: pw.TextDirection.rtl),
                if (dto.agenceTel.isNotEmpty)
                  pw.Text('هاتف: ${dto.agenceTel}',
                      style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
              ]),
              if (logoBytes != null) ...[
                pw.SizedBox(width: 10),
                pw.Container(
                  width: 40,
                  height: 40,
                  padding: const pw.EdgeInsets.all(3),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                ),
              ],
            ]),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
    ]);
  }

  // ── Two-col AR ───────────────────────────────────────────────────────────

  static pw.Widget _twoColAr({
    required List<List<String>> right,
    required List<List<String>> left,
    required PdfColor color,
    required PdfColor light,
  }) {
    pw.Widget cell(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Flexible(child: pw.Text(value.isEmpty ? '—' : value,
            style: PdfTheme.arabicStyle(fontSize: 9),
            textDirection: pw.TextDirection.rtl)),
        pw.SizedBox(width: 6),
        pw.Text(label,
            style: PdfTheme.arabicStyleColored(fontSize: 9, bold: true, color: PdfColors.grey700),
            textDirection: pw.TextDirection.rtl),
      ]),
    );

    pw.Widget col(List<List<String>> rows) => pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: rows.map((r) => cell(r[0], r[1])).toList()),
    );

    return pw.Row(children: [
      pw.Expanded(child: col(right)),
      pw.SizedBox(width: 6),
      pw.Expanded(child: col(left)),
    ]);
  }

  // ── Articles AR ──────────────────────────────────────────────────────────

  static pw.Widget _articlesAr(List<Map<String, String>> articles, PdfColor color) {
    final clauses = articles.isNotEmpty ? articles : _defaultClausesAr;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          borderRadius: pw.BorderRadius.circular(3),
          color: const PdfColor(0.98, 0.98, 0.99)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: clauses.map((c) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            if ((c['titre'] ?? '').isNotEmpty)
              pw.Text(c['titre']!,
                  style: PdfTheme.arabicStyleColored(fontSize: 9, bold: true, color: PdfColors.grey800),
                  textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
            if ((c['corps'] ?? '').isNotEmpty)
              pw.Text(c['corps']!,
                  style: PdfTheme.arabicStyleColored(fontSize: 8.5, color: PdfColors.grey700),
                  textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
          ]),
        )).toList(),
      ),
    );
  }

  // ── Signatures AR ────────────────────────────────────────────────────────

  static pw.Widget _signaturesAr(ContratEchangeDto dto, PdfColor color, PdfColor light) {
    pw.Widget sigBox(String label, String nom) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
            color: light),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(label,
              style: PdfTheme.arabicStyleColored(fontSize: 9, bold: true, color: color),
              textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
          pw.Text('المطلع والموافق — $nom',
              style: PdfTheme.arabicStyleColored(fontSize: 8, color: PdfColors.grey600),
              textDirection: pw.TextDirection.rtl),
          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.Text('التاريخ : _______________',
              style: PdfTheme.arabicStyleColored(fontSize: 8, color: PdfColors.grey500),
              textDirection: pw.TextDirection.rtl),
        ]),
      ),
    );

    return pw.Row(children: [
      sigBox('توقيع المعرض', dto.agenceNom),
      pw.SizedBox(width: 10),
      sigBox('توقيع الزبون', '${dto.clientPrenom} ${dto.clientNom}'.trim()),
    ]);
  }
}