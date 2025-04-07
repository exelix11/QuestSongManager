import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bsaberquest/download_manager/beat_saver_api.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/model/song.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../mod_manager/model/playlist.dart';

class _QueuedItem {
  final DownloadItem item;
  final Future<DownloadResult> Function() action;

  _QueuedItem(this.item, this.action);
}

class DownloadManager {
  Playlist? downloadToPlaylist;
  int maxConcurrentDownloads = 4;

  final Queue<_QueuedItem> _downloadQueue = Queue();

  final List<DownloadItem> items = [];

  int get queuedCount => _downloadQueue.length;

  StreamController<DownloadItem?> downloadItemsObservable =
      StreamController<DownloadItem?>.broadcast();

  void clearCompleted() {
    items
        .removeWhere((element) => element.status != ItemDownloadStatus.pending);

    downloadItemsObservable.add(null);
  }

  void cancelQueue() {
    _downloadQueue.clear();
    downloadItemsObservable.add(null);
  }

  void addTestElements() {
    for (int i = 0; i < 10; i++) {
      var item = SongDownloadItem("Test $i", null, true, null);
      item.statusMessage = "Test message";
      if (i > 5) {
        item.status = ItemDownloadStatus.done;
      } else {
        item.status = ItemDownloadStatus.pending;
      }
      items.add(item);
    }
  }

  void _updateItemState(DownloadItem item) {
    downloadItemsObservable.add(item);
  }

  void _beginBackgroundOperation(
      DownloadItem item, Future<DownloadResult> Function() action) async {
    if (!item._countsForQueue) {
      _processBackgroundOperation(_QueuedItem(item, action));
    } else {
      _downloadQueue.add(_QueuedItem(item, action));
      _tryRunNextInQueue();
    }
  }

  void _tryRunNextInQueue() {
    var pendingCount = items
        .where((element) =>
            element.status == ItemDownloadStatus.pending &&
            element._countsForQueue)
        .length;

    if (pendingCount < maxConcurrentDownloads) {
      if (_downloadQueue.isNotEmpty) {
        var item = _downloadQueue.removeLast();
        _processBackgroundOperation(item);
      }
    }
  }

  void _processBackgroundOperation(_QueuedItem queue) async {
    var item = queue.item;

    var future = queue.action().catchError(
        (error, stackTrace) => DownloadResult.error(error.toString()));

    items.add(item);
    _updateItemState(item);

    var result = await future;
    item.statusMessage = result.message;
    item.status =
        result.error ? ItemDownloadStatus.error : ItemDownloadStatus.done;

    item._completer.complete(result);
    _updateItemState(item);

    _tryRunNextInQueue();
  }

  Future<Playlist> downloadPlaylistMetadata(String jsonUrl) async {
    String body;

    if (App.beatSaverClient.isBeatSaverUrl(jsonUrl)) {
      body = await App.beatSaverClient.get(jsonUrl);
    } else {
      var res = await http.get(Uri.parse(jsonUrl));
      if (res.statusCode != 200) {
        throw Exception("Failed to get playlist info (${res.statusCode})");
      }
      body = utf8.decode(res.bodyBytes);
    }

    return Playlist.fromJson(jsonDecode(body));
  }

  DownloadItem startPlaylistDownload(
      Playlist playlist, Set<String>? songsToDownload, String? webSource) {
    // We skip the queue because playlists depend on the individual songs which are queued
    // Otherwise, if we started 10 playlists at the same time the queue would be full and everything would be stuck
    var item = PlaylistDownloadItem(
        "[Playlist] ${playlist.playlistTitle}", webSource, false);

    item.statusMessage = "Storing metadata";
    item.downloadedIcon = playlist.imageBytes;

    _beginBackgroundOperation(item, () async {
      // Since this is a playlist we are downloading from the internet if there's the image issue it will be automatically fixed so force the warning to false
      playlist.imageCompatibilityIssue = false;
      await App.modManager.addPlaylist(playlist);
      item.playlistFileName = playlist.fileName;

      // If not specified, download all
      songsToDownload ??= playlist.songs.map((e) => e.hash).toSet();

      item.statusMessage = "Downloading songs";
      _updateItemState(item);

      List<Future<DownloadResult>> futures = [];
      for (var song in playlist.songs) {
        if (!songsToDownload!.contains(song.hash) || song.key == null) {
          continue;
        }

        futures.add(downloadMapByID(song.key!, webSource, null).future);
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }

      futures.clear();

      return DownloadResult.ok("Download complete");
    });

    return item;
  }

  void _itemFromBeatSaver(SongDownloadItem item, BeatSaverMapInfo map) {
    item.name = map.name;
    item.urlIcon = map.versions.first.coverUrl;
    item.hash = map.versions.first.hash;
    item.statusMessage = "Downloading song";
    _updateItemState(item);
  }

  DownloadItem downloadMapByMetadata(
      BeatSaverMapInfo info, String? webSource, Playlist? downloadTOPlaylist) {
    var item = SongDownloadItem(
        info.name, webSource, true, downloadToPlaylist?.fileName);
    item.statusMessage = "Downloading metadata";

    _beginBackgroundOperation(item, () async {
      _itemFromBeatSaver(item, info);
      return await _downloadAndAddMap(info.requestHash, item.hash!,
          info.versions.first.downloadUrl, downloadTOPlaylist?.fileName);
    });

    return item;
  }

  DownloadItem downloadMapByHash(
      String hash, String? webSource, Playlist? downloadTOPlaylist) {
    var item =
        SongDownloadItem(hash, webSource, true, downloadToPlaylist?.fileName);
    item.statusMessage = "Downloading metadata";

    _beginBackgroundOperation(item, () async {
      var map = await App.beatSaverClient.getMapByHash(hash);
      _itemFromBeatSaver(item, map);
      return await _downloadAndAddMap(hash, item.hash!,
          map.versions.first.downloadUrl, downloadTOPlaylist?.fileName);
    });

    return item;
  }

  DownloadItem downloadMapByID(
      String id, String? webSource, Playlist? downloadTOPlaylist) {
    var item =
        SongDownloadItem(id, webSource, true, downloadToPlaylist?.fileName);
    item.statusMessage = "Downloading metadata";

    _beginBackgroundOperation(item, () async {
      var map = await App.beatSaverClient.getMapById(id);
      _itemFromBeatSaver(item, map);
      return await _downloadAndAddMap(null, item.hash!,
          map.versions.first.downloadUrl, downloadTOPlaylist?.fileName);
    });

    return item;
  }

  // Expectd hash is the hash we requested to download or expect
  // Download hash is the hash that was returned by the beatsaver api
  // These may differ for example when we are requesting an hash for an old map and the api returns a newer version
  Future<DownloadResult> _downloadAndAddMap(String? expectedHash,
      String downloadHash, String downloadUrl, String? playlistName) async {
    expectedHash = expectedHash?.toLowerCase();
    downloadHash = downloadHash.toLowerCase();

    if (App.modManager.hasSong(downloadHash)) {
      // The map is already downloaded but if the the new hash is different than the old one we are trying to update an outdated playlist
      if (expectedHash != null && expectedHash != downloadHash) {
        App.modManager.replaceSongInPlaylists(expectedHash, downloadHash);
      }

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
          files[file.name] = file.content;
        }
      }
    } catch (e) {
      return DownloadResult.error("Failed to process map: $e");
    }

    Song installed;

    try {
      installed = await App.modManager.installSong(files, expectedHash);
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
  final Completer<DownloadResult> _completer = Completer();
  final bool _countsForQueue;

  Future<DownloadResult> get future => _completer.future;

  String name;
  String statusMessage = "loading";

  String? urlIcon;
  Uint8List? downloadedIcon;

  ItemDownloadStatus status = ItemDownloadStatus.pending;

  DownloadItem(this.name, this.webSource, this._countsForQueue,
      {this.urlIcon, this.downloadedIcon});
}

class SongDownloadItem extends DownloadItem {
  final String? playlist;
  String? hash;

  SongDownloadItem(
      super.name, super.webSource, super._countsForQueue, this.playlist);
}

class PlaylistDownloadItem extends DownloadItem {
  String? playlistFileName;

  PlaylistDownloadItem(super.name, super.webSource, super._countsForQueue);
}
