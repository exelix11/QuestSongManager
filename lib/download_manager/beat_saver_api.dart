import 'dart:convert';

import 'package:bsaberquest/main.dart';
import 'package:http/http.dart' as http;

class BeatSaverClient {
  static const String _baseUrl = "https://api.beatsaver.com/";
  final Map<String, String> _headers = {
    "User-Agent": "QuestSongManager/${App.versionName}"
  };

  bool isBeatSaverUrl(String url) {
    var uri = Uri.parse(url);
    return uri.host == "beatsaver.com" || uri.host == "api.beatsaver.com";
  }

  Future<String> get(String url) {
    if (!isBeatSaverUrl(url)) {
      throw Exception("Invalid BeatSaver URL");
    }

    return http.get(Uri.parse(url), headers: _headers).then((res) {
      if (res.statusCode != 200) {
        throw Exception("The server returned an error (${res.statusCode})");
      }

      return res.body;
    });
  }

  Future<BeatSaverMapInfo> getMapById(String id) async {
    var res =
        await http.get(Uri.parse("$_baseUrl/maps/id/$id"), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception("Failed to get map info (${res.statusCode})");
    }

    var map = Map<String, dynamic>.from(jsonDecode(res.body));
    return BeatSaverMapInfo.fromJson(map);
  }

  Future<BeatSaverMapInfo> getMapByHash(String hash) async {
    var res = await http.get(Uri.parse("$_baseUrl/maps/hash/$hash"),
        headers: _headers);
    if (res.statusCode != 200) {
      throw Exception("Failed to get map info (${res.statusCode})");
    }

    var map = Map<String, dynamic>.from(jsonDecode(res.body));
    return BeatSaverMapInfo.fromJson(map);
  }

  Future<List<BeatSaverMapInfo>> getMapsByHashes(List<String> hash) async {
    // rquests are limited to 50 hashes each so we must manually batch this
    List<BeatSaverMapInfo> ret = [];

    for (var i = 0; i < hash.length;) {
      var step = hash.skip(i).take(50).toList();
      i += step.length;

      var query = step.join(",");
      var res = await http.get(Uri.parse("$_baseUrl/maps/hash/$query"),
          headers: _headers);

      if (res.statusCode != 200) {
        throw Exception("Failed to get map info (${res.statusCode})");
      }

      var list = Map<String, dynamic>.from(jsonDecode(res.body));
      ret.addAll(list.values
          .map((e) => BeatSaverMapInfo.fromJson(e as Map<String, dynamic>)));
    }

    return ret;
  }
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
