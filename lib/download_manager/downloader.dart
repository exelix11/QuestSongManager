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

  final Queue<_QueuedItem> downloadQueue = Queue();

  final List<DownloadItem> pendingItems = [];
  final List<DownloadItem> completedItems = [];

  StreamController<DownloadItem?> downloadItemsObservable =
      StreamController<DownloadItem?>.broadcast();

  void clearCompleted() {
    completedItems.clear();
    downloadItemsObservable.add(null);
  }

  void cancelQueue() {
    downloadQueue.clear();
    downloadItemsObservable.add(null);
  }

  void _updateItemState(DownloadItem item) {
    downloadItemsObservable.add(item);
  }

  void _beginBackgroundOperation(
      DownloadItem item, Future<DownloadResult> Function() action,
      {bool skipQueue = false}) async {
    if (skipQueue) {
      _processBackgroundOperation(_QueuedItem(item, action));
    } else {
      downloadQueue.add(_QueuedItem(item, action));
      _tryRunNextInQueue();
    }
  }

  void _tryRunNextInQueue() {
    if (pendingItems.length < maxConcurrentDownloads) {
      if (downloadQueue.isNotEmpty) {
        var item = downloadQueue.removeLast();
        _processBackgroundOperation(item);
      }
    }
  }

  void _processBackgroundOperation(_QueuedItem queue) async {
    var item = queue.item;

    var future = queue.action().catchError(
        (error, stackTrace) => DownloadResult.error(error.toString()));

    pendingItems.insert(0, item);
    _updateItemState(item);

    var result = await future;
    item.statusMessage = result.message;
    item.status =
        result.error ? ItemDownloadStatus.error : ItemDownloadStatus.done;

    pendingItems.remove(item);
    completedItems.insert(0, item);

    item._completer.complete(result);
    _updateItemState(item);

    _tryRunNextInQueue();
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

    // We skip the queue because it depends on elements that depend on the queue
    // If we start 10 playlists at the same time, the queue will be full and the playlist will not be able to download the songs
    // The songs themselves are each their own download item so they will be queued
    _beginBackgroundOperation(skipQueue: true, item, () async {
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
  final Completer<DownloadResult> _completer = Completer();

  Future<DownloadResult> get future => _completer.future;

  String name;
  String statusMessage = "loading";

  String? urlIcon;
  Uint8List? downloadedIcon;

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
