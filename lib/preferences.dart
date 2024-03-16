import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PreferencesManager {
  Future<bool> isFirstLaunchPermissionRequested() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var res = prefs.getBool('first_launch_permission_requested') ?? false;
    if (!res) {
      prefs.setBool('first_launch_permission_requested', true);
    }
    return res;
  }

  Future<bool> useHashCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('use_hash_cache') ?? true;
  }

  Future setUseHashCache(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('use_hash_cache', value);
  }

  BrowserPreferences _getDefaults() {
    return BrowserPreferences()
      ..bookmarks = [
        WebBookmark('bsaber.com', 'https://bsaber.com/'),
        WebBookmark('beatsaver.com', 'https://beatsaver.com/'),
      ];
  }

  Future resetWebBookmarks() async {
    await setWebBookmarks(_getDefaults());
  }

  Future<BrowserPreferences> getWebBookmarks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? bookmarks = prefs.getString('web_preferences');

    if (bookmarks == null) {
      return _getDefaults();
    }

    try {
      return BrowserPreferences.fromJson(jsonDecode(bookmarks));
    } catch (e) {
      return _getDefaults();
    }
  }

  Future setWebBookmarks(BrowserPreferences settings) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("web_preferences", jsonEncode(settings.toJson()));
  }
}

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
