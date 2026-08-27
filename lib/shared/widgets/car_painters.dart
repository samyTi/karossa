// lib/shared/widgets/car_painters.dart
//
// 5 CustomPainters — berline 5 portes, style blueprint technique précis.
// Chaque pièce de carrosserie est un Path nommé, dessiné séparément,
// ce qui permet au widget de récupérer les bounding boxes et d'y placer
// des checkboxes aux 4 coins.

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE COMMUNE
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const stroke      = Color(0xFF1C2340);
  static const strokeMid   = Color(0xFF3D4870);
  static const strokeLight = Color(0xFF8890B8);
  static const body        = Color(0xFFF2F4FA);
  static const panel       = Color(0xFFE8ECF5);
  static const glass       = Color(0xFFCFDFF5);
  static const glassDeep   = Color(0xFFB8D0F0);
  static const wheel       = Color(0xFF252535);
  static const rim         = Color(0xFFAEB8D0);
  static const headlight   = Color(0xFFFFFAE0);
  static const taillight   = Color(0xFFFFCCCC);
  static const rocker      = Color(0xFFD8DFEE);
}

// ─────────────────────────────────────────────────────────────────────────────
// CLASSE DE BASE
// ─────────────────────────────────────────────────────────────────────────────

abstract class _BP extends CustomPainter {
  const _BP();

  Paint get main => Paint()
    ..color = _C.stroke..style = PaintingStyle.stroke
    ..strokeWidth = 1.5..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;

  Paint get mid => Paint()
    ..color = _C.strokeMid..style = PaintingStyle.stroke
    ..strokeWidth = 0.9..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;

  Paint get light => Paint()
    ..color = _C.strokeLight..style = PaintingStyle.stroke
    ..strokeWidth = 0.6..strokeCap = StrokeCap.round;

  Paint fill(Color c) => Paint()..color = c..style = PaintingStyle.fill;

  void rr(Canvas c, Rect r, double rx, Paint p) =>
      c.drawRRect(RRect.fromRectXY(r, rx, rx), p);

  void drawPiece(Canvas canvas, Path path, Color fillColor, {bool thin = false}) {
    canvas.drawPath(path, fill(fillColor));
    canvas.drawPath(path, thin ? mid : main);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ═════════════════════════════════════════════════════════════════════════════
// VUE PROFIL — gauche (mirrored=false) / droite (mirrored=true)
// Pièces : aile_av, porte_av, porte_ar, aile_ar, capot, coffre,
//          pare_brise, vitre_av, vitre_ar, toit, bas_caisse,
//          phare_av, feu_ar, retro, roues
// ═════════════════════════════════════════════════════════════════════════════

class CarSidePainter extends _BP {
  final bool mirrored;
  const CarSidePainter({this.mirrored = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (mirrored) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    _draw(canvas, size);
    if (mirrored) canvas.restore();
  }

  void _draw(Canvas canvas, Size sz) {
    final w = sz.width;
    final h = sz.height;

    // ── Silhouette complète (ombre portée légère) ────────────────────────
    final outline = _buildOutline(w, h);
    canvas.drawPath(outline, fill(const Color(0x18000000)));

    // ── BAS DE CAISSE ─────────────────────────────────────────────────────
    // Bande entre seuil de portes et bas de carrosserie
    final basGauche = Path()
      ..moveTo(w * 0.148, h * 0.790)
      ..lineTo(w * 0.880, h * 0.790)
      ..lineTo(w * 0.882, h * 0.820)
      ..lineTo(w * 0.148, h * 0.820)
      ..close();
    drawPiece(canvas, basGauche, _C.rocker, thin: true);

    // ── AILE AVANT ────────────────────────────────────────────────────────
    final aileAv = Path()
      ..moveTo(w * 0.088, h * 0.820) // bas roue av
      ..lineTo(w * 0.060, h * 0.820)
      ..quadraticBezierTo(w * 0.042, h * 0.810, w * 0.040, h * 0.770)
      ..lineTo(w * 0.040, h * 0.700)
      ..lineTo(w * 0.045, h * 0.650)
      ..lineTo(w * 0.055, h * 0.600)
      ..quadraticBezierTo(w * 0.068, h * 0.555, w * 0.082, h * 0.528)
      ..lineTo(w * 0.115, h * 0.468)
      ..lineTo(w * 0.148, h * 0.450)
      // haut aile (joint capot)
      ..lineTo(w * 0.192, h * 0.435)
      ..lineTo(w * 0.240, h * 0.418)
      // ligne de caisse
      ..lineTo(w * 0.280, h * 0.430)
      ..lineTo(w * 0.300, h * 0.490)
      // seuil
      ..lineTo(w * 0.300, h * 0.790)
      ..lineTo(w * 0.148, h * 0.790)
      // arche roue avant
      ..quadraticBezierTo(w * 0.098, h * 0.790, w * 0.088, h * 0.820)
      ..close();
    drawPiece(canvas, aileAv, _C.panel);

    // ── PORTE AVANT ───────────────────────────────────────────────────────
    final porteAv = Path()
      ..moveTo(w * 0.305, h * 0.480)
      ..lineTo(w * 0.305, h * 0.790)
      ..lineTo(w * 0.505, h * 0.790)
      ..lineTo(w * 0.505, h * 0.510)
      // ligne de ceinture
      ..lineTo(w * 0.505, h * 0.450)
      ..lineTo(w * 0.350, h * 0.440)
      ..lineTo(w * 0.310, h * 0.455)
      ..close();
    drawPiece(canvas, porteAv, _C.panel);

    // ── PORTE ARRIÈRE ─────────────────────────────────────────────────────
    final porteAr = Path()
      ..moveTo(w * 0.510, h * 0.445)
      ..lineTo(w * 0.510, h * 0.790)
      ..lineTo(w * 0.695, h * 0.790)
      ..lineTo(w * 0.695, h * 0.480)
      ..lineTo(w * 0.695, h * 0.440)
      ..lineTo(w * 0.510, h * 0.445)
      ..close();
    drawPiece(canvas, porteAr, _C.panel);

    // ── AILE ARRIÈRE ──────────────────────────────────────────────────────
    final aileAr = Path()
      ..moveTo(w * 0.700, h * 0.435)
      ..lineTo(w * 0.700, h * 0.790)
      ..lineTo(w * 0.830, h * 0.790) // avant arche ar
      // arche roue arrière
      ..quadraticBezierTo(w * 0.912, h * 0.790, w * 0.922, h * 0.820)
      ..lineTo(w * 0.938, h * 0.820)
      ..quadraticBezierTo(w * 0.948, h * 0.780, w * 0.948, h * 0.740)
      ..lineTo(w * 0.948, h * 0.650)
      ..lineTo(w * 0.944, h * 0.560)
      ..lineTo(w * 0.938, h * 0.500)
      // jonction feu arrière / hayon
      ..lineTo(w * 0.924, h * 0.455)
      ..lineTo(w * 0.906, h * 0.430)
      ..lineTo(w * 0.865, h * 0.420)
      ..lineTo(w * 0.780, h * 0.422)
      ..lineTo(w * 0.740, h * 0.430)
      ..close();
    drawPiece(canvas, aileAr, _C.panel);

    // ── CAPOT ─────────────────────────────────────────────────────────────
    final capot = Path()
      ..moveTo(w * 0.085, h * 0.528)
      ..lineTo(w * 0.118, h * 0.468)
      ..lineTo(w * 0.152, h * 0.448)
      ..lineTo(w * 0.195, h * 0.430)
      ..lineTo(w * 0.245, h * 0.412)
      ..lineTo(w * 0.300, h * 0.402)
      // bord capot côté pare-brise
      ..lineTo(w * 0.318, h * 0.380)
      ..lineTo(w * 0.332, h * 0.358)
      ..lineTo(w * 0.342, h * 0.338)
      // milieu capot (bossage central)
      ..lineTo(w * 0.280, h * 0.370)
      ..lineTo(w * 0.245, h * 0.395)
      ..lineTo(w * 0.200, h * 0.408)
      ..lineTo(w * 0.155, h * 0.435)
      ..lineTo(w * 0.118, h * 0.458)
      ..lineTo(w * 0.090, h * 0.510)
      ..close();
    drawPiece(canvas, capot, _C.body);
    // Nervures capot
    canvas.drawLine(Offset(w * 0.150, h * 0.443), Offset(w * 0.285, h * 0.375), light);
    canvas.drawLine(Offset(w * 0.172, h * 0.433), Offset(w * 0.295, h * 0.382), light);

    // ── COFFRE / HAYON ────────────────────────────────────────────────────
    final coffre = Path()
      ..moveTo(w * 0.770, h * 0.428)
      ..lineTo(w * 0.820, h * 0.420)
      ..lineTo(w * 0.868, h * 0.418)
      ..lineTo(w * 0.908, h * 0.428)
      ..lineTo(w * 0.926, h * 0.452)
      ..lineTo(w * 0.940, h * 0.495)
      // ligne hayon
      ..lineTo(w * 0.945, h * 0.560)
      ..lineTo(w * 0.938, h * 0.490) // retour
      ..close();
    // Ligne de hayon (séparation coffre/carrosserie)
    final ligneHayon = Path()
      ..moveTo(w * 0.770, h * 0.428)
      ..lineTo(w * 0.770, h * 0.790);
    canvas.drawPath(ligneHayon, mid);

    // ── PARE-BRISE ────────────────────────────────────────────────────────
    final pareBrise = Path()
      ..moveTo(w * 0.345, h * 0.338)
      ..lineTo(w * 0.360, h * 0.310)
      ..lineTo(w * 0.385, h * 0.275)
      ..quadraticBezierTo(w * 0.405, h * 0.248, w * 0.430, h * 0.230)
      ..lineTo(w * 0.468, h * 0.215)
      ..lineTo(w * 0.505, h * 0.210)
      ..lineTo(w * 0.505, h * 0.342)
      ..quadraticBezierTo(w * 0.440, h * 0.350, w * 0.380, h * 0.355)
      ..close();
    drawPiece(canvas, pareBrise, _C.glassDeep, thin: true);

    // ── VITRE AVANT LATÉRALE ──────────────────────────────────────────────
    final vitreAv = Path()
      ..moveTo(w * 0.310, h * 0.460)
      ..lineTo(w * 0.310, h * 0.490)
      ..lineTo(w * 0.310, h * 0.510)
      ..lineTo(w * 0.500, h * 0.455)
      ..lineTo(w * 0.500, h * 0.346)
      ..lineTo(w * 0.468, h * 0.346)
      ..quadraticBezierTo(w * 0.395, h * 0.352, w * 0.348, h * 0.360)
      ..lineTo(w * 0.320, h * 0.380)
      ..close();
    drawPiece(canvas, vitreAv, _C.glass, thin: true);

    // ── VITRE ARRIÈRE LATÉRALE ────────────────────────────────────────────
    final vitreAr = Path()
      ..moveTo(w * 0.508, h * 0.346)
      ..lineTo(w * 0.508, h * 0.452)
      ..lineTo(w * 0.508, h * 0.510)
      ..lineTo(w * 0.690, h * 0.455)
      ..lineTo(w * 0.690, h * 0.348)
      ..lineTo(w * 0.652, h * 0.342)
      ..lineTo(w * 0.560, h * 0.338)
      ..close();
    drawPiece(canvas, vitreAr, _C.glass, thin: true);

    // Petite vitre de custode (derrière porte arrière)
    final custode = Path()
      ..moveTo(w * 0.698, h * 0.344)
      ..lineTo(w * 0.698, h * 0.452)
      ..lineTo(w * 0.762, h * 0.445)
      ..lineTo(w * 0.782, h * 0.440)
      ..lineTo(w * 0.795, h * 0.435)
      ..lineTo(w * 0.798, h * 0.344)
      ..close();
    drawPiece(canvas, custode, _C.glass, thin: true);

    // ── TOIT ──────────────────────────────────────────────────────────────
    final toit = Path()
      ..moveTo(w * 0.430, h * 0.225)
      ..lineTo(w * 0.468, h * 0.212)
      ..lineTo(w * 0.510, h * 0.207)
      ..lineTo(w * 0.650, h * 0.210)
      ..lineTo(w * 0.700, h * 0.218)
      ..lineTo(w * 0.750, h * 0.228)
      // montant C
      ..lineTo(w * 0.796, h * 0.245)
      ..lineTo(w * 0.808, h * 0.268)
      ..lineTo(w * 0.808, h * 0.340)
      // bord bas toit
      ..lineTo(w * 0.800, h * 0.342)
      ..lineTo(w * 0.700, h * 0.340)
      ..lineTo(w * 0.510, h * 0.338)
      ..lineTo(w * 0.430, h * 0.338)
      // montant A
      ..lineTo(w * 0.395, h * 0.330)
      ..lineTo(w * 0.380, h * 0.310)
      ..lineTo(w * 0.388, h * 0.268)
      ..lineTo(w * 0.408, h * 0.242)
      ..close();
    drawPiece(canvas, toit, _C.body);

    // ── PHARE AVANT ───────────────────────────────────────────────────────
    final phareAv = Path()
      ..moveTo(w * 0.060, h * 0.542)
      ..lineTo(w * 0.060, h * 0.612)
      ..quadraticBezierTo(w * 0.062, h * 0.635, w * 0.080, h * 0.640)
      ..lineTo(w * 0.154, h * 0.628)
      ..lineTo(w * 0.160, h * 0.542)
      ..close();
    drawPiece(canvas, phareAv, _C.headlight, thin: true);
    // DRL
    canvas.drawLine(Offset(w * 0.074, h * 0.568), Offset(w * 0.156, h * 0.564), light);
    canvas.drawLine(Offset(w * 0.074, h * 0.582), Offset(w * 0.156, h * 0.578), light);

    // ── FEU ARRIÈRE ───────────────────────────────────────────────────────
    final feuAr = Path()
      ..moveTo(w * 0.898, h * 0.445)
      ..lineTo(w * 0.935, h * 0.450)
      ..lineTo(w * 0.945, h * 0.565)
      ..lineTo(w * 0.945, h * 0.695)
      ..quadraticBezierTo(w * 0.936, h * 0.718, w * 0.910, h * 0.722)
      ..lineTo(w * 0.898, h * 0.700)
      ..close();
    drawPiece(canvas, feuAr, _C.taillight, thin: true);
    canvas.drawLine(Offset(w * 0.900, h * 0.582), Offset(w * 0.944, h * 0.580), light);

    // ── RÉTROVISEUR ───────────────────────────────────────────────────────
    final retro = Path()
      ..moveTo(w * 0.295, h * 0.400)
      ..lineTo(w * 0.272, h * 0.392)
      ..quadraticBezierTo(w * 0.256, h * 0.394, w * 0.250, h * 0.412)
      ..lineTo(w * 0.260, h * 0.428)
      ..lineTo(w * 0.295, h * 0.422)
      ..close();
    drawPiece(canvas, retro, _C.panel, thin: true);

    // ── POIGNÉES DE PORTES ────────────────────────────────────────────────
    rr(canvas, Rect.fromLTWH(w * 0.358, h * 0.548, w * 0.082, h * 0.036), 3.0, mid);
    rr(canvas, Rect.fromLTWH(w * 0.558, h * 0.548, w * 0.078, h * 0.036), 3.0, mid);

    // ── MONTANTS ──────────────────────────────────────────────────────────
    // Montant B
    canvas.drawLine(Offset(w * 0.505, h * 0.338), Offset(w * 0.505, h * 0.790), mid);
    // Montant C
    canvas.drawLine(Offset(w * 0.695, h * 0.340), Offset(w * 0.695, h * 0.790), mid);
    // Ligne de ceinture
    canvas.drawLine(Offset(w * 0.100, h * 0.530), Offset(w * 0.940, h * 0.532), light);

    // ── PASSAGES DE ROUES ─────────────────────────────────────────────────
    final archAv = Path();
    archAv.addArc(
        Rect.fromCenter(center: Offset(w * 0.198, h * 0.830), width: w * 0.195, height: w * 0.195),
        math.pi, math.pi);
    canvas.drawPath(archAv, mid);

    final archAr = Path();
    archAr.addArc(
        Rect.fromCenter(center: Offset(w * 0.800, h * 0.830), width: w * 0.195, height: w * 0.195),
        math.pi, math.pi);
    canvas.drawPath(archAr, mid);

    // ── ROUES ─────────────────────────────────────────────────────────────
    _wheel(canvas, Offset(w * 0.198, h * 0.884), w * 0.090, w * 0.048);
    _wheel(canvas, Offset(w * 0.800, h * 0.884), w * 0.090, w * 0.048);
  }

  Path _buildOutline(double w, double h) {
    final p = Path()
      ..moveTo(w * 0.088, h * 0.820)
      ..lineTo(w * 0.058, h * 0.820)
      ..quadraticBezierTo(w * 0.038, h * 0.810, w * 0.038, h * 0.770)
      ..lineTo(w * 0.038, h * 0.680)
      ..lineTo(w * 0.048, h * 0.618)
      ..lineTo(w * 0.058, h * 0.570)
      ..quadraticBezierTo(w * 0.075, h * 0.530, w * 0.090, h * 0.508)
      ..lineTo(w * 0.120, h * 0.462)
      ..lineTo(w * 0.155, h * 0.440)
      ..lineTo(w * 0.200, h * 0.422)
      ..lineTo(w * 0.250, h * 0.408)
      ..lineTo(w * 0.308, h * 0.396)
      ..lineTo(w * 0.345, h * 0.360)
      ..lineTo(w * 0.368, h * 0.320)
      ..lineTo(w * 0.385, h * 0.278)
      ..quadraticBezierTo(w * 0.405, h * 0.248, w * 0.432, h * 0.228)
      ..lineTo(w * 0.472, h * 0.212)
      ..lineTo(w * 0.518, h * 0.206)
      ..lineTo(w * 0.660, h * 0.208)
      ..lineTo(w * 0.712, h * 0.218)
      ..lineTo(w * 0.762, h * 0.232)
      ..lineTo(w * 0.800, h * 0.248)
      ..lineTo(w * 0.818, h * 0.270)
      ..lineTo(w * 0.820, h * 0.340)
      ..lineTo(w * 0.812, h * 0.348)
      ..lineTo(w * 0.800, h * 0.350)
      ..lineTo(w * 0.800, h * 0.422)
      ..lineTo(w * 0.840, h * 0.420)
      ..lineTo(w * 0.880, h * 0.420)
      ..lineTo(w * 0.918, h * 0.432)
      ..lineTo(w * 0.938, h * 0.452)
      ..lineTo(w * 0.948, h * 0.495)
      ..lineTo(w * 0.952, h * 0.558)
      ..lineTo(w * 0.950, h * 0.650)
      ..lineTo(w * 0.948, h * 0.740)
      ..quadraticBezierTo(w * 0.946, h * 0.785, w * 0.940, h * 0.820)
      ..lineTo(w * 0.910, h * 0.820)
      ..lineTo(w * 0.820, h * 0.820)
      ..lineTo(w * 0.148, h * 0.820)
      ..lineTo(w * 0.088, h * 0.820)
      ..close();
    return p;
  }

  void _wheel(Canvas canvas, Offset c, double outer, double rim) {
    canvas.drawCircle(c, outer, Paint()..color = _C.wheel..style = PaintingStyle.fill);
    canvas.drawCircle(c, outer * 0.82, Paint()..color = const Color(0xFFEEEEF5)..style = PaintingStyle.fill);
    canvas.drawCircle(c, rim * 1.22, Paint()..color = _C.rim..style = PaintingStyle.fill);
    canvas.drawCircle(c, rim * 0.30, Paint()..color = _C.wheel..style = PaintingStyle.fill);
    for (int i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5 - math.pi / 2;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * rim * 0.33, c.dy + math.sin(a) * rim * 0.33),
        Offset(c.dx + math.cos(a) * rim * 1.20, c.dy + math.sin(a) * rim * 1.20),
        Paint()..color = _C.strokeMid..strokeWidth = 1.0,
      );
    }
    canvas.drawCircle(c, outer, Paint()..color = _C.stroke..style = PaintingStyle.stroke..strokeWidth = 1.4);
    canvas.drawCircle(c, outer * 0.82, Paint()..color = _C.strokeMid..style = PaintingStyle.stroke..strokeWidth = 0.6);
    canvas.drawCircle(c, rim * 1.22, Paint()..color = _C.strokeMid..style = PaintingStyle.stroke..strokeWidth = 0.8);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VUE DESSUS
// Pièces : capot, toit, coffre, aile_av_g, aile_av_d, aile_ar_g, aile_ar_d,
//          porte_av_g, porte_av_d, porte_ar_g, porte_ar_d,
//          pare_brise, lunette, phares, feux, roues
// ═════════════════════════════════════════════════════════════════════════════

class CarTopPainter extends _BP {
  const CarTopPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── CARROSSERIE GLOBALE (fond) ─────────────────────────────────────────
    final car = Path()
      ..moveTo(w * 0.38, h * 0.018)
      ..quadraticBezierTo(w * 0.50, h * 0.006, w * 0.62, h * 0.018)
      ..lineTo(w * 0.74, h * 0.044)
      ..lineTo(w * 0.84, h * 0.092)
      ..lineTo(w * 0.895, h * 0.158)
      ..lineTo(w * 0.918, h * 0.252)
      ..lineTo(w * 0.928, h * 0.400)
      ..lineTo(w * 0.928, h * 0.600)
      ..lineTo(w * 0.918, h * 0.748)
      ..lineTo(w * 0.895, h * 0.842)
      ..lineTo(w * 0.840, h * 0.908)
      ..quadraticBezierTo(w * 0.50, h * 0.995, w * 0.160, h * 0.908)
      ..lineTo(w * 0.105, h * 0.842)
      ..lineTo(w * 0.082, h * 0.748)
      ..lineTo(w * 0.072, h * 0.600)
      ..lineTo(w * 0.072, h * 0.400)
      ..lineTo(w * 0.082, h * 0.252)
      ..lineTo(w * 0.105, h * 0.158)
      ..lineTo(w * 0.160, h * 0.092)
      ..lineTo(w * 0.260, h * 0.044)
      ..close();
    canvas.drawPath(car, fill(_C.body));
    canvas.drawPath(car, main);

    // ── CAPOT ─────────────────────────────────────────────────────────────
    final capot = Path()
      ..moveTo(w * 0.270, h * 0.048)
      ..lineTo(w * 0.730, h * 0.048)
      ..lineTo(w * 0.815, h * 0.148)
      ..lineTo(w * 0.845, h * 0.238)
      ..lineTo(w * 0.155, h * 0.238)
      ..lineTo(w * 0.185, h * 0.148)
      ..close();
    drawPiece(canvas, capot, _C.panel);
    // Nervures capot
    canvas.drawLine(Offset(w * 0.375, h * 0.052), Offset(w * 0.270, h * 0.235), light);
    canvas.drawLine(Offset(w * 0.500, h * 0.050), Offset(w * 0.500, h * 0.237), light);
    canvas.drawLine(Offset(w * 0.625, h * 0.052), Offset(w * 0.730, h * 0.235), light);

    // ── PHARES AVANT ──────────────────────────────────────────────────────
    rr(canvas, Rect.fromLTWH(w * 0.108, h * 0.032, w * 0.145, h * 0.072), 4.0, fill(_C.headlight));
    rr(canvas, Rect.fromLTWH(w * 0.747, h * 0.032, w * 0.145, h * 0.072), 4.0, fill(_C.headlight));
    rr(canvas, Rect.fromLTWH(w * 0.108, h * 0.032, w * 0.145, h * 0.072), 4.0, mid);
    rr(canvas, Rect.fromLTWH(w * 0.747, h * 0.032, w * 0.145, h * 0.072), 4.0, mid);

    // ── PARE-BRISE AVANT ──────────────────────────────────────────────────
    final pareBrise = Path()
      ..moveTo(w * 0.162, h * 0.240)
      ..lineTo(w * 0.838, h * 0.240)
      ..lineTo(w * 0.840, h * 0.322)
      ..lineTo(w * 0.160, h * 0.322)
      ..close();
    drawPiece(canvas, pareBrise, _C.glassDeep, thin: true);
    // Essuie-glaces
    canvas.drawLine(Offset(w * 0.315, h * 0.262), Offset(w * 0.508, h * 0.308), light);
    canvas.drawLine(Offset(w * 0.508, h * 0.262), Offset(w * 0.710, h * 0.308), light);

    // ── AILES AVANT ───────────────────────────────────────────────────────
    final aileAvG = Path()
      ..moveTo(w * 0.080, h * 0.158)
      ..lineTo(w * 0.158, h * 0.095)
      ..lineTo(w * 0.268, h * 0.048)
      ..lineTo(w * 0.268, h * 0.240)
      ..lineTo(w * 0.158, h * 0.240)
      ..close();
    drawPiece(canvas, aileAvG, _C.panel);

    final aileAvD = Path()
      ..moveTo(w * 0.920, h * 0.158)
      ..lineTo(w * 0.842, h * 0.095)
      ..lineTo(w * 0.732, h * 0.048)
      ..lineTo(w * 0.732, h * 0.240)
      ..lineTo(w * 0.842, h * 0.240)
      ..close();
    drawPiece(canvas, aileAvD, _C.panel);

    // ── PORTIÈRES AVANT (G et D) ──────────────────────────────────────────
    final porteAvG = Path()
      ..moveTo(w * 0.072, h * 0.254)
      ..lineTo(w * 0.158, h * 0.254)
      ..lineTo(w * 0.158, h * 0.472)
      ..lineTo(w * 0.072, h * 0.472)
      ..close();
    drawPiece(canvas, porteAvG, _C.panel);

    final porteAvD = Path()
      ..moveTo(w * 0.928, h * 0.254)
      ..lineTo(w * 0.842, h * 0.254)
      ..lineTo(w * 0.842, h * 0.472)
      ..lineTo(w * 0.928, h * 0.472)
      ..close();
    drawPiece(canvas, porteAvD, _C.panel);

    // ── TOIT / HABITACLE ─────────────────────────────────────────────────
    final toit = Path()
      ..moveTo(w * 0.162, h * 0.324)
      ..lineTo(w * 0.838, h * 0.324)
      ..lineTo(w * 0.838, h * 0.676)
      ..lineTo(w * 0.162, h * 0.676)
      ..close();
    drawPiece(canvas, toit, const Color(0xFFD4E2F8), thin: true);
    // Montant B
    rr(canvas, Rect.fromLTWH(w * 0.155, h * 0.465, w * 0.690, h * 0.060), 0, fill(const Color(0xFFC2D0E8)));
    rr(canvas, Rect.fromLTWH(w * 0.155, h * 0.465, w * 0.690, h * 0.060), 0, light);
    // Appuie-têtes
    _headrest(canvas, w * 0.252, h * 0.332, w * 0.162, h * 0.076);
    _headrest(canvas, w * 0.586, h * 0.332, w * 0.162, h * 0.076);
    _headrest(canvas, w * 0.252, h * 0.528, w * 0.162, h * 0.076);
    _headrest(canvas, w * 0.586, h * 0.528, w * 0.162, h * 0.076);
    // Antenne
    canvas.drawLine(Offset(w * 0.500, h * 0.325), Offset(w * 0.500, h * 0.260), light);
    canvas.drawCircle(Offset(w * 0.500, h * 0.256), 2.5, light);

    // ── PORTIÈRES ARRIÈRE (G et D) ────────────────────────────────────────
    final porteArG = Path()
      ..moveTo(w * 0.072, h * 0.528)
      ..lineTo(w * 0.158, h * 0.528)
      ..lineTo(w * 0.158, h * 0.746)
      ..lineTo(w * 0.072, h * 0.746)
      ..close();
    drawPiece(canvas, porteArG, _C.panel);

    final porteArD = Path()
      ..moveTo(w * 0.928, h * 0.528)
      ..lineTo(w * 0.842, h * 0.528)
      ..lineTo(w * 0.842, h * 0.746)
      ..lineTo(w * 0.928, h * 0.746)
      ..close();
    drawPiece(canvas, porteArD, _C.panel);

    // ── LUNETTE ARRIÈRE ───────────────────────────────────────────────────
    final lunette = Path()
      ..moveTo(w * 0.168, h * 0.678)
      ..lineTo(w * 0.832, h * 0.678)
      ..lineTo(w * 0.832, h * 0.758)
      ..lineTo(w * 0.168, h * 0.758)
      ..close();
    drawPiece(canvas, lunette, _C.glassDeep, thin: true);

    // ── AILES ARRIÈRE ─────────────────────────────────────────────────────
    final aileArG = Path()
      ..moveTo(w * 0.072, h * 0.748)
      ..lineTo(w * 0.158, h * 0.748)
      ..lineTo(w * 0.158, h * 0.910)
      ..lineTo(w * 0.105, h * 0.842)
      ..close();
    drawPiece(canvas, aileArG, _C.panel);

    final aileArD = Path()
      ..moveTo(w * 0.928, h * 0.748)
      ..lineTo(w * 0.842, h * 0.748)
      ..lineTo(w * 0.842, h * 0.910)
      ..lineTo(w * 0.895, h * 0.842)
      ..close();
    drawPiece(canvas, aileArD, _C.panel);

    // ── COFFRE / HAYON ────────────────────────────────────────────────────
    final coffre = Path()
      ..moveTo(w * 0.162, h * 0.760)
      ..lineTo(w * 0.838, h * 0.760)
      ..lineTo(w * 0.840, h * 0.852)
      ..lineTo(w * 0.810, h * 0.948)
      ..lineTo(w * 0.190, h * 0.948)
      ..lineTo(w * 0.160, h * 0.852)
      ..close();
    drawPiece(canvas, coffre, _C.panel);
    canvas.drawLine(Offset(w * 0.310, h * 0.948), Offset(w * 0.272, h * 0.760), light);
    canvas.drawLine(Offset(w * 0.690, h * 0.948), Offset(w * 0.728, h * 0.760), light);

    // ── FEUX ARRIÈRE ──────────────────────────────────────────────────────
    rr(canvas, Rect.fromLTWH(w * 0.108, h * 0.870, w * 0.148, h * 0.078), 4.0, fill(_C.taillight));
    rr(canvas, Rect.fromLTWH(w * 0.744, h * 0.870, w * 0.148, h * 0.078), 4.0, fill(_C.taillight));
    rr(canvas, Rect.fromLTWH(w * 0.108, h * 0.870, w * 0.148, h * 0.078), 4.0, mid);
    rr(canvas, Rect.fromLTWH(w * 0.744, h * 0.870, w * 0.148, h * 0.078), 4.0, mid);

    // ── ROUES ─────────────────────────────────────────────────────────────
    _wTop(canvas, w * 0.008, h * 0.122, w * 0.102, h * 0.138);
    _wTop(canvas, w * 0.890, h * 0.122, w * 0.102, h * 0.138);
    _wTop(canvas, w * 0.008, h * 0.740, w * 0.102, h * 0.138);
    _wTop(canvas, w * 0.890, h * 0.740, w * 0.102, h * 0.138);

    // Séparation portières (ligne montant B)
    canvas.drawLine(Offset(w * 0.160, h * 0.472), Offset(w * 0.840, h * 0.472), light);
    canvas.drawLine(Offset(w * 0.160, h * 0.528), Offset(w * 0.840, h * 0.528), light);
  }

  void _headrest(Canvas canvas, double l, double t, double ww, double hh) {
    rr(canvas, Rect.fromLTWH(l, t, ww, hh), 4.0, fill(const Color(0xFFBACBE4)));
    rr(canvas, Rect.fromLTWH(l, t, ww, hh), 4.0, light);
  }

  void _wTop(Canvas canvas, double l, double t, double ww, double hh) {
    rr(canvas, Rect.fromLTWH(l, t, ww, hh), 5.0, Paint()..color = _C.wheel..style = PaintingStyle.fill);
    rr(canvas, Rect.fromLTWH(l + ww * 0.18, t + hh * 0.18, ww * 0.64, hh * 0.64), 4.0, fill(_C.rim));
    rr(canvas, Rect.fromLTWH(l, t, ww, hh), 5.0, Paint()..color = _C.stroke..style = PaintingStyle.stroke..strokeWidth = 1.3);
    rr(canvas, Rect.fromLTWH(l + ww * 0.18, t + hh * 0.18, ww * 0.64, hh * 0.64), 4.0, Paint()..color = _C.strokeMid..style = PaintingStyle.stroke..strokeWidth = 0.6);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VUE AVANT
// Pièces : pare_choc_av, capot, calandre, phare_g, phare_d, pare_brise,
//          aile_g, aile_d, retro_g, retro_d, roues
// ═════════════════════════════════════════════════════════════════════════════

class CarFrontPainter extends _BP {
  const CarFrontPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── SILHOUETTE (fond) ─────────────────────────────────────────────────
    final sil = Path()
      ..moveTo(w * 0.072, h * 0.942)
      ..lineTo(w * 0.040, h * 0.875)
      ..lineTo(w * 0.026, h * 0.775)
      ..lineTo(w * 0.030, h * 0.658)
      ..lineTo(w * 0.056, h * 0.558)
      ..quadraticBezierTo(w * 0.095, h * 0.490, w * 0.138, h * 0.455)
      ..lineTo(w * 0.188, h * 0.415)
      ..lineTo(w * 0.228, h * 0.355)
      ..lineTo(w * 0.268, h * 0.285)
      ..quadraticBezierTo(w * 0.308, h * 0.225, w * 0.355, h * 0.190)
      ..quadraticBezierTo(w * 0.402, h * 0.158, w * 0.450, h * 0.142)
      ..lineTo(w * 0.500, h * 0.132)
      ..lineTo(w * 0.550, h * 0.142)
      ..quadraticBezierTo(w * 0.598, h * 0.158, w * 0.645, h * 0.190)
      ..quadraticBezierTo(w * 0.692, h * 0.225, w * 0.732, h * 0.285)
      ..lineTo(w * 0.772, h * 0.355)
      ..lineTo(w * 0.812, h * 0.415)
      ..quadraticBezierTo(w * 0.856, h * 0.455, w * 0.898, h * 0.500)
      ..lineTo(w * 0.930, h * 0.580)
      ..lineTo(w * 0.958, h * 0.680)
      ..lineTo(w * 0.968, h * 0.792)
      ..lineTo(w * 0.942, h * 0.880)
      ..lineTo(w * 0.928, h * 0.942)
      ..close();
    canvas.drawPath(sil, fill(_C.body));
    canvas.drawPath(sil, main);

    // ── AILE GAUCHE ───────────────────────────────────────────────────────
    final aileG = Path()
      ..moveTo(w * 0.056, h * 0.558)
      ..quadraticBezierTo(w * 0.095, h * 0.490, w * 0.138, h * 0.455)
      ..lineTo(w * 0.188, h * 0.415)
      ..lineTo(w * 0.228, h * 0.355)
      ..lineTo(w * 0.268, h * 0.285)
      ..lineTo(w * 0.305, h * 0.290)
      ..lineTo(w * 0.305, h * 0.462)
      // bas aile (seuil)
      ..lineTo(w * 0.070, h * 0.940)
      ..lineTo(w * 0.040, h * 0.875)
      ..lineTo(w * 0.026, h * 0.775)
      ..lineTo(w * 0.030, h * 0.658)
      ..close();
    drawPiece(canvas, aileG, _C.panel);

    // ── AILE DROITE ───────────────────────────────────────────────────────
    final aileD = Path()
      ..moveTo(w * 0.944, h * 0.558)
      ..quadraticBezierTo(w * 0.905, h * 0.490, w * 0.862, h * 0.455)
      ..lineTo(w * 0.812, h * 0.415)
      ..lineTo(w * 0.772, h * 0.355)
      ..lineTo(w * 0.732, h * 0.285)
      ..lineTo(w * 0.695, h * 0.290)
      ..lineTo(w * 0.695, h * 0.462)
      ..lineTo(w * 0.930, h * 0.940)
      ..lineTo(w * 0.960, h * 0.875)
      ..lineTo(w * 0.972, h * 0.775)
      ..lineTo(w * 0.968, h * 0.658)
      ..close();
    drawPiece(canvas, aileD, _C.panel);

    // ── PARE-BRISE ────────────────────────────────────────────────────────
    final pb = Path()
      ..moveTo(w * 0.308, h * 0.285)
      ..lineTo(w * 0.358, h * 0.202)
      ..quadraticBezierTo(w * 0.415, h * 0.145, w * 0.500, h * 0.135)
      ..quadraticBezierTo(w * 0.585, h * 0.145, w * 0.642, h * 0.202)
      ..lineTo(w * 0.692, h * 0.285)
      ..lineTo(w * 0.698, h * 0.448)
      ..quadraticBezierTo(w * 0.590, h * 0.462, w * 0.500, h * 0.462)
      ..quadraticBezierTo(w * 0.410, h * 0.462, w * 0.302, h * 0.448)
      ..close();
    drawPiece(canvas, pb, _C.glassDeep, thin: true);

    // ── CAPOT ─────────────────────────────────────────────────────────────
    canvas.drawLine(Offset(w * 0.252, h * 0.462), Offset(w * 0.748, h * 0.462), mid);
    canvas.drawLine(Offset(w * 0.218, h * 0.508), Offset(w * 0.782, h * 0.508), light);
    canvas.drawLine(Offset(w * 0.500, h * 0.462), Offset(w * 0.500, h * 0.588), light);

    // ── PHARE GAUCHE ──────────────────────────────────────────────────────
    final phareG = Path()
      ..moveTo(w * 0.080, h * 0.518)
      ..lineTo(w * 0.082, h * 0.518)
      ..lineTo(w * 0.080, h * 0.520)
      ..lineTo(w * 0.292, h * 0.520)
      ..lineTo(w * 0.302, h * 0.462)
      ..lineTo(w * 0.268, h * 0.432)
      ..lineTo(w * 0.225, h * 0.418)
      ..lineTo(w * 0.176, h * 0.418)
      ..lineTo(w * 0.138, h * 0.455)
      ..lineTo(w * 0.098, h * 0.490)
      ..close();
    drawPiece(canvas, phareG, _C.headlight, thin: true);
    canvas.drawLine(Offset(w * 0.090, h * 0.490), Offset(w * 0.290, h * 0.485), light);

    // ── PHARE DROIT ───────────────────────────────────────────────────────
    final phareD = Path()
      ..moveTo(w * 0.920, h * 0.518)
      ..lineTo(w * 0.708, h * 0.518)
      ..lineTo(w * 0.698, h * 0.462)
      ..lineTo(w * 0.732, h * 0.432)
      ..lineTo(w * 0.775, h * 0.418)
      ..lineTo(w * 0.824, h * 0.418)
      ..lineTo(w * 0.862, h * 0.455)
      ..lineTo(w * 0.902, h * 0.490)
      ..close();
    drawPiece(canvas, phareD, _C.headlight, thin: true);
    canvas.drawLine(Offset(w * 0.710, h * 0.485), Offset(w * 0.910, h * 0.490), light);

    // ── CALANDRE ──────────────────────────────────────────────────────────
    final calandre = Path()
      ..moveTo(w * 0.270, h * 0.688)
      ..lineTo(w * 0.730, h * 0.688)
      ..lineTo(w * 0.752, h * 0.805)
      ..lineTo(w * 0.248, h * 0.805)
      ..close();
    drawPiece(canvas, calandre, _C.panel, thin: true);
    for (int i = 1; i <= 5; i++) {
      final x = 0.270 + i * (0.460 / 6);
      canvas.drawLine(Offset(w * x, h * 0.688), Offset(w * (x + 0.006), h * 0.805), light);
    }
    canvas.drawLine(Offset(w * 0.270, h * 0.724), Offset(w * 0.730, h * 0.726), light);
    canvas.drawLine(Offset(w * 0.248, h * 0.765), Offset(w * 0.752, h * 0.767), light);
    canvas.drawCircle(Offset(w * 0.500, h * 0.635), w * 0.032, fill(const Color(0xFFCDD5E8)));
    canvas.drawCircle(Offset(w * 0.500, h * 0.635), w * 0.032, light);

    // ── PARE-CHOC AVANT ───────────────────────────────────────────────────
    final pareChocAv = Path()
      ..moveTo(w * 0.068, h * 0.852)
      ..lineTo(w * 0.932, h * 0.852)
      ..lineTo(w * 0.950, h * 0.910)
      ..quadraticBezierTo(w * 0.500, h * 0.968, w * 0.050, h * 0.910)
      ..close();
    drawPiece(canvas, pareChocAv, _C.panel, thin: true);
    // Plaque
    rr(canvas, Rect.fromLTWH(w * 0.362, h * 0.858, w * 0.276, h * 0.044), 2.0, fill(const Color(0xFFF5F5DC)));
    rr(canvas, Rect.fromLTWH(w * 0.362, h * 0.858, w * 0.276, h * 0.044), 2.0, light);
    // Antibrouillards
    rr(canvas, Rect.fromLTWH(w * 0.100, h * 0.868, w * 0.118, h * 0.040), 3.0, fill(_C.headlight));
    rr(canvas, Rect.fromLTWH(w * 0.782, h * 0.868, w * 0.118, h * 0.040), 3.0, fill(_C.headlight));
    rr(canvas, Rect.fromLTWH(w * 0.100, h * 0.868, w * 0.118, h * 0.040), 3.0, light);
    rr(canvas, Rect.fromLTWH(w * 0.782, h * 0.868, w * 0.118, h * 0.040), 3.0, light);

    // ── RÉTROVISEURS ─────────────────────────────────────────────────────
    _mirror(canvas, w * 0.098, h * 0.408, true, w);
    _mirror(canvas, w * 0.902, h * 0.408, false, w);

    // ── ROUES ─────────────────────────────────────────────────────────────
    _wheel(canvas, Offset(w * 0.124, h * 0.842), w * 0.090);
    _wheel(canvas, Offset(w * 0.876, h * 0.842), w * 0.090);
  }

  void _mirror(Canvas canvas, double cx, double cy, bool left, double w) {
    final s = w * 0.040;
    final p = Path();
    if (left) {
      p..moveTo(cx + s, cy)
        ..quadraticBezierTo(cx + s * 0.3, cy - s * 0.7, cx - s, cy - s * 0.55)
        ..lineTo(cx - s, cy + s * 0.95)
        ..lineTo(cx + s * 0.8, cy + s * 0.95)
        ..close();
    } else {
      p..moveTo(cx - s, cy)
        ..quadraticBezierTo(cx - s * 0.3, cy - s * 0.7, cx + s, cy - s * 0.55)
        ..lineTo(cx + s, cy + s * 0.95)
        ..lineTo(cx - s * 0.8, cy + s * 0.95)
        ..close();
    }
    drawPiece(canvas, p, _C.panel, thin: true);
  }

  void _wheel(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = _C.wheel..style = PaintingStyle.fill);
    canvas.drawCircle(c, r * 0.74, Paint()..color = const Color(0xFFE0E0EC)..style = PaintingStyle.fill);
    canvas.drawCircle(c, r * 0.42, Paint()..color = _C.wheel..style = PaintingStyle.fill);
    for (int i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * r * 0.44, c.dy + math.sin(a) * r * 0.44),
        Offset(c.dx + math.cos(a) * r * 0.72, c.dy + math.sin(a) * r * 0.72),
        Paint()..color = _C.strokeMid..strokeWidth = 1.2,
      );
    }
    canvas.drawCircle(c, r, Paint()..color = _C.stroke..style = PaintingStyle.stroke..strokeWidth = 1.4);
    canvas.drawCircle(c, r * 0.74, Paint()..color = _C.strokeMid..style = PaintingStyle.stroke..strokeWidth = 0.6);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VUE ARRIÈRE
// Pièces : pare_choc_ar, hayon, lunette, feu_g, feu_d,
//          aile_g, aile_d, retro_g, retro_d, roues
// ═════════════════════════════════════════════════════════════════════════════

class CarRearPainter extends _BP {
  const CarRearPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── SILHOUETTE (fond) ─────────────────────────────────────────────────
    final sil = Path()
      ..moveTo(w * 0.072, h * 0.942)
      ..lineTo(w * 0.040, h * 0.875)
      ..lineTo(w * 0.026, h * 0.775)
      ..lineTo(w * 0.030, h * 0.658)
      ..lineTo(w * 0.056, h * 0.558)
      ..quadraticBezierTo(w * 0.095, h * 0.490, w * 0.138, h * 0.458)
      ..lineTo(w * 0.182, h * 0.422)
      ..lineTo(w * 0.225, h * 0.362)
      ..lineTo(w * 0.268, h * 0.292)
      ..quadraticBezierTo(w * 0.310, h * 0.230, w * 0.355, h * 0.195)
      ..quadraticBezierTo(w * 0.402, h * 0.160, w * 0.450, h * 0.145)
      ..lineTo(w * 0.500, h * 0.135)
      ..lineTo(w * 0.550, h * 0.145)
      ..quadraticBezierTo(w * 0.598, h * 0.160, w * 0.645, h * 0.195)
      ..quadraticBezierTo(w * 0.690, h * 0.230, w * 0.732, h * 0.292)
      ..lineTo(w * 0.775, h * 0.362)
      ..lineTo(w * 0.818, h * 0.422)
      ..quadraticBezierTo(w * 0.862, h * 0.455, w * 0.905, h * 0.498)
      ..lineTo(w * 0.932, h * 0.578)
      ..lineTo(w * 0.958, h * 0.678)
      ..lineTo(w * 0.968, h * 0.792)
      ..lineTo(w * 0.942, h * 0.880)
      ..lineTo(w * 0.928, h * 0.942)
      ..close();
    canvas.drawPath(sil, fill(_C.body));
    canvas.drawPath(sil, main);

    // ── AILE GAUCHE ───────────────────────────────────────────────────────
    final aileG = Path()
      ..moveTo(w * 0.056, h * 0.558)
      ..quadraticBezierTo(w * 0.095, h * 0.490, w * 0.138, h * 0.458)
      ..lineTo(w * 0.182, h * 0.422)
      ..lineTo(w * 0.225, h * 0.362)
      ..lineTo(w * 0.268, h * 0.292)
      ..lineTo(w * 0.295, h * 0.292)
      ..lineTo(w * 0.295, h * 0.462)
      ..lineTo(w * 0.070, h * 0.942)
      ..lineTo(w * 0.040, h * 0.875)
      ..lineTo(w * 0.026, h * 0.775)
      ..lineTo(w * 0.030, h * 0.658)
      ..close();
    drawPiece(canvas, aileG, _C.panel);

    // ── AILE DROITE ───────────────────────────────────────────────────────
    final aileD = Path()
      ..moveTo(w * 0.944, h * 0.558)
      ..quadraticBezierTo(w * 0.905, h * 0.490, w * 0.862, h * 0.458)
      ..lineTo(w * 0.818, h * 0.422)
      ..lineTo(w * 0.775, h * 0.362)
      ..lineTo(w * 0.732, h * 0.292)
      ..lineTo(w * 0.705, h * 0.292)
      ..lineTo(w * 0.705, h * 0.462)
      ..lineTo(w * 0.930, h * 0.942)
      ..lineTo(w * 0.960, h * 0.875)
      ..lineTo(w * 0.972, h * 0.775)
      ..lineTo(w * 0.968, h * 0.658)
      ..close();
    drawPiece(canvas, aileD, _C.panel);

    // ── LUNETTE ARRIÈRE ────────────────────────────────────────────────────
    final lunette = Path()
      ..moveTo(w * 0.298, h * 0.292)
      ..lineTo(w * 0.348, h * 0.200)
      ..quadraticBezierTo(w * 0.412, h * 0.142, w * 0.500, h * 0.138)
      ..quadraticBezierTo(w * 0.588, h * 0.142, w * 0.652, h * 0.200)
      ..lineTo(w * 0.702, h * 0.292)
      ..lineTo(w * 0.710, h * 0.455)
      ..quadraticBezierTo(w * 0.595, h * 0.468, w * 0.500, h * 0.468)
      ..quadraticBezierTo(w * 0.405, h * 0.468, w * 0.290, h * 0.455)
      ..close();
    drawPiece(canvas, lunette, _C.glassDeep, thin: true);
    // Fils chauffants dégivreur
    for (int i = 0; i < 7; i++) {
      final y = 0.215 + i * 0.034;
      canvas.drawLine(Offset(w * 0.308, h * y), Offset(w * 0.692, h * y), light);
    }

    // ── HAYON ─────────────────────────────────────────────────────────────
    final hayon = Path()
      ..moveTo(w * 0.272, h * 0.455)
      ..lineTo(w * 0.728, h * 0.455)
      ..lineTo(w * 0.765, h * 0.785)
      ..lineTo(w * 0.235, h * 0.785)
      ..close();
    drawPiece(canvas, hayon, _C.panel);
    canvas.drawLine(Offset(w * 0.280, h * 0.528), Offset(w * 0.720, h * 0.528), light);
    // Poignée hayon
    rr(canvas, Rect.fromLTWH(w * 0.430, h * 0.718, w * 0.140, h * 0.046), 3.0, fill(const Color(0xFFCDD5E8)));
    rr(canvas, Rect.fromLTWH(w * 0.430, h * 0.718, w * 0.140, h * 0.046), 3.0, light);
    // Logo
    canvas.drawCircle(Offset(w * 0.500, h * 0.600), w * 0.028, fill(const Color(0xFFCDD5E8)));
    canvas.drawCircle(Offset(w * 0.500, h * 0.600), w * 0.028, light);

    // ── FEU GAUCHE ────────────────────────────────────────────────────────
    final feuG = Path()
      ..moveTo(w * 0.086, h * 0.505)
      ..lineTo(w * 0.272, h * 0.502)
      ..lineTo(w * 0.272, h * 0.800)
      ..lineTo(w * 0.118, h * 0.800)
      ..lineTo(w * 0.086, h * 0.780)
      ..close();
    drawPiece(canvas, feuG, _C.taillight, thin: true);
    canvas.drawLine(Offset(w * 0.086, h * 0.650), Offset(w * 0.272, h * 0.650), light);

    // ── FEU DROIT ─────────────────────────────────────────────────────────
    final feuD = Path()
      ..moveTo(w * 0.914, h * 0.505)
      ..lineTo(w * 0.728, h * 0.502)
      ..lineTo(w * 0.728, h * 0.800)
      ..lineTo(w * 0.882, h * 0.800)
      ..lineTo(w * 0.914, h * 0.780)
      ..close();
    drawPiece(canvas, feuD, _C.taillight, thin: true);
    canvas.drawLine(Offset(w * 0.728, h * 0.650), Offset(w * 0.914, h * 0.650), light);

    // ── PARE-CHOC ARRIÈRE ─────────────────────────────────────────────────
    final pareChocAr = Path()
      ..moveTo(w * 0.068, h * 0.855)
      ..lineTo(w * 0.932, h * 0.855)
      ..lineTo(w * 0.950, h * 0.912)
      ..quadraticBezierTo(w * 0.500, h * 0.968, w * 0.050, h * 0.912)
      ..close();
    drawPiece(canvas, pareChocAr, _C.panel, thin: true);
    // Plaque
    rr(canvas, Rect.fromLTWH(w * 0.356, h * 0.862, w * 0.288, h * 0.044), 2.0, fill(const Color(0xFFF5F5DC)));
    rr(canvas, Rect.fromLTWH(w * 0.356, h * 0.862, w * 0.288, h * 0.044), 2.0, light);
    // Échappements
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.295, h * 0.910), width: w * 0.054, height: h * 0.028),
        fill(const Color(0xFF888898)));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.295, h * 0.910), width: w * 0.054, height: h * 0.028), light);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.705, h * 0.910), width: w * 0.054, height: h * 0.028),
        fill(const Color(0xFF888898)));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.705, h * 0.910), width: w * 0.054, height: h * 0.028), light);
    // Réflecteurs
    rr(canvas, Rect.fromLTWH(w * 0.336, h * 0.875, w * 0.120, h * 0.030), 2.0, fill(_C.headlight));
    rr(canvas, Rect.fromLTWH(w * 0.544, h * 0.875, w * 0.120, h * 0.030), 2.0, fill(_C.headlight));
    rr(canvas, Rect.fromLTWH(w * 0.336, h * 0.875, w * 0.120, h * 0.030), 2.0, light);
    rr(canvas, Rect.fromLTWH(w * 0.544, h * 0.875, w * 0.120, h * 0.030), 2.0, light);

    // ── RÉTROVISEURS ─────────────────────────────────────────────────────
    _mirror(canvas, w * 0.096, h * 0.418, true, w);
    _mirror(canvas, w * 0.904, h * 0.418, false, w);

    // ── ROUES ─────────────────────────────────────────────────────────────
    _wheel(canvas, Offset(w * 0.124, h * 0.842), w * 0.090);
    _wheel(canvas, Offset(w * 0.876, h * 0.842), w * 0.090);
  }

  void _mirror(Canvas canvas, double cx, double cy, bool left, double w) {
    final s = w * 0.040;
    final p = Path();
    if (left) {
      p..moveTo(cx + s, cy)
        ..quadraticBezierTo(cx + s * 0.3, cy - s * 0.7, cx - s, cy - s * 0.55)
        ..lineTo(cx - s, cy + s * 0.95)
        ..lineTo(cx + s * 0.8, cy + s * 0.95)
        ..close();
    } else {
      p..moveTo(cx - s, cy)
        ..quadraticBezierTo(cx - s * 0.3, cy - s * 0.7, cx + s, cy - s * 0.55)
        ..lineTo(cx + s, cy + s * 0.95)
        ..lineTo(cx - s * 0.8, cy + s * 0.95)
        ..close();
    }
    drawPiece(canvas, p, _C.panel, thin: true);
  }

  void _wheel(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = _C.wheel..style = PaintingStyle.fill);
    canvas.drawCircle(c, r * 0.74, Paint()..color = const Color(0xFFE0E0EC)..style = PaintingStyle.fill);
    canvas.drawCircle(c, r * 0.42, Paint()..color = _C.wheel..style = PaintingStyle.fill);
    for (int i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * r * 0.44, c.dy + math.sin(a) * r * 0.44),
        Offset(c.dx + math.cos(a) * r * 0.72, c.dy + math.sin(a) * r * 0.72),
        Paint()..color = _C.strokeMid..strokeWidth = 1.2,
      );
    }
    canvas.drawCircle(c, r, Paint()..color = _C.stroke..style = PaintingStyle.stroke..strokeWidth = 1.4);
    canvas.drawCircle(c, r * 0.74, Paint()..color = _C.strokeMid..style = PaintingStyle.stroke..strokeWidth = 0.6);
  }
}