import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:http/http.dart' as http;

class DownloadManager {
  Playlist? downloadToPlaylist;

  List<DownloadItem> downloadItems = [];

  StreamController<DownloadItem> downloadItemsObservable =
      StreamController<DownloadItem>.broadcast();

  Future<DownloadItem> startMapDownload(String id, String? webSource) async {
    var res =
        await http.get(Uri.parse("https://api.beatsaver.com/maps/id/$id"));
    if (res.statusCode != 200) {
      throw Exception("Failed to get map info (${res.statusCode})");
    }

    var map = Map<String, dynamic>.from(jsonDecode(res.body));
    var name = map["name"] as String?;
    var versions = map["versions"] as List<dynamic>;

    if (versions.length > 1) {
      // TODO: figure out order
      App.showToast(
          "WARNING: Song $name has ${versions.length}, downloading latest is not implemented");
    }

    var downloadUrl = versions[0]["downloadURL"] as String?;
    var urlIcon = versions[0]["coverURL"] as String?;
    var hash = versions[0]["hash"] as String?;

    if (name == null ||
        downloadUrl == null ||
        urlIcon == null ||
        hash == null) {
      throw Exception("Failed to get map info");
    }

    var item = DownloadItem(name, downloadUrl, urlIcon,
        downloadToPlaylist?.fileName, hash, webSource);

    item.download = downloadAndAddMap(item).then((result) {
      item.status =
          result.error ? ItemDownloadStatus.error : ItemDownloadStatus.done;
      downloadItemsObservable.add(item);
      return result;
    });

    downloadItems.insert(0, item);
    downloadItemsObservable.add(item);

    return item;
  }

  Future<DownloadResult> downloadAndAddMap(DownloadItem item) async {
    if (App.modManager.hasSong(item.hash)) {
      return DownloadResult("Map already downloaded", false);
    }

    Map<String, Uint8List> files = {};

    try {
      var res = await http.get(Uri.parse(item.downloadUrl));
      if (res.statusCode != 200) {
        return DownloadResult(
            "Failed to download map (${res.statusCode})", true);
      }

      final archive = ZipDecoder().decodeBytes(res.bodyBytes);
      for (var file in archive) {
        if (file.isFile && !file.name.contains("/")) {
          files[file.name] = file.content as Uint8List;
        }
      }
    } catch (e) {
      return DownloadResult("Failed to process map: $e", true);
    }

    Song installed;

    try {
      installed = await App.modManager.installSong(files, item.hash);
    } catch (e) {
      return DownloadResult("Failed to process map: $e", true);
    }

    try {
      if (item.playlist != null) {
        var playlist = App.modManager.playlists[item.playlist!];
        playlist!.add(installed);
        await App.modManager.applyPlaylistChanges(playlist);
      }
    } catch (e) {
      return DownloadResult(
          "${installed.meta.songName} downloaded, but it was not added to the requested playlist: $e",
          false);
    }

    return DownloadResult("${installed.meta.songName} downloaded", false);
  }
}

class DownloadResult {
  final String message;
  final bool error;

  DownloadResult(this.message, this.error);
}

enum ItemDownloadStatus { peding, done, error }

class DownloadItem {
  final String name;
  final String downloadUrl;
  final String urlIcon;
  final String? playlist;
  final String hash;
  final String? webSource;

  late Future<DownloadResult> download;
  ItemDownloadStatus status = ItemDownloadStatus.peding;

  DownloadItem(this.name, this.downloadUrl, this.urlIcon, this.playlist,
      this.hash, this.webSource);
}
