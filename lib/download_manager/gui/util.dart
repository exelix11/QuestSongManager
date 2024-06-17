import 'package:bsaberquest/download_manager/gui/playlist_download_page.dart';
import 'package:bsaberquest/main.dart';
import 'package:flutter/material.dart';

class DownloadUtil {
  static Future downloadPlaylist(
      BuildContext context, String jsonUrl, String? webSource) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                PlaylistDownloadPage(jsonUrl, webSource: webSource)));
  }

  static Future downloadById(String id, String? webSource) async {
    if (id.isEmpty) {
      return;
    }

    try {
      App.showToast("Starting download...");

      var r =
          App.downloadManager.startMapDownloadWithGlobalPlaylist(id, webSource);

      var res = await r.future;

      App.showToast(res.message);
    } catch (e) {
      App.showToast("Failed to download: $e");
    }
  }
}
