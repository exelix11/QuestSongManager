import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bsaberquest/download_manager/oauth_config.dart';
import 'package:bsaberquest/main.dart';
import 'package:bsaberquest/mod_manager/model/playlist.dart';
import 'package:bsaberquest/options/preferences.dart';
import 'package:http/http.dart' as http;

class BeatSaverClient {
  static const String _apiUri = "https://api.beatsaver.com";
  static const String _siteUri = "https://beatsaver.com";

  BeatSaverSession? _session;
  BeatSaverLoginState userState = BeatSaverLoginState.notLoggedIn();

  StreamController<BeatSaverLoginState> loginStateObservable =
      StreamController<BeatSaverLoginState>.broadcast();

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

  Future _refreshSessionIfNeeded({bool logoutOnError = true}) async {
    try {
      if (!BeatSaverOauthConfig.isConfigured) {
        throw Exception("BeatSaver OAuth is not configured in this build");
      }

      // TODO: If in offline mode maybe try resuming the session here since this is called during other network operations too

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
      // The default when we fail to refresh during another request is to log out
      if (logoutOnError) {
        logout(reason: e.toString());
      } else {
        // Otherwise, if this is the app initialization or another process where explicit error handling is better use this flag
        rethrow;
      }
    }
  }

  Future _beginOauthSession() async {
    // Do not call logout in this function as it is used only in the initial session setup
    await _refreshSessionIfNeeded(logoutOnError: false);

    if (_session == null) {
      return;
    }

    var res = await http.get(Uri.parse("$_siteUri/api/oauth2/identity"),
        headers: _authHeaders);

    if (res.statusCode != 200) {
      throw Exception("Failed to get user information (${res.statusCode})");
    }

    var data = Map<String, dynamic>.from(jsonDecode(res.body));
    var userId = data["id"];
    var userName = data["name"];

    // Next it would be nice if we could show the PFP
    String? avatarUrl;

    try {
      var user = await getUserById(userId);
      avatarUrl = user["avatar"];
    } catch (_) {
      // Ignore if this fails
    }

    userState = BeatSaverLoginState.authenticated(
        id: userId, username: userName, avatar: avatarUrl);

    loginStateObservable.add(userState);
  }

  void _disconnectSession(BeatSaverLoginState newState) {
    _session = null;
    _setAuthHeader(null);
    userState = newState;
    loginStateObservable.add(newState);
  }

  void logout({String? reason}) {
    _disconnectSession(BeatSaverLoginState.notLoggedIn(error: reason));
    // On explicit logout, clear the stored session
    App.preferences.beatSaverSession = null;
  }

  // This is the same as logout, but it will not clear the session
  // use in case of network errors when resuming the session to prevent logging out when the app is opened with no internet
  void _offlineMode(String message) {
    _disconnectSession(BeatSaverLoginState.offline(error: message));
  }

  Future tryLoginFromStoredCredentials() async {
    var session = App.preferences.beatSaverSession;
    if (session == null) {
      logout();
      return;
    }

    try {
      useSession(session, true);
    } catch (e) {
      App.showToast(
          "Failed to recover BeatSaver session, please login again ($e)");
    }
  }

  Future useSession(BeatSaverSession session, bool offlineGrace) async {
    if (!BeatSaverOauthConfig.isConfigured) {
      return;
    }

    _session = session;
    _setAuthHeader(session.accessToken);
    try {
      await _beginOauthSession();
    } on SocketException catch (e) {
      // The device is offline, if this is a resume operation, we can continue in offline mode
      if (offlineGrace) {
        _offlineMode(e.toString());
      } else {
        // Otherwise, propagate the error
        rethrow;
      }
    }
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
      useSession(session, false);

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

    return utf8.decode(res.bodyBytes);
  }

  Future<BeatSaverMapInfo> getMapById(String id) async {
    await _refreshSessionIfNeeded();

    var res = await http.get(Uri.parse("$_apiUri/maps/id/$id"),
        headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception("Failed to get map info (${res.statusCode})");
    }

    var map = Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)));
    return BeatSaverMapInfo.fromJson(requestKey: id, map);
  }

  Future<BeatSaverMapInfo> getMapByHash(String hash) async {
    await _refreshSessionIfNeeded();

    var res = await http.get(Uri.parse("$_apiUri/maps/hash/$hash"),
        headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception("Failed to get map info (${res.statusCode})");
    }

    var map = Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)));
    return BeatSaverMapInfo.fromJson(requestHash: hash, map);
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

      var list =
          Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)));
      ret.addAll(list.entries
          .where((e) =>
              e.value !=
              null) // May be null in case of custom songs that beat saver doesn't know
          .map((e) => BeatSaverMapInfo.fromJson(
              requestHash: e.key, e.value as Map<String, dynamic>)));
    }

    return ret;
  }

  Future<Map<String, dynamic>> getUserById(String id) async {
    var res = await http.get(Uri.parse("$_apiUri/users/id/$id"),
        headers: _plainHeaders);
    if (res.statusCode != 200) {
      throw Exception("Failed to get user info (${res.statusCode})");
    }

    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  final RegExp _playlistSyncUrl = RegExp(
      r"^https?:\/\/api\.beatsaver\.com\/playlists\/id\/(\d+)\/download");

  static String makePlaylistLinkUrl(BeatSaverPlaylistMetadata playlist) =>
      "https://api.beatsaver.com/playlists/id/${playlist.id}/download";

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

  Future<String> findPlaylistOwnerById(String playlistId) async {
    var data = await get("$_apiUri/playlists/id/$playlistId");
    var json = Map<String, dynamic>.from(jsonDecode(data));
    return json["playlist"]["owner"]["id"].toString();
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

      var message = {
        "hashes": step,
        "ignoreUnknown": true,
        "inPlaylist": add,
        "keys": []
      };

      var res = await http.post(
          Uri.parse("$_apiUri/playlists/id/$playlistId/batch"),
          headers: head,
          body: jsonEncode(message));

      if (res.statusCode != 200) {
        throw Exception("Failed to update playlist (${res.statusCode})");
      }

      var body =
          Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)));
      if (body["success"] != true) {
        var errors = body["errors"] as List<String>;
        throw Exception("Failed to update playlist: ${errors.join(", ")}");
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<List<BeatSaverPlaylistMetadata>> getUserPlaylists() async {
    if (userState.state != LoginState.authenticated) {
      throw Exception("You must be logged in to view playlists");
    }

    var data = await get("$_apiUri/playlists/user/${userState.userId}/0");
    var json = List<dynamic>.from(jsonDecode(data)["docs"]);
    return json.map((e) => BeatSaverPlaylistMetadata.fromJson(e)).toList();
  }

  Future pushPlaylistChanges(Playlist playlist) async {
    // Pushing changes to a playlist is a bit complicated becase we need to manually remove the songs we don't want and add the ones we do
    var id = _getPlaylistIdFromSyncUrl(playlist);
    if (id == null) {
      throw Exception("Invalid playlist push URL");
    }

    // Get the current playlist state
    var remote =
        await App.downloadManager.downloadPlaylistMetadata(playlist.syncUrl!);
    var owner = await findPlaylistOwnerById(id);

    // Check this here as getPlaylist may log us out on error
    if (userState.state != LoginState.authenticated) {
      throw Exception("You must be logged in to push playlists");
    }

    if (owner != userState.userId) {
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
      hash: (json["hash"] as String).toLowerCase(),
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

class BeatSaverPlaylistMetadata {
  final String id;
  final String name;
  final String authorId;
  final String authorName;
  final String? image;
  final bool private;
  final String downloadUrl;

  bool query(String query) {
    return name.toLowerCase().contains(query) ||
        authorName.toLowerCase().contains(query);
  }

  BeatSaverPlaylistMetadata(
      {required this.id,
      required this.name,
      required this.authorId,
      required this.authorName,
      String? image,
      required this.private,
      required this.downloadUrl})
      : image = image == null
            ? null
            // Sometimes the image is in the format file:// which is not valid
            : (image.startsWith("https://") || image.startsWith("http://")
                ? image
                : null);

  factory BeatSaverPlaylistMetadata.fromJson(Map<String, dynamic> json) {
    return BeatSaverPlaylistMetadata(
      id: (json["playlistId"] as int).toString(),
      name: json["name"] as String,
      authorId: (json["owner"]["id"] as int).toString(),
      authorName: json["owner"]["name"] as String,
      image: json["playlistImage512"] as String? ??
          json["playlistImage"] as String?,
      private: json["type"] == "Private",
      downloadUrl: json["downloadURL"] as String,
    );
  }
}

class BeatSaverMapInfo {
  final String? requestKey;
  final String? requestHash;

  final String lastUpdate;
  final String name;
  final String id;
  final List<MapVersion> versions;

  factory BeatSaverMapInfo.fromJson(Map<String, dynamic> json,
      {String? requestKey, String? requestHash}) {
    return BeatSaverMapInfo(
      requestKey: requestKey,
      requestHash: requestHash?.toLowerCase(),
      lastUpdate: json["lastPublishedAt"] as String,
      name: json["name"] as String,
      id: json["id"] as String,
      versions: (json["versions"] as List<dynamic>)
          .map((e) => MapVersion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  BeatSaverMapInfo(
      {this.requestKey,
      this.requestHash,
      required this.lastUpdate,
      required this.name,
      required this.id,
      required this.versions});
}

enum LoginState { notLoggedIn, authenticated, offline }

class BeatSaverLoginState {
  final LoginState state;

  // When state is logged in, these fields are guaranteed to be non-null
  final String? userId;
  final String? username;

  // This may be null even when logged in
  final String? avatar;

  // WHen offline or not logged in, this field may contain the error message
  final String? error;

  String toGuiMessage() {
    switch (state) {
      case LoginState.notLoggedIn:
        return error == null ? "Not logged in" : "Not logged in ($error)";
      case LoginState.authenticated:
        return "Logged in as $username";
      case LoginState.offline:
        return "You are offline";
    }
  }

  BeatSaverLoginState._(
      {required this.state,
      this.userId,
      this.username,
      this.avatar,
      this.error});

  factory BeatSaverLoginState.notLoggedIn({String? error}) {
    return BeatSaverLoginState._(state: LoginState.notLoggedIn, error: error);
  }

  factory BeatSaverLoginState.authenticated(
      {required String id, required String username, required String? avatar}) {
    return BeatSaverLoginState._(
        state: LoginState.authenticated,
        userId: id,
        username: username,
        avatar: avatar);
  }

  factory BeatSaverLoginState.offline({String? error}) {
    return BeatSaverLoginState._(state: LoginState.offline, error: error);
  }
}
