import 'package:bsaberquest/main.dart';

class DownloadUtil {
  static Future downloadPlaylist(String jsonUrl, String playlistName,
      String? webSource, bool downloadSongs) async {
    try {
      if (!await App.modManager.isPlaylistNameFree(playlistName)) {
        App.showToast("Playlist name already exists");
        return;
      }

      App.showToast("Starting download...");

      var res = await App.downloadManager
          .startPlaylistDownload(
              jsonUrl, playlistName, webSource, downloadSongs)
          .future;

      App.showToast(res.message);
    } catch (e) {
      App.showToast("Failed to download: $e");
    }
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
