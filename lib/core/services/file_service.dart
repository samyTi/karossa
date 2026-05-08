import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

class FileService {
  static Future<File> savePdf(Uint8List data, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/$name.pdf");
    await file.writeAsBytes(data);
    return file;
  }
}