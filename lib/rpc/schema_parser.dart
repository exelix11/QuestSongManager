import 'package:bsaberquest/download_manager/oauth_config.dart';
import 'package:bsaberquest/rpc/rpc_manager.dart';

class BsSchemaParser {
  static final RegExp _playlistUrlRegex =
      RegExp(r'^https://api.beatsaver.com/playlists/id/(\d+)/download$');

  static RpcCommand? parse(String url) {
    if (url.endsWith("/")) url = url.substring(0, url.length - 1);

    if (url.startsWith(BeatSaverOauthConfig.REDIRECT_URL)) {
      var uri = Uri.parse(url);
      var code = uri.queryParameters["code"];
      if (code == null) return null;
      return RpcCommand.beatSaverOauthLogin(code);
    }

    if (url.startsWith('beatsaver://')) {
      return RpcCommand.downloadSong(url.split('beatsaver://').last);
    }

    if (url.startsWith('bsplaylist://playlist/')) {
      return RpcCommand.downloadPlaylist(
          url.split('bsplaylist://playlist/').last);
    }

    if (_playlistUrlRegex.hasMatch(url)) {
      return RpcCommand.downloadPlaylist(url);
    }

    return null;
  }
}
