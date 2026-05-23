// lib/features/contrats/presentation/contrat_echange_pdf_generator.dart
//
// Générateur PDF — Contrat d'échange de véhicule
// Calqué sur contrat_location_pdf_generator.dart (même architecture)
//
// Génère DEUX documents :
//   • Version française (LTR) : contrat_echange_XXXX_FR.pdf
//   • Version arabe (RTL)     : contrat_echange_XXXX_AR.pdf
//
// Les articles dynamiques (contract_articles) sont injectés depuis
// ContratGeneratorService via les champs articlesFr / articlesAr du DTO.
//
// DÉPENDANCES pubspec.yaml (déjà présentes) :
//   pdf: ^3.11.0
//   path_provider: ^2.1.0
//   intl: ^0.19.0

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─────────────────────────────────────────────────────────────────────────────
//  DTO
// ─────────────────────────────────────────────────────────────────────────────

class ContratEchangeDto {
  final String   echangeId;
  final DateTime dateEtablissement;
  final DateTime dateEchange;

  // Agence (showroom)
  final String  agenceNom;
  final String  agenceAdresse;
  final String  agenceTel;
  final String? agenceEmail;
  final String? agenceVille;
  final String? agenceRc;
  final String? agenceCouleurHex;
  final Uint8List? agenceLogoBytes;

  // Client
  final String  clientNom;
  final String  clientPrenom;
  final String  clientTel;
  final String? clientEmail;
  final String? clientAdresse;
  final String? clientCin;
  final String? clientNumPermis;

  // Véhicule cédé par le showroom → client
  final String  vehiculeCedeMarque;
  final String  vehiculeCedeModele;
  final int?    vehiculeCedeAnnee;
  final String? vehiculeCedeCouleur;
  final String? vehiculeCedeImmat;
  final int?    vehiculeCedeKm;

  // Véhicule repris du client → showroom
  final String  vehiculeReprisMarque;
  final String  vehiculeReprisModele;
  final int?    vehiculeReprisAnnee;
  final String? vehiculeReprisImmat;
  final int?    vehiculeReprisKm;

  // Financier
  final double  valeurReprise;       // valeur estimée du véhicule repris
  final double  complementClient;   // complément payé par le client
  final double? commissionGerantPct;
  final double? commissionGerantMnt;

  // Divers
  final String? notes;

  // Articles dynamiques (déjà résolus par ContractArticlesRepository)
  final List<Map<String, String>> articlesFr;
  final List<Map<String, String>> articlesAr;

  const ContratEchangeDto({
    required this.echangeId,
    required this.dateEtablissement,
    required this.dateEchange,
    required this.agenceNom,
    required this.agenceAdresse,
    required this.agenceTel,
    this.agenceEmail,
    this.agenceVille,
    this.agenceRc,
    this.agenceCouleurHex,
    this.agenceLogoBytes,
    required this.clientNom,
    required this.clientPrenom,
    required this.clientTel,
    this.clientEmail,
    this.clientAdresse,
    this.clientCin,
    this.clientNumPermis,
    required this.vehiculeCedeMarque,
    required this.vehiculeCedeModele,
    this.vehiculeCedeAnnee,
    this.vehiculeCedeCouleur,
    this.vehiculeCedeImmat,
    this.vehiculeCedeKm,
    required this.vehiculeReprisMarque,
    required this.vehiculeReprisModele,
    this.vehiculeReprisAnnee,
    this.vehiculeReprisImmat,
    this.vehiculeReprisKm,
    required this.valeurReprise,
    this.complementClient = 0,
    this.commissionGerantPct,
    this.commissionGerantMnt,
    this.notes,
    this.articlesFr = const [],
    this.articlesAr = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Paires de documents / fichiers
// ─────────────────────────────────────────────────────────────────────────────

class ContratEchangePdfPair {
  final pw.Document fr;
  final pw.Document ar;
  const ContratEchangePdfPair({required this.fr, required this.ar});
}

class ContratEchangeFilePair {
  final File fr;
  final File ar;
  const ContratEchangeFilePair({required this.fr, required this.ar});
}

// ─────────────────────────────────────────────────────────────────────────────
//  GÉNÉRATEUR
// ─────────────────────────────────────────────────────────────────────────────

class ContratEchangePdfGenerator {
  ContratEchangePdfGenerator._();

  static DateFormat get _dateFmt     => DateFormat('dd/MM/yyyy', 'fr');
  static DateFormat get _dateLongFmt => DateFormat('d MMMM yyyy', 'fr');
  static NumberFormat get _moneyFmt  => NumberFormat('#,###', 'fr');

  static String _id8(String id) =>
      id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  // ── Chargement police latine — FR ───────────────────────────────────────
  // Corrige é à ç ê – ' « » qui s'affichent mal avec Helvetica (ASCII seulement)

  static pw.Font? _latinFont;
  static pw.Font? _latinFontBold;
  static bool     _latinFontLoaded = false;

  static Future<void> _loadLatinFont() async {
    if (_latinFontLoaded) return;
    try {
      final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final bold    = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      _latinFont     = pw.Font.ttf(regular);
      _latinFontBold = pw.Font.ttf(bold);
    } catch (e) {
      // ignore: avoid_print
      print('[ContratEchangePdf] ⚠️ Police latine non chargée : $e');
    }
    _latinFontLoaded = true;
  }

  // ── Chargement police arabe ─────────────────────────────────────────────

  static pw.Font? _arabicFont;
  static bool     _fontLoaded = false;

  static Future<void> _loadArabicFont() async {
    if (_fontLoaded) return;
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
      _arabicFont = pw.Font.ttf(fontData);
    } catch (_) {
      // Police arabe absente → version AR rendue en latin (dégradé gracieux)
    }
    _fontLoaded = true;
  }

  // ── API publique ────────────────────────────────────────────────────────

  /// Génère les deux documents (FR + AR) en parallèle.
  static Future<ContratEchangePdfPair> buildBothAsync(
      ContratEchangeDto dto) async {
    await Future.wait([_loadLatinFont(), _loadArabicFont()]);
    return ContratEchangePdfPair(
      fr: _buildFr(dto),
      ar: _buildAr(dto),
    );
  }

  /// Génère le document FR uniquement (compatibilité ascendante).
  static Future<pw.Document> buildAsync(ContratEchangeDto dto) async {
    await _loadLatinFont();
    return _buildFr(dto);
  }

  static Future<Uint8List> saveBytes(pw.Document doc) async => doc.save();

  /// Sauvegarde les deux fichiers et retourne leurs chemins.
  static Future<ContratEchangeFilePair> saveBothToFile(
    ContratEchangePdfPair pair,
    String echangeId,
  ) async {
    final dir  = await getApplicationDocumentsDirectory();
    final id8  = _id8(echangeId);
    final pathFr = '${dir.path}/contrat_echange_${id8}_FR.pdf';
    final pathAr = '${dir.path}/contrat_echange_${id8}_AR.pdf';

    final fileFr = File(pathFr)..writeAsBytesSync(await pair.fr.save());
    final fileAr = File(pathAr)..writeAsBytesSync(await pair.ar.save());

    return ContratEchangeFilePair(fr: fileFr, ar: fileAr);
  }

  static Future<File> saveToFile(pw.Document doc, String echangeId) async {
    final dir  = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/contrat_echange_${_id8(echangeId)}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VERSION FRANÇAISE (LTR)
  // ══════════════════════════════════════════════════════════════════════════

  static pw.Document _buildFr(ContratEchangeDto dto) {
    final doc   = pw.Document();
    final color = _hexColor(dto.agenceCouleurHex);
    final light = PdfColor(color.red, color.green, color.blue, 0.10);
    final id8   = _id8(dto.echangeId);

    pw.Widget withLatinTheme(pw.Widget child) {
      if (_latinFont == null) return child;
      return pw.Theme(
        data: pw.ThemeData.withFont(
          base: _latinFont!,
          bold: _latinFontBold ?? _latinFont!,
        ),
        child: child,
      );
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      header: (_) => withLatinTheme(_headerFr(dto, color, id8)),
      footer: (ctx) => withLatinTheme(_footerFr(dto, ctx)),
      build: (_) => [withLatinTheme(pw.Column(children: [
        // ── Parties ────────────────────────────────────────────────────────
        _sectionFr('PARTIES DE L\'ÉCHANGE', color),
        pw.SizedBox(height: 4),
        _twoCol(
          left: [
            ['Showroom', dto.agenceNom],
            ['Tél',      dto.agenceTel],
            if ((dto.agenceRc ?? '').isNotEmpty) ['RC', dto.agenceRc!],
            if ((dto.agenceAdresse).isNotEmpty) ['Adresse', dto.agenceAdresse],
          ],
          right: [
            ['Client',    '${dto.clientPrenom} ${dto.clientNom}'],
            ['Téléphone', dto.clientTel],
            if ((dto.clientEmail ?? '').isNotEmpty) ['Email', dto.clientEmail!],
            if ((dto.clientAdresse ?? '').isNotEmpty)
              ['Adresse', dto.clientAdresse!],
            if ((dto.clientCin ?? '').isNotEmpty) ['CIN', dto.clientCin!],
          ],
          color: color, light: light,
        ),
        pw.SizedBox(height: 10),

        // ── Véhicule cédé ──────────────────────────────────────────────────
        _sectionFr('VÉHICULE CÉDÉ PAR LE SHOWROOM AU CLIENT', color),
        pw.SizedBox(height: 4),
        _twoCol(
          left: [
            ['Marque', dto.vehiculeCedeMarque],
            ['Modèle', dto.vehiculeCedeModele],
            if (dto.vehiculeCedeAnnee != null)
              ['Année', dto.vehiculeCedeAnnee.toString()],
          ],
          right: [
            ['Immatriculation',
              dto.vehiculeCedeImmat?.isNotEmpty == true
                  ? dto.vehiculeCedeImmat!
                  : '-'],
            ['Kilométrage',
              dto.vehiculeCedeKm != null
                  ? '${_moneyFmt.format(dto.vehiculeCedeKm!)} km'
                  : '-'],
            if ((dto.vehiculeCedeCouleur ?? '').isNotEmpty)
              ['Couleur', dto.vehiculeCedeCouleur!],
          ],
          color: color, light: light,
        ),
        pw.SizedBox(height: 10),

        // ── Véhicule repris ────────────────────────────────────────────────
        _sectionFr('VÉHICULE REPRIS DU CLIENT PAR LE SHOWROOM', color),
        pw.SizedBox(height: 4),
        _twoCol(
          left: [
            ['Marque', dto.vehiculeReprisMarque],
            ['Modèle', dto.vehiculeReprisModele],
            if (dto.vehiculeReprisAnnee != null)
              ['Année', dto.vehiculeReprisAnnee.toString()],
          ],
          right: [
            ['Immatriculation',
              dto.vehiculeReprisImmat?.isNotEmpty == true
                  ? dto.vehiculeReprisImmat!
                  : '-'],
            ['Kilométrage',
              dto.vehiculeReprisKm != null
                  ? '${_moneyFmt.format(dto.vehiculeReprisKm!)} km'
                  : '-'],
          ],
          color: color, light: light,
        ),
        pw.SizedBox(height: 10),

        // ── Financier ──────────────────────────────────────────────────────
        _sectionFr('DÉTAILS FINANCIERS', color),
        pw.SizedBox(height: 4),
        _financialTable(dto, color, light),
        pw.SizedBox(height: 10),

        // ── Notes ──────────────────────────────────────────────────────────
        if ((dto.notes ?? '').isNotEmpty) ...[
          _sectionFr('OBSERVATIONS', color),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(dto.notes!,
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey800)),
          ),
          pw.SizedBox(height: 10),
        ],

        // ── Conditions générales (articles dynamiques ou statiques) ────────
        _sectionFr('CONDITIONS GÉNÉRALES', color),
        pw.SizedBox(height: 4),
        _conditionsFr(dto.articlesFr),
        pw.SizedBox(height: 14),

        // ── Signatures ─────────────────────────────────────────────────────
        _signaturesFr(dto, color, light),
      ]))]
    ));

    return doc;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VERSION ARABE (RTL)
  // ══════════════════════════════════════════════════════════════════════════

  static pw.Document _buildAr(ContratEchangeDto dto) {
    final doc   = pw.Document();
    final color = _hexColor(dto.agenceCouleurHex);
    final light = PdfColor(color.red, color.green, color.blue, 0.10);
    final id8   = _id8(dto.echangeId);

    final arabicStyle = pw.TextStyle(
      font: _arabicFont,
      fontSize: 10,
    );
    final arabicBold = pw.TextStyle(
      font: _arabicFont,
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );

    pw.Widget arText(String t, {pw.TextStyle? style}) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Text(t, style: style ?? arabicStyle,
              textDirection: pw.TextDirection.rtl),
        );

    pw.Widget arSection(String t) => pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Text(t,
                style: pw.TextStyle(
                    font: _arabicFont,
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold),
                textDirection: pw.TextDirection.rtl),
          ),
        );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      // En-tête identique mais titre en arabe
      header: (_) => _headerAr(dto, color, id8, arabicBold),
      footer: (ctx) => _footerAr(dto, ctx, arabicStyle),
      build: (_) => [
        // ── Parties ────────────────────────────────────────────────────────
        arSection('أطراف العقد'),
        pw.SizedBox(height: 4),
        _twoColAr(
          right: [
            ['المعرض', dto.agenceNom],
            ['الهاتف', dto.agenceTel],
            if ((dto.agenceRc ?? '').isNotEmpty) ['س.ت', dto.agenceRc!],
          ],
          left: [
            ['الزبون', '${dto.clientPrenom} ${dto.clientNom}'],
            ['الهاتف', dto.clientTel],
            if ((dto.clientCin ?? '').isNotEmpty) ['ر.ت.و', dto.clientCin!],
          ],
          color: color, light: light, font: _arabicFont,
        ),
        pw.SizedBox(height: 10),

        // ── Véhicule cédé ──────────────────────────────────────────────────
        arSection('السيارة المُسلَّمة من المعرض إلى الزبون'),
        pw.SizedBox(height: 4),
        _twoColAr(
          right: [
            ['الماركة', dto.vehiculeCedeMarque],
            ['الموديل', dto.vehiculeCedeModele],
            if (dto.vehiculeCedeAnnee != null)
              ['السنة', dto.vehiculeCedeAnnee.toString()],
          ],
          left: [
            ['رقم التسجيل',
              dto.vehiculeCedeImmat?.isNotEmpty == true
                  ? dto.vehiculeCedeImmat!
                  : '-'],
            ['عداد الكيلومترات',
              dto.vehiculeCedeKm != null
                  ? '${_moneyFmt.format(dto.vehiculeCedeKm!)} كم'
                  : '-'],
          ],
          color: color, light: light, font: _arabicFont,
        ),
        pw.SizedBox(height: 10),

        // ── Véhicule repris ────────────────────────────────────────────────
        arSection('السيارة المُستردَّة من الزبون'),
        pw.SizedBox(height: 4),
        _twoColAr(
          right: [
            ['الماركة', dto.vehiculeReprisMarque],
            ['الموديل', dto.vehiculeReprisModele],
            if (dto.vehiculeReprisAnnee != null)
              ['السنة', dto.vehiculeReprisAnnee.toString()],
          ],
          left: [
            ['رقم التسجيل',
              dto.vehiculeReprisImmat?.isNotEmpty == true
                  ? dto.vehiculeReprisImmat!
                  : '-'],
            ['الكيلومترات',
              dto.vehiculeReprisKm != null
                  ? '${_moneyFmt.format(dto.vehiculeReprisKm!)} كم'
                  : '-'],
          ],
          color: color, light: light, font: _arabicFont,
        ),
        pw.SizedBox(height: 10),

        // ── Financier ──────────────────────────────────────────────────────
        arSection('التفاصيل المالية'),
        pw.SizedBox(height: 4),
        _financialTableAr(dto, color, light, _arabicFont),
        pw.SizedBox(height: 10),

        // ── Conditions (articles AR) ───────────────────────────────────────
        arSection('الشروط العامة'),
        pw.SizedBox(height: 4),
        _conditionsAr(dto.articlesAr, _arabicFont),
        pw.SizedBox(height: 14),

        // ── Signatures ─────────────────────────────────────────────────────
        _signaturesAr(dto, color, light, _arabicFont),
      ],
    ));

    return doc;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  WIDGETS FRANÇAIS
  // ══════════════════════════════════════════════════════════════════════════

  static pw.Widget _headerFr(
      ContratEchangeDto dto, PdfColor color, String id8) =>
      pw.Column(children: [
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Logo + infos agence
              pw.Row(children: [
                if (dto.agenceLogoBytes != null) ...[
                  pw.Container(
                    width: 44, height: 44,
                    child: pw.Image(
                        pw.MemoryImage(dto.agenceLogoBytes!),
                        fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 8),
                ],
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                  pw.Text(dto.agenceNom,
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold)),
                  if (dto.agenceAdresse.isNotEmpty)
                    pw.Text(dto.agenceAdresse,
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 8)),
                  pw.Text(
                    [
                      if (dto.agenceTel.isNotEmpty) 'Tél : ${dto.agenceTel}',
                      if ((dto.agenceEmail ?? '').isNotEmpty)
                        dto.agenceEmail!,
                    ].join('  |  '),
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 8),
                  ),
                  if ((dto.agenceRc ?? '').isNotEmpty)
                    pw.Text('RC : ${dto.agenceRc!}',
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 8)),
                ]),
              ]),
              // Titre
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                pw.Text('CONTRAT D\'ÉCHANGE',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('N° $id8',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(_dateFmt.format(dto.dateEchange),
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 9)),
                pw.Text(
                    'Établi le ${_dateLongFmt.format(dto.dateEtablissement)}',
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 8)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
      ]);

  static pw.Widget _footerFr(
          ContratEchangeDto dto, pw.Context ctx) =>
      pw.Column(children: [
        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
          pw.Text(
              '${dto.agenceNom}'
              '${dto.agenceTel.isNotEmpty ? '  |  Tél : ${dto.agenceTel}' : ''}',
              style: const pw.TextStyle(
                  fontSize: 7, color: PdfColors.grey600)),
          pw.Text(
              'Page ${ctx.pageNumber}/${ctx.pagesCount}  -  '
              'Généré le ${_dateFmt.format(DateTime.now())}',
              style: const pw.TextStyle(
                  fontSize: 7, color: PdfColors.grey600)),
        ]),
      ]);

  static pw.Widget _sectionFr(String title, PdfColor color) =>
      pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(title,
            style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _twoCol({
    required List<List<String>> left,
    required List<List<String>> right,
    required PdfColor color,
    required PdfColor light,
  }) {
    pw.Widget cell(String label, String value) => pw.Padding(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 82,
                child: pw.Text(label,
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700))),
            pw.Flexible(
                child: pw.Text(value.isEmpty ? '-' : value,
                    style: const pw.TextStyle(fontSize: 9))),
          ]),
        );

    pw.Widget col(List<List<String>> rows) => pw.Container(
          decoration: pw.BoxDecoration(
            border:
                pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: rows.map((r) => cell(r[0], r[1])).toList()),
        );

    return pw.Row(children: [
      pw.Expanded(child: col(left)),
      pw.SizedBox(width: 6),
      pw.Expanded(child: col(right)),
    ]);
  }

  static pw.Widget _financialTable(
      ContratEchangeDto dto, PdfColor color, PdfColor light) {
    pw.Widget hCell(String t) => pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          color: color,
          child: pw.Center(
              child: pw.Text(t,
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold))),
        );

    pw.Widget dCell(String t, {bool isLabel = false}) => pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          color: isLabel ? light : PdfColors.white,
          child: pw.Center(
              child: pw.Text(t,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: isLabel ? pw.FontWeight.bold : null,
                      color: isLabel ? color : PdfColors.black))),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(160),
        1: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(children: [hCell('POSTE'), hCell('MONTANT')]),
        pw.TableRow(children: [
          dCell('Valeur de reprise (véhicule client)', isLabel: true),
          dCell('${_moneyFmt.format(dto.valeurReprise)} DA'),
        ]),
        pw.TableRow(children: [
          dCell('Complément réglé par le client', isLabel: true),
          dCell('${_moneyFmt.format(dto.complementClient)} DA'),
        ]),
        pw.TableRow(children: [
          dCell('Différence (valeur cédée - reprise)', isLabel: true),
          dCell(() {
            // montant global de l'opération côté client
            final diff = dto.complementClient + dto.valeurReprise;
            return '${_moneyFmt.format(diff)} DA';
          }()),
        ]),
        if ((dto.commissionGerantMnt ?? 0) > 0)
          pw.TableRow(children: [
            dCell(
              'Commission gérant'
              '${dto.commissionGerantPct != null ? ' (${dto.commissionGerantPct!.toStringAsFixed(1)} %)' : ''}',
              isLabel: true,
            ),
            dCell('${_moneyFmt.format(dto.commissionGerantMnt!)} DA'),
          ]),
      ],
    );
  }

  static pw.Widget _conditionsFr(List<Map<String, String>> articles) {
    // Articles dynamiques s'ils existent, sinon clauses par défaut
    final clauses = articles.isNotEmpty
        ? articles
        : [
            {
              'titre': '1. État des véhicules',
              'corps':
                  'Les deux parties déclarent accepter les véhicules en l\'état au moment de l\'échange.',
            },
            {
              'titre': '2. Transfert de propriété',
              'corps':
                  'Le transfert de propriété est effectif dès la signature du présent contrat et le règlement du complément financier.',
            },
            {
              'titre': '3. Documents et clés',
              'corps':
                  'Chaque partie remet à l\'autre les documents de propriété dûment barrés ainsi que l\'ensemble des clés du véhicule.',
            },
            {
              'titre': '4. Litiges',
              'corps':
                  'Tout litige relatif au présent contrat sera soumis aux tribunaux compétents du lieu de signature.',
            },
          ];

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
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800)),
                pw.Text(corps,
                    style: const pw.TextStyle(
                        fontSize: 8.5, color: PdfColors.grey700),
                    textAlign: pw.TextAlign.justify),
              ]),
            );
          }).toList()),
    );
  }

  static pw.Widget _signaturesFr(
      ContratEchangeDto dto, PdfColor color, PdfColor light) {
    pw.Widget box(String label, String name) =>
        pw.Expanded(
            child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border:
                pw.Border.all(color: PdfColors.grey300, width: 0.5),
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
            pw.Text('Lu et approuvé - $name',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 44),
            pw.Divider(color: PdfColors.grey400, thickness: 0.5),
            pw.Text('Date : _______________',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey500)),
          ]),
        ));

    return pw.Row(children: [
      box('Signature du client',
          '${dto.clientPrenom} ${dto.clientNom}'),
      pw.SizedBox(width: 10),
      box('Signature du showroom', dto.agenceNom),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  WIDGETS ARABES
  // ══════════════════════════════════════════════════════════════════════════

  static pw.Widget _headerAr(ContratEchangeDto dto, PdfColor color,
      String id8, pw.TextStyle arabicBold) =>
      pw.Column(children: [
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.Text('عقد تبادل سيارات',
                      style: arabicBold.copyWith(
                          color: PdfColors.white, fontSize: 14),
                      textDirection: pw.TextDirection.rtl),
                ),
                pw.Text('N° $id8',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(_dateFmt.format(dto.dateEchange),
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 9)),
              ]),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                pw.Text(dto.agenceNom,
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold)),
                if (dto.agenceTel.isNotEmpty)
                  pw.Text('هاتف : ${dto.agenceTel}',
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 9)),
                if ((dto.agenceRc ?? '').isNotEmpty)
                  pw.Text('س.ت : ${dto.agenceRc!}',
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 9)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
      ]);

  static pw.Widget _footerAr(
      ContratEchangeDto dto, pw.Context ctx, pw.TextStyle arabicStyle) =>
      pw.Column(children: [
        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
                'Page ${ctx.pageNumber}/${ctx.pagesCount}  -  '
                '${_dateFmt.format(DateTime.now())}',
                style: const pw.TextStyle(
                    fontSize: 7, color: PdfColors.grey600)),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Text(dto.agenceNom,
                  style: arabicStyle.copyWith(
                      fontSize: 7, color: PdfColors.grey600),
                  textDirection: pw.TextDirection.rtl),
            ),
          ],
        ),
      ]);

  static pw.Widget _twoColAr({
    required List<List<String>> right,
    required List<List<String>> left,
    required PdfColor color,
    required PdfColor light,
    pw.Font? font,
  }) {
    pw.Widget cell(String label, String value) => pw.Padding(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Row(children: [
              pw.SizedBox(
                width: 82,
                child: pw.Text(label,
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700),
                    textDirection: pw.TextDirection.rtl),
              ),
              pw.Flexible(
                  child: pw.Text(value.isEmpty ? '-' : value,
                      style: pw.TextStyle(font: font, fontSize: 9),
                      textDirection: pw.TextDirection.rtl)),
            ]),
          ),
        );

    pw.Widget col(List<List<String>> rows) => pw.Container(
          decoration: pw.BoxDecoration(
            border:
                pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: rows.map((r) => cell(r[0], r[1])).toList()),
        );

    return pw.Row(children: [
      pw.Expanded(child: col(right)),
      pw.SizedBox(width: 6),
      pw.Expanded(child: col(left)),
    ]);
  }

  static pw.Widget _financialTableAr(
      ContratEchangeDto dto, PdfColor color, PdfColor light, pw.Font? font) {
    pw.Widget hCell(String t) => pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          color: color,
          child: pw.Center(
              child: pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Text(t,
                style: pw.TextStyle(
                    font: font,
                    color: PdfColors.white,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold),
                textDirection: pw.TextDirection.rtl),
          )),
        );

    pw.Widget dCell(String t,
            {bool isLabel = false, bool rtl = false}) =>
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          color: isLabel ? light : PdfColors.white,
          child: pw.Center(
              child: rtl
                  ? pw.Directionality(
                      textDirection: pw.TextDirection.rtl,
                      child: pw.Text(t,
                          style: pw.TextStyle(
                              font: font,
                              fontSize: 9,
                              fontWeight: isLabel
                                  ? pw.FontWeight.bold
                                  : null,
                              color: isLabel
                                  ? color
                                  : PdfColors.black),
                          textDirection: pw.TextDirection.rtl),
                    )
                  : pw.Text(t,
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight:
                              isLabel ? pw.FontWeight.bold : null,
                          color: isLabel
                              ? color
                              : PdfColors.black))),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FixedColumnWidth(160),
      },
      children: [
        pw.TableRow(children: [
          hCell('المبلغ'),
          hCell('البيان'),
        ]),
        pw.TableRow(children: [
          dCell('${_moneyFmt.format(dto.valeurReprise)} دج'),
          dCell('قيمة السيارة المُستردَّة', isLabel: true, rtl: true),
        ]),
        pw.TableRow(children: [
          dCell('${_moneyFmt.format(dto.complementClient)} دج'),
          dCell('الفرق المدفوع من الزبون', isLabel: true, rtl: true),
        ]),
        if ((dto.commissionGerantMnt ?? 0) > 0)
          pw.TableRow(children: [
            dCell('${_moneyFmt.format(dto.commissionGerantMnt!)} دج'),
            dCell('عمولة المسيّر', isLabel: true, rtl: true),
          ]),
      ],
    );
  }

  static pw.Widget _conditionsAr(
      List<Map<String, String>> articles, pw.Font? font) {
    final clauses = articles.isNotEmpty
        ? articles
        : [
            {
              'titre': 'حالة السيارات',
              'corps':
                  'يُقرّ الطرفان بقبول السيارات في حالتها الراهنة لحظة إتمام التبادل.',
            },
            {
              'titre': 'نقل الملكية',
              'corps':
                  'تنتقل الملكية فور توقيع هذا العقد وتسوية المبالغ المالية المتفق عليها.',
            },
            {
              'titre': 'الوثائق والمفاتيح',
              'corps':
                  'يُسلّم كل طرف للآخر وثيقة الملكية المشطوبة ومفاتيح السيارة كاملةً.',
            },
            {
              'titre': 'النزاعات',
              'corps':
                  'تُحال أي نزاعات تتعلق بهذا العقد إلى الجهات القضائية المختصة.',
            },
          ];

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
        color: const PdfColor(0.98, 0.98, 0.99),
      ),
      child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: clauses.map((c) {
            final titre = c['titre'] ?? '';
            final corps = c['corps'] ?? '';
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                  if (titre.isNotEmpty)
                    pw.Text(titre,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800),
                        textDirection: pw.TextDirection.rtl),
                  pw.Text(corps,
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 9,
                          color: PdfColors.grey700),
                      textAlign: pw.TextAlign.justify,
                      textDirection: pw.TextDirection.rtl),
                ]),
              ),
            );
          }).toList()),
    );
  }

  static pw.Widget _signaturesAr(ContratEchangeDto dto, PdfColor color,
      PdfColor light, pw.Font? font) {
    pw.Widget box(String label, String name) =>
        pw.Expanded(
            child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border:
                pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
            color: light,
          ),
          child: pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      font: font,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: color),
                  textDirection: pw.TextDirection.rtl),
              pw.Text('مقروء ومعتمد - $name',
                  style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: PdfColors.grey600),
                  textDirection: pw.TextDirection.rtl),
              pw.SizedBox(height: 44),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.Text('التاريخ : _______________',
                  style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: PdfColors.grey500),
                  textDirection: pw.TextDirection.rtl),
            ]),
          ),
        ));

    return pw.Row(children: [
      box('توقيع المعرض', dto.agenceNom),
      pw.SizedBox(width: 10),
      box('توقيع الزبون',
          '${dto.clientPrenom} ${dto.clientNom}'),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UTILITAIRES
  // ══════════════════════════════════════════════════════════════════════════

  static PdfColor _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return const PdfColor(0.10, 0.44, 0.83);
    final h = hex.replaceAll('#', '');
    if (h.length != 6) return const PdfColor(0.10, 0.44, 0.83);
    return PdfColor(
      int.parse(h.substring(0, 2), radix: 16) / 255,
      int.parse(h.substring(2, 4), radix: 16) / 255,
      int.parse(h.substring(4, 6), radix: 16) / 255,
    );
  }
}
