import 'package:bsaberquest/main.dart';

class DownloadUtil {
  static Future downloadById(String id, String? webSource) async {
    if (id.isEmpty) {
      return;
    }

    try {
      App.showToast("Starting download...");

      var r = await App.downloadManager.startMapDownload(id, webSource);

      var res = await r.download;

      App.showToast(res.message);
    } catch (e) {
      App.showToast("Failed to download: $e");
    }
  }
}
