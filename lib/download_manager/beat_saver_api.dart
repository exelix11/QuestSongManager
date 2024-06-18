import 'dart:async';
import 'dart:convert';

import 'package:bsaberquest/download_manager/oauth_config.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/model/playlist.dart';
import 'package:bsaberquest/options/preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BeatSaverClient {
  static const String _apiUri = "https://api.beatsaver.com";
  static const String _siteUri = "https://beatsaver.com";

  final RegExp _playlistSyncUrl =
      RegExp(r"^https?:\/\/api\.beatsaver\.com\/playlists\/id\/(\d+)\/");

  BeatSaverSession? _session;
  BeatSaverUserInfo? userInfo;

  StreamController<BeatSaverLoginNotification> loginStateObservable =
      StreamController<BeatSaverLoginNotification>.broadcast();

  final Map<String, String> _plainHeaders = {
    "User-Agent": "QuestSongManager/${App.versionName}"
  };

  final Map<String, String> _authHeaders = {
    "User-Agent": "QuestSongManager/${App.versionName}"
  };

  void _setAuthHeader(String? token) {
    if (_authHeaders.containsKey("Authorization")) {
      _authHeaders.remove("Authorization");
    }

    if (token == null) {
      return;
    }

    _authHeaders["Authorization"] = "Bearer $token";
  }

  static BeatSaverSession sessionFromOauthJson(String json) {
    var data = Map<String, dynamic>.from(jsonDecode(json));
    return BeatSaverSession(
        accessToken: data["access_token"],
        refreshToken: data["refresh_token"],
        accessExpiration:
            DateTime.now().add(Duration(seconds: data["expires_in"])));
  }

  Future _refreshSessionIfNeeded() async {
    try {
      if (!BeatSaverOauthConfig.isConfigured) {
        throw Exception("BeatSaver OAuth is not configured in this build");
      }

      if (_session == null) {
        return;
      }

      // If the session expires in more than 5 minutes, we don't need to refresh
      var exp = DateTime.now().add(const Duration(minutes: 5));
      if (_session!.accessExpiration.isAfter(exp)) {
        // Session is valid, no need to refresh
        return;
      }

      // Otherwise, we need to refresh the session
      var res = await http.post(Uri.parse("$_siteUri/api/oauth2/token"),
          headers: _plainHeaders,
          body: {
            "client_id": BeatSaverOauthConfig.clientId,
            "client_secret": BeatSaverOauthConfig.clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": _session!.refreshToken
          });

      if (res.statusCode != 200) {
        throw Exception("Failed to refresh session (${res.statusCode})");
      }

      _session = sessionFromOauthJson(res.body);

      _setAuthHeader(_session!.accessToken);

      App.preferences.beatSaverSession = _session;
    } catch (e) {
      logout(reason: e.toString());
    }
  }

  Future _fetchUserInformation() async {
    await _refreshSessionIfNeeded();

    if (_session == null) {
      return;
    }

    String userId;
    String userName;

    // First, get the user name and id
    try {
      var res = await http.get(Uri.parse("$_siteUri/api/oauth2/identity"),
          headers: _authHeaders);

      if (res.statusCode != 200) {
        throw Exception("Failed to get user information (${res.statusCode})");
      }

      var data = Map<String, dynamic>.from(jsonDecode(res.body));
      userId = data["id"];
      userName = data["name"];
    } catch (e) {
      logout(reason: e.toString());
      return;
    }

    // Next it would be nice if we could show the PFP
    String? avatarUrl;

    try {
      var user = await getUserById(userId);
      avatarUrl = user["avatar"];
    } catch (_) {
      // Ignore this one
    }

    userInfo =
        BeatSaverUserInfo(id: userId, username: userName, avatar: avatarUrl);

    loginStateObservable.add(BeatSaverLoginNotification(userInfo: userInfo));
  }

  void logout({String? reason}) {
    _session = null;
    userInfo = null;
    _setAuthHeader(null);
    App.preferences.beatSaverSession = null;
    loginStateObservable.add(BeatSaverLoginNotification(error: reason));
  }

  Future useSession(BeatSaverSession session) async {
    if (!BeatSaverOauthConfig.isConfigured) {
      return;
    }

    _session = session;
    _setAuthHeader(session.accessToken);
    await _fetchUserInformation();
  }

  Uri beginOauthLogin() {
    return Uri.parse(
        "$_siteUri/oauth2/authorize?response_type=code&client_id=${BeatSaverOauthConfig.clientId}&redirect_uri=${BeatSaverOauthConfig.REDIRECT_URL}");
  }

  Future finalizeOauthLogin(String code) async {
    logout();
    try {
      var res = await http.post(Uri.parse("$_siteUri/api/oauth2/token"),
          headers: _plainHeaders,
          body: {
            "client_id": BeatSaverOauthConfig.clientId,
            "client_secret": BeatSaverOauthConfig.clientSecret,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": BeatSaverOauthConfig.REDIRECT_URL
          });

      if (res.statusCode != 200) {
        throw Exception("Failed to finalize login (${res.statusCode})");
      }

      var session = sessionFromOauthJson(res.body);
      useSession(session);

      // If all went well, store the session
      App.preferences.beatSaverSession = _session;
    } catch (e) {
      // Pass the failure reason to any listeners too
      logout(reason: e.toString());
      rethrow;
    }
  }

  bool isBeatSaverUrl(String url) {
    var uri = Uri.parse(url);
    return uri.host == "beatsaver.com" || uri.host == "api.beatsaver.com";
  }

  Future<String> get(String url) async {
    // Do not accidentally leak the access token
    if (!isBeatSaverUrl(url)) {
      throw Exception("Invalid BeatSaver URL");
    }

    await _refreshSessionIfNeeded();

    var res = await http.get(Uri.parse(url), headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception("The server returned an error (${res.statusCode})");
    }

    return res.body;
  }

  Future<BeatSaverMapInfo> getMapById(String id) async {
    await _refreshSessionIfNeeded();

    var res = await http.get(Uri.parse("$_apiUri/maps/id/$id"),
        headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception("Failed to get map info (${res.statusCode})");
    }

    var map = Map<String, dynamic>.from(jsonDecode(res.body));
    return BeatSaverMapInfo.fromJson(map);
  }

  Future<BeatSaverMapInfo> getMapByHash(String hash) async {
    await _refreshSessionIfNeeded();

    var res = await http.get(Uri.parse("$_apiUri/maps/hash/$hash"),
        headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception("Failed to get map info (${res.statusCode})");
    }

    var map = Map<String, dynamic>.from(jsonDecode(res.body));
    return BeatSaverMapInfo.fromJson(map);
  }

  Future<List<BeatSaverMapInfo>> getMapsByHashes(List<String> hash) async {
    // rquests are limited to 50 hashes each so we must manually batch this
    List<BeatSaverMapInfo> ret = [];

    await _refreshSessionIfNeeded();

    for (var i = 0; i < hash.length;) {
      var step = hash.skip(i).take(50).toList();
      i += step.length;

      var query = step.join(",");
      var res = await http.get(Uri.parse("$_apiUri/maps/hash/$query"),
          headers: _authHeaders);

      if (res.statusCode != 200) {
        throw Exception("Failed to get map info (${res.statusCode})");
      }

      var list = Map<String, dynamic>.from(jsonDecode(res.body));
      ret.addAll(list.values
          .map((e) => BeatSaverMapInfo.fromJson(e as Map<String, dynamic>)));
    }

    return ret;
  }

  Future<Map<String, dynamic>> getUserById(String id) async {
    var res = await http.get(Uri.parse("$_apiUri/users/id/$id"),
        headers: _plainHeaders);
    if (res.statusCode != 200) {
      throw Exception("Failed to get user info (${res.statusCode})");
    }

    return jsonDecode(res.body);
  }

  bool isValidPlaylistForPush(Playlist playlist) {
    return _getPlaylistIdFromSyncUrl(playlist) != null;
  }

  String? _getPlaylistIdFromSyncUrl(Playlist playlist) {
    if (playlist.syncUrl == null) {
      return null;
    }

    var match = _playlistSyncUrl.firstMatch(playlist.syncUrl!);
    if (match == null) {
      return null;
    }

    return match.group(1)!;
  }

  Future<BeatSaverPlaylist> getPlaylist(String url) async {
    var data = await get(url);
    var json = Map<String, dynamic>.from(jsonDecode(data));
    var playlist = Playlist.fromJson(json);

    return BeatSaverPlaylist.fromPlaylist(
        playlist, json["owner"]["id"].toString());
  }

  Future _playlistSongOperation(
      String playlistId, bool add, List<String> hashes) async {
    await _refreshSessionIfNeeded();

    var head = Map<String, String>.from(_authHeaders);
    head["Content-Type"] = "application/json";

    for (int i = 0; i < hashes.length;) {
      // Max 100 songs per request
      var step = hashes.skip(i).take(100).toList();
      i += step.length;

      var message = {"hashes": step, "ignoreUnknown": true, "inPlaylist": add};

      var res = await http.post(
          Uri.parse("$_apiUri/playlists/id/$playlistId/batch"),
          headers: head,
          body: jsonEncode(message));

      if (res.statusCode != 200) {
        throw Exception("Failed to update playlist (${res.statusCode})");
      }

      var body = Map<String, dynamic>.from(jsonDecode(res.body));
      if (body["success"] != true) {
        var errors = body["errors"] as List<String>;
        throw Exception("Failed to update playlist: ${errors.join(", ")}");
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future pushPlaylistChanges(Playlist playlist) async {
    // Pushing changes to a playlist is a bit complicated becase we need to manually remove the songs we don't want and add the ones we do
    var id = _getPlaylistIdFromSyncUrl(playlist);
    if (id == null) {
      throw Exception("Invalid playlist push URL");
    }

    // Get the current playlist state
    var remote = await getPlaylist(playlist.syncUrl!);

    // Check this here as getPlaylist may log us out on error
    if (userInfo == null) {
      throw Exception("You must be logged in to push playlists");
    }

    if (remote.ownerId != userInfo!.id) {
      throw Exception("You do not own this playlist");
    }

    var remove = remote.songs
        .where((song) =>
            !playlist.songs.any((element) => element.hash == song.hash))
        .map((e) => e.hash)
        .toList();

    var add = playlist.songs
        .where(
            (song) => !remote.songs.any((element) => element.hash == song.hash))
        .map((e) => e.hash)
        .toList();

    if (remove.isNotEmpty) {
      await _playlistSongOperation(id, false, remove);
    }

    if (add.isNotEmpty) {
      await _playlistSongOperation(id, true, add);
    }
  }
}

class BeatSaverPlaylist extends Playlist {
  final String ownerId;

  BeatSaverPlaylist(this.ownerId);

  factory BeatSaverPlaylist.fromPlaylist(Playlist p, String ownerId) {
    return BeatSaverPlaylist(ownerId)..fromAnotherInstance(p);
  }
}

class UserInfo {
  final String id;
  final String username;
  final String avatar;

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json["id"] as String,
      username: json["username"] as String,
      avatar: json["avatar"] as String,
    );
  }

  UserInfo({required this.id, required this.username, required this.avatar});
}

class MapVersion {
  final String hash;
  final String? coverUrl;
  final String downloadUrl;
  final String state;
  final String createdAt;

  bool get isStatePublished => state == "Published";

  factory MapVersion.fromJson(Map<String, dynamic> json) {
    return MapVersion(
      hash: json["hash"] as String,
      coverUrl: json["coverURL"] as String?,
      downloadUrl: json["downloadURL"] as String,
      state: json["state"] as String,
      createdAt: json["createdAt"] as String,
    );
  }

  MapVersion(
      {required this.hash,
      required this.coverUrl,
      required this.downloadUrl,
      required this.state,
      required this.createdAt});
}

class BeatSaverMapInfo {
  final String lastUpdate;
  final String name;
  final String id;
  final List<MapVersion> versions;

  factory BeatSaverMapInfo.fromJson(Map<String, dynamic> json) {
    return BeatSaverMapInfo(
      lastUpdate: json["lastPublishedAt"] as String,
      name: json["name"] as String,
      id: json["id"] as String,
      versions: (json["versions"] as List<dynamic>)
          .map((e) => MapVersion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  BeatSaverMapInfo(
      {required this.lastUpdate,
      required this.name,
      required this.id,
      required this.versions});
}

class BeatSaverUserInfo {
  final String id;
  final String username;
  final String? avatar;

  BeatSaverUserInfo(
      {required this.id, required this.username, required this.avatar});
}

class BeatSaverLoginNotification {
  final BeatSaverUserInfo? userInfo;
  final String? error;

  BeatSaverLoginNotification({this.userInfo, this.error});
}
