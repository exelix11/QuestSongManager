class Song {
  final String folderPath;
  final String infoFileName;
  final BeatSaberSongInfo meta;
  final bool isValid;

  late String _hash;

  String get hash => _hash;

  String? get iconPath => !isValid || (meta.coverImageFilename?.isEmpty ?? true)
      ? null
      : "$folderPath/${meta.coverImageFilename}";

  set hash(String value) {
    _hash = value.toLowerCase();
  }

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

  Song(String hash, this.folderPath, this.infoFileName, this.isValid,
      this.meta) {
    this.hash = hash;
  }

  factory Song.create(String hash, String folderPath, String infoFileName,
      BeatSaberSongInfo meta) {
    return Song(hash, folderPath, infoFileName, true, meta);
  }

  factory Song.fromError(String folderPath, String error, String identifier) {
    return Song(identifier, folderPath, "error", false,
        BeatSaberSongInfo("Error: $error", "", null, null, null, []));
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

  static fromJson(Map<String, dynamic> json) {
    if (json.containsKey('_songName')) {
      return BeatSaberSongInfo.fromJsonLegacy(json);
    }

    if (json.containsKey('song')) {
      return BeatSaberSongInfo.fromJsonV4(json);
    }

    throw Exception(
        "The song info JSON is not valid. It could be using an unsupported version.");
  }

  // TODO: This is very barebones, it's only a fix to allow downloading such songs, may need better support in the future.
  factory BeatSaberSongInfo.fromJsonV4(Map<String, dynamic> json) {
    return BeatSaberSongInfo(
      json['song']['title'] as String,
      json['coverImageFilename'] as String?,
      json['song']['subTitle'] as String?,
      json['song']['author'] as String?,
      null,
      (json['difficultyBeatmaps'] as List)
          .map((e) => e["beatmapDataFilename"] as String)
          .toList(),
    );
  }

  factory BeatSaberSongInfo.fromJsonLegacy(Map<String, dynamic> json) {
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
