// lib/shared/widgets/signature_pad.dart
//
// Pad de signature tactile "maison" (aucune dépendance pub externe requise).
// Capture les traits au doigt/stylet et exporte un PNG (Uint8List) prêt à
// être uploadé sur Supabase Storage puis injecté dans les PDF de contrat.
//
// Usage :
//   final key = GlobalKey<SignaturePadState>();
//   SignaturePad(key: key)
//   ...
//   final bytes = await key.currentState?.exportPng();

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter/rendering.dart';
import '../../core/extensions/l10n_extension.dart';

class SignaturePad extends StatefulWidget {
  final double height;
  final Color strokeColor;
  final double strokeWidth;

  const SignaturePad({
    super.key,
    this.height = 180,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.4,
  });

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  final GlobalKey _boundaryKey = GlobalKey();

  bool get isEmpty => _strokes.isEmpty;

  void clear() => setState(_strokes.clear);

  void _onPanStart(DragStartDetails details) {
    setState(() => _strokes.add([details.localPosition]));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _strokes.last.add(details.localPosition));
  }

  /// Exporte le contenu du pad en PNG. Retourne `null` si rien n'a été signé.
  Future<Uint8List?> exportPng() async {
    if (isEmpty) return null;
    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RepaintBoundary(
          key: _boundaryKey,
          child: Container(
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              child: CustomPaint(
                painter: _SignaturePainter(
                  strokes: _strokes,
                  color: widget.strokeColor,
                  strokeWidth: widget.strokeWidth,
                ),
                child: isEmpty
                    ? Center(
                        child: Text(
                          'Signez ici',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: isEmpty ? null : clear,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(context.l10n.effacer),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  _SignaturePainter({required this.strokes, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
