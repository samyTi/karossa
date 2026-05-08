// lib/features/contrats/presentation/contrat_vente_pdf_generator.dart
//
// Générateur PDF — Contrat de vente de véhicule
// Calqué sur contrat_location_pdf_generator.dart (même structure, mêmes helpers)
//
// DÉPENDANCES pubspec.yaml (déjà présentes) :
//   pdf: ^3.11.0
//   path_provider: ^2.1.0
//   intl: ^0.19.0

import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─────────────────────────────────────────────────────────────────────────────
//  DTO
// ─────────────────────────────────────────────────────────────────────────────

class ContratVenteDto {
  final String venteId;
  final DateTime dateEtablissement;

  // Vendeur (showroom)
  final String agenceNom;
  final String agenceAdresse;
  final String agenceTel;
  final String? agenceEmail;
  final String? agenceVille;
  final String? agenceRc;
  final String? agenceCouleurHex;

  // Acheteur
  final String acheteurNom;
  final String acheteurPrenom;
  final String acheteurTel;
  final String? acheteurEmail;
  final String? acheteurAdresse;
  final String? acheteurCin;
  final String? acheteurNumPermis;

  // Véhicule
  final String vehiculeMarque;
  final String vehiculeModele;
  final int? vehiculeAnnee;
  final String? vehiculeCouleur;
  final String? vehiculeImmatriculation;
  final String? vehiculeCarburant;
  final String? vehiculeBoite;
  final int? vehiculeKilometrage;
  final String? vehiculeNumChassis;

  // Financier
  final double prixVente;
  final double? prixCatalogue;
  final double acompteVerse;
  final double soldeRestant;
  final String modePaiement;
  final String statutPaiement; // 'complet' | 'partiel'

  // Divers
  final String? notes;

  const ContratVenteDto({
    required this.venteId,
    required this.dateEtablissement,
    required this.agenceNom,
    required this.agenceAdresse,
    required this.agenceTel,
    this.agenceEmail,
    this.agenceVille,
    this.agenceRc,
    this.agenceCouleurHex,
    required this.acheteurNom,
    required this.acheteurPrenom,
    required this.acheteurTel,
    this.acheteurEmail,
    this.acheteurAdresse,
    this.acheteurCin,
    this.acheteurNumPermis,
    required this.vehiculeMarque,
    required this.vehiculeModele,
    this.vehiculeAnnee,
    this.vehiculeCouleur,
    this.vehiculeImmatriculation,
    this.vehiculeCarburant,
    this.vehiculeBoite,
    this.vehiculeKilometrage,
    this.vehiculeNumChassis,
    required this.prixVente,
    this.prixCatalogue,
    required this.acompteVerse,
    required this.soldeRestant,
    required this.modePaiement,
    required this.statutPaiement,
    this.notes,
  });

  String get acheteurFullName => '$acheteurPrenom $acheteurNom';
  String get vehiculeLabel =>
      '$vehiculeMarque $vehiculeModele${vehiculeAnnee != null ? ' (${vehiculeAnnee!})' : ''}';
  bool get isSolde => statutPaiement == 'complet';
}

// ─────────────────────────────────────────────────────────────────────────────
//  GÉNÉRATEUR PDF
// ─────────────────────────────────────────────────────────────────────────────

class ContratVentePdfGenerator {
  ContratVentePdfGenerator._();

  static final _dateFmt  = DateFormat('dd/MM/yyyy', 'fr');
  static final _moneyFmt = NumberFormat('#,###', 'fr');
  static String _idFmt(String id) =>
      id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  // ── Point d'entrée principal ──────────────────────────────

  static pw.Document build(ContratVenteDto dto) {
    final doc   = pw.Document();
    final color = _hexColor(dto.agenceCouleurHex);
    final light = PdfColor(color.red, color.green, color.blue, 0.12);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      header: (ctx) => _buildHeader(dto, color),
      footer: (ctx) => _buildFooter(dto, ctx),
      build: (ctx) => [
        // 1. Acheteur
        _sectionTitle('INFORMATIONS ACHETEUR', color),
        pw.SizedBox(height: 4),
        _twoColInfoTable(
          left: [
            ['Nom',       dto.acheteurNom],
            ['Prénom',    dto.acheteurPrenom],
            ['Téléphone', dto.acheteurTel],
          ],
          right: [
            ['N° CIN',    dto.acheteurCin    ?? '—'],
            ['N° Permis', dto.acheteurNumPermis ?? '—'],
            ['Email',     dto.acheteurEmail  ?? '—'],
          ],
          color: color,
          light: light,
        ),
        if ((dto.acheteurAdresse ?? '').isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _oneLineInfo('Adresse', dto.acheteurAdresse!, color, light),
        ],
        pw.SizedBox(height: 8),

        // 2. Véhicule
        _sectionTitle('INFORMATIONS VÉHICULE', color),
        pw.SizedBox(height: 4),
        _twoColInfoTable(
          left: [
            ['Marque',      dto.vehiculeMarque],
            ['Modèle',      dto.vehiculeModele],
            ['Année',       dto.vehiculeAnnee?.toString() ?? '—'],
            ['Couleur',     dto.vehiculeCouleur ?? '—'],
          ],
          right: [
            ['Matricule',   dto.vehiculeImmatriculation ?? '—'],
            ['Carburant',   dto.vehiculeCarburant  ?? '—'],
            ['Boîte',       dto.vehiculeBoite      ?? '—'],
            ['Kilométrage', dto.vehiculeKilometrage != null
                ? '${_moneyFmt.format(dto.vehiculeKilometrage!)} km'
                : '—'],
          ],
          color: color,
          light: light,
        ),
        if ((dto.vehiculeNumChassis ?? '').isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _oneLineInfo('N° Châssis', dto.vehiculeNumChassis!, color, light),
        ],
        pw.SizedBox(height: 8),

        // 3. Détails financiers
        _sectionTitle('DÉTAILS DE LA VENTE', color),
        pw.SizedBox(height: 4),
        _financialTable(dto, color, light),
        pw.SizedBox(height: 6),
        _totalRow(dto, color, light),
        pw.SizedBox(height: 8),

        // 4. Conditions générales
        _sectionTitle('CONDITIONS GÉNÉRALES', color),
        pw.SizedBox(height: 4),
        _conditionsGenerales(),
        pw.SizedBox(height: 12),

        // 5. Signatures
        _signatures(dto, color, light),
      ],
    ));

    return doc;
  }

  // ── Sauvegarde en bytes (pour upload Supabase Storage) ────

  static Future<Uint8List> saveBytes(pw.Document doc) async {
    return await doc.save();
  }

  // ── Sauvegarde locale ─────────────────────────────────────

  static Future<File> saveToFile(pw.Document doc, String venteId) async {
    final bytes  = await doc.save();
    final appDir = await getApplicationDocumentsDirectory();
    final name   = 'contrat_vente_${_idFmt(venteId)}.pdf';
    final file   = File('${appDir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ═══════════════════════════════════════════════════════════
  //  WIDGETS INTERNES
  // ═══════════════════════════════════════════════════════════

  static pw.Widget _buildHeader(ContratVenteDto dto, PdfColor color) {
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
                    if (dto.agenceEmail?.isNotEmpty == true) dto.agenceEmail!,
                  ].join('  |  '),
                  style:
                      const pw.TextStyle(color: PdfColors.white, fontSize: 8),
                ),
                if ((dto.agenceRc ?? '').isNotEmpty)
                  pw.Text('RC : ${dto.agenceRc!}',
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 8)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('CONTRAT DE VENTE',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('N° ${_idFmt(dto.venteId)}',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(_dateFmt.format(dto.dateEtablissement),
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
    ]);
  }

  static pw.Widget _buildFooter(ContratVenteDto dto, pw.Context ctx) {
    return pw.Column(children: [
      pw.Divider(color: PdfColors.grey300, thickness: 0.5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${dto.agenceNom}${dto.agenceTel.isNotEmpty ? '  |  Tél : ${dto.agenceTel}' : ''}',
            style:
                const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${ctx.pageNumber}/${ctx.pagesCount}  —  '
            'Généré le ${_dateFmt.format(DateTime.now())}',
            style:
                const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    ]);
  }

  static pw.Widget _sectionTitle(String text, PdfColor color) {
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

  static pw.Widget _twoColInfoTable({
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
              width: 80,
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700)),
            ),
            pw.Flexible(
              child: pw.Text(
                  value.isEmpty ? '—' : value,
                  style: const pw.TextStyle(fontSize: 9)),
            ),
          ]),
        );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
            child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: left.map((r) => cell(r[0], r[1])).toList(),
          ),
        )),
        pw.SizedBox(width: 6),
        pw.Expanded(
            child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: right.map((r) => cell(r[0], r[1])).toList(),
          ),
        )),
      ],
    );
  }

  static pw.Widget _oneLineInfo(
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

  static pw.Widget _financialTable(
      ContratVenteDto dto, PdfColor color, PdfColor light) {
    final modeLabel = switch (dto.modePaiement) {
      'especes'  => 'Espèces',
      'virement' => 'Virement bancaire',
      'cheque'   => 'Chèque',
      'credit'   => 'Crédit',
      _          => dto.modePaiement,
    };

    pw.Widget headerCell(String t) => pw.Container(
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

    pw.Widget dataCell(String t, {bool isLabel = false, bool isAmount = false}) =>
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          color: isLabel ? light : PdfColors.white,
          child: pw.Center(
              child: pw.Text(t,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: (isLabel || isAmount)
                          ? pw.FontWeight.bold
                          : null,
                      color: isLabel ? color : PdfColors.black))),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(110),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(children: [
          headerCell(''),
          headerCell('MONTANT'),
          headerCell('MODE'),
        ]),
        if (dto.prixCatalogue != null)
          pw.TableRow(children: [
            dataCell('Prix catalogue', isLabel: true),
            dataCell('${_moneyFmt.format(dto.prixCatalogue!)} DA'),
            dataCell('—'),
          ]),
        pw.TableRow(children: [
          dataCell('Prix de vente', isLabel: true),
          dataCell('${_moneyFmt.format(dto.prixVente)} DA', isAmount: true),
          dataCell(modeLabel),
        ]),
        pw.TableRow(children: [
          dataCell('Acompte versé', isLabel: true),
          dataCell('${_moneyFmt.format(dto.acompteVerse)} DA'),
          dataCell('—'),
        ]),
        pw.TableRow(children: [
          dataCell('Solde restant', isLabel: true),
          dataCell('${_moneyFmt.format(dto.soldeRestant)} DA'),
          dataCell(dto.isSolde ? '✓ Soldé' : 'À régler'),
        ]),
      ],
    );
  }

  static pw.Widget _totalRow(
      ContratVenteDto dto, PdfColor color, PdfColor light) {
    final statutColor = dto.isSolde
        ? const PdfColor(0.13, 0.65, 0.36)   // vert
        : const PdfColor(0.90, 0.50, 0.09);   // orange

    return pw.Row(children: [
      pw.Expanded(
          child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: light,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Véhicule vendu',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600)),
            pw.Text(dto.vehiculeLabel,
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
            if (dto.vehiculeImmatriculation != null)
              pw.Text('Immat. : ${dto.vehiculeImmatriculation!}',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      )),
      pw.SizedBox(width: 6),
      pw.Expanded(
          child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('PRIX DE VENTE',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Text('${_moneyFmt.format(dto.prixVente)} DA',
                style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 4),
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                color: statutColor,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                dto.isSolde ? '✓ Paiement complet' : '⚠ Paiement partiel',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
              ),
            ),
          ],
        ),
      )),
    ]);
  }

  static pw.Widget _conditionsGenerales() {
    const clauses = [
      '1. Le vendeur certifie être le propriétaire légal du véhicule décrit ci-dessus '
          'et garantit qu\'il est libre de tout gage, opposition ou saisie.',
      '2. L\'acheteur déclare avoir pris connaissance de l\'état du véhicule et l\'accepter '
          'en l\'état au moment de la signature du présent contrat.',
      '3. Le transfert de propriété est effectif à compter du règlement intégral du prix '
          'de vente convenu. Jusqu\'à ce moment, le véhicule reste la propriété du vendeur.',
      '4. Le vendeur remet à l\'acheteur, lors de la livraison : la carte grise barrée, '
          'le certificat de non-gage, les clés et tout document de bord.',
      '5. Les éventuelles pannes ou défauts survenant après la livraison ne pourront être '
          'imputés au vendeur sauf vice caché dûment constaté.',
      '6. Tout litige relatif au présent contrat sera soumis aux tribunaux compétents '
          'du lieu de signature.',
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
        children: clauses
            .map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Text(c,
                      style: const pw.TextStyle(
                          fontSize: 8.5, color: PdfColors.grey800),
                      textAlign: pw.TextAlign.justify),
                ))
            .toList(),
      ),
    );
  }

  static pw.Widget _signatures(
      ContratVenteDto dto, PdfColor color, PdfColor light) {
    pw.Widget sigBox(String label, String name) => pw.Expanded(
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
                pw.Text('Lu et approuvé — $name',
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
      sigBox('Signature de l\'acheteur', dto.acheteurFullName),
      pw.SizedBox(width: 10),
      sigBox('Signature du vendeur', dto.agenceNom),
    ]);
  }

  // ── Helpers ───────────────────────────────────────────────

  static PdfColor _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) {
      return const PdfColor(0.10, 0.44, 0.83);
    }
    final h = hex.replaceAll('#', '');
    if (h.length != 6) return const PdfColor(0.10, 0.44, 0.83);
    return PdfColor(
      int.parse(h.substring(0, 2), radix: 16) / 255,
      int.parse(h.substring(2, 4), radix: 16) / 255,
      int.parse(h.substring(4, 6), radix: 16) / 255,
    );
  }
}
