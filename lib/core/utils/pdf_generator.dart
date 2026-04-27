// lib/core/utils/pdf_generator.dart
// Générateur PDF avec paramètres dynamiques du showroom

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfGenerator {
  static final _dateFormat  = DateFormat('dd/MM/yyyy', 'fr');
  // ignore: unused_field
  static final _moneyFormat = NumberFormat('#,###', 'fr');

  // ── Helper : convertit couleur hex → PdfColor ──────────────
  // ignore: unused_element
  static PdfColor _fromHex(String hex) {
    final h = hex.replaceAll('#', '');
    final r = int.parse(h.substring(0, 2), radix: 16) / 255;
    final g = int.parse(h.substring(2, 4), radix: 16) / 255;
    final b = int.parse(h.substring(4, 6), radix: 16) / 255;
    return PdfColor(r, g, b);
  }

  // ── En-tête commun à tous les contrats ────────────────────
  static pw.Widget _buildHeader({
    required String titre,
    required String contratId,
    required Map<String, dynamic> showroom,
    required PdfColor primaryColor,
  }) {
    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(
              showroom['nom'] ?? 'Garage Auto',
              style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold,
                color: primaryColor),
            ),
            if ((showroom['adresse'] ?? '').isNotEmpty)
              pw.Text(showroom['adresse'],
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            if ((showroom['tel'] ?? '').isNotEmpty)
              pw.Text("Tél : ${showroom['tel']}",
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            if ((showroom['email'] ?? '').isNotEmpty)
              pw.Text(showroom['email'],
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            if ((showroom['rc'] ?? '').isNotEmpty)
              pw.Text("RC : ${showroom['rc']}",
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(titre,
              style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold,
                color: primaryColor)),
            pw.Text('N° \${contratId.substring(0, 8).toUpperCase()}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text(_dateFormat.format(DateTime.now()),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ]),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Divider(color: primaryColor, thickness: 1.5),
      pw.SizedBox(height: 12),
    ]);
  }

  // ══ CONTRAT DE LOCATION ════════════════════════════════════
  static pw.Document buildContratLocation({
    required String clientNom,
    required String clientTel,
    required String? clientEmail,
    required String? clientCni,
    required String? clientPermis,
    required String vehiculeNom,
    required String? immatriculation,
    required String? carburant,
    required String? boite,
    required DateTime dateDebut,
    required DateTime dateFin,
    required int kmDepart,
    required double prixJour,
    required double caution,
    required String? notesDepart,
    required String contratId,
    Map<String, dynamic>? showroom,
    Map<String, dynamic>? repartitions,
    PdfColor? primaryColor,
  }) {
    final doc      = pw.Document();
    final color    = primaryColor ?? const PdfColor(0.10, 0.44, 0.83);
    final nbJours  = dateFin.difference(dateDebut).inDays.clamp(1, 9999);
    // ignore: unused_local_variable
    final total    = prixJour * nbJours;
    final sh       = showroom ?? {'nom': 'Garage Auto'};

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader(
            titre: 'CONTRAT DE LOCATION',
            contratId: contratId,
            showroom: sh,
            primaryColor: color,
          ),

          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionTitle('LOCATAIRE', color),
                _line('Nom',      clientNom),
                _line('Tél',      clientTel),
                if (clientEmail != null && clientEmail.isNotEmpty)
                  _line('Email', clientEmail),
                if (clientCni   != null) _line('CNI',    clientCni),
                if (clientPermis != null) _line('Permis', clientPermis),
              ],
            )),
            pw.SizedBox(width: 24),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionTitle('VÉHICULE', color),
                _line('Véhicule', vehiculeNom),
                if (immatriculation != null) _line('Immat.', immatriculation),
                if (carburant != null) _line('Carburant', carburant),
                if (boite     != null) _line('Boite',     boite),
              ],
            )),
          ]),

          pw.SizedBox(height: 14),
          _sectionTitle('DÉTAILS DE LA LOCATION', color),
          pw.Row(children: [
            pw.Expanded(child: pw.Column(children: [
              _line('Date départ',  _dateFormat.format(dateDebut)),
              _line('Date retour',  _dateFormat.format(dateFin)),
              _line('Durée',        '$nbJours jour\${nbJours > 1 ? "s" : ""}'),
            ])),
            pw.Expanded(child: pw.Column(children: [
              _line('Km départ',   '\${_moneyFormat.format(kmDepart)} km'),
              _line('Prix / jour', '\${_moneyFormat.format(prixJour)} DA'),
              _line('Caution',     '\${_moneyFormat.format(caution)} DA'),
            ])),
          ]),

          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('MONTANT TOTAL', style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.Text('\${_moneyFormat.format(total)} DA',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16, color: color)),
              ],
            ),
          ),

          if (notesDepart != null && notesDepart.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionTitle('ÉTAT DU VÉHICULE AU DÉPART', color),
            pw.Text(notesDepart,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
          ],

          pw.Spacer(),
          pw.SizedBox(height: 16),
          _clausesLocale(),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _signatureBox('Le locataire'),
              _signatureBox('Le gérant'),
            ],
          ),
        ],
      ),
    ));
    return doc;
  }

  // ══ CONTRAT DE VENTE ══════════════════════════════════════
  static pw.Document buildContratVente({
    required String clientNom,
    required String clientTel,
    required String? clientEmail,
    required String? clientCni,
    required String vehiculeNom,
    required String? immatriculation,
    required int? annee,
    required int? kilometrage,
    required String? carburant,
    required double prixVente,
    required DateTime dateVente,
    required String contratId,
    Map<String, dynamic>? showroom,
    String? notes,
    PdfColor? primaryColor,
  }) {
    final doc   = pw.Document();
    final color = primaryColor ?? const PdfColor(0.10, 0.44, 0.83);
    final sh    = showroom ?? {'nom': 'Garage Auto'};

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader(
            titre: 'BON DE VENTE',
            contratId: contratId,
            showroom: sh,
            primaryColor: color,
          ),

          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionTitle('ACHETEUR', color),
                _line('Nom', clientNom),
                _line('Tél', clientTel),
                if (clientEmail != null && clientEmail.isNotEmpty)
                  _line('Email', clientEmail),
                if (clientCni != null) _line('CNI', clientCni),
              ],
            )),
            pw.SizedBox(width: 24),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionTitle('VÉHICULE VENDU', color),
                _line('Désignation', vehiculeNom),
                if (annee != null) _line('Année', '\$annee'),
                if (immatriculation != null) _line('Immat.', immatriculation),
                if (kilometrage != null)
                  _line('Kilométrage', '\${_moneyFormat.format(kilometrage)} km'),
                if (carburant != null) _line('Carburant', carburant),
              ],
            )),
          ]),

          pw.SizedBox(height: 14),
          _sectionTitle('TRANSACTION', color),
          _line('Date de vente', _dateFormat.format(dateVente)),

          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('PRIX DE VENTE', style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.Text('\${_moneyFormat.format(prixVente)} DA',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16, color: color)),
              ],
            ),
          ),

          if (notes != null && notes.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionTitle('OBSERVATIONS', color),
            pw.Text(notes,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
          ],

          pw.Spacer(),
          _clausesVente(),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _signatureBox('L\'acheteur'),
              _signatureBox('Le vendeur'),
            ],
          ),
        ],
      ),
    ));
    return doc;
  }

  // ══ CONTRAT D'ÉCHANGE ═════════════════════════════════════
  static pw.Document buildContratEchange({
    required String clientNom,
    required String clientTel,
    required String? clientCni,
    required String vehiculeCedeNom,
    required String? vehiculeCedeImmat,
    required String vehiculeReprisMarque,
    required String vehiculeReprisModele,
    required int? vehiculeReprisAnnee,
    required int? vehiculeReprisKm,
    required String? vehiculeReprisImmat,
    required double valeurReprise,
    required double complementClient,
    required DateTime dateEchange,
    required String contratId,
    Map<String, dynamic>? showroom,
    String? notes,
    PdfColor? primaryColor,
  }) {
    final doc   = pw.Document();
    final color = primaryColor ?? const PdfColor(0.10, 0.44, 0.83);
    final sh    = showroom ?? {'nom': 'Garage Auto'};

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader(
            titre: 'CONTRAT D\'ÉCHANGE',
            contratId: contratId,
            showroom: sh,
            primaryColor: color,
          ),

          _sectionTitle('CLIENT', color),
          _line('Nom', clientNom),
          _line('Tél', clientTel),
          if (clientCni != null) _line('CNI', clientCni),

          pw.SizedBox(height: 14),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionTitle('VÉHICULE CÉDÉ (Showroom)', color),
                _line('Désignation', vehiculeCedeNom),
                if (vehiculeCedeImmat != null)
                  _line('Immat.', vehiculeCedeImmat),
              ],
            )),
            pw.SizedBox(width: 24),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionTitle('VÉHICULE REPRIS (Client)', color),
                _line('Marque / Modèle',
                    '\$vehiculeReprisMarque \$vehiculeReprisModele'),
                if (vehiculeReprisAnnee != null)
                  _line('Année', '\$vehiculeReprisAnnee'),
                if (vehiculeReprisKm != null)
                  _line('Km', '\${_moneyFormat.format(vehiculeReprisKm)} km'),
                if (vehiculeReprisImmat != null && vehiculeReprisImmat.isNotEmpty)
                  _line('Immat.', vehiculeReprisImmat),
              ],
            )),
          ]),

          pw.SizedBox(height: 14),
          _sectionTitle('VALEURS', color),
          _line('Date échange', _dateFormat.format(dateEchange)),
          _line('Valeur de reprise',  '\${_moneyFormat.format(valeurReprise)} DA'),
          _line('Complément client', '\${_moneyFormat.format(complementClient)} DA'),

          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('VALEUR TOTALE', style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.Text(
                    '\${_moneyFormat.format(valeurReprise + complementClient)} DA',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16, color: color)),
              ],
            ),
          ),

          if (notes != null && notes.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionTitle('OBSERVATIONS', color),
            pw.Text(notes,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
          ],

          pw.Spacer(),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _signatureBox('Le client'),
              _signatureBox('Le gérant'),
            ],
          ),
        ],
      ),
    ));
    return doc;
  }

  // ── Widgets helpers ────────────────────────────────────────

  static pw.Widget _sectionTitle(String t, [PdfColor? color]) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6, top: 4),
    child: pw.Text(t,
      style: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 11,
        color: color ?? PdfColors.grey700,
      )),
  );

  static pw.Widget _line(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(children: [
      pw.SizedBox(
        width: 130,
        child: pw.Text(k, style: pw.TextStyle(
            fontSize: 10, fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey600))),
      pw.Flexible(
        child: pw.Text(v, style: const pw.TextStyle(fontSize: 10))),
    ]),
  );

  static pw.Widget _signatureBox(String label) => pw.Column(children: [
    pw.Container(
      width: 160, height: 70,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
    ),
    pw.SizedBox(height: 4),
    pw.Text(label,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
  ]);

  static pw.Widget _clausesLocale() => pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Text(
      'Le locataire s\'engage à restituer le véhicule dans l\'état où il l\'a pris, '
      'à la date et l\'heure convenus. Tout retard sera facturé au tarif journalier. '
      'La caution sera restituée après vérification de l\'état du véhicule.',
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
    ),
  );

  static pw.Widget _clausesVente() => pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Text(
      'Le vendeur certifie être propriétaire du véhicule et que celui-ci est '
      'libre de tout gage. La vente est conclue en l\'état, sans recours possible '
      'après remise des clés et signature du présent contrat.',
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
    ),
  );

  // ignore: unused_element
  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
