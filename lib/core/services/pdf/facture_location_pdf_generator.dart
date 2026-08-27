// lib/core/services/pdf/facture_location_pdf_generator.dart
//
// Génère la facture PDF d'une location, destinée au CLIENT.
//
// ⚠️ Document volontairement distinct du contrat de location
// (contrat_location_pdf_generator) : c'est un document comptable simple
// (désignation / montant / paiements reçus / solde). Il ne fait JAMAIS
// apparaître la répartition interne gérant / propriétaire(s) — cette
// donnée reste interne au showroom (voir LocationRepartitionSummary /
// l'écran "Résumé" pour ça).

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:garage_auto/core/extensions/l10n_extension.dart';
import 'pdf_theme.dart' hide debugPrint;

class FacturePaiementLigne {
  final DateTime date;
  final String? mode;
  final double montant;

  const FacturePaiementLigne({
    required this.date,
    this.mode,
    required this.montant,
  });
}

class FactureLocationDto {
  final String locationId;
  final DateTime dateEmission;

  // Agence
  final String agenceNom;
  final String agenceAdresse;
  final String agenceTel;
  final String? agenceEmail;
  final String? agenceRc;
  final String agenceCouleurHex;

  // Client
  final String clientNomComplet;
  final String clientTel;
  final String? clientAdresse;

  // Véhicule
  final String vehiculeDesignation; // "Marque Modèle"
  final String? vehiculeImmatriculation;
  final String? vehiculeCouleur;

  // Location
  final DateTime dateDebut;
  final DateTime? dateFinPrevue;
  final DateTime? dateFinReelle;
  final int nbJours;
  final double prixJour;
  final double montantTotal;
  final double caution;
  final double retenueCaution;
  final bool estTerminee;

  final List<FacturePaiementLigne> paiements;

  const FactureLocationDto({
    required this.locationId,
    required this.dateEmission,
    required this.agenceNom,
    required this.agenceAdresse,
    required this.agenceTel,
    this.agenceEmail,
    this.agenceRc,
    this.agenceCouleurHex = '#2563EB',
    required this.clientNomComplet,
    required this.clientTel,
    this.clientAdresse,
    required this.vehiculeDesignation,
    this.vehiculeImmatriculation,
    this.vehiculeCouleur,
    required this.dateDebut,
    this.dateFinPrevue,
    this.dateFinReelle,
    required this.nbJours,
    required this.prixJour,
    required this.montantTotal,
    this.caution = 0,
    this.retenueCaution = 0,
    this.estTerminee = false,
    this.paiements = const [],
  });

  double get totalPaiements => paiements.fold(0.0, (s, p) => s + p.montant);
  double get solde => montantTotal - totalPaiements;
}

class FactureLocationPdfGenerator {
  FactureLocationPdfGenerator._();

  static String _id8(String id) =>
      (id.length >= 8 ? id.substring(0, 8) : id).toUpperCase();

  static PdfColor _color(String hex) {
    try {
      final h = hex.replaceAll('#', '').trim();
      return PdfColor.fromInt(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const PdfColor.fromInt(0xFF2563EB);
    }
  }

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static Future<pw.Document> build(FactureLocationDto dto) async {
    // Idem recap : aucune police n'était chargée ici, donc un nom de
    // client saisi en arabe ne s'affichait pas du tout sur la facture.
    await PdfTheme.loadAllFonts();
    final doc = pw.Document();
    final accent = _color(dto.agenceCouleurHex);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(dto, accent),
        footer: (ctx) => _buildFooter(dto, ctx),
        build: (ctx) => [
          pw.SizedBox(height: 16),
          _buildPartiesRow(dto),
          pw.SizedBox(height: 20),
          _buildLigneTable(dto, accent),
          pw.SizedBox(height: 16),
          _buildTotalBlock(dto, accent),
          if (dto.paiements.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Paiements reçus',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            _buildPaiementsTable(dto),
          ],
          pw.SizedBox(height: 20),
          _buildSoldeBlock(dto),
          if (dto.caution > 0) ...[
            pw.SizedBox(height: 14),
            _buildCautionBlock(dto),
          ],
          pw.SizedBox(height: 30),
          _buildSignatureRow(dto),
        ],
      ),
    );

    return doc;
  }

  // ── Header / Footer ───────────────────────────────────────────────────

  static pw.Widget _buildHeader(FactureLocationDto dto, PdfColor accent) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    dto.agenceNom,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  if (dto.agenceAdresse.isNotEmpty)
                    pw.Text(dto.agenceAdresse, style: const pw.TextStyle(fontSize: 9)),
                  if (dto.agenceTel.isNotEmpty)
                    pw.Text('Tél : ${dto.agenceTel}', style: const pw.TextStyle(fontSize: 9)),
                  if (dto.agenceEmail != null && dto.agenceEmail!.isNotEmpty)
                    pw.Text(dto.agenceEmail!, style: const pw.TextStyle(fontSize: 9)),
                  if (dto.agenceRc != null && dto.agenceRc!.isNotEmpty)
                    pw.Text('RC : ${dto.agenceRc}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: accent,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'FACTURE',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text('N° ${_id8(dto.locationId)}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Date : ${_d(dto.dateEmission)}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: accent, thickness: 1.2),
      ],
    );
  }

  static pw.Widget _buildFooter(FactureLocationDto dto, pw.Context ctx) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Facture générée automatiquement — ${dto.agenceNom}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }

  // ── Corps ──────────────────────────────────────────────────────────────

  static pw.Widget _buildPartiesRow(FactureLocationDto dto) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _partieBlock('Client', [
            dto.clientNomComplet,
            dto.clientTel,
            if (dto.clientAdresse != null && dto.clientAdresse!.isNotEmpty)
              dto.clientAdresse!,
          ]),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: _partieBlock('Véhicule', [
            dto.vehiculeDesignation,
            if (dto.vehiculeImmatriculation != null && dto.vehiculeImmatriculation!.isNotEmpty)
              'Immat. : ${dto.vehiculeImmatriculation}',
            if (dto.vehiculeCouleur != null && dto.vehiculeCouleur!.isNotEmpty)
              'Couleur : ${dto.vehiculeCouleur}',
          ]),
        ),
      ],
    );
  }

  static pw.Widget _partieBlock(String titre, List<String> lignes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            titre,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          ...lignes.map(
            (l) => pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1.5),
              child: PdfTheme.smartText(l, fontSize: 9.5),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLigneTable(FactureLocationDto dto, PdfColor accent) {
    final periode = dto.dateFinReelle != null
        ? '${_d(dto.dateDebut)} → ${_d(dto.dateFinReelle!)}'
        : dto.dateFinPrevue != null
            ? '${_d(dto.dateDebut)} → ${_d(dto.dateFinPrevue!)} (prévu)'
            : '${_d(dto.dateDebut)} → contrat ouvert';

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1.3),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: accent),
          children: [
            _cellHeader('Désignation'),
            _cellHeader('Jours'),
            _cellHeader('Prix / jour'),
            _cellHeader('Montant'),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'Location ${dto.vehiculeDesignation}\nPériode : $periode',
                style: const pw.TextStyle(fontSize: 9.5),
              ),
            ),
            _cell('${dto.nbJours}'),
            _cell('${dto.prixJour.toInt()} DA'),
            _cell('${dto.montantTotal.toInt()} DA', bold: true),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cellHeader(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          t,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      );

  static pw.Widget _cell(String t, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          t,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
          textAlign: pw.TextAlign.right,
        ),
      );

  static pw.Widget _buildTotalBlock(FactureLocationDto dto, PdfColor accent) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('TOTAL', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text(
              '${dto.montantTotal.toInt()} DA',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: accent),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPaiementsTable(FactureLocationDto dto) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cellHeaderGrey('Date'),
            _cellHeaderGrey('Mode'),
            _cellHeaderGrey('Montant'),
          ],
        ),
        ...dto.paiements.map(
          (p) => pw.TableRow(
            children: [
              _cellLeft(_d(p.date)),
              _cellLeft(p.mode ?? '—'),
              _cell('${p.montant.toInt()} DA'),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _cellHeaderGrey(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _cellLeft(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(t, style: const pw.TextStyle(fontSize: 9.5)),
      );

  static pw.Widget _buildSoldeBlock(FactureLocationDto dto) {
    final solde = dto.solde;
    final soldeColor =
        solde > 0 ? const PdfColor.fromInt(0xFFEF4444) : const PdfColor.fromInt(0xFF10B981);

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: soldeColor, width: 1),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Encaissé', style: const pw.TextStyle(fontSize: 9.5)),
                pw.Text('${dto.totalPaiements.toInt()} DA', style: const pw.TextStyle(fontSize: 9.5)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  solde > 0 ? 'Reste à payer' : 'Solde',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '${solde.toInt()} DA',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: soldeColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildCautionBlock(FactureLocationDto dto) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        dto.retenueCaution > 0
            ? 'Caution versée : ${dto.caution.toInt()} DA — retenue : ${dto.retenueCaution.toInt()} DA (non incluse dans le total ci-dessus)'
            : 'Caution versée : ${dto.caution.toInt()} DA (remboursable, non incluse dans le total ci-dessus)',
        style: const pw.TextStyle(fontSize: 8.5),
      ),
    );
  }

  static pw.Widget _buildSignatureRow(FactureLocationDto dto) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Le client', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 30),
            pw.Container(width: 140, height: 0.7, color: PdfColors.grey400),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Pour ${dto.agenceNom}', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 30),
            pw.Container(width: 140, height: 0.7, color: PdfColors.grey400),
          ],
        ),
      ],
    );
  }
}