// lib/core/services/web_download_stub.dart
//
// Implémentation STUB — mobile / desktop.
// Sur ces plateformes dart:html n'existe pas.
// Cette fonction ne sera jamais appelée (guard kIsWeb dans le service).

// ignore_for_file: avoid_unused_import_elements

import 'dart:typed_data';

/// No-op sur mobile/desktop.
void downloadFileOnWeb(Uint8List bytes, String filename) {
  // Ne rien faire — kIsWeb est false sur ces plateformes,
  // donc cette fonction n'est jamais appelée.
  assert(false, 'downloadFileOnWeb appelé sur une plateforme non-Web');
}