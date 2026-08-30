// lib/core/services/pdf/contrat_location_pdf_generator.dart
//
// Générateur PDF — Contrat de location de véhicule (FR + AR, 2 pages chacun).
// Dépend de :
//   pdf_theme.dart    → polices, couleurs, formateurs
//   pdf_layout.dart   → widgets partagés
//   vehicle_schema_pdf_renderer.dart
//   features/contrats/domain/contrat_location_dto.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_theme.dart' hide debugPrint;
import 'vehicle_schema_pdf_renderer.dart';
import '../../../features/contrats/domain/contrat_location_dto.dart';
import '../../../features/contrats/domain/contrat_location_champs.dart';

export '../../../features/contrats/domain/contrat_location_dto.dart';

class ContratLocationPdfGenerator {
  ContratLocationPdfGenerator._();

  static String _v(String? s) => (s == null || s.isEmpty) ? '' : s;

  /// Champs actifs pour la génération en cours (voir même mécanisme que
  /// ContratLocationClassiquePdfGenerator).
  static Set<String> _champs = ContratLocationChamps.toActiveSet(ContratLocationChamps.defaults);
  static bool _on(String key) => _champs.contains(key);

  // ── Points d'entrée ────────────────────────────────────────────────────────

  /// Génère les deux documents (FR + AR) et les retourne en mémoire.
  static Future<ContratLocationPdfPair> buildBothAsync(
    ContratLocationDto dto, {
    List<Map<String, String>>? articlesFr,
    List<Map<String, String>>? articlesAr,
    Set<String>? champsActifs,
  }) async {
    _champs = champsActifs ?? ContratLocationChamps.toActiveSet(ContratLocationChamps.defaults);
    pw.Widget? schemaWidget;

    debugPrint('🔍 [PDF] etatCarrosserie: ${dto.etatCarrosserie != null ? "non-null, pins: ${dto.etatCarrosserie!.pins.length}" : "NULL"}');
    debugPrint('🔍 [PDF] blueprintBytes: ${dto.blueprintBytes != null ? "${dto.blueprintBytes!.length} bytes" : "NULL"}');

    if (dto.etatCarrosserie != null && dto.etatCarrosserie!.hasAnyDamage) {
      debugPrint('🖼️ [PDF] Chargement blueprint carrosserie...');
      try {
        if (dto.blueprintBytes != null) {
          // Bytes pré-chargés — chemin fiable (form ou ContratsScreen)
          debugPrint('🖼️ [PDF] Bytes disponibles: ${dto.blueprintBytes!.length} bytes');
          schemaWidget = VehicleSchemaPdfRenderer.buildWidgetFromBytes(
            dto.blueprintBytes!,
            dto.etatCarrosserie!,
          );
          debugPrint('✅ [PDF] Blueprint chargé depuis bytes pré-fournis');
        } else {
          // Fallback rootBundle (régénération depuis écran Contrats)
          schemaWidget = await VehicleSchemaPdfRenderer.buildWidget(
            dto.etatCarrosserie!,
          );
          debugPrint('✅ [PDF] Blueprint chargé via rootBundle');
        }
      } catch (e) {
        debugPrint('⚠️ [PDF] Échec chargement blueprint: $e');
        schemaWidget = null;
      }
    } else {
      debugPrint('ℹ️ [PDF] Pas de dommages — maquette omise');
    }

    final d = dto.withSchemaWidget(schemaWidget);
    debugPrint('🔍 [PDF] schemaWidget après withSchemaWidget: ${d.schemaWidget != null ? "OK" : "NULL"}');
    await PdfTheme.loadAllFonts();
    return ContratLocationPdfPair(
      fr: _buildFr(d, articles: articlesFr),
      ar: _buildAr(d, articles: articlesAr),
    );
  }

  static Future<Uint8List> saveBytes(pw.Document doc) async => doc.save();

  static Future<List<File>> saveBothToFiles(
      ContratLocationPdfPair pair, String contratId) async {
    if (kIsWeb) throw UnsupportedError('Non disponible sur Web.');
    final dir = await getApplicationDocumentsDirectory();
    final id  = PdfTheme.shortId(contratId);
    final fr  = File('${dir.path}/contrat_location_${id}_FR.pdf')
      ..writeAsBytesSync(await pair.fr.save());
    final ar  = File('${dir.path}/contrat_location_${id}_AR.pdf')
      ..writeAsBytesSync(await pair.ar.save());
    return [fr, ar];
  }

  // ── Document Français ──────────────────────────────────────────────────────

  static pw.Document _buildFr(
    ContratLocationDto dto, {
    List<Map<String, String>>? articles,
  }) {
    final doc = pw.Document();

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      build: (ctx) => PdfTheme.withLatinTheme(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _headerFr(dto),
          pw.SizedBox(height: 10),
          _titreContratFr(dto),
          pw.SizedBox(height: 8),
          _locataireFr(dto),
          pw.SizedBox(height: 6),
          _vehiculeFr(dto),
          pw.SizedBox(height: 6),
          _tableauDepartRetourFr(dto),
          pw.SizedBox(height: 6),
          _etatVehicule(dto, rtl: false),
          pw.SizedBox(height: 6),
          if (dto.schemaWidget != null) ...[
            _schemaCarrosserie(dto),
            pw.SizedBox(height: 6),
          ],
          if ((dto.etatVehicule ?? '').isNotEmpty) ...[
            _notesVehiculeFr(dto),
            pw.SizedBox(height: 6),
          ],
          _conditionsSummaryFr(),
          pw.SizedBox(height: 8),
          _signaturesFr(),
        ],
      )),
    ));

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      build: (_) => PdfTheme.withLatinTheme(
        _conditionsGeneralesFr(articles),
      ),
    ));

    return doc;
  }

  // ── Document Arabe ─────────────────────────────────────────────────────────

  static pw.Document _buildAr(
    ContratLocationDto dto, {
    List<Map<String, String>>? articles,
  }) {
    final doc = pw.Document();

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      build: (_) => PdfTheme.withArabicTheme(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _headerAr(dto),
          pw.SizedBox(height: 10),
          _titreContratAr(dto),
          pw.SizedBox(height: 8),
          _locataireAr(dto),
          pw.SizedBox(height: 6),
          _vehiculeAr(dto),
          pw.SizedBox(height: 6),
          _tableauDepartRetourAr(dto),
          pw.SizedBox(height: 6),
          _etatVehicule(dto, rtl: true),
          pw.SizedBox(height: 6),
          if (dto.schemaWidget != null) ...[
            _schemaCarrosserie(dto),
            pw.SizedBox(height: 6),
          ],
          if ((dto.etatVehicule ?? '').isNotEmpty) ...[
            _notesVehiculeAr(dto),
            pw.SizedBox(height: 6),
          ],
          _conditionsSummaryAr(),
          pw.SizedBox(height: 8),
          _signaturesAr(),
        ],
      )),
    ));

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      build: (_) => PdfTheme.withArabicTheme(
        _conditionsGeneralesAr(articles),
      ),
    ));

    return doc;
  }

  // ── Widgets FR ─────────────────────────────────────────────────────────────

  static pw.Widget _headerFr(ContratLocationDto dto) =>
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(dto.agenceNom.toUpperCase(),
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            if (_v(dto.agenceVille).isNotEmpty)
              pw.Text('Agence ${dto.agenceVille}',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            if (_v(dto.agenceRc).isNotEmpty)
              pw.Text('LOCAL N°${dto.agenceRc}', style: const pw.TextStyle(fontSize: 8)),
            if (_v(dto.agenceAdresse).isNotEmpty)
              pw.Text(dto.agenceAdresse, style: const pw.TextStyle(fontSize: 8)),
            if (dto.agenceTel.isNotEmpty)
              pw.Text('Mobile : ${dto.agenceTel}', style: const pw.TextStyle(fontSize: 8)),
            if (_v(dto.agenceEmail).isNotEmpty)
              pw.Text('E-Mail : ${dto.agenceEmail}', style: const pw.TextStyle(fontSize: 8)),
          ],
        )),
        pw.SizedBox(width: 12),
        pw.Container(
          width: 90, height: 70,
          alignment: pw.Alignment.centerRight,
          child: dto.agenceLogoBytes != null
              ? pw.Image(pw.MemoryImage(dto.agenceLogoBytes!))
              : pw.Container(
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
                  child: pw.Center(child: pw.Text('LOGO',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)))),
        ),
      ]);

  static pw.Widget _titreContratFr(ContratLocationDto dto) =>
      pw.Column(children: [
        pw.Center(child: pw.Text('CONTRAT DE LOCATION',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline))),
        pw.SizedBox(height: 3),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Text('Date : ${PdfTheme.fmtDate(dto.dateEtablissement)}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ]),
      ]);

  static pw.Widget _locataireFr(ContratLocationDto dto) =>
      pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey500, width: 0.6)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          _sectionBar('Reference du Locataire :'),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(flex: 3, child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('Nom, prénom :', dto.locataireFullName, bold: true),
                if (_on('locataire_naissance')) _infoRow('Né(e) le :', _v(dto.locataireDateNaissance)),
                if (_on('locataire_permis')) _infoRow('N° permis :', '${_v(dto.locataireNumPermis)}  Délivré le : ${_v(dto.locatairePermisDate)}'),
                if (_on('locataire_adresse')) _infoRow('Adresse :', _v(dto.locataireAdresse)),
                _infoRow('Tel :', _v(dto.locataireTel)),
              ],
            )),
            if (_on('locataire_conducteur2')) ...[
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
                      dto.hasConducteur2
                          ? '${dto.conducteur2Prenom ?? ''} ${dto.conducteur2Nom ?? ''}'
                          : ''),
                  _infoRow('Permis N°:', '${_v(dto.conducteur2NumPermis)}  Délivré le : ${_v(dto.conducteur2PermisDate)}'),
                ],
              )),
            ],
          ]),
        ]),
      );

  static pw.Widget _vehiculeFr(ContratLocationDto dto) =>
      pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey500, width: 0.6)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          _sectionBar('Désignation du Véhicule :'),
          pw.Row(children: [
            pw.Expanded(child: _infoRow('Marque :', _v(dto.vehiculeMarque), bold: true)),
            pw.Expanded(child: _infoRow('Matricule :', _v(dto.vehiculeImmatriculation), bold: true)),
            if (_on('vehicule_couleur')) pw.Expanded(child: _infoRow('Couleur :', _v(dto.vehiculeCouleur))),
          ]),
          pw.Row(children: [
            pw.Expanded(child: _infoRow('Modèle :', _v(dto.vehiculeModele))),
            if (_on('vehicule_assurance')) pw.Expanded(child: _infoRow('Assurance :', _v(dto.vehiculeAssurance))),
            if (_on('vehicule_code_radio')) pw.Expanded(child: _infoRow('Code RADIO :', _v(dto.vehiculeCodeRadio))),
          ]),
        ]),
      );

  static pw.Widget _tableauDepartRetourFr(ContratLocationDto dto) {
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
      columnWidths: const {
        0: pw.FixedColumnWidth(55),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(children: [hCell(''), hCell('Date'), hCell('Heure'), hCell('Kilométrage')]),
        pw.TableRow(children: [
          labelCell('Départ'),
          dataCell(PdfTheme.fmtDateLong(dto.dateDepart)),
          dataCell(_v(dto.heureDepart)),
          dataCell(PdfTheme.fmtKm(dto.kmDepart)),
        ]),
        pw.TableRow(children: [dataCell(''), dataCell(''), dataCell(''), dataCell('')]),
        pw.TableRow(children: [
          labelCell('Retour'),
          dataCell(PdfTheme.fmtDateLong(dto.dateRetour)),
          dataCell(_v(dto.heureRetour)),
          dataCell(dto.kmRetour != null ? PdfTheme.fmtKm(dto.kmRetour!) : ''),
        ]),
        pw.TableRow(children: [dataCell(''), dataCell(''), dataCell(''), dataCell('')]),
      ],
    );
  }

  static pw.Widget _conditionsSummaryFr() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(
        "Je reconnais avoir pris connaissance du contrat de location et de ses conditions générales "
        "avant la possession et je m'engage d'assumer toute responsabilité du véhicule.",
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.justify,
      ),
    ]);
  }

  static pw.Widget _signaturesFr() {
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

  static pw.Widget _conditionsGeneralesFr(List<Map<String, String>>? articles) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Center(child: pw.Text('CONDITIONS GENERALES DE LOCATION',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline))),
        pw.SizedBox(height: 10),
        if (articles != null && articles.isNotEmpty)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: articles.map((a) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: _articleFr(a['titre'] ?? '', a['corps'] ?? ''),
            )).toList(),
          ),
      ]);

  static pw.Widget _notesVehiculeFr(ContratLocationDto dto) =>
      pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.orange, width: 0.8),
            borderRadius: pw.BorderRadius.circular(3)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            color: PdfColors.orange,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: pw.Text('ÉTAT DU VÉHICULE — DOMMAGES AVANT LOCATION',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ),
          pw.Padding(padding: const pw.EdgeInsets.all(8),
              child: pw.Text(dto.etatVehicule!,
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey900),
                  textAlign: pw.TextAlign.justify)),
        ]),
      );

  // ── Widgets AR ─────────────────────────────────────────────────────────────

  static pw.Widget _headerAr(ContratLocationDto dto) =>
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // ✅ FIX : sous pw.Directionality(rtl) (posée par withArabicTheme),
        // pw.Row place son PREMIER enfant le plus à DROITE — pas le
        // dernier. Pour obtenir le miroir correct de _headerFr (nom +
        // coordonnées à droite, logo à gauche), c'est donc le bloc texte
        // qui doit être le premier enfant, et le logo le dernier.
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(dto.agenceNom.toUpperCase(),
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
          if (_v(dto.agenceVille).isNotEmpty)
            pw.Text('وكالة ${dto.agenceVille}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
          pw.SizedBox(height: 4),
          if (_v(dto.agenceRc).isNotEmpty)
            pw.Text('رقم السجل التجاري: ${dto.agenceRc}',
                style: const pw.TextStyle(fontSize: 8),
                textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
          if (_v(dto.agenceAdresse).isNotEmpty)
            pw.Text(dto.agenceAdresse,
                style: const pw.TextStyle(fontSize: 8),
                textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
          if (_v(dto.agenceTel).isNotEmpty)
            pw.Text('الهاتف: ${dto.agenceTel}',
                style: const pw.TextStyle(fontSize: 8),
                textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
          if (_v(dto.agenceEmail).isNotEmpty)
            pw.Text('البريد: ${dto.agenceEmail}',
                style: const pw.TextStyle(fontSize: 8),
                textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
        ])),
        pw.SizedBox(width: 12),
        pw.Container(
          width: 90, height: 70,
          alignment: pw.Alignment.centerLeft,
          child: dto.agenceLogoBytes != null
              ? pw.Image(pw.MemoryImage(dto.agenceLogoBytes!))
              : pw.Container(
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
                  child: pw.Center(child: pw.Text('LOGO',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)))),
        ),
      ]);

  static pw.Widget _titreContratAr(ContratLocationDto dto) =>
      pw.Column(children: [
        pw.Center(child: pw.Text('عقد إيجار سيارة',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline),
            textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center)),
        pw.SizedBox(height: 3),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.start, children: [
          pw.Text('التاريخ: ${PdfTheme.fmtDate(dto.dateEtablissement)}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
        ]),
      ]);

  static pw.Widget _locataireAr(ContratLocationDto dto) =>
      pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey500, width: 0.6)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          _sectionBarAr('بيانات المستأجر :'),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(flex: 3, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _infoRowAr('الاسم واللقب :', dto.locataireFullName),
              if (_on('locataire_naissance')) _infoRowAr('تاريخ الميلاد :', _v(dto.locataireDateNaissance)),
              if (_on('locataire_permis')) _infoRowAr('رقم رخصة القيادة :', '${_v(dto.locataireNumPermis)}  صدرت: ${_v(dto.locatairePermisDate)}'),
              if (_on('locataire_adresse')) _infoRowAr('العنوان :', _v(dto.locataireAdresse)),
              _infoRowAr('الهاتف :', _v(dto.locataireTel)),
            ])),
            if (_on('locataire_conducteur2')) ...[
              pw.Container(width: 0.6, color: PdfColors.grey500),
              pw.Expanded(flex: 2, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 2),
                  child: pw.Text('السائق الثاني :',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
                ),
                _infoRowAr('الاسم :', dto.hasConducteur2
                    ? '${dto.conducteur2Prenom ?? ''} ${dto.conducteur2Nom ?? ''}' : ''),
                // ✅ FIX : la date de délivrance du permis du 2ème conducteur
                // était affichée en FR mais absente ici.
                _infoRowAr('رخصة القيادة :',
                    '${_v(dto.conducteur2NumPermis)}  صدرت: ${_v(dto.conducteur2PermisDate)}'),
              ])),
            ],
          ]),
        ]),
      );

  static pw.Widget _vehiculeAr(ContratLocationDto dto) =>
      pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey500, width: 0.6)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          _sectionBarAr('بيانات السيارة :'),
          pw.Row(children: [
            pw.Expanded(child: _infoRowAr('الماركة :', _v(dto.vehiculeMarque))),
            pw.Expanded(child: _infoRowAr('رقم التسجيل :', _v(dto.vehiculeImmatriculation))),
            if (_on('vehicule_couleur')) pw.Expanded(child: _infoRowAr('اللون :', _v(dto.vehiculeCouleur))),
          ]),
          pw.Row(children: [
            pw.Expanded(child: _infoRowAr('الموديل :', _v(dto.vehiculeModele))),
            if (_on('vehicule_assurance')) pw.Expanded(child: _infoRowAr('التأمين :', _v(dto.vehiculeAssurance))),
            if (_on('vehicule_code_radio')) pw.Expanded(child: _infoRowAr('كود الراديو :', _v(dto.vehiculeCodeRadio))),
          ]),
        ]),
      );

  static pw.Widget _tableauDepartRetourAr(ContratLocationDto dto) {
    pw.Widget hCell(String t) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      child: pw.Center(child: pw.Text(t,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline),
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
      columnWidths: const {
        0: pw.FixedColumnWidth(55),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(children: [hCell(''), hCell('التاريخ'), hCell('الساعة'), hCell('عداد الكيلومتر')]),
        pw.TableRow(children: [
          labelCell('الانطلاق'),
          dataCell(PdfTheme.fmtDateLong(dto.dateDepart)),
          dataCell(_v(dto.heureDepart)),
          dataCell(PdfTheme.fmtKm(dto.kmDepart)),
        ]),
        pw.TableRow(children: [dataCell(''), dataCell(''), dataCell(''), dataCell('')]),
        pw.TableRow(children: [
          labelCell('الإرجاع'),
          dataCell(PdfTheme.fmtDateLong(dto.dateRetour)),
          dataCell(_v(dto.heureRetour)),
          dataCell(dto.kmRetour != null ? PdfTheme.fmtKm(dto.kmRetour!) : ''),
        ]),
        pw.TableRow(children: [dataCell(''), dataCell(''), dataCell(''), dataCell('')]),
      ],
    );
  }

  static pw.Widget _conditionsSummaryAr() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(
        'أقر بأنني اطلعت على عقد الإيجار وشروطه العامة قبل استلام السيارة، وأتعهد بتحمل كامل المسؤولية عنها.',
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right,
      ),
    ]);
  }

  static pw.Widget _signaturesAr() {
    pw.Widget col(String label) => pw.Expanded(child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
            decoration: pw.TextDecoration.underline),
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

  static pw.Widget _notesVehiculeAr(ContratLocationDto dto) =>
      pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.orange, width: 0.8),
            borderRadius: pw.BorderRadius.circular(3)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            color: PdfColors.orange,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: pw.Text('حالة السيارة — الأضرار قبل الإيجار',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
                textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
          ),
          pw.Padding(padding: const pw.EdgeInsets.all(8),
              child: pw.Text(dto.etatVehicule!,
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey900),
                  textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right)),
        ]),
      );

  static pw.Widget _conditionsGeneralesAr(List<Map<String, String>>? articles) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Center(child: pw.Text('الشروط العامة للإيجار',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline),
            textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center)),
        pw.SizedBox(height: 10),
        if (articles != null && articles.isNotEmpty)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: articles.map((a) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: _articleAr(a['titre'] ?? '', a['corps'] ?? ''),
            )).toList(),
          ),
      ]);

  // ── Widgets communs FR + AR ────────────────────────────────────────────────

  static pw.Widget _etatVehicule(ContratLocationDto dto, {required bool rtl}) {
    final itemsFr = [
      ('Auto Radio', dto.etatAutoRadio), ('Roue de secours', dto.etatRoueSecours),
      ('Radiateur', dto.etatRadiateur), ('Carburant', dto.etatCarburant),
      ('Avertisseur', dto.etatAvertisseur), ('Controle des 4 Roues', dto.etatControle4Roues),
      ('Controle carrosserie', dto.etatControleCarrosserie),
      ('Controle des feux', dto.etatControleFeuxAv),
      ('Controle Interieur', dto.etatControleInterieur),
    ];
    final itemsAr = [
      ('الراديو', dto.etatAutoRadio), ('عجلة الاحتياط', dto.etatRoueSecours),
      ('المشعاع', dto.etatRadiateur), ('الوقود', dto.etatCarburant),
      ('المنبّه', dto.etatAvertisseur), ('فحص العجلات الأربع', dto.etatControle4Roues),
      ('فحص هيكل السيارة', dto.etatControleCarrosserie),
      ('فحص الأضواء', dto.etatControleFeuxAv),
      ('فحص الداخلية', dto.etatControleInterieur),
    ];
    final items = rtl ? itemsAr : itemsFr;

    pw.Widget checkBox(bool checked) => pw.Container(
      width: 10, height: 10,
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey600, width: 0.7),
          color: checked ? PdfColors.grey800 : PdfColors.white),
      child: checked
          ? pw.Center(child: pw.Text('X',
              style: pw.TextStyle(color: PdfColors.white, fontSize: 6,
                  fontWeight: pw.FontWeight.bold)))
          : null,
    );

    pw.Widget checkRow(String label, bool depart) => rtl
        ? pw.Row(children: [
            pw.Expanded(flex: 2, child: pw.Center(child: checkBox(false))),
            pw.Expanded(flex: 2, child: pw.Center(child: checkBox(depart))),
            pw.Expanded(flex: 5, child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: pw.Text(label, style: const pw.TextStyle(fontSize: 8),
                  textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right))),
          ])
        : pw.Row(children: [
            pw.Expanded(flex: 5, child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: pw.Text(label, style: const pw.TextStyle(fontSize: 8)))),
            pw.Expanded(flex: 2, child: pw.Center(child: checkBox(depart))),
            pw.Expanded(flex: 2, child: pw.Center(child: checkBox(false))),
          ]);

    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        width: 130, height: 140,
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
        child: pw.Center(child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(rtl ? 'السيارة في حالة ممتازة' : 'VEHICULE EN PARFAIT ETAT',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            pw.Text(rtl ? 'نعم   لا' : 'oui   non',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr),
          ],
        )),
      ),
      pw.SizedBox(width: 6),
      pw.Expanded(child: pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Divider(color: PdfColors.grey300, thickness: 0.4),
          ...items.map((e) => checkRow(e.$1, e.$2)),
        ]),
      )),
    ]);
  }

  static pw.Widget _schemaCarrosserie(ContratLocationDto dto) =>
      pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.8),
            borderRadius: pw.BorderRadius.circular(3)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            color: PdfColors.blueGrey700,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: pw.Text('ÉTAT DE LA CARROSSERIE',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ),
          pw.Padding(padding: const pw.EdgeInsets.all(8), child: dto.schemaWidget!),
        ]),
      );

  // ── Helpers communs ────────────────────────────────────────────────────────

  static pw.Widget _sectionBar(String title) => pw.Container(
    color: PdfColors.grey200,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    child: pw.Text(title,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
  );

  static pw.Widget _sectionBarAr(String title) => pw.Container(
    color: PdfColors.grey200,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    child: pw.Text(title,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
  );

  static pw.Widget _infoRow(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('$label ',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800)),
          // smartText: si le client a saisi son nom en arabe, la bonne police
          // et le bon sens d'écriture sont appliqués automatiquement, même
          // si le reste de cette page est en français.
          pw.Flexible(child: PdfTheme.smartText(value, fontSize: 8, bold: bold)),
        ]),
      );

  static pw.Widget _infoRowAr(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    // Toute la page arabe est enveloppée dans un pw.Directionality(rtl) par
    // PdfTheme.withArabicTheme(). Ce pdf package fait hériter pw.Row de
    // cette direction ambiante : le PREMIER enfant de la liste "children"
    // devient l'élément le plus à DROITE (pas le dernier). D'où le bug
    // précédent : en mettant value en premier, il se retrouvait collé au
    // bord droit et label à gauche. On inverse donc l'ordre : label en
    // premier enfant (→ le plus à droite, lu en premier en arabe), puis la
    // valeur en dernier enfant (Expanded, absorbe le reste de la largeur,
    // texte aligné à droite → hugging vers le label).
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('$label ',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800),
            textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
        pw.SizedBox(width: 4),
        pw.Expanded(child: PdfTheme.smartText(value,
            fontSize: 8, textAlign: pw.TextAlign.right)),
      ],
    ),
  );

  static pw.Widget _articleFr(String titre, String corps) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (titre.isNotEmpty)
          pw.Text(titre,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline)),
        pw.SizedBox(height: 2),
        pw.Text(corps,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey900),
            textAlign: pw.TextAlign.justify),
      ]);

  static pw.Widget _articleAr(String titre, String corps) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (titre.isNotEmpty)
          pw.Text(titre,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline),
              textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
        pw.SizedBox(height: 2),
        pw.Text(corps,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey900),
            textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
      ]);
}