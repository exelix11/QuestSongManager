import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bsaberquest/download_manager/beat_saver_api.dart';
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

  Future<Playlist> downloadPlaylist(String jsonUrl) async {
    var res = await http.get(Uri.parse(jsonUrl));
    if (res.statusCode != 200) {
      throw Exception("Failed to get playlist info (${res.statusCode})");
    }

    return Playlist.fromJson(jsonDecode(res.body));
  }

  DownloadItem startPlaylistDownload(
      Playlist playlist, Set<String>? songsToDownload, String? webSource) {
    var item =
        PlaylistDownloadItem("[Playlist] ${playlist.playlistTitle}", webSource);

    item.statusMessage = "Storing metadata";
    item.downloadedIcon = playlist.imageBytes;

    _beginBackgroundOperation(item, () async {
      // Since this is a playlist we are downloading from the internet if there's the image issue it will be automatically fixed so force the warning to false
      playlist.imageCompatibilityIssue = false;
      await App.modManager.addPlaylist(playlist);
      item.playlistFileName = playlist.fileName;

      // If not specified, download all
      songsToDownload ??= playlist.songs.map((e) => e.hash).toSet();

      item.statusMessage = "Downloading songs (0/${songsToDownload!.length})";
      _updateItemState(item);

      List<Future<DownloadResult>> futures = [];
      var count = 0;
      for (var song in playlist.songs) {
        if (!songsToDownload!.contains(song.hash) || song.key == null) {
          continue;
        }

        futures.add(downloadMapByID(song.key!, webSource, null).future);
        count++;

        item.statusMessage =
            "Downloading songs ($count/${songsToDownload!.length})";
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

      return DownloadResult.ok("Download complete");
    });

    return item;
  }

  DownloadItem startMapDownloadWithGlobalPlaylist(
      String id, String? webSource) {
    return downloadMapByID(id, webSource, downloadToPlaylist?.fileName);
  }

  void _itemFromBeatSaver(SongDownloadItem item, BeatSaverMapInfo map) {
    item.name = map.name;
    item.urlIcon = map.versions.first.coverUrl;
    item.hash = map.versions.first.hash;
    item.statusMessage = "Downloading song";
    _updateItemState(item);
  }

  DownloadItem downloadMapByMetadata(
      BeatSaverMapInfo info, String? webSource, String? playlistName) {
    var item =
        SongDownloadItem(info.name, webSource, downloadToPlaylist?.fileName);
    item.statusMessage = "Downloading metadata";

    _beginBackgroundOperation(item, () async {
      _itemFromBeatSaver(item, info);
      return await _downloadAndAddMap(
          item.hash!, info.versions.first.downloadUrl, playlistName);
    });

    return item;
  }

  DownloadItem downloadMapByHash(
      String hash, String? webSource, String? playlistName) {
    var item = SongDownloadItem(hash, webSource, downloadToPlaylist?.fileName);
    item.statusMessage = "Downloading metadata";

    _beginBackgroundOperation(item, () async {
      var map = await App.beatSaverClient.getMapByHash(hash);
      _itemFromBeatSaver(item, map);
      return await _downloadAndAddMap(
          item.hash!, map.versions.first.downloadUrl, playlistName);
    });

    return item;
  }

  DownloadItem downloadMapByID(
      String id, String? webSource, String? playlistName) {
    var item = SongDownloadItem(id, webSource, downloadToPlaylist?.fileName);
    item.statusMessage = "Downloading metadata";

    _beginBackgroundOperation(item, () async {
      var map = await App.beatSaverClient.getMapById(id);
      _itemFromBeatSaver(item, map);
      return await _downloadAndAddMap(
          item.hash!, map.versions.first.downloadUrl, playlistName);
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
