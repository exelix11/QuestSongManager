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
