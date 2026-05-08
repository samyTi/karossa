// lib/core/services/contrat_location_pdf.dart
//
// Générateur PDF fidèle au modèle "ABDEL CAR LOCATION"
// Structure : Page 1 = Contrat  |  Page 2 = Conditions Générales
//
// USAGE :
//   final bytes = await ContratLocationPdf.generate(data: contrat);
//   await ContratLocationPdf.saveAndShare(context, bytes, contrat.id);

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/app_logger.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  DATA TRANSFER OBJECT
// ═══════════════════════════════════════════════════════════════════════════════

/// DTO complet pour générer un contrat de location.
/// Tous les champs nullable sont optionnels ; les champs requis déclenchent
/// une validation avant génération.
class ContratLocationData {
  // ── Agence ──────────────────────────────────────────────────────────────────
  final String agenceNom;         // "ABDEL CAR LOCATION"
  final String agenceSousNom;     // "Agence Location voiture"
  final String agenceAdresse;     // "LOCAL N°02 CITE DJEBLI…"
  final String? agenceMobile;
  final String? agenceFax;
  final String? agenceEmail;

  // ── Locataire ───────────────────────────────────────────────────────────────
  final String locataireNom;      // "BOURAHLA MOHAMMED"
  final DateTime locataireNaissance;
  final String locataireLieuNaissance;
  final String permisNumero;
  final DateTime permisDelivrance;
  final String locataireAdresse;
  final String? locataireTel;

  // ── 2ème conducteur (optionnel) ─────────────────────────────────────────────
  final String? conducteur2Nom;
  final String? conducteur2Adresse;
  final String? conducteur2Permis;
  final DateTime? conducteur2PermisDate;

  // ── Véhicule ────────────────────────────────────────────────────────────────
  final String vehiculeMarque;
  final String vehiculeModele;
  final String vehiculeMatricule;
  final String? vehiculeCouleur;
  final String? vehiculeAssurance;
  final String? vehiculeCodeRadio;

  // ── Détails location ────────────────────────────────────────────────────────
  final DateTime dateDepart;
  final DateTime dateRetour;
  final int kmDepart;
  final int? kmRetour;            // rempli à la restitution

  // ── État du véhicule ────────────────────────────────────────────────────────
  final EtatVehicule etatDepart;
  final EtatVehicule? etatRetour; // rempli à la restitution

  const ContratLocationData({
    required this.agenceNom,
    this.agenceSousNom = 'Agence Location voiture',
    required this.agenceAdresse,
    this.agenceMobile,
    this.agenceFax,
    this.agenceEmail,
    required this.locataireNom,
    required this.locataireNaissance,
    required this.locataireLieuNaissance,
    required this.permisNumero,
    required this.permisDelivrance,
    required this.locataireAdresse,
    this.locataireTel,
    this.conducteur2Nom,
    this.conducteur2Adresse,
    this.conducteur2Permis,
    this.conducteur2PermisDate,
    required this.vehiculeMarque,
    required this.vehiculeModele,
    required this.vehiculeMatricule,
    this.vehiculeCouleur,
    this.vehiculeAssurance,
    this.vehiculeCodeRadio,
    required this.dateDepart,
    required this.dateRetour,
    required this.kmDepart,
    this.kmRetour,
    this.etatDepart = const EtatVehicule(),
    this.etatRetour,
  });

  /// Validation basique avant génération
  List<String> validate() {
    final errors = <String>[];
    if (agenceNom.trim().isEmpty) errors.add('Nom de l\'agence requis');
    if (locataireNom.trim().isEmpty) errors.add('Nom du locataire requis');
    if (permisNumero.trim().isEmpty) errors.add('N° permis requis');
    if (vehiculeMarque.trim().isEmpty) errors.add('Marque du véhicule requise');
    if (vehiculeMatricule.trim().isEmpty) errors.add('Matricule requis');
    if (dateRetour.isBefore(dateDepart)) errors.add('Date retour antérieure au départ');
    return errors;
  }

  /// Exemple mocké — données du contrat visible dans le modèle
  static ContratLocationData mock() => ContratLocationData(
        agenceNom: 'ABDEL CAR LOCATION',
        agenceSousNom: 'Agence Location voiture',
        agenceAdresse: 'LOCAL N°02 CITE DJEBLI MOHAMED RDC\nMOSTAGANEM',
        agenceMobile: '0550 00 00 00',
        agenceFax: '',
        agenceEmail: 'abdellocation13@gmail.com',
        locataireNom: 'BOURAHLA MOHAMMED',
        locataireNaissance: DateTime(1993, 9, 25),
        locataireLieuNaissance: 'MOSTAGANEM',
        permisNumero: '2/01/113',
        permisDelivrance: DateTime(2018, 1, 29),
        locataireAdresse: 'FERME DE BOURAHLA N°04 CHEMOUMA\nMOSTAGANEM',
        locataireTel: '',
        vehiculeMarque: 'SYMBOL',
        vehiculeModele: 'SYMBOL',
        vehiculeMatricule: '10099 116 27',
        vehiculeCouleur: 'BLANCH',
        vehiculeAssurance: 'SAA',
        vehiculeCodeRadio: '',
        dateDepart: DateTime(2025, 8, 4, 18, 19),
        dateRetour: DateTime(2025, 8, 10, 18, 19),
        kmDepart: 0,
        kmRetour: 0,
        etatDepart: EtatVehicule(
          autoRadio: true,
          roueDeSocours: true,
          radiateur: false,
          carburant: true,
          avertisseur: true,
          controle4Roues: false,
          controleCarrosserie: false,
          controleFeux: true,
          controleInterieur: true,
        ),
      );
}

/// État du véhicule : cases à cocher départ / retour
class EtatVehicule {
  final bool autoRadio;
  final bool roueDeSocours;
  final bool radiateur;
  final bool carburant;
  final bool avertisseur;
  final bool controle4Roues;
  final bool controleCarrosserie;
  final bool controleFeux;
  final bool controleInterieur;

  const EtatVehicule({
    this.autoRadio = false,
    this.roueDeSocours = false,
    this.radiateur = false,
    this.carburant = false,
    this.avertisseur = false,
    this.controle4Roues = false,
    this.controleCarrosserie = false,
    this.controleFeux = false,
    this.controleInterieur = false,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
//  GÉNÉRATEUR PDF
// ═══════════════════════════════════════════════════════════════════════════════

class ContratLocationPdf {
  ContratLocationPdf._();

  static final _dateFmt  = DateFormat('dd/MM/yyyy', 'fr');
  static final _timeFmt  = DateFormat('HH:mm',      'fr');
  static final _dtFmt    = DateFormat('dd/MM/yyyy HH:mm', 'fr');

  static const _noir   = PdfColors.black;
  static const _gris   = PdfColors.grey600;
  static const _grisCl = PdfColors.grey200;
  static const _grisMd = PdfColors.grey400;

  // ── Point d'entrée principal ─────────────────────────────────────────────────
  static Future<Uint8List> generate({required ContratLocationData data}) async {
    final errors = data.validate();
    if (errors.isNotEmpty) throw ArgumentError(errors.join('\n'));

    final doc = pw.Document(
      title: 'Contrat de location – ${data.locataireNom}',
      author: data.agenceNom,
    );

    // Page 1 : Contrat
    doc.addPage(_buildPage1(data));

    // Page 2 : Conditions générales
    doc.addPage(_buildPage2());

    return doc.save();
  }

  // ── Sauvegarder + partager ───────────────────────────────────────────────────
  static Future<File?> saveAndShare(
    BuildContext context,
    Uint8List bytes,
    String locataireNom,
  ) async {
    try {
      final dir  = await getTemporaryDirectory();
      final name = 'contrat_${locataireNom.replaceAll(' ', '_')}_'
                   '${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Contrat de location'));
      return file;
    } catch (e) {
      AppLogger.d('Erreur sauvegarde PDF : $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PAGE 1 — CONTRAT
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Page _buildPage1(ContratLocationData d) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _buildAgenceHeader(d),
          pw.SizedBox(height: 6),
          _buildTitreDate(d),
          pw.SizedBox(height: 6),
          _buildSectionLocataire(d),
          pw.SizedBox(height: 5),
          _buildSectionVehicule(d),
          pw.SizedBox(height: 5),
          _buildTableauDatesKm(d),
          pw.SizedBox(height: 5),
          _buildEtatVehicule(d),
          pw.SizedBox(height: 5),
          _buildConditionsResumees(),
          pw.SizedBox(height: 6),
          _buildMentionAccord(),
          pw.SizedBox(height: 8),
          _buildSignatures(),
        ],
      ),
    );
  }

  // ── En-tête agence ────────────────────────────────────────────────────────
  static pw.Widget _buildAgenceHeader(ContratLocationData d) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Infos textuelles
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                d.agenceNom,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                d.agenceSousNom,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(d.agenceAdresse,
                  style: const pw.TextStyle(fontSize: 8, color: _gris)),
              if (d.agenceMobile != null && d.agenceMobile!.isNotEmpty)
                pw.Text('Mobile : ${d.agenceMobile}',
                    style: const pw.TextStyle(fontSize: 8, color: _gris)),
              if (d.agenceFax != null && d.agenceFax!.isNotEmpty)
                pw.Text('Fax : ${d.agenceFax}',
                    style: const pw.TextStyle(fontSize: 8, color: _gris)),
              if (d.agenceEmail != null && d.agenceEmail!.isNotEmpty)
                pw.Text('E-Mail : ${d.agenceEmail}',
                    style: const pw.TextStyle(fontSize: 8, color: _gris)),
            ],
          ),
        ),
        // Logo placeholder (rectangle avec texte)
        pw.Container(
          width: 70,
          height: 60,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _grisMd, width: 0.5),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            'LOGO',
            style: const pw.TextStyle(fontSize: 9, color: _gris),
          ),
        ),
      ],
    );
  }

  // ── Titre centré + date ────────────────────────────────────────────────────
  static pw.Widget _buildTitreDate(ContratLocationData d) {
    return pw.Column(children: [
      pw.Divider(color: _noir, thickness: 0.8),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.SizedBox(width: 80),
          pw.Text(
            'CONTRAT DE LOCATION',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'Date : ${_dateFmt.format(d.dateDepart)}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Divider(color: _noir, thickness: 0.8),
    ]);
  }

  // ── Section locataire ────────────────────────────────────────────────────────
  static pw.Widget _buildSectionLocataire(ContratLocationData d) {
    return _borderedSection(
      title: 'Référence du Locataire :',
      child: pw.Column(children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Colonne gauche
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _labelValeur('Nom, prénom',      d.locataireNom),
                  _labelValeur(
                    'Né(e) le',
                    '${_dateFmt.format(d.locataireNaissance)}'
                    ' à ${d.locataireLieuNaissance}',
                  ),
                  _labelValeur(
                    'Permis de Conduire N°',
                    '${d.permisNumero}  '
                    'Délivré le : ${_dateFmt.format(d.permisDelivrance)}',
                  ),
                  _labelValeur('Adresse', d.locataireAdresse),
                  _labelValeur('Tel :', d.locataireTel ?? ''),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            // Colonne droite — 2ème conducteur
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '2ème Conducteur :',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  _labelValeur('Nom et prénom', d.conducteur2Nom ?? ''),
                  _labelValeur('Adresse',       d.conducteur2Adresse ?? ''),
                  _labelValeur(
                    'permis de Conduire N°',
                    d.conducteur2Permis != null
                        ? '${d.conducteur2Permis}  '
                          'Délivré le : ${d.conducteur2PermisDate != null ? _dateFmt.format(d.conducteur2PermisDate!) : "0"}'
                        : 'Délivré le : 0',
                  ),
                ],
              ),
            ),
          ],
        ),
      ]),
    );
  }

  // ── Section véhicule ────────────────────────────────────────────────────────
  static pw.Widget _buildSectionVehicule(ContratLocationData d) {
    return _borderedSection(
      title: 'Désignation du Véhicule :',
      child: pw.Row(
        children: [
          _labelValeur('Marque',       d.vehiculeMarque),
          pw.SizedBox(width: 20),
          _labelValeur('Matricule :', d.vehiculeMatricule),
          pw.SizedBox(width: 20),
          _labelValeur('Couleur :',    d.vehiculeCouleur ?? ''),
          pw.Spacer(),
        ],
      ),
    ).also((_) {}) // dart trick to chain — using pw.Column below instead
    ?? pw.SizedBox();
    // Rebuilt properly:
  }

  // Note : redéfini proprement ci-dessous via un helper
  static pw.Widget _sectionVehiculeWidget(ContratLocationData d) {
    return _borderedSection(
      title: 'Désignation du Véhicule :',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(child: _labelValeur('Marque',  d.vehiculeMarque)),
              pw.Expanded(child: _labelValeur('Matricule :', d.vehiculeMatricule)),
              pw.Expanded(child: _labelValeur('Couleur :',   d.vehiculeCouleur ?? '')),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            children: [
              pw.Expanded(child: _labelValeur('Modèle',  d.vehiculeModele)),
              pw.Expanded(child: _labelValeur('Assurance :', d.vehiculeAssurance ?? '')),
              pw.Expanded(child: _labelValeur('Code RADIO :', d.vehiculeCodeRadio ?? '')),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tableau dates + kilométrage ──────────────────────────────────────────────
  static pw.Widget _buildTableauDatesKm(ContratLocationData d) {
    const headerStyle = pw.TextStyle(fontSize: 9);
    const cellStyle   = pw.TextStyle(fontSize: 9);

    pw.Widget cellPad(pw.Widget child, {bool isHeader = false}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          color: isHeader ? _grisCl : null,
          child: child,
        );

    return pw.Table(
      border: pw.TableBorder.all(color: _grisMd, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(60),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
      },
      children: [
        // En-tête
        pw.TableRow(children: [
          cellPad(pw.Text('', style: headerStyle), isHeader: true),
          cellPad(
            pw.Text('Date', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            isHeader: true,
          ),
          cellPad(
            pw.Text('Heure', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            isHeader: true,
          ),
          cellPad(
            pw.Text('Kilométrage', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            isHeader: true,
          ),
        ]),
        // Départ
        pw.TableRow(children: [
          cellPad(pw.Text('Départ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
          cellPad(pw.Text(
            '${_frDateLong(d.dateDepart)}',
            style: cellStyle,
          )),
          cellPad(pw.Text(_timeFmt.format(d.dateDepart), style: cellStyle)),
          cellPad(pw.Text('${d.kmDepart} Km', style: cellStyle)),
        ]),
        // Retour
        pw.TableRow(children: [
          cellPad(pw.Text('Retour', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
          cellPad(pw.Text(
            '${_frDateLong(d.dateRetour)}',
            style: cellStyle,
          )),
          cellPad(pw.Text(_timeFmt.format(d.dateRetour), style: cellStyle)),
          cellPad(pw.Text(
            d.kmRetour != null ? '${d.kmRetour} Km' : '',
            style: cellStyle,
          )),
        ]),
      ],
    );
  }

  // ── État du véhicule ────────────────────────────────────────────────────────
  static pw.Widget _buildEtatVehicule(ContratLocationData d) {
    final items = [
      ('Auto Radio',          d.etatDepart.autoRadio,          d.etatRetour?.autoRadio),
      ('Roue de secours',     d.etatDepart.roueDeSocours,      d.etatRetour?.roueDeSocours),
      ('Radiateur',           d.etatDepart.radiateur,          d.etatRetour?.radiateur),
      ('Carburant',           d.etatDepart.carburant,          d.etatRetour?.carburant),
      ('Avertisseur',         d.etatDepart.avertisseur,        d.etatRetour?.avertisseur),
      ('Controle à 4 Roues',  d.etatDepart.controle4Roues,     d.etatRetour?.controle4Roues),
      ('Controle carrosserie',d.etatDepart.controleCarrosserie,d.etatRetour?.controleCarrosserie),
      ('Controle des feux av-ar', d.etatDepart.controleFeux,   d.etatRetour?.controleFeux),
      ('Controle Interieur',  d.etatDepart.controleInterieur,  d.etatRetour?.controleInterieur),
    ];

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Schéma voiture (placeholder)
        pw.Container(
          width: 100,
          height: 90,
          margin: const pw.EdgeInsets.only(right: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _grisMd, width: 0.5),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            '[Vue voiture]',
            style: const pw.TextStyle(fontSize: 7, color: _gris),
          ),
        ),
        // Tableau état
        pw.Expanded(
          child: pw.Table(
            border: pw.TableBorder.all(color: _grisMd, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _grisCl),
                children: [
                  _etatCell('', bold: true),
                  _etatCell('Depart', bold: true),
                  _etatCell('Retour', bold: true),
                ],
              ),
              ...items.map((item) => pw.TableRow(children: [
                _etatCell(item.$1),
                _etatCell(_checkMark(item.$2)),
                _etatCell(item.$3 != null ? _checkMark(item.$3!) : ''),
              ])),
            ],
          ),
        ),
      ],
    );
  }

  // ── Conditions résumées ─────────────────────────────────────────────────────
  static pw.Widget _buildConditionsResumees() {
    const style = pw.TextStyle(fontSize: 7.5, color: _gris);
    const lines = [
      '- Les frais de la réparation de la voiture sont à la charge du client.',
      '- Passport en cour de Validite.',
      '- Kilométrages Limité (400 Km/H). Un forfait de 20 DA/Km en cas de supplément.',
      '- Durée minimum de la location 24H.',
      '- Préserver l\'entretien du véhicule à son retour.',
      '- Les frais d\'immobilisation du véhicule lors de la réparation seront comptés par le client.',
    ];
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _grisMd, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Conditions Générale :',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          ...lines.map((l) => pw.Text(l, style: style)),
        ],
      ),
    );
  }

  // ── Mention d'accord ────────────────────────────────────────────────────────
  static pw.Widget _buildMentionAccord() {
    return pw.Text(
      'Je reconnais avoir pris connaissance du contrat de location et de ses conditions générales de location '
      'avant la possession et je m\'engage d\'assumer toute responsabilité du véhicule.',
      style: pw.TextStyle(
        fontSize: 8,
        fontStyle: pw.FontStyle.italic,
      ),
      textAlign: pw.TextAlign.justify,
    );
  }

  // ── Signatures ──────────────────────────────────────────────────────────────
  static pw.Widget _buildSignatures() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 160,
              height: 40,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _grisMd, width: 0.5),
                ),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Signature du Locataire',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 160,
              height: 40,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _grisMd, width: 0.5),
                ),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Signature du Propriétaire',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PAGE 2 — CONDITIONS GÉNÉRALES
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Page _buildPage2() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Text(
              'CONDITIONS GENERALES DE LOCATION DE VEHICULE',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Divider(color: _noir, thickness: 0.8),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _buildConditionsCol1()),
              pw.SizedBox(width: 14),
              pw.Expanded(child: _buildConditionsCol2()),
            ],
          ),
          pw.Spacer(),
          _buildTarifsRetard(),
          pw.SizedBox(height: 8),
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
    );
  }

  static pw.Widget _buildConditionsCol1() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _cgArticle('1. Véhicule :', [
          'Vous ne pouvez prêtre à aucun titre de propriété du véhicule ni personne autre que nous ne peut vous vendre ou assigner le véhicule. Le locataire n\'effectuera aucune réparation ou sera vendre le véhicule sans notre consentement.',
          'Nous ne serons aucun cas responsables envers vous pour tout litige ou action juridique se rapport avec l\'utilisation du véhicule dans le cadre de votre contrat de location.',
          'Vous sommes obligés avoir livré une voiture conforme à l\'état décrit du véhicule qui vous sera remis avec votre contrat nous vous serons responsable, mais nous ne pourrons être tenus pour responsable de tout défaut d\'état apparent du véhicule qui n\'y figurait pas.',
          'Nous ne pourrions malheureusement pas être tenus de réclamation de domaine des dommages apparents du véhicule lors de votre départ.',
          'Le locataire doit se conformer aux règles de circulation, de stationnement et d\'usage du véhicule.',
          'En Algérie le véhicule ne peu en aucun cas être embarqué sur un bateau ou navire sans autorisation.',
        ]),
        pw.SizedBox(height: 6),
        _cgArticle('2. Conducteurs autorisés :', [
          'Le véhicule ne peut être conduit que par le locataire autorisé comme personne qui était présente au moment de la location et signe ce contrat.',
          'Les locataires autorisés doivent fournir avec justification tous les documents liés à l\'établissement du contrat (Passport - adresse - catégorie et la date de délivrance du permis de conduire et numéro de téléphone).',
        ]),
        pw.SizedBox(height: 6),
        _cgArticle('3. Utilisation interdites du véhicule :', [
          'A - Pour le transport de personnes contre rémunération.',
          'Pour pousser ou remorquer quoi que ce soit.',
          'Dans une course ou autre concours de cette nature.',
          'Pour des activités illégales ou contraires aux lois.',
          'Lorsque le conducteur a des facultés affaiblies par l\'alcool ou est drogué.',
          'Pour le transport d\'un nombre supérieur à celui mentionné sur la carte grise du véhicule.',
          'N\'importe où le conducteur n\'est pas un locataire autorisé.',
          'N\'importe ou ailleurs que sur une route en bonne état.',
          'Pour transporter des marchandises frauduleuses ou trompeuses.',
          'Pour causer intentionnellement des dommages ou pour gagner de l\'argent.',
          'L\'utilisation interdite du véhicule est une Infraction au contrat de location et annule ce dernier et peut vous rendre responsable de toutes les pertes et dommages en rapport avec le véhicule et le contrat.',
          'B - Quand vous stationnez le véhicule pour une courte durée, vous engagez à fermer clef et à vous servir des dispositifs d\'alarme et/d\'antivol dont le véhicule est équipé.',
          'Le locataire est responsable du véhicule en tout temps.',
          'Il est de contact clef en cas de vol ou de vandalisme.',
          'En cas de vol du cambriolage, le locataire est responsable du véhicule et de l\'assurance de ce dernier est entièrement à charge.',
        ]),
        pw.SizedBox(height: 6),
        _cgArticle('4. Location :', [
          'La durée de location se calcule par tranche de 24 heures non fractionnable depuis la première heure de mise à disposition du véhicule.',
          'Le locataire devra payer pour chaque heure et en ration d\'heure à l\'échéance d\'une journée de location jusqu\'à ce que le véhicule nous soit retourné jusqu\'à concurrence en tant que journalier applicable.',
        ]),
      ],
    );
  }

  static pw.Widget _buildConditionsCol2() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _cgArticle('5. Retour du véhicule et fin :', [
          'Le locataire est tenu de retourner le véhicule, ses clefs et ses papiers au bailleur à la date et à l\'heure indiquée sur votre document de location dans le même état que celui duquel il a été loué. Si le locataire rend le véhicule lorsque le bureau est fermé, il pourrait subir le véhicule jusqu\'à réouverture du bureau, et ne peut pas en aucun cas prendre une autre voiture pendant 30 jours à moins de signer un nouveau contrat de location. S\'il néglige de faire il devra nous payer des frais dependants et location.',
          'En cas de vol du contrat est arrêté dès transmission au bailleur des clefs. La caution sera rempli par le locataire et les frais d\'assurance amiable entre locataire et les tierces.',
          'En tout cas nous ne remettons les clef des personnes présentes sur le parking prétendant être des agents de location.',
          'En cas de confiscation de mise sous scellés du véhicule, le contrat de l\'assurance résilia du contrat en cas droit des que vous les serons informés par les autorités judiciaires ou les locataires.',
        ]),
        pw.SizedBox(height: 6),
        _cgArticle('6. Le Paiement :', [
          'Le prix de location est calculé selon les tarifs en vigueur et ne fera fois de la signature du contrat les éventuelles redevances ou royalties ainsi que les pénalités correspondants à des violations ou à des différentes cotisations relatives aux garanties ou assurances complémentaires souscrites le dépôt légales.',
        ]),
        pw.SizedBox(height: 6),
        _cgArticle('7. Dépôt de garantie :', [
          'Le montant de dépôt de garantie dépend de la catégorie du véhicule loué. Il est destiné à couvrir le préjudice subi par le locataire du fait de dommage ou de vol. Le dépôt de la caution sera remboursé de façon amiable entre locataire et le bailleur en cas de dommage imputable et en cas de vol de véhicule.',
        ]),
        pw.SizedBox(height: 6),
        _cgArticle('8. Les Frais :', [
          'Le locataire est tenu de payer tous les frais stipulés au document de location à savoir :',
          '- Frais de temps calculé au temps incluse au document de la location.',
          '- Frais de service de réapprovisionnement en carburant si vous nous retournez le véhicule avec moins de carburant qu\'au moment du départ. Vous l\'avez payé pour nous, il vous devra pour tous les frais de réapprovisionnement en carburant.',
          '- Vous devez payer les montants exigibles pour toutes les taxes applicables.',
          '- Vous devez payer toutes les amendes, Pénalités et autres dépenses occasionnées par l\'utilisation du véhicule en infraction.',
          '- Si ces frais sont assujettis à une vérification final. S\'il y a erreur de facturation vous réglerez le montant corrigés ou vous serez remboursé.',
        ]),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _noir, width: 1.0),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'ATTENTION',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '- Le kilométrage inclut est de 400 Kms Maximum par 24h, au-delà du kilométrage il sera facturé 20 DA par kilomètre supplémentaire parcouru.',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                '- Si le véhicule est remis à l\'agence après les délais, la tarification suivante sera appliquée :',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTarifsRetard() {
    final tarifs = [
      ('1H',  '600 DA'),
      ('2H',  '1 500 DA'),
      ('3H',  '2 000 DA'),
      ('4H et plus', 'Prix de la journée'),
    ];

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: _grisMd, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(60),
            1: pw.FixedColumnWidth(100),
          },
          children: tarifs.map((t) => pw.TableRow(children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: pw.Text(t.$1, style: const pw.TextStyle(fontSize: 8)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: pw.Text(
                t.$2,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ])).toList(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS COMMUNS
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _borderedSection({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _grisMd, width: 0.5),
      ),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  static pw.Widget _labelValeur(String label, String valeur) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label : ',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.TextSpan(
              text: valeur,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _etatCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: bold
            ? pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)
            : const pw.TextStyle(fontSize: 7.5),
      ),
    );
  }

  static String _checkMark(bool val) => val ? '✓' : '✗';

  static String _frDateLong(DateTime d) {
    const mois = [
      '', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${mois[d.month]} ${d.year}';
  }

  static pw.Widget _cgArticle(String title, List<String> paragraphs) {
    const pStyle = pw.TextStyle(fontSize: 7.5, color: _gris);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        ...paragraphs.map((p) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2, left: 4),
              child: pw.Text(p, style: pStyle, textAlign: pw.TextAlign.justify),
            )),
      ],
    );
  }
}

// Extension utilitaire (évite d'importer package:collection)
extension _NullableAlso<T> on T? {
  T? also(void Function(T) fn) {
    if (this != null) fn(this as T);
    return this;
  }
}
