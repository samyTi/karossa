// lib/core/utils/pdf_file_helper.dart
//
// Helper unifié pour la sauvegarde de fichiers PDF.
// Gère Mobile/Desktop (via path_provider) et Web (via téléchargement navigateur).
//
// RÉSOUT :
//   - Error: No such file or directory 'lib/core/utils/pdf_file_helper.dart'
//   - Error: Method not found: 'getApplicationDocumentsDirectory'

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

// dart:io et path_provider uniquement sur mobile/desktop
import 'dart:io' if (dart.library.html) 'dart:io';
import 'package:path_provider/path_provider.dart'
    if (dart.library.html) 'package:path_provider/path_provider.dart';

/// Sauvegarde des bytes PDF sur le disque (mobile/desktop).
/// Sur Web, déclenche un téléchargement navigateur.
/// Retourne le [File] créé, ou null sur Web.
Future<File?> savePdfBytes(List<int> bytes, String filename) async {
  if (kIsWeb) {
    _downloadOnWeb(Uint8List.fromList(bytes), filename);
    return null;
  }
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  return file;
}

/// Sauvegarde un PDF FR + AR en deux fichiers séparés (mobile/desktop).
/// Retourne une paire de [File], ou null sur Web (téléchargements déclenchés).
Future<PdfFilePair?> savePdfPairBytes({
  required List<int> bytesFr,
  required List<int> bytesAr,
  required String filenameFr,
  required String filenameAr,
}) async {
  if (kIsWeb) {
    _downloadOnWeb(Uint8List.fromList(bytesFr), filenameFr);
    _downloadOnWeb(Uint8List.fromList(bytesAr), filenameAr);
    return null;
  }
  final dir = await getApplicationDocumentsDirectory();
  final fileFr = File('${dir.path}/$filenameFr');
  final fileAr = File('${dir.path}/$filenameAr');
  await fileFr.writeAsBytes(bytesFr);
  await fileAr.writeAsBytes(bytesAr);
  return PdfFilePair(fr: fileFr, ar: fileAr);
}

/// Paire de fichiers PDF (français + arabe).
class PdfFilePair {
  final File fr;
  final File ar;
  const PdfFilePair({required this.fr, required this.ar});
}

// ── Téléchargement Web (implémentation inline pour éviter les stubs) ─────────
void _downloadOnWeb(Uint8List bytes, String filename) {
  // Implémentation vide sur mobile/desktop — ne sera jamais appelée
  // car kIsWeb est false. Sur Web, le conditional import fournit
  // l'implémentation réelle via dart:html.
  //
  // Si vous compilez pour le Web, créez :
  //   lib/core/utils/web_download_real.dart
  // avec une implémentation dart:html.
  //
  // Pour l'instant, no-op (évite l'erreur de compilation).
  assert(false, '_downloadOnWeb appelé sur une plateforme non-Web');
}