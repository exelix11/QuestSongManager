import 'dart:typed_data';
import 'dart:convert';

class Song {
  final String folderPath;
  final String infoFileName;
  final BeatSaberSongInfo meta;
  final bool isValid;
  String? hash;

  String get shortFolderName =>
      folderPath.substring(folderPath.lastIndexOf("/") + 1);

  Song(this.folderPath, this.infoFileName, this.isValid, this.meta);

  factory Song.create(
      String folderPath, String infoFileName, BeatSaberSongInfo meta) {
    return Song(folderPath, infoFileName, true, meta);
  }

  factory Song.fromError(String folderPath, String error, String identifier) {
    return Song(
        folderPath, "error", false, BeatSaberSongInfo("Error: $error", "", []))
      ..hash = identifier;
  }
}

class BeatSaberSongInfo {
  final String songName;
  final String coverImageFilename;
  final List<String> fileNames;

  factory BeatSaberSongInfo.fromJson(Map<String, dynamic> json) {
    return BeatSaberSongInfo(
      json['_songName'] as String,
      json['_coverImageFilename'] as String,
      (json['_difficultyBeatmapSets'] as List)
          .expand((e) => e["_difficultyBeatmaps"] as List)
          .map((e) => e["_beatmapFilename"] as String)
          .toList(),
    );
  }

  BeatSaberSongInfo(this.songName, this.coverImageFilename, this.fileNames);
}

class PlayListSong {
  final String hash;
  final String songName;

  PlayListSong(this.hash, this.songName);

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
    );
  }

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'songName': songName,
      };
}

class Playlist {
  String fileName = "new_playlist.json";

  String? imageString;
  String playlistTitle = "new playlist";
  String playlistAuthor = "unknown";
  List<PlayListSong> songs = [];

  Uint8List? imageBytes;

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
      ..playlistTitle = json['playlistTitle'] as String
      ..playlistAuthor = json['playlistAuthor'] as String
      ..imageString = json['imageString'] as String?
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
        'songs': songs.map((e) => e.toJson()).toList(),
      };
}
