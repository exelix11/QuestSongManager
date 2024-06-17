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

  bool useHashCache() {
    return _prefs.getBool('use_hash_cache') ?? true;
  }

  void setUseHashCache(bool value) async {
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
    setWebBookmarks(_getDefaults());
  }

  BrowserPreferences getWebBookmarks() {
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

  void setWebBookmarks(BrowserPreferences settings) {
    _prefs.setString("web_preferences", jsonEncode(settings.toJson()));
  }

  void setPreferredCustomSongFolder(PreferredCustomSongFolder folder) {
    _prefs.setString("preferred_custom_song_folder", folder.toString());
  }

  PreferredCustomSongFolder getPreferredCustomSongFolder() {
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

  String? getGameRootPath() {
    var path = _prefs.getString("game_root_path");
    if (path == null) return null;
    if (path.isEmpty) return null;
    return path;
  }

  void setGameRootPath(String path) {
    _prefs.setString("game_root_path", path);
  }

  void setAutoDownloadPlaylist(String? name) {
    _prefs.setString("auto_download_playlist", name ?? "");
  }

  String? getAutoDownloadPlaylist() {
    var path = _prefs.getString("auto_download_playlist");
    if (path == null) return null;
    if (path.isEmpty) return null;
    return path;
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
