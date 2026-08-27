// lib/core/services/pdf/contrat_location_classique_pdf_generator.dart
//
// Générateur PDF — Contrat de location de véhicule, template "classique"
// (2ème habillage disponible, au choix de l'utilisateur à la génération).
// Reprend la structure d'un contrat de location d'agence type :
//   - Encadrés LOCATAIRE / LOUEUR côte à côte
//   - Encadrés VÉHICULE / LA LOCATION côte à côte
//   - Schéma carrosserie + encadré kilométrage/carburant + remarques
//   - Page 2 : "Compte rendu de fin de location" + "Conditions générales"
//
// Dépend de :
//   pdf_theme.dart    → polices, couleurs, formateurs
//   vehicle_schema_pdf_renderer.dart
//   features/contrats/domain/contrat_location_dto.dart
//
// FR + AR, 2 pages chacun (même contrat que ContratLocationPdfGenerator,
// habillage différent — voir ContratLocationTemplate).

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_theme.dart' hide debugPrint;
import 'vehicle_schema_pdf_renderer.dart';
import '../../../features/contrats/domain/contrat_location_dto.dart';

class ContratLocationClassiquePdfGenerator {
  ContratLocationClassiquePdfGenerator._();

  static String _v(String? s) => (s == null || s.isEmpty) ? '—' : s;

  // ── Points d'entrée ────────────────────────────────────────────────────────

  static Future<ContratLocationPdfPair> buildBothAsync(
    ContratLocationDto dto, {
    List<Map<String, String>>? articlesFr,
    List<Map<String, String>>? articlesAr,
  }) async {
    pw.Widget? schemaWidget;

    if (dto.etatCarrosserie != null && dto.etatCarrosserie!.hasAnyDamage) {
      try {
        if (dto.blueprintBytes != null) {
          schemaWidget = VehicleSchemaPdfRenderer.buildWidgetFromBytes(
            dto.blueprintBytes!,
            dto.etatCarrosserie!,
          );
        } else {
          schemaWidget = await VehicleSchemaPdfRenderer.buildWidget(
            dto.etatCarrosserie!,
          );
        }
      } catch (e) {
        debugPrint('⚠️ [PDF-classique] Échec chargement blueprint: $e');
        schemaWidget = null;
      }
    }

    final d = dto.withSchemaWidget(schemaWidget);
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
    final id = PdfTheme.shortId(contratId);
    final fr = File('${dir.path}/contrat_location_classique_${id}_FR.pdf')
      ..writeAsBytesSync(await pair.fr.save());
    final ar = File('${dir.path}/contrat_location_classique_${id}_AR.pdf')
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
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      build: (ctx) => PdfTheme.withLatinTheme(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _headerFr(dto),
          pw.SizedBox(height: 10),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: _boxLocataireFr(dto)),
            pw.SizedBox(width: 6),
            pw.Expanded(child: _boxLoueurFr(dto)),
          ]),
          pw.SizedBox(height: 6),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: _boxVehiculeFr(dto)),
            pw.SizedBox(width: 6),
            pw.Expanded(child: _boxLocationFr(dto)),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              flex: 3,
              child: dto.schemaWidget != null
                  ? _schemaCarrosserie(dto, 'VEUILLEZ INDIQUER SUR CE SCHÉMA LES DOMMAGES VISIBLES SUR LE VÉHICULE')
                  : _schemaPlaceholder(),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              flex: 2,
              child: pw.Column(children: [
                _boxKmCarburantFr(dto),
                pw.SizedBox(height: 6),
                _boxRemarquesFr(dto),
              ]),
            ),
          ]),
          pw.SizedBox(height: 10),
          _mentionEngagementFr(),
          pw.SizedBox(height: 10),
          _signaturesFr(),
        ],
      )),
    ));

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      build: (_) => PdfTheme.withLatinTheme(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _compteRenduFinLocationFr(dto),
          pw.SizedBox(height: 14),
          _conditionsGeneralesFr(articles),
        ],
      )),
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
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      build: (ctx) => PdfTheme.withArabicTheme(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _headerAr(dto),
          pw.SizedBox(height: 10),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: _boxLoueurAr(dto)),
            pw.SizedBox(width: 6),
            pw.Expanded(child: _boxLocataireAr(dto)),
          ]),
          pw.SizedBox(height: 6),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: _boxLocationAr(dto)),
            pw.SizedBox(width: 6),
            pw.Expanded(child: _boxVehiculeAr(dto)),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              flex: 2,
              child: pw.Column(children: [
                _boxKmCarburantAr(dto),
                pw.SizedBox(height: 6),
                _boxRemarquesAr(dto),
              ]),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              flex: 3,
              child: dto.schemaWidget != null
                  ? _schemaCarrosserie(dto, 'يرجى تحديد الأضرار الظاهرة على السيارة في هذا المخطط', rtl: true)
                  : _schemaPlaceholder(rtl: true),
            ),
          ]),
          pw.SizedBox(height: 10),
          _mentionEngagementAr(),
          pw.SizedBox(height: 10),
          _signaturesAr(),
        ],
      )),
    ));

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      build: (_) => PdfTheme.withArabicTheme(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _compteRenduFinLocationAr(dto),
          pw.SizedBox(height: 14),
          _conditionsGeneralesAr(articles),
        ],
      )),
    ));

    return doc;
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  static pw.Widget _headerFr(ContratLocationDto dto) {
    final color = PdfTheme.hexColor(dto.agenceCouleurHex);
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('CONTRAT DE LOCATION',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: color)),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('N° ${PdfTheme.shortId(dto.contratId)}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          if (dto.agenceLogoBytes != null) ...[
            pw.SizedBox(height: 4),
            pw.Image(pw.MemoryImage(dto.agenceLogoBytes!), height: 32, fit: pw.BoxFit.contain),
          ],
        ]),
      ]),
      pw.SizedBox(height: 2),
      pw.Text(
        '${dto.agenceNom} - ${_v(dto.agenceAdresse)}',
        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
      ),
      if (dto.agenceTel.isNotEmpty)
        pw.Text('Tél : ${dto.agenceTel}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
      if ((dto.agenceEmail ?? '').isNotEmpty)
        pw.Text(dto.agenceEmail!, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
      pw.SizedBox(height: 6),
      pw.Divider(color: color, thickness: 1.2),
    ]);
  }

  static pw.Widget _headerAr(ContratLocationDto dto) {
    final color = PdfTheme.hexColor(dto.agenceCouleurHex);
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      // ✅ FIX : sous Directionality(rtl), le PREMIER enfant du Row finit à
      // DROITE. Pour un vrai miroir du header FR (titre à l'emplacement
      // "de départ" = gauche en FR, droite en AR ; le n° de contrat à
      // l'emplacement "de fin" = droite en FR, gauche en AR), le titre doit
      // donc être listé en premier ici, pas le numéro de contrat.
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        PdfTheme.arText('عقد إيجار سيارة', fontSize: 22, bold: true, color: color),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Text('N° ${PdfTheme.shortId(dto.contratId)}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          if (dto.agenceLogoBytes != null) ...[
            pw.SizedBox(height: 4),
            pw.Image(pw.MemoryImage(dto.agenceLogoBytes!), height: 32, fit: pw.BoxFit.contain),
          ],
        ]),
      ]),
      pw.SizedBox(height: 2),
      PdfTheme.arText(dto.agenceNom, fontSize: 9, bold: true, color: PdfColors.grey800),
      if (_v(dto.agenceAdresse).isNotEmpty)
        PdfTheme.arText(dto.agenceAdresse, fontSize: 8.5, color: PdfColors.grey700),
      if (dto.agenceTel.isNotEmpty)
        PdfTheme.arText('الهاتف : ${dto.agenceTel}', fontSize: 8.5, color: PdfColors.grey700),
      if ((dto.agenceEmail ?? '').isNotEmpty)
        PdfTheme.arText(dto.agenceEmail!, fontSize: 8.5, color: PdfColors.grey700),
      pw.SizedBox(height: 6),
      pw.Divider(color: color, thickness: 1.2),
    ]);
  }

  // ── Encadrés génériques ──────────────────────────────────────────────────

  static pw.Widget _box({
    required String title,
    required List<pw.Widget> children,
    bool rtl = false,
  }) =>
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            color: PdfColors.grey200,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: rtl
                ? PdfTheme.arText(title, fontSize: 9, bold: true)
                : pw.Text(title, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(7),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: children),
          ),
        ]),
      );

  static pw.Widget _line(String label, String value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        // pw.RichText garde une seule police pour tout le run : si value est
        // saisi en arabe, il n'y a pas de glyphe dans la police latine du
        // thème. On repasse par un Row + smartText qui choisit la police
        // adaptée au contenu réel de value.
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('$label : ',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.Flexible(child: PdfTheme.smartText(value, fontSize: 8, bold: bold)),
        ]),
      );

  static pw.Widget _lineAr(String label, String value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        // ⚠️ FIX : concaténer '$label : $value' dans UNE seule chaîne passée
        // à un Text unique en TextDirection.rtl casse l'ordre des chiffres
        // latins noyés dans la valeur (montant, kilométrage...) — le package
        // `pdf` ne fait pas un vrai algorithme bidi Unicode et peut réordonner
        // les groupes de chiffres/le suffixe ("DA", "km") au lieu de les
        // garder groupés dans leur ordre naturel de gauche à droite.
        // On sépare donc label (arabe, RTL) et valeur (potentiellement des
        // chiffres/latin) dans deux Text distincts au sein d'un Row RTL :
        // le premier enfant d'un Row RTL se retrouve à droite (label, lu en
        // premier), la valeur suit vers la gauche mais reste un run LTR
        // indépendant → les chiffres restent dans le bon ordre.
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            PdfTheme.arText('$label : ', fontSize: 8, bold: bold),
            pw.Flexible(
              child: PdfTheme.smartText(value, fontSize: 8, bold: bold, textAlign: pw.TextAlign.right),
            ),
          ],
        ),
      );

  // ── Widgets FR ─────────────────────────────────────────────────────────────

  static pw.Widget _boxLocataireFr(ContratLocationDto dto) => _box(
        title: 'LE LOCATAIRE',
        children: [
          _line('Nom/Prénom', dto.locataireFullName, bold: true),
          _line('Adresse', _v(dto.locataireAdresse)),
          _line('Date de naissance', _v(dto.locataireDateNaissance)),
          _line('Permis n°', _v(dto.locataireNumPermis)),
          _line('Téléphone', dto.locataireTel),
          _line('Email', _v(dto.locataireEmail)),
          if (dto.hasConducteur2) ...[
            pw.SizedBox(height: 4),
            pw.Text('2ème conducteur', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
            _line('Nom', '${_v(dto.conducteur2Prenom)} ${_v(dto.conducteur2Nom)}'),
            _line('Permis n°', _v(dto.conducteur2NumPermis)),
          ],
        ],
      );

  static pw.Widget _boxLoueurFr(ContratLocationDto dto) => _box(
        title: 'LE LOUEUR',
        children: [
          _line('Société', dto.agenceNom, bold: true),
          _line('Adresse', dto.agenceAdresse),
          if ((dto.agenceRc ?? '').isNotEmpty) _line('R.C N°', dto.agenceRc!),
          if ((dto.agenceArtNo ?? '').isNotEmpty) _line('ART N°', dto.agenceArtNo!),
          _line('Téléphone', dto.agenceTel),
          if ((dto.agenceEmail ?? '').isNotEmpty) _line('Email', dto.agenceEmail!),
          if ((dto.agentNom ?? '').isNotEmpty)
            _line('Agent', [dto.agentNom, dto.agentTel].whereType<String>().where((s) => s.isNotEmpty).join(', ')),
        ],
      );

  static pw.Widget _boxVehiculeFr(ContratLocationDto dto) => _box(
        title: 'LE VÉHICULE',
        children: [
          _line('Marque/Modèle', '${dto.vehiculeMarque} ${dto.vehiculeModele}', bold: true),
          _line('Immat./réf', _v(dto.vehiculeImmatriculation)),
          _line('Couleur', _v(dto.vehiculeCouleur)),
          _line('Carburant', _v(dto.vehiculeCarburant)),
          _line('Boîte', _v(dto.vehiculeBoite)),
        ],
      );

  static pw.Widget _boxLocationFr(ContratLocationDto dto) => _box(
        title: 'LA LOCATION : id ${PdfTheme.shortId(dto.contratId)}',
        children: [
          _line('Début', '${PdfTheme.fmtDate(dto.dateDepart)} ${_v(dto.heureDepart)}${dto.lieuDepart != null ? ', ${dto.lieuDepart}' : ''}'),
          _line('Fin', '${PdfTheme.fmtDate(dto.dateRetour)} ${_v(dto.heureRetour)}${dto.lieuRetour != null ? ', ${dto.lieuRetour}' : ''}'),
          _line('Prix Total', PdfTheme.fmtMoney(dto.montantTotal), bold: true),
          _line('Caution', PdfTheme.fmtMoney(dto.caution)),
          if ((dto.modePaiement ?? '').isNotEmpty) _line('Mode de paiement', dto.modePaiement!),
          if ((dto.optionsLocation ?? []).isNotEmpty)
            _line('Options', dto.optionsLocation!.join(', ')),
        ],
      );

  static pw.Widget _boxKmCarburantFr(ContratLocationDto dto) => _box(
        title: 'KILOMÉTRAGE / CARBURANT',
        children: [
          _line('Kilométrage', PdfTheme.fmtKm(dto.kmDepart)),
          pw.SizedBox(height: 4),
          pw.Text('Carburant', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.SizedBox(height: 3),
          _fuelGauge(dto.carburantNiveauDepart ?? 1.0),
        ],
      );

  static pw.Widget _boxRemarquesFr(ContratLocationDto dto) => _box(
        title: 'REMARQUES',
        children: [
          pw.Text(
            (dto.remarquesDepart ?? dto.observations ?? '').isEmpty
                ? 'Aucune'
                : (dto.remarquesDepart ?? dto.observations!),
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      );

  static pw.Widget _mentionEngagementFr() => pw.Text(
        "Je soussigné atteste avoir reçu le véhicule en l'état indiqué ci-dessus et prends la responsabilité du véhicule "
        "durant la location. Je m'engage à restituer le véhicule en l'état initial, à l'heure et au lieu indiqués dans le "
        'présent contrat. Dans le cas contraire, je devrai payer les frais engendrés, conformément aux conditions de location. '
        "J'autorise irrévocablement le loueur à prélever sur ma caution toute somme due au titre du présent contrat.",
        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
        textAlign: pw.TextAlign.justify,
      );

  static pw.Widget _mentionEngagementAr() => PdfTheme.arText(
        'أقر أنا الموقع أدناه بأنني استلمت السيارة بالحالة المذكورة أعلاه وأتحمل المسؤولية عنها طوال مدة الإيجار. '
        'وأتعهد بإعادتها بحالتها الأصلية، في الوقت والمكان المحددين في هذا العقد. وفي حال المخالفة، ألتزم بدفع المصاريف '
        'الناتجة عن ذلك وفقاً لشروط الإيجار. كما أفوّض المؤجر بشكل لا رجعة فيه باقتطاع أي مبلغ مستحق من التأمين.',
        fontSize: 7.5,
        color: PdfColors.grey800,
        textAlign: pw.TextAlign.right,
      );

  static pw.Widget _signaturesFr() => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Signature Agent :', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 30),
            pw.Container(width: 140, height: 0.6, color: PdfColors.grey400),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Signature Client :', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 30),
            pw.Container(width: 140, height: 0.6, color: PdfColors.grey400),
          ]),
        ],
      );

  static pw.Widget _signaturesAr() => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            PdfTheme.arText('توقيع العميل :', fontSize: 9, bold: true),
            pw.SizedBox(height: 30),
            pw.Container(width: 140, height: 0.6, color: PdfColors.grey400),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            PdfTheme.arText('توقيع الوكيل :', fontSize: 9, bold: true),
            pw.SizedBox(height: 30),
            pw.Container(width: 140, height: 0.6, color: PdfColors.grey400),
          ]),
        ],
      );

  // ── Widgets AR ─────────────────────────────────────────────────────────────

  static pw.Widget _boxLocataireAr(ContratLocationDto dto) => _box(
        rtl: true,
        title: 'المستأجر',
        children: [
          _lineAr('الاسم/اللقب', dto.locataireFullName, bold: true),
          _lineAr('العنوان', _v(dto.locataireAdresse)),
          _lineAr('تاريخ الميلاد', _v(dto.locataireDateNaissance)),
          _lineAr('رخصة القيادة رقم', _v(dto.locataireNumPermis)),
          _lineAr('الهاتف', dto.locataireTel),
          _lineAr('البريد الإلكتروني', _v(dto.locataireEmail)),
          if (dto.hasConducteur2) ...[
            pw.SizedBox(height: 4),
            PdfTheme.arText('السائق الثاني', fontSize: 7.5, bold: true, color: PdfColors.grey600),
            _lineAr('الاسم', '${_v(dto.conducteur2Prenom)} ${_v(dto.conducteur2Nom)}'),
            _lineAr('رخصة القيادة رقم', _v(dto.conducteur2NumPermis)),
          ],
        ],
      );

  static pw.Widget _boxLoueurAr(ContratLocationDto dto) => _box(
        rtl: true,
        title: 'المؤجر',
        children: [
          _lineAr('الشركة', dto.agenceNom, bold: true),
          _lineAr('العنوان', dto.agenceAdresse),
          if ((dto.agenceRc ?? '').isNotEmpty) _lineAr('السجل التجاري رقم', dto.agenceRc!),
          if ((dto.agenceArtNo ?? '').isNotEmpty) _lineAr('رقم المادة الجبائية', dto.agenceArtNo!),
          _lineAr('الهاتف', dto.agenceTel),
          if ((dto.agenceEmail ?? '').isNotEmpty) _lineAr('البريد الإلكتروني', dto.agenceEmail!),
          if ((dto.agentNom ?? '').isNotEmpty)
            _lineAr('الوكيل', [dto.agentNom, dto.agentTel].whereType<String>().where((s) => s.isNotEmpty).join(', ')),
        ],
      );

  static pw.Widget _boxVehiculeAr(ContratLocationDto dto) => _box(
        rtl: true,
        title: 'السيارة',
        children: [
          _lineAr('الماركة/الطراز', '${dto.vehiculeMarque} ${dto.vehiculeModele}', bold: true),
          _lineAr('رقم التسجيل', _v(dto.vehiculeImmatriculation)),
          _lineAr('اللون', _v(dto.vehiculeCouleur)),
          _lineAr('نوع الوقود', _v(dto.vehiculeCarburant)),
          _lineAr('ناقل الحركة', _v(dto.vehiculeBoite)),
        ],
      );

  static pw.Widget _boxLocationAr(ContratLocationDto dto) => _box(
        rtl: true,
        title: 'الإيجار : ${PdfTheme.shortId(dto.contratId)}',
        children: [
          _lineAr('البداية', '${PdfTheme.fmtDate(dto.dateDepart)} ${_v(dto.heureDepart)}${dto.lieuDepart != null ? '، ${dto.lieuDepart}' : ''}'),
          _lineAr('النهاية', '${PdfTheme.fmtDate(dto.dateRetour)} ${_v(dto.heureRetour)}${dto.lieuRetour != null ? '، ${dto.lieuRetour}' : ''}'),
          _lineAr('المبلغ الإجمالي', PdfTheme.fmtMoney(dto.montantTotal), bold: true),
          _lineAr('التأمين', PdfTheme.fmtMoney(dto.caution)),
          if ((dto.modePaiement ?? '').isNotEmpty) _lineAr('طريقة الدفع', dto.modePaiement!),
          if ((dto.optionsLocation ?? []).isNotEmpty) _lineAr('الخيارات', dto.optionsLocation!.join(', ')),
        ],
      );

  static pw.Widget _boxKmCarburantAr(ContratLocationDto dto) => _box(
        rtl: true,
        title: 'الكيلومترات / الوقود',
        children: [
          _lineAr('الكيلومترات', PdfTheme.fmtKm(dto.kmDepart)),
          pw.SizedBox(height: 4),
          PdfTheme.arText('الوقود', fontSize: 8, bold: true, color: PdfColors.grey800),
          pw.SizedBox(height: 3),
          _fuelGauge(dto.carburantNiveauDepart ?? 1.0),
        ],
      );

  static pw.Widget _boxRemarquesAr(ContratLocationDto dto) => _box(
        rtl: true,
        title: 'ملاحظات',
        children: [
          PdfTheme.arText(
            (dto.remarquesDepart ?? dto.observations ?? '').isEmpty
                ? 'لا توجد ملاحظات'
                : (dto.remarquesDepart ?? dto.observations!),
            fontSize: 8,
          ),
        ],
      );

  // ── Jauge de carburant (barre segmentée simple) ─────────────────────────

  static pw.Widget _fuelGauge(double level) {
    final clamped = level.clamp(0.0, 1.0);
    const segments = 8;
    final filled = (clamped * segments).round();
    return pw.Row(children: [
      pw.Text('0', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      pw.SizedBox(width: 3),
      pw.Expanded(
        child: pw.Row(
          children: List.generate(segments, (i) {
            final on = i < filled;
            return pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.symmetric(horizontal: 0.6),
                height: 8,
                color: on ? PdfColors.red700 : PdfColors.grey300,
              ),
            );
          }),
        ),
      ),
      pw.SizedBox(width: 3),
      pw.Text('1', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
    ]);
  }

  static pw.Widget _schemaCarrosserie(ContratLocationDto dto, String title, {bool rtl = false}) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.8),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            color: PdfColors.blueGrey700,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: rtl
                ? PdfTheme.arText(title, fontSize: 8, bold: true, color: PdfColors.white)
                : pw.Text(title,
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
          pw.Padding(padding: const pw.EdgeInsets.all(8), child: dto.schemaWidget!),
        ]),
      );

  static pw.Widget _schemaPlaceholder({bool rtl = false}) => pw.Container(
        height: 170,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Center(
          child: rtl
              ? PdfTheme.arText('لا توجد أضرار مسجلة', fontSize: 8, color: PdfColors.grey500)
              : pw.Text('Aucun dommage signalé', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ),
      );

  // ── Page 2 : compte rendu de fin de location ────────────────────────────

  static pw.Widget _compteRenduFinLocationFr(ContratLocationDto dto) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text('COMPTE RENDU DE FIN DE LOCATION',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          _line('Agent', _v(dto.agentNom)),
          _line('Date et heure de restitution', '.............'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
            },
            children: [
              _crRow('Remarques', 'Kilométrage : .....    Carburant : .....'),
              _crRow('Kilomètres supplémentaires', 'km x 10 DA = ..... DA'),
              _crRow('Carburant supplémentaire', '.. l x 30 DA = ..... DA'),
              _crRow(
                'Compensation amiable pour des problèmes mineurs (salissures, dommages légers, retards.)',
                '..... DA',
              ),
              _crRow(
                "Le véhicule a été endommagé et la réparation nécessite l'intervention d'un professionnel : la caution "
                'est encaissée pour le besoin des réparations',
                '..... DA',
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          _signaturesFr(),
        ],
      );

  static pw.TableRow _crRow(String label, String value) => pw.TableRow(children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
        ),
      ]);

  static pw.Widget _compteRenduFinLocationAr(ContratLocationDto dto) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          PdfTheme.arTextCenter('محضر نهاية الإيجار', fontSize: 13, bold: true),
          pw.SizedBox(height: 4),
          _lineAr('الوكيل', _v(dto.agentNom)),
          _lineAr('تاريخ ووقت الاستعادة', '...........'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
            },
            children: [
              _crRowAr('الكيلومترات : .....    الوقود : .....', 'ملاحظات'),
              _crRowAr('km x 10 DA = ..... DA', 'كيلومترات إضافية'),
              _crRowAr('.. l x 30 DA = ..... DA', 'وقود إضافي'),
              _crRowAr('..... DA', 'تعويض ودي عن مشاكل بسيطة (اتساخ، أضرار طفيفة، تأخير.)'),
              _crRowAr('..... DA', 'السيارة تضررت وتتطلب الإصلاح تدخل متخصص: يتم اقتطاع التأمين لتغطية الإصلاحات'),
            ],
          ),
          pw.SizedBox(height: 10),
          _signaturesAr(),
        ],
      );

  static pw.TableRow _crRowAr(String value, String label) => pw.TableRow(children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: PdfTheme.arText(value, fontSize: 8, textAlign: pw.TextAlign.right),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: PdfTheme.arText(label, fontSize: 8, textAlign: pw.TextAlign.right),
        ),
      ]);

  // ── Conditions générales ────────────────────────────────────────────────

  /// Articles par défaut si aucun article personnalisé n'a été configuré
  /// pour le showroom (mêmes clauses type que le modèle papier de référence).
  static const List<Map<String, String>> _defaultArticlesFr = [
    {
      'titre': 'Motifs de refus d\'un véhicule',
      'corps': "Le jour de la livraison, le client ne peut refuser la livraison du véhicule que si celui-ci ne réunit pas "
          'les conditions de sécurité (pneumatique, direction, freinage). Tout refus pour des questions esthétiques '
          '(rayures, bosses, etc.) sera considéré comme une annulation de dernière minute.',
    },
    {
      'titre': 'Remboursement',
      'corps': "Aucun remboursement ne s'effectue en Algérie. Pas de remboursement pour tout montant inférieur à 50 euros "
          '(le client aura un avoir sur son compte).',
    },
    {
      'titre': 'Assurance',
      'corps': "En cas de souscription à une assurance tous risques, une provision peut être demandée pour le lavage et le "
          'carburant, restituée si le véhicule est rendu propre et avec le plein. Pour tout client âgé de moins de 25 ans '
          "ou n'ayant pas 5 ans de permis, l'assurance peut être annulée et la caution automatiquement demandée.",
    },
    {
      'titre': 'Prolongation',
      'corps': 'Le tarif de chaque prolongation faite après la prise du véhicule est comptabilisé sur la base de la durée '
          'de la prolongation elle-même et non sur la base de la durée de la location initiale.',
    },
    {
      'titre': 'Documents à fournir',
      'corps': 'Le présent contrat imprimé en double exemplaire, chèque de caution ou justificatif d\'assurance, et '
          'photocopie du permis de conduire.',
    },
    {
      'titre': 'Âge minimum',
      'corps': '25 ans ou 5 ans de permis. 2 ans de permis obligatoires. Si moins : caution doublée.',
    },
    {
      'titre': 'Caution',
      'corps': "La caution est obligatoire, sauf souscription à une assurance tous risques. Son montant varie selon la "
          'catégorie du véhicule.',
    },
    {
      'titre': 'Pénalité sur état de restitution',
      'corps': 'Le véhicule doit être restitué avec le plein de carburant et propre. Toute pénalité liée à ces points doit '
          "être réglée sur place au moment de la restitution du véhicule.",
    },
    {
      'titre': 'Horaires',
      'corps': "Le client doit respecter les horaires fournis sur la fiche de réservation. Toute prolongation de la "
          "location sans l'accord express du loueur peut entraîner une pénalité, avec facturation de chaque jour "
          'supplémentaire au tarif majoré.',
    },
    {
      'titre': 'Panne mécanique',
      'corps': "En cas de panne mécanique relevant de la responsabilité du client, la prise en charge du dépannage et de "
          'la réparation sont à la charge totale du client. Si le client n\'est pas responsable, le loueur doit fournir '
          'un véhicule de remplacement dans les meilleurs délais, selon la disponibilité des modèles.',
    },
    {
      'titre': 'Annulation',
      'corps': "Toute annulation tardive peut entraîner une retenue sur le montant de la location, à titre de frais de "
          'gestion ou de dommages, selon le délai de prévenance.',
    },
    {
      'titre': 'Kilométrage',
      'corps': 'Un forfait kilométrique quotidien est inclus dans le prix. Au-delà, un tarif au kilomètre supplémentaire '
          "s'applique, selon la catégorie du véhicule.",
    },
    {
      'titre': 'Pénalités de retard',
      'corps': "Une tolérance de retard limitée est accordée. Passé ce délai, une pénalité horaire s'applique, plafonnée "
          "au montant d'une journée de location majorée.",
    },
    {
      'titre': 'Perte de papiers ou de clefs',
      'corps': "En cas de perte des papiers ou des clefs originaux du véhicule, le client sera pénalisé d'un montant "
          'forfaitaire fixé par le loueur.',
    },
    {
      'titre': 'Non restitution du véhicule',
      'corps': 'Tout jour de retard au-delà du terme du contrat est facturé à un tarif majoré, sans préjudice des '
          'poursuites éventuelles pour non-restitution.',
    },
    {
      'titre': 'Conditions de location',
      'corps': "Le client déclare avoir pris connaissance des présentes conditions de location et en accepter les "
          "termes. Le loueur se réserve le droit de modifier à tout moment les conditions de location.",
    },
  ];

  static const List<Map<String, String>> _defaultArticlesAr = [
    {
      'titre': 'أسباب رفض تسليم السيارة',
      'corps': 'يوم التسليم، لا يمكن للعميل رفض استلام السيارة إلا إذا كانت لا تستوفي شروط السلامة (الإطارات، التوجيه، الفرامل). '
          'أي رفض لأسباب جمالية (خدوش، انبعاجات...) يُعتبر إلغاءً في اللحظة الأخيرة.',
    },
    {
      'titre': 'الاسترداد',
      'corps': 'لا يتم أي استرداد للمبالغ داخل الجزائر. لا يوجد استرداد لأي مبلغ يقل عن 50 يورو (يستفيد العميل من رصيد دائن في حسابه).',
    },
    {
      'titre': 'التأمين',
      'corps': 'في حال الاشتراك في تأمين شامل، قد يُطلب مبلغ تحفظي مقابل الغسيل والوقود، ويُعاد إذا أُعيدت السيارة نظيفة وبخزان ممتلئ. '
          'بالنسبة للعملاء الذين تقل أعمارهم عن 25 سنة أو لا يملكون رخصة قيادة منذ 5 سنوات، قد يُلغى التأمين ويُطلب التأمين النقدي إلزامياً.',
    },
    {
      'titre': 'التمديد',
      'corps': 'يُحتسب سعر كل تمديد يتم بعد استلام السيارة على أساس مدة التمديد نفسها وليس على أساس مدة الإيجار الأصلية.',
    },
    {
      'titre': 'الوثائق المطلوبة',
      'corps': 'هذا العقد مطبوعاً من نسختين، شيك التأمين أو ما يثبت وجود تأمين، ونسخة من رخصة القيادة.',
    },
    {
      'titre': 'السن الأدنى',
      'corps': '25 سنة أو 5 سنوات من حيازة رخصة القيادة. سنتان من الرخصة إلزاميتان. أقل من ذلك: يُضاعف مبلغ التأمين.',
    },
    {
      'titre': 'التأمين النقدي (الكفالة)',
      'corps': 'التأمين النقدي إلزامي، إلا في حال الاشتراك في تأمين شامل. يختلف مبلغه حسب فئة السيارة.',
    },
    {
      'titre': 'غرامة حالة الإرجاع',
      'corps': 'يجب إرجاع السيارة بخزان وقود ممتلئ ونظيفة. أي غرامة متعلقة بهذه النقاط يجب تسويتها في عين المكان عند استرجاع السيارة.',
    },
    {
      'titre': 'التوقيت',
      'corps': 'يجب على العميل احترام التوقيت المذكور في ورقة الحجز. أي تمديد للإيجار دون موافقة صريحة من المؤجر قد يؤدي إلى غرامة، '
          'مع احتساب كل يوم إضافي بسعر مرتفع.',
    },
    {
      'titre': 'العطل الميكانيكي',
      'corps': 'في حال حدوث عطل ميكانيكي بسبب العميل، تكون مصاريف الإصلاح والمساعدة على عاتق العميل بالكامل. أما إذا لم يكن العميل '
          'مسؤولاً، فعلى المؤجر توفير سيارة بديلة في أقرب وقت ممكن حسب توفر الطرازات.',
    },
    {
      'titre': 'الإلغاء',
      'corps': 'قد يؤدي الإلغاء المتأخر إلى اقتطاع جزء من مبلغ الإيجار كمصاريف تسيير أو تعويض عن الأضرار، حسب مهلة الإشعار.',
    },
    {
      'titre': 'الكيلومترات',
      'corps': 'يشمل السعر حصة يومية من الكيلومترات. وفيما يتجاوزها، يُطبَّق سعر إضافي لكل كيلومتر حسب فئة السيارة.',
    },
    {
      'titre': 'غرامات التأخير',
      'corps': 'يُمنح هامش تسامح محدود للتأخير. بعد انقضائه، تُطبَّق غرامة بالساعة، بحد أقصى يعادل سعر يوم إيجار واحد مع زيادة.',
    },
    {
      'titre': 'فقدان الوثائق أو المفاتيح',
      'corps': 'في حال فقدان الوثائق الأصلية أو المفاتيح الخاصة بالسيارة، يُطبَّق على العميل مبلغ جزافي يحدده المؤجر.',
    },
    {
      'titre': 'عدم إرجاع السيارة',
      'corps': 'يُحتسب كل يوم تأخير بعد انتهاء مدة العقد بسعر مرتفع، دون الإخلال بأي متابعة قانونية محتملة بسبب عدم إرجاع السيارة.',
    },
    {
      'titre': 'شروط الإيجار',
      'corps': 'يقر العميل بأنه اطلع على شروط الإيجار الحالية ويقبل بنودها. يحتفظ المؤجر بحق تعديل شروط الإيجار في أي وقت.',
    },
  ];

  static pw.Widget _conditionsGeneralesFr(List<Map<String, String>>? articles) {
    final list = (articles != null && articles.isNotEmpty) ? articles : _defaultArticlesFr;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Center(
        child: pw.Text('CONDITIONS GÉNÉRALES DE LOCATION',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
      ),
      pw.SizedBox(height: 8),
      pw.Wrap(
        spacing: 14,
        runSpacing: 6,
        children: list
            .map((a) => pw.Container(
                  width: 255,
                  child: _articleFr(a['titre'] ?? '', a['corps'] ?? ''),
                ))
            .toList(),
      ),
    ]);
  }

  static pw.Widget _conditionsGeneralesAr(List<Map<String, String>>? articles) {
    final list = (articles != null && articles.isNotEmpty) ? articles : _defaultArticlesAr;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Center(
        child: PdfTheme.arTextCenter('الشروط العامة للإيجار', fontSize: 12, bold: true),
      ),
      pw.SizedBox(height: 8),
      pw.Wrap(
        spacing: 14,
        runSpacing: 6,
        children: list
            .map((a) => pw.Container(
                  width: 255,
                  child: _articleAr(a['titre'] ?? '', a['corps'] ?? ''),
                ))
            .toList(),
      ),
    ]);
  }

  static pw.Widget _articleFr(String titre, String corps) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (titre.isNotEmpty)
          pw.Text(titre, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
        pw.SizedBox(height: 2),
        pw.Text(corps, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey900), textAlign: pw.TextAlign.justify),
      ]);

  static pw.Widget _articleAr(String titre, String corps) =>
      // Sous Directionality(rtl) (posée par PdfTheme.withArabicTheme() au
      // niveau de la page), CrossAxisAlignment.start = DROITE et .end =
      // GAUCHE (comportement directionally-aware du package `pdf`, identique
      // à Flutter). C'était .end ici → chaque clause était collée à GAUCHE.
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (titre.isNotEmpty)
          PdfTheme.arText(titre, fontSize: 8, bold: true, textAlign: pw.TextAlign.right),
        pw.SizedBox(height: 2),
        PdfTheme.arText(corps, fontSize: 7, color: PdfColors.grey900, textAlign: pw.TextAlign.right),
      ]);
}
