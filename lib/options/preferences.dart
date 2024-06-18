import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PreferencesManager {
  late SharedPreferences _prefs;

  Future init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool isFirstLaunchPermissionRequested() {
    var res = _prefs.getBool('first_launch_permission_requested') ?? false;
    if (!res) {
      _prefs.setBool('first_launch_permission_requested', true);
    }
    return res;
  }

  bool get useHashCache {
    return _prefs.getBool('use_hash_cache') ?? true;
  }

  set useHashCache(bool value) {
    _prefs.setBool('use_hash_cache', value);
  }

  BrowserPreferences _getDefaults() {
    return BrowserPreferences()
      ..bookmarks = [
        WebBookmark('bsaber.info', 'https://bsaber.info/'),
        WebBookmark('beatsaver.com', 'https://beatsaver.com/'),
      ];
  }

  void resetWebBookmarks() {
    webBookmarks = _getDefaults();
  }

  BrowserPreferences get webBookmarks {
    String? bookmarks = _prefs.getString('web_preferences');

    if (bookmarks == null) {
      return _getDefaults();
    }

    try {
      return BrowserPreferences.fromJson(jsonDecode(bookmarks));
    } catch (e) {
      return _getDefaults();
    }
  }

  set webBookmarks(BrowserPreferences settings) {
    _prefs.setString("web_preferences", jsonEncode(settings.toJson()));
  }

  set preferredCustomSongFolder(PreferredCustomSongFolder folder) {
    _prefs.setString("preferred_custom_song_folder", folder.toString());
  }

  PreferredCustomSongFolder get preferredCustomSongFolder {
    String? folder = _prefs.getString("preferred_custom_song_folder");

    if (folder == null) {
      return PreferredCustomSongFolder.auto;
    }

    try {
      return PreferredCustomSongFolder.values
          .firstWhere((element) => element.toString() == folder);
    } catch (e) {
      return PreferredCustomSongFolder.auto;
    }
  }

  String? get gameRootPath {
    var path = _prefs.getString("game_root_path");
    if (path == null) return null;
    if (path.isEmpty) return null;
    return path;
  }

  set gameRootPath(String? path) {
    _prefs.setString("game_root_path", path ?? "");
  }

  set autoDownloadPlaylist(String? name) {
    _prefs.setString("auto_download_playlist", name ?? "");
  }

  String? get autoDownloadPlaylist {
    var path = _prefs.getString("auto_download_playlist");
    if (path == null) return null;
    if (path.isEmpty) return null;
    return path;
  }

  bool get removeFromPlaylistOnSongDelete {
    return _prefs.getBool("auto_remove_songs_on_delete") ?? false;
  }

  set removeFromPlaylistOnSongDelete(bool value) {
    _prefs.setBool("auto_remove_songs_on_delete", value);
  }

  BeatSaverSession? get beatSaverSession {
    var session = _prefs.getString("beatsaver_session");
    if (session == null) return null;
    try {
      return BeatSaverSession.fromJson(jsonDecode(session));
    } catch (e) {
      return null;
    }
  }

  set beatSaverSession(BeatSaverSession? session) {
    if (session == null) {
      _prefs.remove("beatsaver_session");
    } else {
      _prefs.setString("beatsaver_session", jsonEncode(session.toJson()));
    }
  }
}

enum PreferredCustomSongFolder { auto, songLoader, songCore }

class BrowserPreferences {
  List<WebBookmark> bookmarks = [];
  String? homepage;

  BrowserPreferences();

  int getHomepageIndex() {
    if (bookmarks.isEmpty) {
      return -1;
    }

    if (homepage == null) {
      return 0;
    }

    try {
      return bookmarks.indexWhere((element) => element.url == homepage);
    } catch (e) {
      return 0;
    }
  }

  WebBookmark? getHomepage() {
    var index = getHomepageIndex();
    if (index == -1) {
      return null;
    }

    return bookmarks[index];
  }

  factory BrowserPreferences.fromJson(Map<String, dynamic> json) {
    var prefs = BrowserPreferences();
    prefs.bookmarks = (json['bookmarks'] as List)
        .map((e) => WebBookmark.fromJson(e))
        .toList();
    prefs.homepage = json['homepage'];
    return prefs;
  }

  Map<String, dynamic> toJson() {
    return {
      'bookmarks': bookmarks.map((e) => e.toJson()).toList(),
      'homepage': homepage
    };
  }
}

class WebBookmark {
  final String title;
  final String url;

  WebBookmark(this.title, this.url);

  String toJson() {
    return jsonEncode({'title': title, 'url': url});
  }

  factory WebBookmark.fromJson(String json) {
    Map<String, dynamic> map = jsonDecode(json);
    return WebBookmark(map['title'], map['url']);
  }
}

class BeatSaverSession {
  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiration;

  BeatSaverSession(
      {required this.accessToken,
      required this.refreshToken,
      required this.accessExpiration});

  factory BeatSaverSession.fromJson(Map<String, dynamic> json) {
    return BeatSaverSession(
        accessToken: json['access_token'],
        refreshToken: json['refresh_token'],
        accessExpiration: DateTime.parse(json['access_expiration']));
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'access_expiration': accessExpiration.toIso8601String()
    };
  }
}
