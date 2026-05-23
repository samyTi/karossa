// lib/core/services/web_download_real.dart
//
// Implémentation RÉELLE — Web uniquement.
// Ce fichier est importé uniquement quand dart.library.html est disponible.

// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Déclenche un téléchargement de fichier dans le navigateur.
void downloadFileOnWeb(Uint8List bytes, String filename) {
  final blob   = html.Blob([bytes], 'application/pdf');
  final url    = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}