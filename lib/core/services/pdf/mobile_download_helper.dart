import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Écrit le PDF dans le dossier temporaire de l'app puis ouvre la feuille de
/// partage native (Enregistrer dans Fichiers, envoyer par mail/WhatsApp...).
///
/// IMPORTANT : on écrit dans `getTemporaryDirectory()` (et non
/// `getApplicationDocumentsDirectory()`) car ce fichier n'a vocation qu'à
/// être partagé immédiatement — il n'a pas besoin d'être conservé dans le
/// stockage privé de l'app, qui de toute façon n'est pas accessible à
/// l'utilisateur.
///
/// Les erreurs sont désormais propagées (pas de catch silencieux) afin que
/// l'appelant (ContratOrchestrator) puisse informer l'utilisateur en cas
/// d'échec réel, au lieu d'afficher un faux message de succès.
Future<void> downloadFilePlatform(
  Uint8List bytes,
  String filename, {
  String? subject,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('[PDF] Écrit temporairement: ${file.path}');

  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: subject,
      text: subject,
    ),
  );

  if (result.status == ShareResultStatus.dismissed) {
    debugPrint("[PDF] Partage annulé par l'utilisateur pour $filename");
  } else {
    debugPrint('[PDF] Partagé avec succès: $filename');
  }
}
