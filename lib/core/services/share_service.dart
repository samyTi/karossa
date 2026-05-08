import 'package:share_plus/share_plus.dart';

class ShareService {
  static Future<void> shareFile(String path) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
      ),
    );
  }
}