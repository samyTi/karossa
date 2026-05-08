// lib/features/contrats/presentation/contrat_location_pdf_generator.dart
//
// v3 — Mise en page calquée sur le modèle de référence :
//   Page 1 : En-tête agence + logo zone | CONTRAT DE LOCATION | infos locataire
//            2ème conducteur | désignation véhicule | tableau départ/retour
//            état véhicule (checklist) | conditions générales résumées | signatures
//   Page 2 : CONDITIONS GENERALES DE LOCATION (8 articles complets)
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
  /// Affiché dans la section 'Observations / État du véhicule' du contrat.
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
    // checklist — tous false par défaut (rayer la mention inutile = non coché)
    this.etatAutoRadio = false,
    this.etatRoueSecours = false,
    this.etatRadiateur = false,
    this.etatCarburant = false,
    this.etatAvertisseur = false,
    this.etatControle4Roues = false,
    this.etatControleCarrosserie = false,
    this.etatControleFeuxAv = false,
    this.etatControleInterieur = false,
    // anciens champs conservés pour compatibilité (ignorés visuellement)
    this.observations,
    this.etatVehicule,
  });

  int get nbJours =>
      dateRetour.difference(dateDepart).inDays.clamp(1, 9999);

  double get montantTotal => prixJour * nbJours;

  String get locataireFullName => '$locatairePrenom $locataireNom';

  bool get hasConducteur2 =>
      conducteur2Nom != null && conducteur2Nom!.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
//  GÉNÉRATEUR PDF
// ─────────────────────────────────────────────────────────────────────────────

class ContratLocationPdfGenerator {
  ContratLocationPdfGenerator._();

  // Getters au lieu de static final pour éviter le crash avant initializeDateFormatting()
  static DateFormat get _dateFmt => DateFormat('dd/MM/yyyy', 'fr');
  static DateFormat get _dateLongFmt => DateFormat('d MMMM yyyy', 'fr');
  static NumberFormat get _moneyFmt => NumberFormat('#,###', 'fr');

  static String _idFmt(String id) =>
      id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  static String _val(String? v) => (v == null || v.isEmpty) ? '' : v;

  // ── Point d'entrée principal ──────────────────────────────

  // Police arabe chargée une seule fois (cache statique)
  static pw.Font? _arabicFont;
  static pw.Font? _arabicFontBold;

  /// Charge la police arabe Cairo depuis les assets Flutter.
  /// Assurez-vous d'avoir dans pubspec.yaml :
  ///   flutter:
  ///     fonts:
  ///       - family: Cairo
  ///         fonts:
  ///           - asset: assets/fonts/Cairo-Regular.ttf
  ///           - asset: assets/fonts/Cairo-Bold.ttf
  ///             weight: 700
  static Future<void> _loadArabicFont() async {
    if (_arabicFont != null) return;
    try {
      final regular = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final bold    = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      _arabicFont     = pw.Font.ttf(regular);
      _arabicFontBold = pw.Font.ttf(bold);
    } catch (_) {
      // Fallback : sans police arabe, l'affichage sera dégradé
      _arabicFont     = null;
      _arabicFontBold = null;
    }
  }

  /// Génère le document PDF de façon asynchrone (nécessaire pour charger la police arabe).
  static Future<pw.Document> buildAsync(ContratLocationDto dto) async {
    await _loadArabicFont();
    return build(dto);
  }

  static pw.Document build(ContratLocationDto dto) {
    final doc = pw.Document();

    // ─────────────────────────────────────────────────────
    //  EXEMPLAIRE FRANÇAIS  (page 1 contrat + page 2 CGV)
    // ─────────────────────────────────────────────────────
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
          // Section état / dommages du véhicule si renseignée
          if ((dto.etatVehicule ?? '').trim().isNotEmpty)
            _buildNotesVehicule(dto),
          if ((dto.etatVehicule ?? '').trim().isNotEmpty)
            pw.SizedBox(height: 6),
          _buildConditionsSummary(),
          pw.SizedBox(height: 8),
          _buildSignatures(dto),
        ],
      ),
    ));

    // Page 2 : conditions générales complètes (exemplaire français)
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      build: (ctx) => _buildConditionsGeneralesPage(dto),
    ));

    // ─────────────────────────────────────────────────────
    //  EXEMPLAIRE ARABE  (page 3 contrat + page 4 CGV)
    // ─────────────────────────────────────────────────────
    // Helper pour le thème arabe (applique la police à tout le contenu)
    pw.Widget _withArabicTheme(pw.Widget child) {
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
      build: (ctx) => _withArabicTheme(pw.Column(
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
          if ((dto.etatVehicule ?? '').trim().isNotEmpty)
            _buildNotesVehiculeAr(dto),
          if ((dto.etatVehicule ?? '').trim().isNotEmpty)
            pw.SizedBox(height: 6),
          _buildConditionsSummaryAr(),
          pw.SizedBox(height: 8),
          _buildSignaturesAr(dto),
        ],
      )),
    ));

    // Page 4 : conditions générales arabes
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      build: (ctx) => _withArabicTheme(_buildConditionsGeneralesPageAr(dto)),
    ));

    return doc;
  }

  // ── saveBytes / saveToFile (compatibilité) ────────────────

  static Future<Uint8List> saveBytes(pw.Document doc) async {
    return await doc.save();
  }

  static Future<File> saveToFile(pw.Document doc, String contratId) async {
    final bytes = await doc.save();
    final appDir = await getApplicationDocumentsDirectory();
    final name = 'contrat_location_${_idFmt(contratId)}.pdf';
    final file = File('${appDir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ═══════════════════════════════════════════════════════════
  //  PAGE 1 — WIDGETS
  // ═══════════════════════════════════════════════════════════

  // ── En-tête agence (haut gauche) + zone logo (haut droite) ──
  static pw.Widget _buildAgenceHeader(ContratLocationDto dto) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Infos agence à gauche
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                dto.agenceNom.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (dto.agenceVille != null && dto.agenceVille!.isNotEmpty)
                pw.Text(
                  'Agence ${dto.agenceVille}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.SizedBox(height: 4),
              if (dto.agenceRc != null && dto.agenceRc!.isNotEmpty)
                _headerLine('LOCAL N°${dto.agenceRc}', fontSize: 8),
              if (dto.agenceAdresse.isNotEmpty)
                _headerLine(dto.agenceAdresse, fontSize: 8),
              if (dto.agenceTel.isNotEmpty) ...[
                _headerLine('Mobile : ${dto.agenceTel}', fontSize: 8),
                _headerLine('Fax :', fontSize: 8),
              ],
              if (dto.agenceEmail != null && dto.agenceEmail!.isNotEmpty)
                _headerLine('E-Mail : ${dto.agenceEmail}', fontSize: 8),
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        // Zone logo à droite
        // Zone logo
        pw.Container(
          width: 90,
          height: 70,
          alignment: pw.Alignment.centerRight,
          child: dto.agenceLogoBytes != null
              ? pw.Image(pw.MemoryImage(dto.agenceLogoBytes!))
              : pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  ),
                  child: pw.Center(
                    child: pw.Text('LOGO', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
                  ),
                ),
        ),
      ],
    );
  }

  static pw.Widget _headerLine(String text, {double fontSize = 9}) =>
      pw.Text(text, style: pw.TextStyle(fontSize: fontSize));

  // ── Titre central du contrat ──────────────────────────────
  static pw.Widget _buildTitreContrat(ContratLocationDto dto) {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text(
            'CONTRAT DE LOCATION',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Date : ${_dateFmt.format(dto.dateEtablissement)}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  // ── Section locataire + 2ème conducteur ──────────────────
  static pw.Widget _buildLocataireSection(ContratLocationDto dto) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Titre de section
          _sectionBar('Reference du Locataire :'),
          // Ligne 1 : Nom/Prénom | 2ème conducteur (titre)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Nom, prénom :', dto.locataireFullName, bold: true),
                    _infoRow(
                      'Né(e) le :',
                      '${_val(dto.locataireDateNaissance)} à ${_val(dto.agenceVille ?? '')}',
                    ),
                    _infoRow(
                      'N° de permis de Conduire N°:',
                      '${_val(dto.locataireNumPermis)}  Délivré le : ${_val(dto.locatairePermisDate)}',
                    ),
                    _infoRow('Adresse :', _val(dto.locataireAdresse)),
                    _infoRow('Tel :', _val(dto.locataireTel)),
                  ],
                ),
              ),
              pw.Container(
                width: 0.6,
                color: PdfColors.grey500,
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 2),
                      child: pw.Text(
                        '2eme Conducteur :',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    _infoRow(
                      'Nom et prénom :',
                      dto.hasConducteur2
                          ? '${dto.conducteur2Prenom ?? ''} ${dto.conducteur2Nom ?? ''}'
                          : '',
                    ),
                    _infoRow('Adresse :', ''),
                    _infoRow(
                      'permis de Conduire N°',
                      dto.conducteur2NumPermis != null
                          ? '${dto.conducteur2NumPermis}  Délivré le : ${_val(dto.conducteur2PermisDate)}'
                          : '  Délivré le : 0',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Désignation du véhicule ───────────────────────────────
  static pw.Widget _buildVehiculeSection(ContratLocationDto dto) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _sectionBar('Désignation du Véhicule :'),
          pw.Row(
            children: [
              pw.Expanded(
                child: _infoRow('Marque', _val(dto.vehiculeMarque), bold: true),
              ),
              pw.Expanded(
                child: _infoRow(
                  'Matricule :',
                  _val(dto.vehiculeImmatriculation),
                  bold: true,
                ),
              ),
              pw.Expanded(
                child: _infoRow('Couleur :', _val(dto.vehiculeCouleur)),
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(
                child: _infoRow('Modèle :', _val(dto.vehiculeModele)),
              ),
              pw.Expanded(
                child: _infoRow('Assurance :', _val(dto.vehiculeAssurance)),
              ),
              pw.Expanded(
                child: _infoRow(
                  'Code RADIO :',
                  _val(dto.vehiculeCodeRadio),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tableau Départ / Retour ───────────────────────────────
  static pw.Widget _buildTableauDepartRetour(ContratLocationDto dto) {
    final dateDepart = _dateLongFmt.format(dto.dateDepart);
    final dateRetour = _dateLongFmt.format(dto.dateRetour);
    final heureDepart = _val(dto.heureDepart);
    final heureRetour = _val(dto.heureRetour);
    final kmDep = '${_moneyFmt.format(dto.kmDepart)} Km';
    final kmRet = dto.kmRetour != null
        ? '${_moneyFmt.format(dto.kmRetour!)} Km'
        : '';

    const colDate = pw.FlexColumnWidth(3);
    const colHeure = pw.FlexColumnWidth(2);
    const colKm = pw.FlexColumnWidth(2);
    const colLabel = pw.FixedColumnWidth(55);

    pw.Widget hCell(String t) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          child: pw.Center(
            child: pw.Text(
              t,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
        );

    pw.Widget labelCell(String t) => pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          child: pw.Text(
            t,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );

    pw.Widget dataCell(String t) => pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: pw.Center(
            child: pw.Text(t, style: const pw.TextStyle(fontSize: 9)),
          ),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
      columnWidths: const {
        0: colLabel,
        1: colDate,
        2: colHeure,
        3: colKm,
      },
      children: [
        // En-tête
        pw.TableRow(children: [
          hCell(''),
          hCell('Date'),
          hCell('Heure'),
          hCell('Kilométrage'),
        ]),
        // Départ
        pw.TableRow(children: [
          labelCell('Départ'),
          dataCell(dateDepart),
          dataCell(heureDepart),
          dataCell(kmDep),
        ]),
        // Ligne vide pour espace
        pw.TableRow(children: [
          dataCell(''),
          dataCell(''),
          dataCell(''),
          dataCell(''),
        ]),
        // Retour
        pw.TableRow(children: [
          labelCell('Retour'),
          dataCell(dateRetour),
          dataCell(heureRetour),
          dataCell(kmRet),
        ]),
        // Ligne vide retour
        pw.TableRow(children: [
          dataCell(''),
          dataCell(''),
          dataCell(''),
          dataCell(''),
        ]),
      ],
    );
  }

  // ── État du véhicule (checklist + dessin voiture) ────────
  static pw.Widget _buildEtatVehicule(ContratLocationDto dto) {
    // Items de la checklist avec leur valeur départ/retour
    final items = [
      ('Auto Radio',            dto.etatAutoRadio),
      ('Roue de secours',       dto.etatRoueSecours),
      ('Radiateur',             dto.etatRadiateur),
      ('Carburant',             dto.etatCarburant),
      ('Avertisseur',           dto.etatAvertisseur),
      ('Controle des 4 Roues',  dto.etatControle4Roues),
      ('Controle carrossenie',  dto.etatControleCarrosserie),
      ('Controle des feux av-ar', dto.etatControleFeuxAv),
      ('Controle Interieur',    dto.etatControleInterieur),
    ];

    pw.Widget checkRow(String label, bool depart) => pw.Row(children: [
      pw.Expanded(
        flex: 5,
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ),
      ),
      pw.Expanded(
        flex: 2,
        child: pw.Center(child: _checkBox(depart)),
      ),
      pw.Expanded(
        flex: 2,
        child: pw.Center(child: _checkBox(false)), // retour toujours vide
      ),
    ]);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Colonne gauche : dessin voiture stylisé (simple cadre)
        pw.Container(
          width: 130,
          height: 140,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
          child: pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'VEHICULE EN PARFAIT ETAT',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  '(rayer la mention inutile)',
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'oui   non',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 6),
        // Colonne droite : checklist
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // En-tête colonnes
                pw.Row(children: [
                  pw.Expanded(flex: 5, child: pw.SizedBox()),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Center(
                      child: pw.Text(
                        'Depart',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Center(
                      child: pw.Text(
                        'Retour',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ]),
                pw.Divider(color: PdfColors.grey300, thickness: 0.4),
                ...items.map((e) => checkRow(e.$1, e.$2)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _checkBox(bool checked) => pw.Container(
        width: 10,
        height: 10,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey600, width: 0.7),
          color: checked ? PdfColors.grey800 : PdfColors.white,
        ),
        child: checked
            ? pw.Center(
                child: pw.Text(
                  'X',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              )
            : null,
      );

  // ── Résumé conditions en bas de page 1 ───────────────────
  static pw.Widget _buildConditionsSummary() {
    final lines = [
      '- Les Jours de la réparation de la voiture sont a la charge du client.',
      '- Passport en cour de Validité.',
      '- Kilométrages Limité (400 Km/H). Un forfait de 20 DA/Km en cas de supplément.',
      '- Durée minimum de la location 24H.',
      '- Préserver l\'entretien du véhicule à son retour.',
      '- Les (frais d\'immobilisation du véhicule lors de la réparation seront comptes par le client.',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '- Conditions Générale :',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        ...lines.map(
          (l) => pw.Text(l, style: const pw.TextStyle(fontSize: 7.5)),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Je reconnai avoir pris connaissance du contrat de location et de ses conditions générales de location '
          'avant la possession et je m\'engage d\'assumer toute responsabilité du véhicule.',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.justify,
        ),
      ],
    );
  }

  // ── Signatures ───────────────────────────────────────────
  static pw.Widget _buildSignatures(ContratLocationDto dto) {
    pw.Widget col(String label) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
              pw.SizedBox(height: 30),
            ],
          ),
        );

    return pw.Row(children: [
      col('Signature du Locataire'),
      pw.SizedBox(width: 20),
      col('Signature du Propriétaire'),
    ]);
  }

  // ── Section Notes / État du véhicule (FR) ─────────────────
  /// Affiche les dommages/pannes déclarés sur le véhicule avant la location.
  static pw.Widget _buildNotesVehicule(ContratLocationDto dto) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.orange, width: 0.8),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: PdfColors.orange,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: pw.Text(
              'ÉTAT DU VÉHICULE — DOMMAGES / ANOMALIES CONSTATÉS AVANT LOCATION',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              dto.etatVehicule!,
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey900),
              textAlign: pw.TextAlign.justify,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: pw.Text(
              'Le locataire déclare avoir pris connaissance de l\'état du véhicule décrit ci-dessus '
              'et l\'accepte en l\'état au moment de la prise en charge.',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  EXEMPLAIRE ARABE — WIDGETS
  // ═══════════════════════════════════════════════════════════

  static pw.Widget _buildAgenceHeaderAr(ContratLocationDto dto) {
    // En-tête miroir : infos agence à droite, zone logo à gauche
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Zone logo à gauche
        pw.Container(
          width: 90,
          height: 70,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                dto.agenceNom.toUpperCase(),
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.right,
              ),
              if ((dto.agenceVille ?? '').isNotEmpty)
                pw.Text('وكالة ${dto.agenceVille}',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                  textDirection: pw.TextDirection.rtl,
                  textAlign: pw.TextAlign.right),
              pw.SizedBox(height: 4),
              if ((dto.agenceRc ?? '').isNotEmpty)
                pw.Text('رقم المحل: ${dto.agenceRc}', style: const pw.TextStyle(fontSize: 8), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
              if (dto.agenceAdresse.isNotEmpty)
                pw.Text(dto.agenceAdresse, style: const pw.TextStyle(fontSize: 8), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
              if (dto.agenceTel.isNotEmpty)
                pw.Text('الهاتف: ${dto.agenceTel}', style: const pw.TextStyle(fontSize: 8), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
              if ((dto.agenceEmail ?? '').isNotEmpty)
                pw.Text('البريد: ${dto.agenceEmail}', style: const pw.TextStyle(fontSize: 8), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTitreContratAr(ContratLocationDto dto) {
    return pw.Column(children: [
      pw.Center(
        child: pw.Text('عقد إيجار سيارة',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold,
            decoration: pw.TextDecoration.underline),
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.center),
      ),
      pw.SizedBox(height: 3),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Text('التاريخ: ${_dateFmt.format(dto.dateEtablissement)}',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right),
      ]),
    ]);
  }

  static pw.Widget _buildLocataireSectionAr(ContratLocationDto dto) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        _sectionBarRtl('بيانات المستأجر :'),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(flex: 3, child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _infoRowRtl('الاسم واللقب :', dto.locataireFullName),
              _infoRowRtl('تاريخ الميلاد :', _val(dto.locataireDateNaissance)),
              _infoRowRtl('رقم رخصة القيادة :', '${_val(dto.locataireNumPermis)}  صدرت بتاريخ: ${_val(dto.locatairePermisDate)}'),
              _infoRowRtl('العنوان :', _val(dto.locataireAdresse)),
              _infoRowRtl('الهاتف :', _val(dto.locataireTel)),
            ],
          )),
          pw.Container(width: 0.6, color: PdfColors.grey500),
          pw.Expanded(flex: 2, child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 2),
                child: pw.Text('السائق الثاني :',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  textDirection: pw.TextDirection.rtl,
                  textAlign: pw.TextAlign.right),
              ),
              _infoRowRtl('الاسم واللقب :',
                dto.hasConducteur2 ? '${dto.conducteur2Prenom ?? ''} ${dto.conducteur2Nom ?? ''}' : ''),
              _infoRowRtl('العنوان :', ''),
              _infoRowRtl('رخصة القيادة :', dto.conducteur2NumPermis ?? ''),
            ],
          )),
        ]),
      ]),
    );
  }

  static pw.Widget _buildVehiculeSectionAr(ContratLocationDto dto) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.6)),
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
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
          decoration: pw.TextDecoration.underline),
        textDirection: pw.TextDirection.rtl)),
    );

    pw.Widget labelCell(String t) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      child: pw.Text(t,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        textDirection: pw.TextDirection.rtl),
    );

    pw.Widget dataCell(String t) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Center(child: pw.Text(t, style: const pw.TextStyle(fontSize: 9))),
    );

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
        child: pw.Text(label,
          style: const pw.TextStyle(fontSize: 8),
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right),
      )),
    ]);

    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Expanded(child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Row(children: [
            pw.Expanded(flex: 2, child: pw.Center(child: pw.Text('الإرجاع',
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.right))),
            pw.Expanded(flex: 2, child: pw.Center(child: pw.Text('الانطلاق',
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.right))),
            pw.Expanded(flex: 5, child: pw.SizedBox()),
          ]),
          pw.Divider(color: PdfColors.grey300, thickness: 0.4),
          ...items.map((e) => checkRow(e.$1, e.$2)),
        ]),
      )),
      pw.SizedBox(width: 6),
      pw.Container(
        width: 130,
        height: 140,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
        child: pw.Center(child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('السيارة في حالة ممتازة', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center),
            pw.Text('(شطب ما لا ينطبق)', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            pw.Text('نعم   لا', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
          ],
        )),
      ),
    ]);
  }

  static pw.Widget _buildNotesVehiculeAr(ContratLocationDto dto) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.orange, width: 0.8),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          color: PdfColors.orange,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(
            'حالة السيارة — الأضرار / الأعطال المُلاحَظة قبل الإيجار',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            dto.etatVehicule!,
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey900),
            textAlign: pw.TextAlign.right,
            textDirection: pw.TextDirection.rtl,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: pw.Text(
            'يُقرّ المستأجر بأنه اطّلع على حالة السيارة المذكورة أعلاه وقبلها على ما هي عليه عند الاستلام.',
            style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
          ),
        ),
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
      pw.Text('- الشروط العامة :', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
      pw.SizedBox(height: 2),
      ...lines.map((l) => pw.Text(l,
        style: const pw.TextStyle(fontSize: 7.5),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.right)),
      pw.SizedBox(height: 6),
      pw.Text(
        'أقرّ بأنني اطّلعت على عقد الإيجار وشروطه العامة قبل استلام السيارة، '
        'وأتعهد بتحمّل كامل المسؤولية عن السيارة المستأجرة.',
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.justify,
      ),
    ]);
  }

  static pw.Widget _buildSignaturesAr(ContratLocationDto dto) {
    pw.Widget col(String label) => pw.Expanded(child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(label,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
            decoration: pw.TextDecoration.underline),
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right),
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
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold,
            decoration: pw.TextDecoration.underline),
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right),
        pw.SizedBox(height: 2),
        pw.Text(corps,
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey900),
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.justify),
      ],
    );

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Center(child: pw.Text('الشروط العامة للإيجار',
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold,
          decoration: pw.TextDecoration.underline),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.center)),
      pw.SizedBox(height: 10),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // العمود الأيمن
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          article('5. إعادة السيارة :',
            'يلتزم المستأجر بإعادة السيارة ومفاتيحها ووثائقها إلى المؤجر في التاريخ والساعة المحددة بنفس الحالة. '
            'في حال سقط موعد الإعادة في يوم عطلة وكان المكتب مغلقاً، يبقى المستأجر مسؤولاً عن السيارة حتى إعادة الفتح. '
            'لا يجوز الاحتفاظ بالسيارة أكثر من 30 يوماً دون توقيع عقد جديد.\n\n'
            'في حالة السرقة، يُوقف العقد فور تسليم الوثائق اللازمة للمؤجر.'),
          pw.SizedBox(height: 6),
          article('6. الدفع :',
            'يُحسب مبلغ الإيجار وفق التعريفات المعمول بها ويُسدَّد عند توقيع العقد. '
            'لا تشمل أقساط الضمان والتأمينات الإضافية المبلغَ الأساسي للإيجار.'),
          pw.SizedBox(height: 6),
          article('7. مبلغ الضمان :',
            'يتوقف مبلغ الضمان على فئة السيارة، وهو مخصص لتغطية الأضرار أو السرقة. '
            ' الضمان بعد التحقق،  منه قيمة أي ضرر مثبت.'),
          pw.SizedBox(height: 6),
          article('8. الرسوم :',
            '- رسوم المدة المحددة في وثيقة الإيجار.\n'
            '- رسوم التزوّد بالوقود إن أُعيدت السيارة بمستوى أقل مما كانت عليه.\n'
            '- جميع الغرامات والمخالفات الناجمة عن استخدام السيارة.\n'
            '- تخضع هذه الرسوم للمراجعة النهائية؛ وفي حالة وجود خطأ في الفاتورة يُصحَّح المبلغ أو يُردّ الفارق.'),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 0.8)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Center(child: pw.Text('تنبيه',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center)),
              pw.SizedBox(height: 4),
              pw.Text('- الحد الأقصى للمسافة 400 كم/24 ساعة، وما زاد يُحتسب بـ 20 دج/كم.',
                style: const pw.TextStyle(fontSize: 7.5),
                textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
              pw.SizedBox(height: 3),
              pw.Text('- التعريفة المطبّقة عند التأخر في إعادة السيارة:',
                style: const pw.TextStyle(fontSize: 7.5),
                textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
              pw.SizedBox(height: 4),
              _tarifRowRtl('ساعة واحدة', '600 دج'),
              _tarifRowRtl('ساعتان', '1 500 دج'),
              _tarifRowRtl('3 ساعات', '2 000 دج'),
              _tarifRowRtl('4 ساعات فأكثر', 'سعر اليوم كاملاً'),
            ]),
          ),
          pw.SizedBox(height: 10),
          pw.Center(child: pw.Text('قرأت وأوافق\nالمستأجر',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center)),
        ])),
        pw.SizedBox(width: 12),
        // العمود الأيسر
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          article('1. السيارة :',
            'لا يحق للمستأجر إقراض السيارة أو التصرف فيها بأي شكل، ولا يجوز له إجراء أي إصلاح دون موافقتنا.\n\n'
            'لن نكون مسؤولين عن أي نزاع أو دعوى قضائية تتعلق بعقد الإيجار.\n\n'
            'يُعدّ المستأجر مستلماً للسيارة بالحالة المبيّنة في العقد، ويكون مسؤولاً عن أي عيب لم يُذكر فيه.\n\n'
            'لن نأخذ بعين الاعتبار أي ادعاء بشأن حالة الملحقات بعد مغادرة المستأجر.\n\n'
            'يلتزم المستأجر بقوانين المرور والوقوف وقواعد استخدام السيارة.'),
          pw.SizedBox(height: 6),
          article('2. السائقون المرخّصون :',
            'لا يُسمح بقيادة السيارة إلا للمستأجر المُرخَّص الذي كان حاضراً عند توقيع العقد.\n\n'
            'يجب على جميع السائقين المرخّصين تقديم وثائق إثبات هوية كاملة (جواز سفر، عنوان، رقم رخصة القيادة، رقم الهاتف).'),
          pw.SizedBox(height: 6),
          article('3. الاستخدامات المحظورة :',
            'أ - لا يجوز استخدام السيارة:\n'
            '- لنقل أشخاص بأجر.\n'
            '- لسحب أو دفع أي شيء.\n'
            '- في أي سباق أو منافسة.\n'
            '- في أنشطة غير مشروعة.\n'
            '- عند تعرّض السائق لتأثير الكحول أو المخدرات.\n'
            '- لنقل عدد أكبر من المسافرين المُحدَّد في بطاقة التسجيل.\n'
            '- من قِبل أي شخص غير مُرخَّص.\n\n'
            'ب - عند إيقاف السيارة، يلتزم المستأجر بإغلاقها وتفعيل نظام الإنذار/الحماية.\n\n'
            'لا يجوز ترك السيارة بمفاتيحها في الداخل. في حالة السرقة أو التخريب تقع المسؤولية الكاملة على المستأجر.'),
          pw.SizedBox(height: 6),
          article('4. الإيجار :',
            'تُحسب مدة الإيجار بوحدات 24 ساعة غير قابلة للتجزئة من أولى ساعات وضع السيارة تحت التصرف.\n\n'
            'يلتزم المستأجر بالدفع عن كل ساعة تأخير حتى تُسلَّم السيارة وفق التعريفة اليومية السارية.'),
        ])),
      ]),
    ]);
  }

  // ═══════════════════════════════════════════════════════════
  //  HELPERS RTL (arabe)
  // ═══════════════════════════════════════════════════════════

  /// Retourne un TextStyle avec la police arabe si disponible.
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
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      decoration: decoration,
      fontStyle: fontStyle,
      font: font,
      fontBold: boldFont,
    );
  }

  static pw.Widget _sectionBarRtl(String title) => pw.Container(
    color: PdfColors.grey200,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    child: pw.Text(title,
      style: _arStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
      textDirection: pw.TextDirection.rtl,
      textAlign: pw.TextAlign.right),
  );

  static pw.Widget _infoRowRtl(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Flexible(child: pw.Text(value,
        style: _arStyle(fontSize: 8),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.right)),
      pw.SizedBox(width: 4),
      pw.Text('$label ',
        style: _arStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.right),
    ]),
  );

  static pw.Widget _tarifRowRtl(String duree, String prix) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Text(duree, style: _arStyle(fontSize: 7.5), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
      pw.Text('  <-  ',
        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(width: 8),
      pw.Text(prix,
        style: _arStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.right),
    ]),
  );

  // ═══════════════════════════════════════════════════════════
  //  PAGE 2 (FR) — CONDITIONS GÉNÉRALES COMPLÈTES
  // ═══════════════════════════════════════════════════════════

  static pw.Widget _buildConditionsGeneralesPage(ContratLocationDto dto) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Center(
          child: pw.Text(
            'CONDITIONS GENERALES DE LOCATION',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Colonne gauche
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _article('1. Véhicule :',
                    'Vous ne pouvez prêter le véhicule à aucun titre de propriété ni de possession et personne autre que nous ne peut vendre ou assigner le véhicule. Le locataire n\'effectuera aucune réparation sur le véhicule sans notre consentement.\n\n'
                    'Nous ne serons aucun cas responsable envers vous pour tout litige ou action judiciaire en rapport avec toute personne relative au contrat de location.\n\n'
                    'Vous êtes réputés avoir livré un véhicule conforme a l\'état décrit du véhicule quel vous sera émis avec votre contrat vous serez tenus de payer toute défectuosité apparente qui n\'y figurait pas.\n\n'
                    'Nous ne pourrons malheureusement pas tenir compte de réclamation de l\'état des accessoires appartenant au véhicule loué après votre départ.\n\n'
                    'Le locataire doit se conformer aux règles de circulation, de stationnement et d\'usage du véhicule.\n\n'
                    'Ailleurs en Algérie le véhicule ne peu en aucun cas être embarqué sur un bateau ou navire sans autorisation.',
                  ),
                  pw.SizedBox(height: 6),
                  _article('2. Conducteurs autorisés :',
                    'Le véhicule ne peut être conduit que par le locataire autorisé comme personne qui était présente au moment de la location et signe ce document de location.\n\n'
                    'Les locataires autorisés doivent fournir avec justification tous les renseignements a l\'établissement du contrat (Passport - adresse - catégorie et la date de délivrance du permis de conduire et numéro de téléphone).',
                  ),
                  pw.SizedBox(height: 6),
                  _article('3. Utilisation interdites du véhicule :',
                    'A -   Pour le véhicule ne peut être utilisé :\n'
                    '- Pour le transport de personnes contre rémunération.\n'
                    '- Pour pousser ou remorquer quoi que ce soit.\n'
                    '- Dans une course ou autre concours de cette nature.\n'
                    '- Dans des illégales comme les attaques a main armée.\n'
                    '- Lorsque le conducteur a des facultés affaiblies par l\'alcool ou est intoxiqué.\n'
                    '- Pour le transport d\'un nombre supérieur a celui mentionné sur la carte grise du véhicule.\n'
                    '- N\'importe où si le conducteur n\'est pas un locataire autorisé.\n'
                    '- N\'importe où si vous avez sur une voie en aller état.\n'
                    '- Pour des activités illégales ou des fausses plaques.\n'
                    '- Pour causer intentionnellement des dommages ou pour une fraude ou tromperies.\n'
                    '- L\'utilisation interdit du véhicule est une Infraction au contrat de location et annule ce dernier et peut vous rendre responsable de tous les dommages et pertes en rapport avec le véhicule loué sans exception.\n\n'
                    'B -   Quand vous stationnez le véhicule pour un court durée, vous êtes engager de fermer clef et a vous servez des dispositifs d\'alarme et/ou d\'antivol dont le véhicule est pourvu.\n\n'
                    'Le locataire est tenu de ne pas laisser la voiture inmociable avec les clefs ou le contact a l\'intérieur. En cas de vol ou vandalisé l\'immobilisation du véhicule la responsabilité de ce dernier est entièrement engagée.\n\n'
                    'En cas de vol du domaine.\n\n'
                    'Le locataire est responsable et s\'engage a supporter tous les frais sans distinction judiciaire ou pénale la valeur totale du véhicule et il devra nous transmettre dans les brefs délais le constat aimable d\'accident ou le procès-verbal de déclaration de vol remis par les autorités compétentes.',
                  ),
                  pw.SizedBox(height: 6),
                  _article('4. Location :',
                    'La durée de location se calcule par tranche de 24 heures non fractionnaire depuis la première heure de mise à disposition du véhicule.\n\n'
                    'Le locataire devra payer pour chaque heure et en ration d\'heure an échéance d\'une journée de location jusqu\'a ce que le véhicule nous soit retourné jusqu\'a concurrence en tant que journalier applicable.',
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            // Colonne droite
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _article('5. Retour du véhicule et fin :',
                    'Le locataire est tenu de retourner le véhicule, les clés et ses papiers au bailleur a la date et a l\'heure indiquée sur document de location dans le même état. Si aujourd\'hui est un jour férié le locataire rend le véhicule lorsque le bureau est fermé, il pourrait subir le véhicule jusqu\'à réouverture du bureau, et ne peut pas garder le véhicule pendant plus de 30 jours à moins de signer un nouveau contrat de location. S\'il néglige de le faire il devra nous payer toute la dépense en rapport.\n\n'
                    'En cas de vol le contrat est arrêté dès transmission au bailleur des papiers amiable dument rempli par le contrat de location et le tiers éventuel. En aucun vous ne remettiez les clefs a des personnes présentes sur le parking prétendant être des agents de location.\n\n'
                    'En cas de confiscation de mise sous scellés du véhicule, le contrat de location n\'est plus résilié ou bien droit dès que nous serons informés par les autorités judiciaires ou les locataires.',
                  ),
                  pw.SizedBox(height: 6),
                  _article('6. Le Paiement :',
                    'Le montant de location se calcule selon les tarifs en vigueur et ne fera lors de la signature du contrat les éventuelles réductions ou majorations. Sont exclues du montant de location les différentes cotisations relatives aux garanties ou assurances complémentaires souscrites le dépôt légale.',
                  ),
                  pw.SizedBox(height: 6),
                  _article('7. Dépôt de garantie :',
                    'Le montant de garantie dépend de la catégorie du véhicule il est destiné à couvrir le préjudice subi par le locataire du fait de dommage ou de vol. Le dépôt de la caution sera restitué après vérification en cas de dommage imputable et en cas de vol de véhicule.',
                  ),
                  pw.SizedBox(height: 6),
                  _article('8. Les frais :',
                    'Il est tenu de payer tous les frais stipulés au document de location a savoir :\n'
                    '- Frais de temps calculé au temps indiqué au document de la location.\n'
                    '- Frais de service de réapprovisionnement en carburant si vous ne retournez le véhicule avec moins de carburant qu\'au moment du départ, il vous donc payer pour les frais de réapprovisionnement en carburant.\n'
                    '- Vous devez payer tous les amendes, Pénalités et autres dépenses occasionnées par l\'utilisation de véhicule de location.\n'
                    '- Tous ces frais sont assujettis à une vérification final. S\'il y a erreur de facturation vous règlerez le montant corrigés ou vous serez remboursé.',
                  ),
                  pw.SizedBox(height: 10),
                  // Encadré ATTENTION
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Center(
                          child: pw.Text(
                            'ATTENTION',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '- Le kilométrage est limité de 400 Km Maximum par 24h, au delà il sera facturé 20 DA de kilométrage supplémentaire parcouru.',
                          style: const pw.TextStyle(fontSize: 7.5),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          '- Si le véhicule est remis à l\'agence après les délais, la tarification suivante sera appliquée :',
                          style: const pw.TextStyle(fontSize: 7.5),
                        ),
                        pw.SizedBox(height: 4),
                        _tarifRow('1H', '600 DA'),
                        _tarifRow('2H', '1 500 DA'),
                        _tarifRow('3H', '2 000 DA'),
                        _tarifRow('4H et plus', 'Prix de la journée'),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Text(
                      'LU ET APPROUVE\nLE LOCATAIRE',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HELPERS COMMUNS
  // ═══════════════════════════════════════════════════════════

  /// Barre de titre de section (fond gris clair, texte en gras)
  static pw.Widget _sectionBar(String title) => pw.Container(
        color: PdfColors.grey200,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: pw.Text(
          title,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        ),
      );

  /// Ligne label : valeur
  static pw.Widget _infoRow(String label, String value,
      {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '$label ',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.Flexible(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: bold ? pw.FontWeight.bold : null,
                ),
              ),
            ),
          ],
        ),
      );

  /// Article numéroté pour les conditions générales
  static pw.Widget _article(String titre, String corps) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(
          titre,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            decoration: pw.TextDecoration.underline,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          corps,
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey900),
          textAlign: pw.TextAlign.justify,
        ),
      ]);

  /// Ligne tarif dans l'encadré ATTENTION
  static pw.Widget _tarifRow(String duree, String prix) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(children: [
          pw.SizedBox(width: 8),
          pw.Container(
            width: 50,
            child: pw.Text(duree,
                style: const pw.TextStyle(fontSize: 7.5)),
          ),
          pw.Text(
            '  ->  $prix',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ]),
      );

  /// Convertit une couleur hex (#RRGGBB) en PdfColor
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