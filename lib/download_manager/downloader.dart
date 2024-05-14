import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../mod_manager/model/playlist.dart';

class DownloadManager {
  Playlist? downloadToPlaylist;

  List<DownloadItem> downloadItems = [];

  StreamController<DownloadItem?> downloadItemsObservable =
      StreamController<DownloadItem?>.broadcast();

  void clearCompleted() {
    downloadItems.removeWhere((element) =>
        element.status == ItemDownloadStatus.done ||
        element.status == ItemDownloadStatus.error);

    downloadItemsObservable.add(null);
  }

  void _updateItemState(DownloadItem item) {
    downloadItemsObservable.add(item);
  }

  void _beginBackgroundOperation(
      DownloadItem item, Future<DownloadResult> Function() future) async {
    item.future = future().catchError(
        (error, stackTrace) => DownloadResult.error(error.toString()));

    downloadItems.insert(0, item);
    _updateItemState(item);

    var result = await item.future;
    item.statusMessage = result.message;
    item.status =
        result.error ? ItemDownloadStatus.error : ItemDownloadStatus.done;
    _updateItemState(item);
  }

  DownloadItem startPlaylistDownload(String jsonUrl, String playlistName,
      String? webSource, bool downloadSongs) {
    var item = PlaylistDownloadItem(playlistName, webSource);
    item.statusMessage = "Downloading metadata";

    _beginBackgroundOperation(item, () async {
      var res = await http.get(Uri.parse(jsonUrl));
      if (res.statusCode != 200) {
        throw Exception("Failed to get playlist info (${res.statusCode})");
      }

      var playlist = Playlist.fromJson(jsonDecode(res.body));
      // Force playlist name
      playlist.playlistTitle = playlistName;
      // Since this is a playlist we are downloading from the internet if there's the image issue it will be automatically fixed so force the warning to false
      playlist.imageCompatibilityIssue = false;

      item.name = "[Playlist] ${playlist.playlistTitle}";
      item.downloadedIcon = playlist.imageBytes;
      _updateItemState(item);

      await App.modManager.addPlaylist(playlist);
      item.playlistFileName = playlist.fileName;

      if (downloadSongs) {
        var keys =
            playlist.songs.map((e) => e.key).where((x) => x != null).toList();

        item.statusMessage = "Downloading songs (0/${keys.length})";
        _updateItemState(item);

        List<Future<DownloadResult>> futures = [];
        var count = 0;
        for (var key in keys) {
          // No need to specify a playlist name here, as we already have one with all the songs
          futures.add(startMapDownload(key!, webSource, null).future);
          count++;

          item.statusMessage = "Downloading songs ($count/${keys.length})";
          _updateItemState(item);

          if (futures.length >= 3) {
            await Future.wait(futures);
            futures.clear();
          }
        }

        if (futures.isNotEmpty) {
          await Future.wait(futures);
        }
        futures.clear();
      }

      return DownloadResult.ok("Download complete");
    });

    return item;
  }

  DownloadItem startMapDownloadWithGlobalPlaylist(
      String id, String? webSource) {
    return startMapDownload(id, webSource, downloadToPlaylist?.fileName);
  }

  DownloadItem startMapDownload(
      String id, String? webSource, String? playlistName) {
    var item = SongDownloadItem(id, webSource, downloadToPlaylist?.fileName);
    item.statusMessage = "Downloading metadata";

    _beginBackgroundOperation(item, () async {
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

      item.name = name;
      item.urlIcon = urlIcon;
      item.hash = hash;
      item.statusMessage = "Downloading song";
      _updateItemState(item);

      return await _downloadAndAddMap(hash, downloadUrl, playlistName);
    });

    return item;
  }

  Future<DownloadResult> _downloadAndAddMap(
      String hash, String downloadUrl, String? playlistName) async {
    if (App.modManager.hasSong(hash)) {
      return DownloadResult.ok("Map already downloaded");
    }

    Map<String, Uint8List> files = {};

    try {
      var res = await http.get(Uri.parse(downloadUrl));
      if (res.statusCode != 200) {
        return DownloadResult.error(
            "Failed to download map (${res.statusCode})");
      }

      final archive = ZipDecoder().decodeBytes(res.bodyBytes);
      for (var file in archive) {
        if (file.isFile && !file.name.contains("/")) {
          files[file.name] = file.content as Uint8List;
        }
      }
    } catch (e) {
      return DownloadResult.error("Failed to process map: $e");
    }

    Song installed;

    try {
      installed = await App.modManager.installSong(files, hash);
    } catch (e) {
      return DownloadResult.error("Failed to process map: $e");
    }

    try {
      if (playlistName != null) {
        var playlist = App.modManager.playlists[playlistName];
        playlist!.add(installed);
        await App.modManager.applyPlaylistChanges(playlist);
      }
    } catch (e) {
      return DownloadResult.ok(
          "${installed.meta.songName} downloaded, but it was not added to the requested playlist: $e");
    }

    return DownloadResult.ok("${installed.meta.songName} downloaded");
  }
}

class DownloadResult {
  final String message;
  final bool error;

  DownloadResult._init(this.message, this.error);

  factory DownloadResult.ok([String? message]) {
    return DownloadResult._init(message ?? "", false);
  }

  factory DownloadResult.error(String message) {
    return DownloadResult._init(message, true);
  }
}

enum ItemDownloadStatus { pending, done, error }

class DownloadItem {
  final String? webSource;

  String name;
  String statusMessage = "loading";

  String? urlIcon;
  Uint8List? downloadedIcon;

  late Future<DownloadResult> future;
  ItemDownloadStatus status = ItemDownloadStatus.pending;

  DownloadItem(this.name, this.webSource, {this.urlIcon, this.downloadedIcon});
}

class SongDownloadItem extends DownloadItem {
  final String? playlist;
  String? hash;

  SongDownloadItem(super.name, super.webSource, this.playlist);
}

class PlaylistDownloadItem extends DownloadItem {
  String? playlistFileName;

  PlaylistDownloadItem(super.name, super.webSource);
}
