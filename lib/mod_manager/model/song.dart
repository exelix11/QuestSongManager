import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

class Song {
  final String folderPath;
  final String infoFileName;
  final BeatSaberSongInfo meta;
  final bool isValid;
  String? hash;

  String prettyMetaInfo() {
    var info = "";

    if (meta.songSubName != null) {
      info += meta.songSubName!;
    }
    if (meta.songAuthorName != null) {
      if (info.isNotEmpty) {
        info += "\n";
      }
      info += meta.songAuthorName!;
    }
    if (meta.levelAuthorName != null) {
      if (info.isNotEmpty) {
        info += "\n";
      }
      info += meta.levelAuthorName!;
    }

    return info;
  }

  Song(this.folderPath, this.infoFileName, this.isValid, this.meta);

  factory Song.create(
      String folderPath, String infoFileName, BeatSaberSongInfo meta) {
    return Song(folderPath, infoFileName, true, meta);
  }

  factory Song.fromError(String folderPath, String error, String identifier) {
    return Song(folderPath, "error", false,
        BeatSaberSongInfo("Error: $error", "", null, null, null, []))
      ..hash = identifier;
  }
}

class BeatSaberSongInfo {
  final String songName;
  final String? coverImageFilename;

  final String? songSubName;
  final String? songAuthorName;
  final String? levelAuthorName;

  final List<String> fileNames;

  bool query(String query) {
    if (songName.toLowerCase().contains(query)) {
      return true;
    }

    if (songSubName != null && songSubName!.toLowerCase().contains(query)) {
      return true;
    }

    if (songAuthorName != null &&
        songAuthorName!.toLowerCase().contains(query)) {
      return true;
    }

    if (levelAuthorName != null &&
        levelAuthorName!.toLowerCase().contains(query)) {
      return true;
    }

    return false;
  }

  factory BeatSaberSongInfo.fromJson(Map<String, dynamic> json) {
    return BeatSaberSongInfo(
      json['_songName'] as String,
      json['_coverImageFilename'] as String?,
      json['_songSubName'] as String?,
      json['_songAuthorName'] as String?,
      json['_levelAuthorName'] as String?,
      (json['_difficultyBeatmapSets'] as List)
          .expand((e) => e["_difficultyBeatmaps"] as List)
          .map((e) => e["_beatmapFilename"] as String)
          .toList(),
    );
  }

  BeatSaberSongInfo(this.songName, this.coverImageFilename, this.songSubName,
      this.songAuthorName, this.levelAuthorName, this.fileNames);
}

class PlayListSong {
  final String? key;
  final String hash;
  final String songName;

  PlayListSong(this.hash, this.songName, {this.key});

  factory PlayListSong.fromSong(Song song) {
    if (song.hash == null) {
      throw Exception("Song must be hashed before adding to playlist");
    }

    if (!song.isValid) {
      throw Exception("This song is not valid");
    }

    return PlayListSong(song.hash!, song.meta.songName);
  }

  factory PlayListSong.fromJson(Map<String, dynamic> json) {
    return PlayListSong(
      json['hash'] as String,
      json['songName'] as String,
      key: json['key'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'songName': songName,
        'key': key,
      };
}

class Playlist {
  String fileName = "new_playlist.json";

  String? imageString;
  String playlistTitle = "new playlist";
  String playlistAuthor = "unknown";
  String? playlistDescription;
  List<PlayListSong> songs = [];

  Uint8List? imageBytes;

  Map<String, dynamic>? customData;

  Playlist();

  void add(Song song) {
    if (song.hash == null) {
      throw Exception("Song must be hashed before adding to playlist");
    }

    if (songs.any((element) => element.hash == song.hash)) {
      return;
    }

    songs.add(PlayListSong.fromSong(song));
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    var p = Playlist()
      ..playlistTitle = json['playlistTitle'] as String? ?? "unknown name"
      ..playlistAuthor = json['playlistAuthor'] as String? ?? "unknown"
      ..playlistDescription = json['playlistDescription'] as String?
      // api.beatsaver.com uses image rather than imageString
      ..imageString = json['imageString'] as String? ?? json['image'] as String?
      ..customData = json['customData'] as Map<String, dynamic>?
      ..songs = (json['songs'] as List)
          .map((e) => PlayListSong.fromJson(e as Map<String, dynamic>))
          .toList();

    if (p.imageString != null) {
      p.imageBytes = base64Decode(p.imageString!);
    }

    return p;
  }

  Map<String, dynamic> toJson() => {
        'playlistTitle': playlistTitle,
        'playlistAuthor': playlistAuthor,
        'imageString': imageString,
        'customData': customData,
        'playlistDescription': playlistDescription,
        'songs': songs.map((e) => e.toJson()).toList(),
      };
}
