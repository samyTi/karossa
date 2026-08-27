// lib/core/services/pdf/vehicle_schema_pdf_renderer.dart
//
// Rend la maquette de carrosserie (image blueprint + pins de dommage)
// dans le PDF, de façon identique sur Web et Mobile : le package `pdf`
// fait son propre rendu vectoriel indépendamment de la plateforme, donc
// tant que les bytes de l'image sont fournis en mémoire (MemoryImage),
// le résultat est strictement identique partout.

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../features/vehicules/domain/etat_carrosserie_model.dart';

const _kCarAssetPath = 'assets/images/car_blueprint.jpg';

class VehicleSchemaPdfRenderer {
  VehicleSchemaPdfRenderer._();

  static Uint8List? _cachedBlueprint;

  static Future<Uint8List> loadBlueprintBytes() async {
    _cachedBlueprint ??=
        (await rootBundle.load(_kCarAssetPath)).buffer.asUint8List();
    return _cachedBlueprint!;
  }

  static PdfColor _pdfColor(TypeDommage t) => switch (t) {
        TypeDommage.rayure => const PdfColor.fromInt(0xFFF59E0B),
        TypeDommage.bosse => const PdfColor.fromInt(0xFFEF4444),
        TypeDommage.casse => const PdfColor.fromInt(0xFF7C3AED),
        TypeDommage.autre => const PdfColor.fromInt(0xFF6B7280),
      };

  /// Construit la maquette annotée (image + pins numérotés) à partir de
  /// bytes déjà chargés en mémoire.
  ///
  /// [showEmptyState] : si true et qu'aucun pin n'existe, affiche tout de
  /// même l'image vierge avec la mention "aucun impact constaté" — utile
  /// pour un constat d'état des lieux qui doit prouver qu'une vérification
  /// a bien eu lieu, même sans dommage trouvé.
  static pw.Widget buildWidgetFromBytes(
    Uint8List blueprintBytes,
    EtatCarrosserie etat, {
    double pdfWidth = 500,
    bool showLegend = true,
  }) {
    final pins = etat.pins;
    const double pinRadius = 8.0;

    final imageProvider = pw.MemoryImage(blueprintBytes);

    // 🔧 CORRECTIF (décalage + perte de points sur le template "classique") :
    //
    // Auparavant, ce schéma était construit avec une largeur FIXE
    // (pdfWidth, 500pt par défaut), calculée avant d'être inséré dans la
    // page. Or selon le template du contrat, l'endroit où ce widget est
    // inséré n'offre pas forcément 500pt de large :
    //   - template "standard"  → colonne pleine largeur (~539pt)   → OK de justesse
    //   - template "classique" → Expanded(flex: 3) dans une Row     → ~310-325pt seulement !
    // Un enfant plus large que l'espace qui lui est réellement alloué
    // déborde et se retrouve recouvert par le widget voisin (dessiné
    // après, donc par-dessus) → certains pins disparaissent visuellement,
    // et ceux qui restent visibles ne montrent qu'une portion recadrée de
    // l'image de 500pt (pas l'image entière), donc à une position qui ne
    // correspond plus à ce qui a été pointé à l'écran.
    //
    // Le correctif : on utilise pw.LayoutBuilder pour connaître la largeur
    // RÉELLEMENT disponible à l'endroit d'insertion (exactement comme
    // CarDamageMap le fait côté écran avec Flutter LayoutBuilder), et on en
    // déduit la hauteur avec le même ratio (0.56) partout. Comme les
    // positions des pins sont stockées en pourcentage, la conversion en
    // points PDF reste toujours fidèle au pourcentage d'origine, quelle
    // que soit la largeur réellement disponible. `pdfWidth` ne sert plus
    // que de repli si jamais aucune contrainte de largeur finie n'est
    // fournie par le parent (cas très rare, ex. Wrap non contraint).
    final schema = pw.LayoutBuilder(
      builder: (context, constraints) {
        final hasFiniteWidth =
            constraints != null && constraints.maxWidth.isFinite;
        final w = hasFiniteWidth ? constraints.maxWidth : pdfWidth;
        final h = w * 0.56;

        return pw.SizedBox(
          width: w,
          height: h,
          child: pw.Stack(
            children: [
              // ── 1. Image de fond (compatible Web + Mobile) ─────────────
              pw.SizedBox(
                width: w,
                height: h,
                child: pw.Image(
                  imageProvider,
                  fit: pw.BoxFit.fill,
                ),
              ),

              // ── 2. Pins numérotés ───────────────────────────────────────
              ...pins.indexed.map((entry) {
                final (index, pin) = entry;
                final left = (pin.xPct / 100 * w) - pinRadius;
                final top = (pin.yPct / 100 * h) - pinRadius;

                final color = _pdfColor(pin.type);

                return pw.Positioned(
                  left: left,
                  top: top,
                  child: pw.Container(
                    width: pinRadius * 2,
                    height: pinRadius * 2,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      color: color,
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(
                        color: PdfColors.white,
                        width: 1.2,
                      ),
                    ),
                    child: pw.Text(
                      '${index + 1}',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 7.0,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),

              // ── 3. Bandeau "aucun impact" si la maquette est vierge ────
              if (pins.isEmpty)
                pw.Positioned(
                  right: 8,
                  bottom: 8,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green700,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Text(
                      'Aucun impact constaté',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (!showLegend || pins.isEmpty) return schema;

    // ── 4. Légende : numéro → type de dommage (+ note si présente) ──────
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        schema,
        pw.SizedBox(height: 6),
        pw.Wrap(
          spacing: 10,
          runSpacing: 4,
          children: pins.indexed.map((entry) {
            final (index, pin) = entry;
            final label = pin.note != null && pin.note!.isNotEmpty
                ? '${pin.type.label} — ${pin.note}'
                : pin.type.label;
            return pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  width: 12,
                  height: 12,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: _pdfColor(pin.type),
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: PdfColors.white, width: 0.8),
                  ),
                  child: pw.Text(
                    '${index + 1}',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Text(label, style: const pw.TextStyle(fontSize: 7.5)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  static Future<pw.Widget> buildWidget(
    EtatCarrosserie etat, {
    double pdfWidth = 500,
    bool showLegend = true,
  }) async {
    final bytes = await loadBlueprintBytes();
    return buildWidgetFromBytes(
      bytes,
      etat,
      pdfWidth: pdfWidth,
      showLegend: showLegend,
    );
  }
}