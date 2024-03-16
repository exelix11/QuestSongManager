import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PreferencesManager {
  Future<bool> useHashCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('use_hash_cache') ?? true;
  }

  Future setUseHashCache(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('use_hash_cache', value);
  }

  List<WebBookmark> _getDefaults() {
    return [
      WebBookmark('bsaber.com', 'https://bsaber.com/'),
      WebBookmark('beatsaver.com', 'https://beatsaver.com/'),
    ];
  }

  Future resetWebBookmarks() async {
    await setWebBookmarks(_getDefaults());
  }

  Future<List<WebBookmark>> getWebBookmarks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? bookmarks = prefs.getStringList('web_bookmarks');

    if (bookmarks == null) {
      return _getDefaults();
    }

    try {
      return bookmarks.map((e) => WebBookmark.fromJson(e)).toList();
    } catch (e) {
      return _getDefaults();
    }
  }

  Future setWebBookmarks(List<WebBookmark> bookmarks) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
        'web_bookmarks', bookmarks.map((e) => '${e.title} ${e.url}').toList());
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
