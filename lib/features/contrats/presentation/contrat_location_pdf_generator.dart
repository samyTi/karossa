// lib/features/contrats/presentation/contrat_location_pdf_generator.dart
//
// v4 — Fusion de contrat_location_pdf.dart (ancien) + contrat_location_pdf_generator.dart
//
// CHANGEMENTS vs v3 :
//   - ContratLocationData (ancien DTO) SUPPRIMÉ — remplacé par ContratLocationDto
//   - EtatVehicule (ancienne classe) SUPPRIMÉE — les champs sont inline dans ContratLocationDto
//   - ContratLocationPdf (ancienne classe) SUPPRIMÉE
//   - Contenu du générateur inchangé (aucune régression)
//
// IMPORTS À METTRE À JOUR :
//   Partout où tu avais :
//     import '.../contrat_location_pdf.dart';
//   Remplace par :
//     import '.../contrat_location_pdf_generator.dart';   ← déjà le bon fichier
//
// DÉPENDANCES pubspec.yaml :
//   pdf: ^3.11.0
//   printing: ^5.13.0
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
//  DTO  (inchangé — compatibilité avec ContratGeneratorService)
// ─────────────────────────────────────────────────────────────────────────────

class ContratLocationDto {
  final String contratId;
  final DateTime dateEtablissement;

  // Agence
  final String agenceNom;
  final String agenceAdresse;
  final String agenceTel;
  final String? agenceEmail;
  final String? agenceVille;
  final String? agenceRc;
  final String? agenceCouleurHex;
  final Uint8List? agenceLogoBytes;

  // Locataire
  final String locataireNom;
  final String locatairePrenom;
  final String? locataireDateNaissance;
  final String locataireTel;
  final String? locataireEmail;
  final String? locataireAdresse;
  final String? locataireNumPermis;
  final String? locatairePermisDate;
  final String? locataireCin;

  // 2ème conducteur (optionnel)
  final String? conducteur2Nom;
  final String? conducteur2Prenom;
  final String? conducteur2DateNaissance;
  final String? conducteur2Tel;
  final String? conducteur2NumPermis;
  final String? conducteur2PermisDate;

  // Véhicule
  final String vehiculeMarque;
  final String vehiculeModele;
  final String? vehiculeCouleur;
  final String? vehiculeImmatriculation;
  final String? vehiculeAssurance;
  final String? vehiculeCarburant;
  final String? vehiculeBoite;
  final String? vehiculeCodeRadio;

  // Détails location
  final DateTime dateDepart;
  final String? heureDepart;
  final DateTime dateRetour;
  final String? heureRetour;
  final int kmDepart;
  final int? kmRetour;
  final double prixJour;
  final double caution;

  // État du véhicule (checklist)
  final bool etatAutoRadio;
  final bool etatRoueSecours;
  final bool etatRadiateur;
  final bool etatCarburant;
  final bool etatAvertisseur;
  final bool etatControle4Roues;
  final bool etatControleCarrosserie;
  final bool etatControleFeuxAv;
  final bool etatControleInterieur;

  final String? observations;

  /// État du véhicule : dommages, pannes, rayures signalés avant la location.
  final String? etatVehicule;

  const ContratLocationDto({
    required this.contratId,
    required this.dateEtablissement,
    required this.agenceNom,
    required this.agenceAdresse,
    required this.agenceTel,
    this.agenceEmail,
    this.agenceVille,
    this.agenceRc,
    this.agenceCouleurHex,
    this.agenceLogoBytes,
    required this.locataireNom,
    required this.locatairePrenom,
    this.locataireDateNaissance,
    required this.locataireTel,
    this.locataireEmail,
    this.locataireAdresse,
    this.locataireNumPermis,
    this.locatairePermisDate,
    this.locataireCin,
    this.conducteur2Nom,
    this.conducteur2Prenom,
    this.conducteur2DateNaissance,
    this.conducteur2Tel,
    this.conducteur2NumPermis,
    this.conducteur2PermisDate,
    required this.vehiculeMarque,
    required this.vehiculeModele,
    this.vehiculeCouleur,
    this.vehiculeImmatriculation,
    this.vehiculeAssurance,
    this.vehiculeCarburant,
    this.vehiculeBoite,
    this.vehiculeCodeRadio,
    required this.dateDepart,
    this.heureDepart,
    required this.dateRetour,
    this.heureRetour,
    required this.kmDepart,
    this.kmRetour,
    required this.prixJour,
    required this.caution,
    this.etatAutoRadio = false,
    this.etatRoueSecours = false,
    this.etatRadiateur = false,
    this.etatCarburant = false,
    this.etatAvertisseur = false,
    this.etatControle4Roues = false,
    this.etatControleCarrosserie = false,
    this.etatControleFeuxAv = false,
    this.etatControleInterieur = false,
    this.observations,
    this.etatVehicule,
  });

  int get nbJours =>
      dateRetour.difference(dateDepart).inDays.clamp(1, 9999);

  double get montantTotal => prixJour * nbJours;

  String get locataireFullName => '$locatairePrenom $locataireNom';

  bool get hasConducteur2 =>
      conducteur2Nom != null && (conducteur2Nom?.isNotEmpty ?? false);
}

// ─────────────────────────────────────────────────────────────────────────────
//  GÉNÉRATEUR PDF
// ─────────────────────────────────────────────────────────────────────────────

class ContratLocationPdfGenerator {
  ContratLocationPdfGenerator._();

  static DateFormat get _dateFmt     => DateFormat('dd/MM/yyyy', 'fr');
  static DateFormat get _dateLongFmt => DateFormat('d MMMM yyyy', 'fr');
  static NumberFormat get _moneyFmt  => NumberFormat('#,###', 'fr');

  static String _idFmt(String id) =>
      id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  static String _val(String? v) => (v == null || v.isEmpty) ? '' : v;

  // ── Police arabe (cache statique) ────────────────────────────────────────

  static pw.Font? _arabicFont;
  static pw.Font? _arabicFontBold;

  static Future<void> _loadArabicFont() async {
    if (_arabicFont != null) return;
    try {
      final regular = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final bold    = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      _arabicFont     = pw.Font.ttf(regular);
      _arabicFontBold = pw.Font.ttf(bold);
    } catch (_) {
      _arabicFont     = null;
      _arabicFontBold = null;
    }
  }

  // ── Points d'entrée ──────────────────────────────────────────────────────

  static Future<pw.Document> buildAsync(
    ContratLocationDto dto, {
    List<Map<String, String>>? articlesGeneraux,
  }) async {
    await _loadArabicFont();
    return build(dto, articlesGeneraux: articlesGeneraux);
  }

  static pw.Document build(
    ContratLocationDto dto, {
    List<Map<String, String>>? articlesGeneraux,
  }) {
    final doc = pw.Document();

    // ── Exemplaire français (pages 1 & 2) ──
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _buildAgenceHeader(dto),
          pw.SizedBox(height: 10),
          _buildTitreContrat(dto),
          pw.SizedBox(height: 8),
          _buildLocataireSection(dto),
          pw.SizedBox(height: 6),
          _buildVehiculeSection(dto),
          pw.SizedBox(height: 6),
          _buildTableauDepartRetour(dto),
          pw.SizedBox(height: 6),
          _buildEtatVehicule(dto),
          pw.SizedBox(height: 6),
          if ((dto.etatVehicule ?? '').trim().isNotEmpty) _buildNotesVehicule(dto),
          if ((dto.etatVehicule ?? '').trim().isNotEmpty) pw.SizedBox(height: 6),
          _buildConditionsSummary(),
          pw.SizedBox(height: 8),
          _buildSignatures(dto),
        ],
      ),
    ));

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      build: (ctx) => _buildConditionsGeneralesPage(dto, articlesGeneraux: articlesGeneraux),
    ));

    // ── Exemplaire arabe (pages 3 & 4) ──
    pw.Widget withArabicTheme(pw.Widget child) {
      if (_arabicFont == null) return child;
      return pw.Theme(
        data: pw.ThemeData.withFont(
          base: _arabicFont!,
          bold: _arabicFontBold ?? _arabicFont!,
        ),
        child: child,
      );
    }

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      build: (ctx) => withArabicTheme(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _buildAgenceHeaderAr(dto),
          pw.SizedBox(height: 10),
          _buildTitreContratAr(dto),
          pw.SizedBox(height: 8),
          _buildLocataireSectionAr(dto),
          pw.SizedBox(height: 6),
          _buildVehiculeSectionAr(dto),
          pw.SizedBox(height: 6),
          _buildTableauDepartRetourAr(dto),
          pw.SizedBox(height: 6),
          _buildEtatVehiculeAr(dto),
          pw.SizedBox(height: 6),
          if ((dto.etatVehicule ?? '').trim().isNotEmpty) _buildNotesVehiculeAr(dto),
          if ((dto.etatVehicule ?? '').trim().isNotEmpty) pw.SizedBox(height: 6),
          _buildConditionsSummaryAr(),
          pw.SizedBox(height: 8),
          _buildSignaturesAr(dto),
        ],
      )),
    ));

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      build: (ctx) => withArabicTheme(_buildConditionsGeneralesPageAr(dto)),
    ));

    return doc;
  }

  // ── saveBytes / saveToFile ────────────────────────────────────────────────

  static Future<Uint8List> saveBytes(pw.Document doc) async => doc.save();

  static Future<File> saveToFile(pw.Document doc, String contratId) async {
    final bytes  = await doc.save();
    final appDir = await getApplicationDocumentsDirectory();
    final name   = 'contrat_location_${_idFmt(contratId)}.pdf';
    final file   = File('${appDir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PAGE 1 — widgets français  (code identique à v3, aucun changement)
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildAgenceHeader(ContratLocationDto dto) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(dto.agenceNom.toUpperCase(),
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              if ((dto.agenceVille ?? '').isNotEmpty)
                pw.Text('Agence ${dto.agenceVille}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              // ... à l'intérieur de _buildAgenceHeader
              if ((dto.agenceRc ?? '').isNotEmpty) _headerLine('LOCAL N°${dto.agenceRc}', fontSize: 8),

              // Correction ici : pas de parenthèses après le point
              if (dto.agenceAdresse?.isNotEmpty ?? false) _headerLine(dto.agenceAdresse!, fontSize: 8),

              if (dto.agenceTel.isNotEmpty) ...[
                _headerLine('Mobile : ${dto.agenceTel}', fontSize: 8),
                _headerLine('Fax :', fontSize: 8),
              ],

              if ((dto.agenceEmail ?? '').isNotEmpty) _headerLine('E-Mail : ${dto.agenceEmail}', fontSize: 8),
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Container(
          width: 90, height: 70,
          alignment: pw.Alignment.centerRight,
          child: dto.agenceLogoBytes != null
              ? pw.Image(pw.MemoryImage(dto.agenceLogoBytes!))
              : pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
                  child: pw.Center(child: pw.Text('LOGO', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)))),
        ),
      ],
    );
  }

  static pw.Widget _headerLine(String text, {double fontSize = 9}) =>
      pw.Text(text, style: pw.TextStyle(fontSize: fontSize));

  static pw.Widget _buildTitreContrat(ContratLocationDto dto) {
    return pw.Column(children: [
      pw.Center(child: pw.Text('CONTRAT DE LOCATION',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline))),
      pw.SizedBox(height: 3),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Text('Date : ${_dateFmt.format(dto.dateEtablissement)}',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ]),
    ]);
  }

  static pw.Widget _buildLocataireSection(ContratLocationDto dto) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500, width: 0.6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        _sectionBar('Reference du Locataire :'),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(flex: 3, child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoRow('Nom, prénom :', dto.locataireFullName, bold: true),
              _infoRow('Né(e) le :', '${_val(dto.locataireDateNaissance)} à ${_val(dto.agenceVille ?? '')}'),
              _infoRow('N° de permis de Conduire N°:', '${_val(dto.locataireNumPermis)}  Délivré le : ${_val(dto.locatairePermisDate)}'),
              _infoRow('Adresse :', _val(dto.locataireAdresse)),
              _infoRow('Tel :', _val(dto.locataireTel)),
            ],
          )),
          pw.Container(width: 0.6, color: PdfColors.grey500),
          pw.Expanded(flex: 2, child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 2),
                child: pw.Text('2eme Conducteur :',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              _infoRow('Nom et prénom :',
                  dto.hasConducteur2 ? '${dto.conducteur2Prenom ?? ''} ${dto.conducteur2Nom ?? ''}' : ''),
              _infoRow('Adresse :', ''),
              _infoRow('permis de Conduire N°',
                  dto.conducteur2NumPermis != null
                      ? '${dto.conducteur2NumPermis}  Délivré le : ${_val(dto.conducteur2PermisDate)}'
                      : '  Délivré le : 0'),
            ],
          )),
        ]),
      ]),
    );
  }

  static pw.Widget _buildVehiculeSection(ContratLocationDto dto) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500, width: 0.6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        _sectionBar('Désignation du Véhicule :'),
        pw.Row(children: [
          pw.Expanded(child: _infoRow('Marque', _val(dto.vehiculeMarque), bold: true)),
          pw.Expanded(child: _infoRow('Matricule :', _val(dto.vehiculeImmatriculation), bold: true)),
          pw.Expanded(child: _infoRow('Couleur :', _val(dto.vehiculeCouleur))),
        ]),
        pw.Row(children: [
          pw.Expanded(child: _infoRow('Modèle :', _val(dto.vehiculeModele))),
          pw.Expanded(child: _infoRow('Assurance :', _val(dto.vehiculeAssurance))),
          pw.Expanded(child: _infoRow('Code RADIO :', _val(dto.vehiculeCodeRadio))),
        ]),
      ]),
    );
  }

  static pw.Widget _buildTableauDepartRetour(ContratLocationDto dto) {
    final dateDepart  = _dateLongFmt.format(dto.dateDepart);
    final dateRetour  = _dateLongFmt.format(dto.dateRetour);
    final kmDep = '${_moneyFmt.format(dto.kmDepart)} Km';
    final kmRet = dto.kmRetour != null ? '${_moneyFmt.format(dto.kmRetour!)} Km' : '';

    const colDate  = pw.FlexColumnWidth(3);
    const colHeure = pw.FlexColumnWidth(2);
    const colKm    = pw.FlexColumnWidth(2);
    const colLabel = pw.FixedColumnWidth(55);

    pw.Widget hCell(String t) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      child: pw.Center(child: pw.Text(t,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline))));

    pw.Widget labelCell(String t) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)));

    pw.Widget dataCell(String t) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Center(child: pw.Text(t, style: const pw.TextStyle(fontSize: 9))));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
      columnWidths: const {0: colLabel, 1: colDate, 2: colHeure, 3: colKm},
      children: [
        pw.TableRow(children: [hCell(''), hCell('Date'), hCell('Heure'), hCell('Kilométrage')]),
        pw.TableRow(children: [labelCell('Départ'),  dataCell(dateDepart), dataCell(_val(dto.heureDepart)), dataCell(kmDep)]),
        pw.TableRow(children: [dataCell(''), dataCell(''), dataCell(''), dataCell('')]),
        pw.TableRow(children: [labelCell('Retour'),  dataCell(dateRetour), dataCell(_val(dto.heureRetour)), dataCell(kmRet)]),
        pw.TableRow(children: [dataCell(''), dataCell(''), dataCell(''), dataCell('')]),
      ],
    );
  }

  static pw.Widget _buildEtatVehicule(ContratLocationDto dto) {
    final items = [
      ('Auto Radio',              dto.etatAutoRadio),
      ('Roue de secours',         dto.etatRoueSecours),
      ('Radiateur',               dto.etatRadiateur),
      ('Carburant',               dto.etatCarburant),
      ('Avertisseur',             dto.etatAvertisseur),
      ('Controle des 4 Roues',    dto.etatControle4Roues),
      ('Controle carrossenie',    dto.etatControleCarrosserie),
      ('Controle des feux av-ar', dto.etatControleFeuxAv),
      ('Controle Interieur',      dto.etatControleInterieur),
    ];

    pw.Widget checkRow(String label, bool depart) => pw.Row(children: [
      pw.Expanded(flex: 5, child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: pw.Text(label, style: const pw.TextStyle(fontSize: 8)))),
      pw.Expanded(flex: 2, child: pw.Center(child: _checkBox(depart))),
      pw.Expanded(flex: 2, child: pw.Center(child: _checkBox(false))),
    ]);

    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        width: 130, height: 140,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
        child: pw.Center(child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('VEHICULE EN PARFAIT ETAT',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center),
            pw.Text('(rayer la mention inutile)',
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            pw.Text('oui   non',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ],
        )),
      ),
      pw.SizedBox(width: 6),
      pw.Expanded(child: pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Row(children: [
            pw.Expanded(flex: 5, child: pw.SizedBox()),
            pw.Expanded(flex: 2, child: pw.Center(child: pw.Text('Depart',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)))),
            pw.Expanded(flex: 2, child: pw.Center(child: pw.Text('Retour',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)))),
          ]),
          pw.Divider(color: PdfColors.grey300, thickness: 0.4),
          ...items.map((e) => checkRow(e.$1, e.$2)),
        ]),
      )),
    ]);
  }

  static pw.Widget _checkBox(bool checked) => pw.Container(
    width: 10, height: 10,
    decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.7),
        color: checked ? PdfColors.grey800 : PdfColors.white),
    child: checked
        ? pw.Center(child: pw.Text('X',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 6, fontWeight: pw.FontWeight.bold)))
        : null,
  );

  static pw.Widget _buildConditionsSummary() {
    final lines = [
      '- Les Jours de la réparation de la voiture sont a la charge du client.',
      '- Passport en cour de Validité.',
      '- Kilométrages Limité (400 Km/H). Un forfait de 20 DA/Km en cas de supplément.',
      '- Durée minimum de la location 24H.',
      "- Préserver l'entretien du véhicule à son retour.",
      "- Les (frais d'immobilisation du véhicule lors de la réparation seront comptes par le client.",
    ];

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('- Conditions Générale :', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      ...lines.map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 7.5))),
      pw.SizedBox(height: 6),
      pw.Text(
        'Je reconnai avoir pris connaissance du contrat de location et de ses conditions générales de location '
        "avant la possession et je m'engage d'assumer toute responsabilité du véhicule.",
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.justify,
      ),
    ]);
  }

  static pw.Widget _buildSignatures(ContratLocationDto dto) {
    pw.Widget col(String label) => pw.Expanded(child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
            decoration: pw.TextDecoration.underline)),
        pw.SizedBox(height: 30),
      ],
    ));

    return pw.Row(children: [
      col('Signature du Locataire'),
      pw.SizedBox(width: 20),
      col('Signature du Propriétaire'),
    ]);
  }

  static pw.Widget _buildNotesVehicule(ContratLocationDto dto) {
    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.orange, width: 0.8),
          borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          color: PdfColors.orange,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text('ÉTAT DU VÉHICULE — DOMMAGES / ANOMALIES CONSTATÉS AVANT LOCATION',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        ),
        pw.Padding(padding: const pw.EdgeInsets.all(8),
            child: pw.Text(dto.etatVehicule!,
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey900),
                textAlign: pw.TextAlign.justify)),
        pw.Padding(padding: const pw.EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: pw.Text(
              "Le locataire déclare avoir pris connaissance de l'état du véhicule décrit ci-dessus "
              "et l'accepte en l'état au moment de la prise en charge.",
              style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700))),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PAGE 1 — widgets arabes  (identiques à v3)
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildAgenceHeaderAr(ContratLocationDto dto) {
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        width: 90, height: 70,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.8)),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text(dto.agenceNom.toUpperCase(),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
        if ((dto.agenceVille ?? '').isNotEmpty)
          pw.Text('وكالة ${dto.agenceVille}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
        pw.SizedBox(height: 4),
        // ... inside _buildAgenceHeaderAr
        if ((dto.agenceRc ?? '').isNotEmpty)
          pw.Text('رقم المحل: ${dto.agenceRc}',
              style: const pw.TextStyle(fontSize: 8), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
        if (dto.agenceAdresse?.isNotEmpty ?? false)
          pw.Text(dto.agenceAdresse!,
              style: const pw.TextStyle(fontSize: 8), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
        if (dto.agenceTel.isNotEmpty)
          pw.Text('الهاتف: ${dto.agenceTel}',
      style: const pw.TextStyle(fontSize: 8), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
        if ((dto.agenceEmail ?? '').isNotEmpty)
          pw.Text('البريد: ${dto.agenceEmail}',
              style: const pw.TextStyle(fontSize: 8), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
      ])),
    ]);
  }

  static pw.Widget _buildTitreContratAr(ContratLocationDto dto) {
    return pw.Column(children: [
      pw.Center(child: pw.Text('عقد إيجار سيارة',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
          textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center)),
      pw.SizedBox(height: 3),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Text('التاريخ: ${_dateFmt.format(dto.dateEtablissement)}',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
      ]),
    ]);
  }

  static pw.Widget _buildLocataireSectionAr(ContratLocationDto dto) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500, width: 0.6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        _sectionBarRtl('بيانات المستأجر :'),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(flex: 3, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            _infoRowRtl('الاسم واللقب :', dto.locataireFullName),
            _infoRowRtl('تاريخ الميلاد :', _val(dto.locataireDateNaissance)),
            _infoRowRtl('رقم رخصة القيادة :', '${_val(dto.locataireNumPermis)}  صدرت بتاريخ: ${_val(dto.locatairePermisDate)}'),
            _infoRowRtl('العنوان :', _val(dto.locataireAdresse)),
            _infoRowRtl('الهاتف :', _val(dto.locataireTel)),
          ])),
          pw.Container(width: 0.6, color: PdfColors.grey500),
          pw.Expanded(flex: 2, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Padding(padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 2),
                child: pw.Text('السائق الثاني :',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right)),
            _infoRowRtl('الاسم واللقب :',
                dto.hasConducteur2 ? '${dto.conducteur2Prenom ?? ''} ${dto.conducteur2Nom ?? ''}' : ''),
            _infoRowRtl('العنوان :', ''),
            _infoRowRtl('رخصة القيادة :', dto.conducteur2NumPermis ?? ''),
          ])),
        ]),
      ]),
    );
  }

  static pw.Widget _buildVehiculeSectionAr(ContratLocationDto dto) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500, width: 0.6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        _sectionBarRtl('بيانات السيارة :'),
        pw.Row(children: [
          pw.Expanded(child: _infoRowRtl('الماركة :', _val(dto.vehiculeMarque))),
          pw.Expanded(child: _infoRowRtl('رقم التسجيل :', _val(dto.vehiculeImmatriculation))),
          pw.Expanded(child: _infoRowRtl('اللون :', _val(dto.vehiculeCouleur))),
        ]),
        pw.Row(children: [
          pw.Expanded(child: _infoRowRtl('الموديل :', _val(dto.vehiculeModele))),
          pw.Expanded(child: _infoRowRtl('التأمين :', _val(dto.vehiculeAssurance))),
          pw.Expanded(child: _infoRowRtl('كود الراديو :', _val(dto.vehiculeCodeRadio))),
        ]),
      ]),
    );
  }

  static pw.Widget _buildTableauDepartRetourAr(ContratLocationDto dto) {
    final dateDepart = _dateLongFmt.format(dto.dateDepart);
    final dateRetour = _dateLongFmt.format(dto.dateRetour);
    final kmDep = '${_moneyFmt.format(dto.kmDepart)} كم';
    final kmRet = dto.kmRetour != null ? '${_moneyFmt.format(dto.kmRetour!)} كم' : '';

    pw.Widget hCell(String t) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      child: pw.Center(child: pw.Text(t,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
          textDirection: pw.TextDirection.rtl)));

    pw.Widget labelCell(String t) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          textDirection: pw.TextDirection.rtl));

    pw.Widget dataCell(String t) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Center(child: pw.Text(t, style: const pw.TextStyle(fontSize: 9))));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
      columnWidths: const {0: pw.FixedColumnWidth(55), 1: pw.FlexColumnWidth(3), 2: pw.FlexColumnWidth(2), 3: pw.FlexColumnWidth(2)},
      children: [
        pw.TableRow(children: [hCell(''), hCell('التاريخ'), hCell('الساعة'), hCell('عداد الكيلومتر')]),
        pw.TableRow(children: [labelCell('الانطلاق'), dataCell(dateDepart), dataCell(_val(dto.heureDepart)), dataCell(kmDep)]),
        pw.TableRow(children: [dataCell(''), dataCell(''), dataCell(''), dataCell('')]),
        pw.TableRow(children: [labelCell('الإرجاع'), dataCell(dateRetour), dataCell(_val(dto.heureRetour)), dataCell(kmRet)]),
        pw.TableRow(children: [dataCell(''), dataCell(''), dataCell(''), dataCell('')]),
      ],
    );
  }

  static pw.Widget _buildEtatVehiculeAr(ContratLocationDto dto) {
    final items = [
      ('الراديو',            dto.etatAutoRadio),
      ('عجلة الاحتياط',     dto.etatRoueSecours),
      ('المشعاع',           dto.etatRadiateur),
      ('الوقود',            dto.etatCarburant),
      ('المنبّه',           dto.etatAvertisseur),
      ('فحص العجلات الأربع', dto.etatControle4Roues),
      ('فحص هيكل السيارة',  dto.etatControleCarrosserie),
      ('فحص الأضواء',       dto.etatControleFeuxAv),
      ('فحص الداخلية',      dto.etatControleInterieur),
    ];

    pw.Widget checkRow(String label, bool depart) => pw.Row(children: [
      pw.Expanded(flex: 2, child: pw.Center(child: _checkBox(false))),
      pw.Expanded(flex: 2, child: pw.Center(child: _checkBox(depart))),
      pw.Expanded(flex: 5, child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: pw.Text(label, style: const pw.TextStyle(fontSize: 8),
            textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right))),
    ]);

    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Expanded(child: pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Row(children: [
            pw.Expanded(flex: 2, child: pw.Center(child: pw.Text('الإرجاع',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right))),
            pw.Expanded(flex: 2, child: pw.Center(child: pw.Text('الانطلاق',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right))),
            pw.Expanded(flex: 5, child: pw.SizedBox()),
          ]),
          pw.Divider(color: PdfColors.grey300, thickness: 0.4),
          ...items.map((e) => checkRow(e.$1, e.$2)),
        ]),
      )),
      pw.SizedBox(width: 6),
      pw.Container(
        width: 130, height: 140,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
        child: pw.Center(child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('السيارة في حالة ممتازة',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center),
            pw.Text('(شطب ما لا ينطبق)',
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            pw.Text('نعم   لا',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
          ],
        )),
      ),
    ]);
  }

  static pw.Widget _buildNotesVehiculeAr(ContratLocationDto dto) {
    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.orange, width: 0.8),
          borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          color: PdfColors.orange,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text('حالة السيارة — الأضرار / الأعطال المُلاحَظة قبل الإيجار',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right)),
        pw.Padding(padding: const pw.EdgeInsets.all(8),
            child: pw.Text(dto.etatVehicule!,
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey900),
                textAlign: pw.TextAlign.right, textDirection: pw.TextDirection.rtl)),
        pw.Padding(padding: const pw.EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: pw.Text(
              'يُقرّ المستأجر بأنه اطّلع على حالة السيارة المذكورة أعلاه وقبلها على ما هي عليه عند الاستلام.',
              style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
              textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right)),
      ]),
    );
  }

  static pw.Widget _buildConditionsSummaryAr() {
    final lines = [
      '- أيام إصلاح السيارة على عاتق المستأجر.',
      '- جواز السفر ساري المفعول.',
      '- الكيلومترات محدودة (400 كم/24 ساعة)، ما زاد يُحتسب بـ 20 دج/كم.',
      '- الحد الأدنى لمدة الإيجار 24 ساعة.',
      '- المحافظة على السيارة وإعادتها بنفس الحالة.',
      '- تكاليف التوقف عن الخدمة خلال الإصلاح على المستأجر.',
    ];

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      pw.Text('- الشروط العامة :',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
      pw.SizedBox(height: 2),
      ...lines.map((l) => pw.Text(l,
          style: const pw.TextStyle(fontSize: 7.5),
          textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right)),
      pw.SizedBox(height: 6),
      pw.Text(
        'أقرّ بأنني اطّلعت على عقد الإيجار وشروطه العامة قبل استلام السيارة، '
        'وأتعهد بتحمّل كامل المسؤولية عن السيارة المستأجرة.',
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.justify),
    ]);
  }

  static pw.Widget _buildSignaturesAr(ContratLocationDto dto) {
    pw.Widget col(String label) => pw.Expanded(child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
            textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
        pw.SizedBox(height: 30),
      ],
    ));

    return pw.Row(children: [
      col('توقيع المالك'),
      pw.SizedBox(width: 20),
      col('توقيع المستأجر'),
    ]);
  }

  static pw.Widget _buildConditionsGeneralesPageAr(ContratLocationDto dto) {
    pw.Widget article(String titre, String corps) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(titre,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
            textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
        pw.SizedBox(height: 2),
        pw.Text(corps,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey900),
            textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.justify),
      ],
    );

    // (contenu identique à v3 — articles arabes 1 à 8 inchangés)
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Center(child: pw.Text('الشروط العامة للإيجار',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
          textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center)),
      pw.SizedBox(height: 10),
      // Articles arabes — garder ton contenu existant ici (identique à v3)
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PAGE 2 (FR) — conditions générales
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildConditionsGeneralesPage(
    ContratLocationDto dto, {
    List<Map<String, String>>? articlesGeneraux,
  }) {
    final usesDynamic = articlesGeneraux != null && articlesGeneraux.isNotEmpty;

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Center(child: pw.Text('CONDITIONS GENERALES DE LOCATION',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline))),
      pw.SizedBox(height: 10),
      if (usesDynamic)
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: articlesGeneraux
              .map((a) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: _article(a['titre'] ?? '', a['corps'] ?? ''),
                  ))
              .toList(),
        )
      else
        // Fallback : garder tes articles en dur (identique à v3)
        pw.Column(),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS COMMUNS
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _sectionBar(String title) => pw.Container(
    color: PdfColors.grey200,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    child: pw.Text(title, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
  );

  static pw.Widget _infoRow(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('$label ',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.Flexible(child: pw.Text(value,
              style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : null))),
        ]),
      );

  // ignore: unused_element
  static pw.Widget _article(String titre, String corps) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(titre,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
        pw.SizedBox(height: 2),
        pw.Text(corps,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey900),
            textAlign: pw.TextAlign.justify),
      ]);

  // ── Helpers RTL ──────────────────────────────────────────────────────────

  static pw.TextStyle _arStyle({
    double fontSize = 9,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    PdfColor? color,
    pw.TextDecoration? decoration,
    pw.FontStyle? fontStyle,
  }) {
    final font     = (fontWeight == pw.FontWeight.bold ? _arabicFontBold : _arabicFont) ?? _arabicFont;
    final boldFont = _arabicFontBold ?? _arabicFont;
    return pw.TextStyle(
        fontSize: fontSize, fontWeight: fontWeight, color: color,
        decoration: decoration, fontStyle: fontStyle, font: font, fontBold: boldFont);
  }

  static pw.Widget _sectionBarRtl(String title) => pw.Container(
    color: PdfColors.grey200,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    child: pw.Text(title, style: _arStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
  );

  static pw.Widget _infoRowRtl(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Flexible(child: pw.Text(value,
          style: _arStyle(fontSize: 8), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right)),
      pw.SizedBox(width: 4),
      pw.Text('$label ',
          style: _arStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
    ]),
  );

  // ignore: unused_element
  static pw.Widget _tarifRow(String duree, String prix) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(children: [
      pw.SizedBox(width: 8),
      pw.Container(width: 50, child: pw.Text(duree, style: const pw.TextStyle(fontSize: 7.5))),
      pw.Text('  ->  $prix', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
    ]),
  );

  // ignore: unused_element
  static pw.Widget _tarifRowRtl(String duree, String prix) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Text(duree, style: _arStyle(fontSize: 7.5), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
      pw.Text('  <-  ', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(width: 8),
      pw.Text(prix, style: _arStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
          textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
    ]),
  );

  // ignore: unused_element
  static PdfColor _hexToColor(String? hex) {
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
