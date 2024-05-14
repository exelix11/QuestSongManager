import 'dart:typed_data';
import 'dart:convert';

import 'song.dart';

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
