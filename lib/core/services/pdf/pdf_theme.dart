// lib/core/services/pdf/pdf_theme.dart
//
// Helpers partagés par tous les générateurs PDF :
//   - Chargement des polices (Latin + Arabe)
//   - Conversion couleur hex → PdfColor
//   - Formateurs de date et de montant
//   - Wrapper de thème Latin/Arabe

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfTheme {
  PdfTheme._();

  // ── Formateurs ─────────────────────────────────────────────────────────────

  static final dateFmt     = DateFormat('dd/MM/yyyy', 'fr');
  static final dateLongFmt = DateFormat('d MMMM yyyy', 'fr');
  static final moneyFmt    = NumberFormat('#,###', 'fr');

  static String fmtDate(DateTime d)     => dateFmt.format(d);
  static String fmtDateLong(DateTime d) => dateLongFmt.format(d);
  static String fmtMoney(num m)         => '${moneyFmt.format(m)} DA';
  static String fmtKm(num km)           => '${moneyFmt.format(km)} km';
  static String shortId(String id)      =>
      id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  // ── Couleur hex → PdfColor ─────────────────────────────────────────────────

  static const PdfColor _defaultColor = PdfColor(0.10, 0.44, 0.83);

  static PdfColor hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return _defaultColor;
    final h = hex.replaceAll('#', '');
    if (h.length != 6) return _defaultColor;
    return PdfColor(
      int.parse(h.substring(0, 2), radix: 16) / 255,
      int.parse(h.substring(2, 4), radix: 16) / 255,
      int.parse(h.substring(4, 6), radix: 16) / 255,
    );
  }

  /// Couleur de fond claire à partir d'une PdfColor pleine.
  static PdfColor lightVariant(PdfColor c, {double alpha = 0.12}) =>
      PdfColor(c.red, c.green, c.blue, alpha);

  // ── Police Latin (Roboto) ──────────────────────────────────────────────────

  static pw.Font? _latinFont;
  static pw.Font? _latinFontBold;
  static bool     _latinLoaded = false;

  static Future<void> loadLatinFont() async {
    if (_latinLoaded) return;
    _latinLoaded = true;
    try {
      final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final bold    = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      _latinFont     = pw.Font.ttf(regular);
      _latinFontBold = pw.Font.ttf(bold);
    } catch (e) {
      // Roboto absent → Helvetica par défaut
      // ignore: avoid_print
      print('[PdfTheme] Police Latin non chargée : $e');
    }
  }

  // ── Police Arabe (Noto Naskh) ──────────────────────────────────────────────
  // IMPORTANT : la police DOIT être explicitement référencée dans chaque
  // TextStyle arabe. Le Theme seul ne suffit pas pour les scripts complexes
  // (arabe, hébreu) car le moteur de rendu PDF nécessite la font directement.

  static pw.Font? _arabicFont;
  static pw.Font? _arabicFontBold;
  static bool     _arabicLoaded = false;

  static Future<void> loadArabicFont() async {
    if (_arabicLoaded) return;
    _arabicLoaded = true;
    try {
      final regular = await rootBundle
          .load('assets/fonts/NotoNaskhArabic-Regular.ttf');
      _arabicFont = pw.Font.ttf(regular);
      // Essayer de charger la variante Bold si elle existe
      try {
        final bold = await rootBundle
            .load('assets/fonts/NotoNaskhArabic-Bold.ttf');
        _arabicFontBold = pw.Font.ttf(bold);
      } catch (_) {
        // Pas de variante Bold → utiliser Regular pour bold aussi
        _arabicFontBold = _arabicFont;
      }
    } catch (e) {
      // Police arabe absente → les textes arabes seront illisibles (tofu)
      // ignore: avoid_print
      print('[PdfTheme] Police Arabe non chargée : $e');
    }
  }

  static Future<void> loadAllFonts() =>
      Future.wait([loadLatinFont(), loadArabicFont()]);

  // ── Wrappers de thème ──────────────────────────────────────────────────────

  /// Enveloppe un widget dans le thème Latin si la police est chargée.
  static pw.Widget withLatinTheme(pw.Widget child) {
    if (_latinFont == null) return child;
    return pw.Theme(
      data: pw.ThemeData.withFont(
        base: _latinFont!,
        bold: _latinFontBold ?? _latinFont!,
      ),
      child: child,
    );
  }

  /// Enveloppe un widget dans le thème Arabe.
  /// NOTE: withArabicTheme injecte la font dans le Theme global, mais pour
  /// garantir le rendu correct des glyphes arabes, CHAQUE pw.Text arabe doit
  /// aussi utiliser arabicStyle() ou arText() qui référencent _arabicFont
  /// explicitement.
  static pw.Widget withArabicTheme(pw.Widget child) {
    if (_arabicFont == null) return child;
    return pw.Theme(
      data: pw.ThemeData.withFont(
        base: _arabicFont!,
        bold: _arabicFontBold ?? _arabicFont!,
      ),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: child,
      ),
    );
  }

  // ── Texte "intelligent" (contenu saisi par l'utilisateur) ─────────────────
  // Un client peut taper son nom/prénom/adresse en arabe MÊME sur un contrat
  // dont les libellés sont en français (et inversement). Un pw.Text() sans
  // police explicite hérite du Theme de la page (Latin OU Arabe seulement),
  // donc l'autre script s'affiche en glyphes manquants ("tofu") ou dans le
  // mauvais sens. smartText() détecte le script réel de la VALEUR et choisit
  // la bonne police + le bon sens d'écriture, indépendamment du Theme de la
  // page. À utiliser pour toute valeur saisie par l'utilisateur (nom, prénom,
  // adresse, notes...), jamais pour les libellés fixes.

  static final RegExp _arabicRegex =
      RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');

  static bool containsArabic(String text) => _arabicRegex.hasMatch(text);

  static pw.Widget smartText(
    String text, {
    double fontSize = 8,
    bool bold = false,
    PdfColor? color,
    pw.TextAlign? textAlign,
  }) {
    final isArabic = containsArabic(text);
    return pw.Text(
      text,
      style: pw.TextStyle(
        font: isArabic ? (bold ? (_arabicFontBold ?? _arabicFont) : _arabicFont) : null,
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : null,
        color: color,
      ),
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      textAlign: textAlign ?? (isArabic ? pw.TextAlign.right : pw.TextAlign.left),
    );
  }

  // ── Styles de texte Arabe ──────────────────────────────────────────────────
  // Ces méthodes DOIVENT être utilisées pour tout texte arabe dans les PDF.
  // Elles référencent explicitement _arabicFont pour garantir le rendu.

  static pw.TextStyle arabicStyle({
    double fontSize = 10,
    bool bold = false,
    PdfColor? color,
  }) =>
      pw.TextStyle(
        font:      bold ? (_arabicFontBold ?? _arabicFont) : _arabicFont,
        fontSize:  fontSize,
        color:     color,
      );

  static pw.TextStyle arabicStyleColored({
    double fontSize = 10,
    bool bold = false,
    required PdfColor color,
  }) =>
      pw.TextStyle(
        font:      bold ? (_arabicFontBold ?? _arabicFont) : _arabicFont,
        fontSize:  fontSize,
        color:     color,
      );

  /// Texte RTL avec police arabe — raccourci principal.
  /// À utiliser pour TOUS les textes arabes dans les générateurs PDF.
  static pw.Widget arText(
    String t, {
    double fontSize = 10,
    bool bold = false,
    PdfColor? color,
    pw.TextAlign textAlign = pw.TextAlign.right,
  }) =>
      pw.Text(
        t,
        style: arabicStyle(fontSize: fontSize, bold: bold, color: color),
        textDirection: pw.TextDirection.rtl,
        textAlign: textAlign,
      );

  /// Texte arabe centré.
  static pw.Widget arTextCenter(
    String t, {
    double fontSize = 10,
    bool bold = false,
    PdfColor? color,
  }) =>
      pw.Text(
        t,
        style: arabicStyle(fontSize: fontSize, bold: bold, color: color),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.center,
      );
}

// ignore: avoid_print
void debugPrint(String msg) => print(msg);