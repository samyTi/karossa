import 'dart:typed_data';

class PdfGenerator {
  static Future<Uint8List> generateContrat({
    required String client,
    required String vehicule,
    required double prix,
  }) async {
    // Remplace par vraie lib PDF (pdf package)
    return Uint8List.fromList(List.generate(200, (i) => i));
  }
}