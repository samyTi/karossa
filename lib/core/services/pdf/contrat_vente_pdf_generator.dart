// lib/core/services/pdf/contrat_vente_pdf_generator.dart
//
// Générateur PDF — Contrat de vente de véhicule.
// Dépend de :
//   pdf_theme.dart   → polices, couleurs, formateurs
//   pdf_layout.dart  → widgets partagés (header, footer, sections…)
//   features/contrats/domain/contrat_vente_dto.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_theme.dart';
import 'pdf_layout.dart';
import '../../../features/contrats/domain/contrat_vente_dto.dart';

export '../../../features/contrats/domain/contrat_vente_dto.dart';

class ContratVentePdfGenerator {
  ContratVentePdfGenerator._();

  // ── Clauses par défaut (utilisées si articles dynamiques vides) ────────────

  static const _defaultClauses = [
    {
      'titre': '1. Propriété',
      'corps': 'Le vendeur certifie être le propriétaire légal du véhicule '
          'et garantit qu\'il est libre de tout gage ou opposition.',
    },
    {
      'titre': '2. État du véhicule',
      'corps': 'L\'acheteur déclare avoir pris connaissance de l\'état du '
          'véhicule et l\'accepte en l\'état au moment de la signature.',
    },
    {
      'titre': '3. Transfert de propriété',
      'corps': 'Le transfert de propriété est effectif à compter du règlement '
          'intégral du prix de vente. Jusqu\'à ce moment le véhicule reste '
          'la propriété du vendeur.',
    },
    {
      'titre': '4. Documents remis',
      'corps': 'Le vendeur remet à l\'acheteur lors de la livraison : '
          'la carte grise barrée, le certificat de non-gage, les clés et '
          'tout document de bord.',
    },
    {
      'titre': '5. Litiges',
      'corps': 'Tout litige relatif au présent contrat sera soumis aux '
          'tribunaux compétents du lieu de signature.',
    },
  ];

  // ── Point d'entrée ─────────────────────────────────────────────────────────

  static Future<pw.Document> buildAsync(ContratVenteDto dto) async {
    await PdfTheme.loadLatinFont();
    return _build(dto);
  }

  static Future<Uint8List> buildBytes(ContratVenteDto dto) async {
    final doc = await buildAsync(dto);
    return doc.save();
  }

  // ── Construction ───────────────────────────────────────────────────────────

  static pw.Document _build(ContratVenteDto dto) {
    final doc   = pw.Document();
    final color = PdfTheme.hexColor(dto.agenceCouleurHex);
    final light = PdfTheme.lightVariant(color);
    final id8   = PdfTheme.shortId(dto.venteId);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      header: (_) => PdfTheme.withLatinTheme(
        PdfLayout.header(
          agenceNom:          dto.agenceNom,
          agenceAdresse:      dto.agenceAdresse,
          agenceTel:          dto.agenceTel,
          agenceEmail:        dto.agenceEmail,
          agenceRc:           dto.agenceRc,
          titreContrat:       'CONTRAT DE VENTE',
          numero:             id8,
          date:               dto.dateEtablissement,
          color:              color,
          logoImage: dto.agenceLogoBytes != null
              ? pw.MemoryImage(dto.agenceLogoBytes!)
              : null,
        ),
      ),
      footer: (ctx) => PdfTheme.withLatinTheme(
        PdfLayout.footer(
          agenceNom: dto.agenceNom,
          agenceTel: dto.agenceTel,
          ctx: ctx,
        ),
      ),
      build: (_) => [
        PdfTheme.withLatinTheme(pw.Column(children: [
          // 1. Acheteur
          PdfLayout.sectionTitle('INFORMATIONS ACHETEUR', color),
          pw.SizedBox(height: 4),
          PdfLayout.twoColTable(
            left: [
              ['Nom',       dto.acheteurNom],
              ['Prénom',    dto.acheteurPrenom],
              ['Téléphone', dto.acheteurTel],
            ],
            right: [
              ['N° CIN',    dto.acheteurCin         ?? '—'],
              ['N° Permis', dto.acheteurNumPermis    ?? '—'],
              ['Email',     dto.acheteurEmail        ?? '—'],
            ],
            color: color,
            light: light,
          ),
          if ((dto.acheteurAdresse ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 4),
            PdfLayout.oneLineInfo(
                'Adresse', dto.acheteurAdresse!, color, light),
          ],
          pw.SizedBox(height: 10),

          // 2. Véhicule
          PdfLayout.sectionTitle('INFORMATIONS VÉHICULE', color),
          pw.SizedBox(height: 4),
          PdfLayout.twoColTable(
            left: [
              ['Marque',  dto.vehiculeMarque],
              ['Modèle',  dto.vehiculeModele],
              ['Année',   dto.vehiculeAnnee?.toString() ?? '—'],
              ['Couleur', dto.vehiculeCouleur           ?? '—'],
            ],
            right: [
              ['Matricule',
                dto.vehiculeImmatriculation ?? '—'],
              ['Carburant', dto.vehiculeCarburant  ?? '—'],
              ['Boîte',     dto.vehiculeBoite      ?? '—'],
              ['Kilométrage',
                dto.vehiculeKilometrage != null
                    ? PdfTheme.fmtKm(dto.vehiculeKilometrage!)
                    : '—'],
            ],
            color: color,
            light: light,
          ),
          if ((dto.vehiculeNumChassis ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 4),
            PdfLayout.oneLineInfo(
                'N° Châssis', dto.vehiculeNumChassis!, color, light),
          ],
          pw.SizedBox(height: 10),

          // 3. Financier
          PdfLayout.sectionTitle('DÉTAILS DE LA VENTE', color),
          pw.SizedBox(height: 4),
          _financialTable(dto, color, light),
          pw.SizedBox(height: 6),
          _totalRow(dto, color, light),
          pw.SizedBox(height: 10),

          // 4. Conditions
          PdfLayout.sectionTitle('CONDITIONS GÉNÉRALES', color),
          pw.SizedBox(height: 4),
          PdfLayout.articlesBlock(dto.articlesFr,
              defaultClauses: _defaultClauses),
          pw.SizedBox(height: 12),

          // 5. Signatures
          PdfLayout.signatures(
            labelGauche: 'Signature de l\'acheteur',
            nomGauche:   dto.acheteurNomComplet,
            labelDroite: 'Signature du vendeur',
            nomDroite:   dto.agenceNom,
            color:       color,
            light:       light,
          ),
        ])),
      ],
    ));

    return doc;
  }

  // ── Tableau financier ──────────────────────────────────────────────────────

  static pw.Widget _financialTable(
      ContratVenteDto dto, PdfColor color, PdfColor light) {
    final modeLabel = switch (dto.modePaiement) {
      'especes'  => 'Espèces',
      'virement' => 'Virement bancaire',
      'cheque'   => 'Chèque',
      'credit'   => 'Crédit',
      _          => dto.modePaiement,
    };

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(110),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(children: [
          PdfLayout.tableHeaderCell('', color),
          PdfLayout.tableHeaderCell('MONTANT', color),
          PdfLayout.tableHeaderCell('MODE', color),
        ]),
        pw.TableRow(children: [
          PdfLayout.tableDataCell('Prix de vente',  isLabel: true, labelColor: color, labelBg: light),
          PdfLayout.tableDataCell(PdfTheme.fmtMoney(dto.prixVente), isBold: true),
          PdfLayout.tableDataCell(modeLabel),
        ]),
        pw.TableRow(children: [
          PdfLayout.tableDataCell('Acompte versé',  isLabel: true, labelColor: color, labelBg: light),
          PdfLayout.tableDataCell(PdfTheme.fmtMoney(dto.acompteVerse)),
          PdfLayout.tableDataCell('—'),
        ]),
        pw.TableRow(children: [
          PdfLayout.tableDataCell('Solde restant',  isLabel: true, labelColor: color, labelBg: light),
          PdfLayout.tableDataCell(PdfTheme.fmtMoney(dto.soldeRestant)),
          PdfLayout.tableDataCell(dto.estSolde ? '✓ Soldé' : 'À régler'),
        ]),
      ],
    );
  }

  // ── Récapitulatif total ────────────────────────────────────────────────────

  static pw.Widget _totalRow(
      ContratVenteDto dto, PdfColor color, PdfColor light) {
    final statutColor = dto.estSolde
        ? const PdfColor(0.13, 0.65, 0.36)
        : const PdfColor(0.90, 0.50, 0.09);

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
              pw.Text(dto.vehiculeInfos,
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
        ),
      ),
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
              pw.Text(PdfTheme.fmtMoney(dto.prixVente),
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
                  dto.estSolde
                      ? '✓ Paiement complet'
                      : '⚠ Paiement partiel',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}