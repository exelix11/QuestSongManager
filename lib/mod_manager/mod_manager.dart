import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bsaberquest/main.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as dart_path;

import 'model/playlist.dart';
import 'model/song.dart';

enum CustomLevelLocation {
  // "legacy", used in old versions of songLoader but compatible with all versions
  songLoader,
  // New starting from mods for beat saber 1.35
  songCore
}

abstract class PathProvider {
  List<String> get songPaths;
  List<String> get playlistPaths;

  String get installSongPath => songPaths[0];
  String get installPlaylistPath => playlistPaths[0];
}

class QuestPaths extends PathProvider {
  // These are currently both supported but only SongLoader works on older beatsaber versions ( < 1.35)
  // https://github.com/raineio/Quest-SongCore/blob/main/include/config.hpp
  final String _songLoaderlevelsPath = "Mods/SongLoader/CustomLevels";
  final String _songCoreLevelsPath = "Mods/SongCore/CustomLevels";

  @override
  List<String> get songPaths => [_songCoreLevelsPath, _songLoaderlevelsPath];

  @override
  List<String> get playlistPaths => ["Mods/PlaylistManager/Playlists"];

  CustomLevelLocation preferredInstallLocation = CustomLevelLocation.songCore;

  @override
  String get installSongPath =>
      preferredInstallLocation == CustomLevelLocation.songLoader
          ? _songLoaderlevelsPath
          : _songCoreLevelsPath;
}

class PcPaths extends PathProvider {
  @override
  List<String> get songPaths => [
        "Beat Saber_Data/CustomLevels",
        "Beat Saber_Data/CustomMultiplayerLevels"
      ];

  @override
  List<String> get playlistPaths => ["Playlists"];

  @override
  String get installSongPath => songPaths[0];
}

class ModManager {
  final String _hashCacheFileName = ".bsq_hash_cache";
  final PathProvider paths;
  final String gameRoot;

  bool _isInitialized = false;

  // Indexed by hash
  Map<String, Song> songs = {};
  // Indexed by file name
  Map<String, Playlist> playlists = {};
  // Indexed by file name
  Map<String, ErrorPlaylist> errorPlaylists = {};

  bool useFastHashCache = true;

  final StreamController songListObservable = StreamController.broadcast();
  final StreamController playlistObservable = StreamController.broadcast();

  ModManager(this.gameRoot) : paths = App.isQuest ? QuestPaths() : PcPaths();

  Future<Song> _loadSongFile(File file) async {
    var info = await file.readAsString();
    var metadata = BeatSaberSongInfo.fromJson(jsonDecode(info));
    var infoFileName = dart_path.basename(file.path);
    var folderPath = file.parent.path;
    var hash = await _hashSong(folderPath, infoFileName, metadata);
    var song = Song.create(hash, folderPath, infoFileName, metadata);
    return song;
  }

  Future<Playlist> _loadPlaylistFile(File file) async {
    var playlist = Playlist.fromJson(jsonDecode(await file.readAsString()));
    playlist.fileName = dart_path.basename(file.path);
    return playlist;
  }

  Future removeCachedHashes() async {
    useFastHashCache = false;
    for (var song in songs.values) {
      var hashFile = File("${song.folderPath}/$_hashCacheFileName");
      if (await hashFile.exists()) {
        await hashFile.delete();
      }
    }
  }

  Future reloadIfNeeded() async {
    if (!_isInitialized) {
      await reloadFromDisk();
    }
  }

  Future<int> _loadFrominstallLocation(
      String location, int invalidCounter) async {
    var customLevelsDir = Directory("$gameRoot/$location");
    if (!await customLevelsDir.exists()) {
      return invalidCounter;
    }

    for (var entity in customLevelsDir.listSync()) {
      if (entity is Directory) {
        var infoFile = File("${entity.path}/info.dat");

        if (!await infoFile.exists()) {
          infoFile = File("${entity.path}/Info.dat");
        }

        if (await infoFile.exists()) {
          Song song;
          try {
            song = await _loadSongFile(infoFile);
          } catch (e) {
            // if this is a file permission error throw, otherwise handle gracefully
            if (e is FileSystemException && e.osError?.errorCode == 13) {
              rethrow;
            }

            song = Song.fromError(
                entity.path, e.toString(), "invalid_${invalidCounter++}");
          }
          songs[song.hash] = song;
        }
      }
    }

    return invalidCounter;
  }

  Future _loadPlaylistsFromLocation(String location) async {
    var playlistsDir = Directory("$gameRoot/$location");
    if (!await playlistsDir.exists()) {
      await playlistsDir.create(recursive: true);
    }

    for (var entity in playlistsDir.listSync()) {
      if (entity is File) {
        // Only use lwPath here and not to store the file for platforms where file casing matters
        var lwPath = entity.path.toLowerCase();
        if (!lwPath.endsWith(".json") && !lwPath.endsWith(".bplist")) {
          continue;
        }

        Playlist playlist;
        try {
          playlist = await _loadPlaylistFile(entity);
          playlists[playlist.fileName] = playlist;
        } catch (e) {
          var name = dart_path.basename(entity.path);
          errorPlaylists[name] = ErrorPlaylist(name, name, e.toString());
        }
      }
    }
  }

  Future reloadFromDisk() async {
    songs.clear();
    playlists.clear();
    errorPlaylists.clear();

    var invalid = 0;

    for (var path in paths.songPaths) {
      invalid += await _loadFrominstallLocation(path, invalid);
    }

    for (var path in paths.playlistPaths) {
      await _loadPlaylistsFromLocation(path);
    }

    _isInitialized = true;
    songListObservable.sink.add(null);
    playlistObservable.sink.add(null);
  }

  Future<String?> _tryGetCachedHash(String songFolderPath) async {
    if (useFastHashCache) {
      var hashFile = File("$songFolderPath/$_hashCacheFileName");
      if (await hashFile.exists()) {
        var hash = await hashFile.readAsString();

        if (hash.length == 40) {
          return hash.toLowerCase();
        }
      }
    }

    return null;
  }

  Future _writeCachedHash(String folderPath, String hash) async {
    if (useFastHashCache) {
      var hashFile = File("$folderPath/$_hashCacheFileName");
      await hashFile.writeAsString(hash);
    }
  }

  Future<String> _hashSongFromDiskFiles(
      String folderPath, String infoFileName, BeatSaberSongInfo meta) async {
    var content = [
      await File("$folderPath/$infoFileName").readAsBytes(),
      for (var file in meta.fileNames)
        await File("$folderPath/$file").readAsBytes()
    ];

    return hashSongInfo(content);
  }

  Future<String> _hashSong(
      String songPath, String infoFileName, BeatSaberSongInfo meta) async {
    var hash = await _tryGetCachedHash(songPath);

    if (hash != null) {
      return hash;
    }

    hash = await _hashSongFromDiskFiles(songPath, infoFileName, meta);

    await _writeCachedHash(songPath, hash);

    return hash;
  }

  Future<bool> checkSongHash(Song song) async {
    var diskHash = await _hashSongFromDiskFiles(
        song.folderPath, song.infoFileName, song.meta);

    if (diskHash != song.hash) {
      var oldHash = song.hash;
      song.hash = diskHash;
      await _writeCachedHash(song.folderPath, song.hash);

      if (songs.containsKey(oldHash)) {
        songs.remove(oldHash);
        songs[diskHash] = song;
        songListObservable.sink.add(null);
      }

      return false;
    }

    return true;
  }

  String hashSongInfo(List<Uint8List> content) {
    var sink = AccumulatorSink<crypto.Digest>();
    var hash = crypto.sha1.startChunkedConversion(sink);

    for (var file in content) {
      hash.add(file);
    }

    hash.close();
    return sink.events.single.toString().toLowerCase();
  }

  bool hasSong(String hash) {
    return songs.containsKey(hash);
  }

  Future _ensureInstallLocationExists() async {
    var dir = Directory("$gameRoot/${paths.installSongPath}");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future _ensurePlaylistLocationExists() async {
    var dir = Directory("$gameRoot/${paths.installPlaylistPath}");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future replaceSongInPlaylists(String oldHash, String newHash) async {
    var newSong = songs[newHash];
    if (newSong == null) {
      throw Exception("New song not found");
    }

    for (var playlist in playlists.values) {
      bool replaced = false;

      for (var i = 0; i < playlist.songs.length; i++) {
        if (playlist.songs[i].hash == oldHash) {
          replaced = true;
          playlist.songs[i] = PlayListSong(newSong.hash, newSong.meta.songName);
        }
      }

      if (replaced) {
        await applyPlaylistChanges(playlist);
      }
    }
  }

  Future _handleSongUpdate(String oldHash, String newHash) async {
    var old = songs[oldHash];

    // We might not have the old song but playlists that reference it
    // eg when the user clicks on download song from a playlist with the old hash
    await replaceSongInPlaylists(oldHash, newHash);

    if (old == null) {
      return;
    }

    await _deleteSingleSong(old, _PlaylistHandling.none);
  }

  Future<Song> installSong(
      Map<String, Uint8List> unpackedFiles, String? expectedHash) async {
    await reloadIfNeeded();
    await _ensureInstallLocationExists();

    var info = unpackedFiles["info.dat"];
    info ??= unpackedFiles["Info.dat"];

    if (info == null) {
      throw Exception("Failed to find info.dat in map");
    }

    var bsInfo = BeatSaberSongInfo.fromJson(jsonDecode(utf8.decode(info)));

    List<Uint8List> ordered = [];
    ordered.add(info);
    for (var file in bsInfo.fileNames) {
      if (unpackedFiles.containsKey(file)) {
        ordered.add(unpackedFiles[file]!);
      }
    }

    var hash = hashSongInfo(ordered);
    if (songs.containsKey(hash)) {
      throw Exception("Song with hash $hash already exists");
    }

    var directory = Directory("$gameRoot/${paths.installSongPath}/$hash");
    if (await directory.exists()) {
      throw Exception("Song with hash $hash already exists on disk");
    }

    await directory.create(recursive: true);

    try {
      for (var file in unpackedFiles.entries) {
        var f = File("${directory.path}/${file.key}");
        await f.writeAsBytes(file.value);
      }
    } catch (e) {
      String error = "Failed to install song: $e";

      try {
        await directory.delete(recursive: true);
      } catch (e) {
        error += "\nFailed to cleanup : $e";
      }

      throw Exception(error);
    }

    var song = Song.create(
        hash, directory.path, dart_path.basename(directory.path), bsInfo);

    try {
      await _writeCachedHash(song.folderPath, song.hash);
    } catch (e) {
      // It is safe to ignore this
    }

    songs[song.hash] = song;

    // When we are expecting a hash different than the one we calculated, it's probably because a song was updated
    // Update all its references in playlists and remove the old song
    if (expectedHash != null && hash != expectedHash) {
      await _handleSongUpdate(expectedHash, hash);
    }

    songListObservable.sink.add(null);
    return song;
  }

  List<Playlist> findPlaylistsBySong(Song song) {
    return playlists.values
        .where((element) => element.songs.any((x) => x.hash == song.hash))
        .toList();
  }

  // Delete a song and remove it from all playlists, but don't save the playlists
  Future<List<Playlist>> _deleteSingleSong(
      Song song, _PlaylistHandling handlePlaylists) async {
    // Get the song from our list to ensure we know it exists
    song = songs[song.hash]!;

    var dir = Directory(song.folderPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }

    songs.remove(song.hash);

    if (handlePlaylists == _PlaylistHandling.none) {
      return [];
    }

    var affectedPlaylists = findPlaylistsBySong(song);

    for (var playlist in affectedPlaylists) {
      playlist.songs.removeWhere((element) => element.hash == song.hash);
    }

    return affectedPlaylists;
  }

  // Apply changes to a playlist and save it to disk but don't notify the UI
  Future _internalApplyPlaylistChanges(Playlist playlist) async {
    await reloadIfNeeded();
    await _ensurePlaylistLocationExists();

    if (!playlists.containsKey(playlist.fileName)) {
      throw Exception(
          "Playlist with name ${playlist.playlistTitle} does not exist");
    }

    var file =
        File("$gameRoot/${paths.installPlaylistPath}/${playlist.fileName}");
    await file.writeAsString(jsonEncode(playlist.toJson()));

    // Since we wrote the playlist file from scratch, we can assume it's up to date
    playlist.imageCompatibilityIssue = false;
  }

  Future deleteSongs(Iterable<Song> songs) async {
    await reloadIfNeeded();

    Set<Playlist> affectedPlaylists = {};

    var handlePlaylist = App.preferences.removeFromPlaylistOnSongDelete
        ? _PlaylistHandling.remove
        : _PlaylistHandling.none;

    for (var song in songs) {
      affectedPlaylists.addAll(await _deleteSingleSong(song, handlePlaylist));
    }

    // Notify the UI only once
    songListObservable.sink.add(null);

    if (affectedPlaylists.isEmpty) {
      return;
    }

    // Save all the playlists that were affected and notify only once
    for (var playlist in affectedPlaylists) {
      await _internalApplyPlaylistChanges(playlist);
    }

    playlistObservable.sink.add(null);
  }

  Future deleteSong(Song song) async {
    return deleteSongs([song]);
  }

  String _playlistNameToFileName(String name) {
    var filename = "${name.replaceAll(" ", "_")}.bplist_BMBF.json";
    return filename;
  }

  Future<Playlist?> getPlaylistByName(String name) async {
    await reloadIfNeeded();

    var filename = _playlistNameToFileName(name);
    if (!playlists.containsKey(filename)) {
      return null;
    }

    return playlists[filename];
  }

  Future<bool> isPlaylistNameFree(String name) async {
    await reloadIfNeeded();

    var filename = _playlistNameToFileName(name);
    if (playlists.containsKey(filename)) {
      return false;
    }

    // Maybe the file exists but we did not load it (eg exception during load)
    var file = File("$gameRoot/${paths.installPlaylistPath}/$filename");
    if (await file.exists()) {
      return false;
    }

    return true;
  }

  Future addPlaylist(Playlist playlist) async {
    await reloadIfNeeded();
    await _ensurePlaylistLocationExists();

    var name = playlist.playlistTitle;

    if (name.isEmpty) {
      throw Exception("Playlist name cannot be empty");
    }

    var filename = _playlistNameToFileName(name);

    if (playlists.containsKey(filename)) {
      throw Exception("Playlist with name $name already exists");
    }

    var file = File("$gameRoot/${paths.installPlaylistPath}/$filename");
    if (await file.exists()) {
      throw Exception("Playlist file with name $name already exists");
    }

    playlist.fileName = filename;
    playlists[filename] = playlist;
    await file.writeAsString(jsonEncode(playlist.toJson()));
    playlistObservable.sink.add(null);
  }

  Future<Playlist> createPlaylist(String name) async {
    var playlist = Playlist()..playlistTitle = name;

    await addPlaylist(playlist);

    return playlist;
  }

  Future applyMultiplePlaylistChanges(List<Playlist> playlists) async {
    for (var p in playlists) {
      await _internalApplyPlaylistChanges(p);
    }
    // Fire the event only once
    playlistObservable.sink.add(null);
  }

  Future applyPlaylistChanges(Playlist playlist) async {
    await _internalApplyPlaylistChanges(playlist);
    playlistObservable.sink.add(null);
  }

  Future deletePlaylist(Playlist playlist) async {
    await reloadIfNeeded();

    if (!playlists.containsKey(playlist.fileName)) {
      throw Exception(
          "Playlist with name ${playlist.playlistTitle} does not exist");
    }

    var file =
        File("$gameRoot/${paths.installPlaylistPath}/${playlist.fileName}");
    if (!await file.exists()) {
      throw Exception(
          "Playlist file with name ${playlist.playlistTitle} does not exist");
    }

    await file.delete();

    playlists.remove(playlist.fileName);

    playlistObservable.sink.add(null);
  }

  CustomLevelLocation? getLocationForSong(Song song) {
    return CustomLevelLocation.songCore;
    // if (song.folderPath.startsWith("$gameRoot/$_songLoaderlevelsPath")) {
    //   return CustomLevelLocation.songLoader;
    // } else if (song.folderPath.startsWith("$gameRoot/$_songCoreLevelsPath")) {
    //   return CustomLevelLocation.songCore;
    // }

    // return null;
  }
}

enum _PlaylistHandling { remove, none }
