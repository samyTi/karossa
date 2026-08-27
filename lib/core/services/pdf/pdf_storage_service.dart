import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'web_download_helper.dart'
    if (dart.library.io) 'mobile_download_helper.dart';

class PdfStorageService {

  static Future<void> saveAndShare({
    required Uint8List bytes,
    required String filename,
    String? subject,
  }) async {
    await downloadFilePlatform(bytes, filename, subject: subject);
  }

  static Future<void> saveAndShareMultiple({
    required List<Uint8List> bytesList,
    required List<String> filenames,
    required String subject,
  }) async {
    for (int i = 0; i < bytesList.length; i++) {
      await downloadFilePlatform(bytesList[i], filenames[i], subject: subject);
    }
  }
}