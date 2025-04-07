import 'dart:typed_data';
import 'dart:convert';

import '../../main.dart';
import 'song.dart';

class PlayListSong {
  final String? key;
  final String hash;
  final String songName;

  // When loading playlists from json, preserve additional attributes we don't support such as difficulties
  final Map<String, dynamic> _extraJsonAttributes = {};

  BeatSaberSongInfo? _info;

  // Lazily try to get additional song info if we have the song
  BeatSaberSongInfo? get meta => _info ??= App.modManager.songs[hash]?.meta;

  PlayListSong(this.hash, this.songName, {this.key});

  factory PlayListSong.fromSong(Song song) {
    if (!song.isValid) {
      throw Exception("This song is not valid");
    }

    return PlayListSong(song.hash, song.meta.songName);
  }

  factory PlayListSong.fromJson(Map<String, dynamic> json) {
    var p = PlayListSong(
      (json['hash'] as String).toLowerCase(),
      json['songName'] as String,
      key: json['key'] as String?,
    );

    for (var entry in json.entries) {
      if (entry.key == "hash" ||
          entry.key == "songName" ||
          entry.key == "key") {
        continue;
      }

      p._extraJsonAttributes[entry.key] = entry.value;
    }

    return p;
  }

  bool query(String query) {
    return songName.toLowerCase().contains(query) ||
        (meta?.query(query) ?? false);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> obj = {
      'hash': hash,
      'songName': songName,
      'key': key,
    };

    obj.addEntries(_extraJsonAttributes.entries);

    return obj;
  }
}

class Playlist {
  String fileName = "new_playlist.json";

  String playlistTitle = "new playlist";
  String playlistAuthor = "unknown";
  String? playlistDescription;
  List<PlayListSong> songs = [];

  Uint8List? imageBytes;
  bool imageCompatibilityIssue = false;

  Map<String, dynamic>? customData;

  String? get syncUrl => customData?['syncURL'] as String?;

  set syncUrl(String? value) {
    customData ??= {};
    customData!['syncURL'] = value;
  }

  Playlist();

  void fromAnotherInstance(Playlist other) {
    playlistTitle = other.playlistTitle;
    playlistAuthor = other.playlistAuthor;
    playlistDescription = other.playlistDescription;
    songs = List.from(other.songs);
    imageBytes = other.imageBytes;
    imageCompatibilityIssue = other.imageCompatibilityIssue;
    customData = other.customData;
  }

  void add(Song song) {
    if (songs.any((element) => element.hash == song.hash)) {
      return;
    }

    songs.add(PlayListSong.fromSong(song));
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    // Beat saber on quest uses imageString while the pc version uses image
    var image = json['imageString'] as String? ?? json['image'] as String?;

    var p = Playlist()
      ..playlistTitle = json['playlistTitle'] as String? ?? "unknown name"
      ..playlistAuthor = json['playlistAuthor'] as String? ?? "unknown"
      ..playlistDescription = json['playlistDescription'] as String?
      ..customData = json['customData'] as Map<String, dynamic>?;

    for (Map<String, dynamic> song in json['songs'] as List) {
      if (song.containsKey("hash") && song.containsKey("songName")) {
        p.songs.add(PlayListSong.fromJson(song));
      }
    }

    if (image != null) {
      // The pc version prepends base64, to the image string
      if (image.startsWith("base64,")) {
        image = image.substring("base64,".length);
      }
      p.imageBytes = base64Decode(image);

      // When we are using the wrong image format, show a warning
      if (App.isQuest && !json.containsKey("imageString")) {
        p.imageCompatibilityIssue = true;
      } else if (!App.isQuest && !json.containsKey("image")) {
        p.imageCompatibilityIssue = true;
      }
    }

    return p;
  }

  bool query(String query) {
    return playlistTitle.toLowerCase().contains(query) ||
        playlistAuthor.toLowerCase().contains(query) ||
        (playlistDescription?.toLowerCase().contains(query) ?? false);
  }

  Map<String, dynamic> toJson() {
    var obj = {
      'playlistTitle': playlistTitle,
      'playlistAuthor': playlistAuthor,
      'playlistDescription': playlistDescription,
      'songs': songs.map((e) => e.toJson()).toList(),
    };

    if (customData?.isNotEmpty ?? false) {
      obj['customData'] = customData;
    }

    if (imageBytes != null) {
      var encodedImage = base64Encode(imageBytes!);
      // Save the image in a way that is compatible with the current platform
      if (App.isQuest) {
        obj['imageString'] = encodedImage;
      } else {
        obj['image'] = "base64,$encodedImage";
      }
    }

    return obj;
  }
}

class ErrorPlaylist {
  final String error;
  final String fileName;
  final String displayName;

  ErrorPlaylist(this.displayName, this.fileName, this.error);
}
